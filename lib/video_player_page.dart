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

  // DEEP FIX: OLLY EMBED ADDED AS VIP AD-FREE SERVER
  int activeServerIndex = 0;
  final List<Map<String, dynamic>> servers = [
    {'name': 'Olly VIP (Ad-Free / Fast)', 'color': Colors.redAccent, 'type': 'olly'},
    {'name': 'Server 2 (Dual Audio Mix)', 'color': Colors.green, 'type': 'vidlink'},
    {'name': 'Server 3 (Auto Server)', 'color': Colors.orange, 'type': 'vidsrc_net'},
    {'name': 'Server 4 (Backup)', 'color': Colors.blue, 'type': 'stellar'},
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

    // 1. OLLY EMBED (Ad-Free API added from your request)
    if (srv == 'olly') return isTv ? 'https://ollyembed.pages.dev/tv/$id/$s/$e?server=1' : 'https://ollyembed.pages.dev/movie/$id?server=1';
    
    // 2. VidLink (Dual Audio support inside player)
    if (srv == 'vidlink') return isTv ? 'https://vidlink.pro/tv/$id/$s/$e' : 'https://vidlink.pro/movie/$id';
    
    // 3. VidSrc Net
    if (srv == 'vidsrc_net') return isTv ? 'https://vidsrc.net/embed/tv?tmdb=$id&season=$s&episode=$e' : 'https://vidsrc.net/embed/movie?tmdb=$id';
    
    // 4. Stellar (English Backup)
    return isTv ? 'https://stellar.rip/en/watch/embed/tv/$id-$s-$e?theme=E50914&title=true&poster=true&autoPlay=true' : 'https://stellar.rip/en/watch/embed/movie/$id?theme=E50914&title=true&poster=true&autoPlay=true';
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
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // DEEP FIX: INVISIBLE AD KILLER & FAST BUFFERING
            _controller.runJavaScript('''
              // 1. Silent Ad Click Killer
              document.addEventListener('click', function(e) {
                var a = e.target.closest('a');
                if (a && a.target === '_blank') { e.preventDefault(); }
              }, true);
              
              // 2. Kill Popups
              window.open = function() { return null; };
              
              // 3. Fast Buffer and Status Checker
              var checkVideo = setInterval(function() {
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0) {
                  vids[0].preload = 'auto'; // FAST BUFFER
                  if (vids[0].currentTime > 0.1) {
                    VideoState.postMessage('playing');
                    clearInterval(checkVideo);
                  }
                }
              }, 500);
              
              // 4. Hide server text overlays
              var style = document.createElement('style');
              style.innerHTML = 'div[style*="z-index"] { display: none !important; pointer-events: none !important; }';
              document.head.appendChild(style);
            ''');
          },
          // SMART NETWORK BLOCKER: Sirf obvious ads ko block karega
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            if (url.contains('casino') || url.contains('bet') || url.contains('tracking') || url.contains('pop')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse(_generateVideoUrl()),
        headers: {'Referer': 'https://hannutv.app/'},
      );

    // Audio Autoplay Bypass
    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    // 12 Second fallback loading timeout
    Future.delayed(const Duration(seconds: 12), () {
      if (mounted && !isVideoPlaying) {
        setState(() => isVideoPlaying = true);
      }
    });
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
              const Text("Olly VIP is completely Ad-Free. For Dual Audio (Hindi), try Server 2 and click the ⚙️ icon inside the player.", style: TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ...List.generate(servers.length, (index) {
                final srv = servers[index];
                return ListTile(
                  leading: Icon(Icons.circle, color: srv['color'], size: 16),
                  title: Text(srv['name'], style: TextStyle(color: activeServerIndex == index ? Colors.red : Colors.white, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    if (activeServerIndex != index) {
                      setState(() => activeServerIndex = index);
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
    _controller.runJavaScript('''
      var vids = document.getElementsByTagName('video');
      if (vids.length > 0) {
        vids[0].style.objectFit = '${isCropped ? "cover" : "contain"}';
        vids[0].style.width = '100%';
        vids[0].style.height = '100%';
      }
    ''');
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
    // POPSCOPE: Deep logic to return to video if ad redirects the page
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Agar ad ki wajah se page aage chala gaya hai, toh back daba kar video pe wapas aao
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          // Warna screen close kardo
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
              // 1. FAST RAW WEBVIEW PLAYER
              WebViewWidget(controller: _controller),
              
              // 2. WATERMARK LOGO (Right Corner) - Always visible, semi-transparent
              if (isVideoPlaying)
                Positioned(
                  top: 20,
                  right: 20,
                  child: SafeArea(
                    child: IgnorePointer( // Touch ko video tak pass hone dega
                      child: Opacity(
                        opacity: 0.6, // Transparent effect
                        child: Image.asset(
                          'assets/logo.png',
                          height: 35, // Chota watermark size
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
                        "Loading ${servers[activeServerIndex]['name']}...",
                        style: const TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
                
              // 4. TOP LEFT: BACK BUTTON (Auto Hides in 3s)
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

              // 5. BOTTOM RIGHT: SERVER & CROP BUTTONS (Auto Hides in 3s)
              if (isVideoPlaying && showControls)
                Positioned(
                  bottom: 20, // Niche move kiya taaki Watermark se overlap na ho
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