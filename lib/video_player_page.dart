import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class VideoPlayerPage extends StatefulWidget {
  final int tmdbId;
  final String mediaType;
  final int season;
  final int episode;
  final String movieTitle;
  final String? customUrl;

  const VideoPlayerPage({
    Key? key,
    required this.tmdbId,
    required this.mediaType,
    required this.season,
    required this.episode,
    required this.movieTitle,
    this.customUrl,
  }) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final WebViewController _controller;
  
  bool isVideoPlaying = false;
  bool isCropped = false;
  bool showControls = true;
  Timer? _hideTimer;
  
  bool hasAutoSwitched = false;

  // DEEP FIX: 4 PREMIUM SERVERS (Olly, VidBolt Hindi, Stellar, VidLink)
  int activeServerIndex = 0;
  final List<Map<String, dynamic>> servers = [
    {'name': 'Olly VIP (Ad-Free/Fast)', 'color': Colors.redAccent, 'type': 'olly'},
    {'name': 'VidBolt VIP (Auto Hindi)', 'color': Colors.orange, 'type': 'vidbolt'},
    {'name': 'Stellar Premium (English)', 'color': Colors.blue, 'type': 'stellar'},
    {'name': 'VidLink (Dual Audio)', 'color': Colors.green, 'type': 'vidlink'},
  ];

  @override
  void initState() {
    super.initState();
    
    // SCREEN FULLSCREEN LANDSCAPE MODE
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initWebView();
    _startHideTimer();
  }

  String _generateVideoUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) return widget.customUrl!;
    
    final srv = servers[activeServerIndex]['type'];
    final id = widget.tmdbId;
    final s = widget.season;
    final e = widget.episode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    // 1. OLLY EMBED (Ad-Free VIP)
    if (srv == 'olly') return isTv ? 'https://ollyembed.pages.dev/tv/$id/$s/$e?server=1' : 'https://ollyembed.pages.dev/movie/$id?server=1';
    
    // 2. VIDBOLT (Auto Hindi Dub Parameter)
    if (srv == 'vidbolt') return isTv ? 'https://vidbolt.pro/tv/$id/$s/$e?theme=e50914&autoPlay=true&audio=hindi' : 'https://vidbolt.pro/movie/$id?theme=e50914&autoPlay=true&audio=hindi';
    
    // 3. STELLAR (Fallback 1)
    if (srv == 'stellar') return isTv ? 'https://stellar.rip/en/watch/embed/tv/$id-$s-$e?theme=E50914&title=true&poster=true&autoPlay=true' : 'https://stellar.rip/en/watch/embed/movie/$id?theme=E50914&title=true&poster=true&autoPlay=true';

    // 4. VIDLINK (Fallback 2 - Dual Audio inside player)
    return isTv ? 'https://vidlink.pro/tv/$id/$s/$e' : 'https://vidlink.pro/movie/$id';
  }

  void _initWebView() {
    setState(() {
      isVideoPlaying = false;
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'VideoState',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'playing' && mounted) {
            setState(() => isVideoPlaying = true);
          } 
          // DEEP AUTO-FALLBACK: Agar ek server nahi chala toh agle par switch karega
          else if (message.message == 'not_found' && !hasAutoSwitched && mounted) {
            hasAutoSwitched = true; 
            setState(() {
              // Agar Olly fail hua, toh VidBolt par jayega
              activeServerIndex = (activeServerIndex + 1) % servers.length;
            });
            _initWebView();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            // STRICT AD BLOCKER: Sirf iframe and video content allow karega
            if (url.contains('casino') || url.contains('bet') || url.contains('ads') || url.contains('pop') || url.contains('track')) {
              return NavigationDecision.prevent; 
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // DEEP FIX FOR VIDBOLT "IFRAME ERROR": We create a virtual HTML page with an iframe
    final String htmlContent = '''
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
              body, html { margin: 0; padding: 0; width: 100%; height: 100%; background-color: #000; overflow: hidden; }
              iframe { width: 100%; height: 100%; border: none; }
          </style>
      </head>
      <body>
          <iframe id="video-player" src="${_generateVideoUrl()}" width="100%" height="100%" frameborder="0" allowfullscreen="true" allow="autoplay; fullscreen; encrypted-media"></iframe>
          <script>
              // 1. INVISIBLE AD SHIELD: Prevents any new tabs or popup clicks
              document.addEventListener('click', function(e) {
                  var a = e.target.closest('a');
                  if (a && a.target === '_blank') { e.preventDefault(); }
              }, true);
              window.open = function() { return null; };
              
              // 2. VIDEO NOT FOUND CHECKER (Auto-Fallback logic)
              var checkError = setInterval(function() {
                  var text = document.body.innerText.toLowerCase();
                  if (text.includes("video not found") || text.includes("404")) {
                      VideoState.postMessage('not_found');
                      clearInterval(checkError);
                  }
              }, 1000);

              // 3. PLAYER READY SIGNAL
              setTimeout(function() {
                  VideoState.postMessage('playing');
              }, 4000); // 4 seconds loading screen, then bypass
          </script>
      </body>
      </html>
    ''';

    // Load as a virtual website to trick the servers
    _controller.loadHtmlString(htmlContent, baseUrl: 'https://hannutv.app/');

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (mounted) {
      setState(() => showControls = true);
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => showControls = false);
      }
    });
  }

  void _showServerSelector() {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Streaming Server", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Olly VIP is Ad-Free. VidBolt tries to load Hindi Audio automatically.", style: TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ...List.generate(servers.length, (index) {
                final srv = servers[index];
                return ListTile(
                  leading: Icon(Icons.circle, color: srv['color'], size: 16),
                  title: Text(srv['name'], style: TextStyle(color: activeServerIndex == index ? Colors.red : Colors.white, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    if (activeServerIndex != index) {
                      setState(() {
                        activeServerIndex = index;
                        hasAutoSwitched = false; // Reset fallback
                      });
                      _initWebView(); 
                    } else {
                      _startHideTimer();
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    ).then((_) => _startHideTimer());
  }

  void toggleCrop() {
    setState(() => isCropped = !isCropped);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // POPSCOPE: Protects against ad hijacks
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _startHideTimer,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // 1. FAST IFRAME WEBVIEW PLAYER
              WebViewWidget(controller: _controller),
              
              // 2. HANNUTV WATERMARK LOGO (Transparent, Top Right)
              if (isVideoPlaying)
                Positioned(
                  top: 20,
                  right: 20,
                  child: SafeArea(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.5,
                        child: Image.asset(
                          'assets/logo.png',
                          height: 35,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. HANNUTV LOADING SCREEN
              if (!isVideoPlaying)
                Container(
                  color: Colors.black,
                  width: double.infinity,
                  height: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        height: 60,
                        errorBuilder: (_, __, ___) => const Text(
                          'HANNUTV',
                          style: TextStyle(color: Colors.red, fontSize: 30, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const CircularProgressIndicator(color: Colors.red),
                      const SizedBox(height: 15),
                      Text(
                        "Connecting to ${servers[activeServerIndex]['name']}...",
                        style: const TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
                
              // 4. TOP LEFT: BACK BUTTON (Auto Hides)
              if (isVideoPlaying && showControls)
                Positioned(
                  top: 20,
                  left: 20,
                  child: SafeArea(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),

              // 5. BOTTOM RIGHT: SERVER & CROP BUTTONS (Auto Hides)
              if (isVideoPlaying && showControls)
                Positioned(
                  bottom: 20, // Moved to bottom to avoid overlapping Watermark
                  right: 20,
                  child: SafeArea(
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _showServerSelector,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.circle, color: servers[activeServerIndex]['color'], size: 12),
                                const SizedBox(width: 6),
                                const Text("Servers", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              isCropped ? Icons.fullscreen_exit : Icons.crop_free,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: toggleCrop,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}