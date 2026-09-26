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
  late WebViewController _controller;
  
  bool isVideoPlaying = false;
  bool isCropped = false;
  bool showControls = true;
  Timer? _hideTimer;
  
  bool showServerSelectionUI = true; // PLAY KARNE SE PEHLE UI DIKHEGA!

  // DEEP FIX: Saare servers add kar diye hain. "Stellar" ki jagah "Nyumatflix" kar diya!
  int activeServerIndex = 0;
  final List<Map<String, dynamic>> servers = [
    {'name': 'Olly VIP (Ad-Free)', 'color': Colors.redAccent, 'type': 'olly'},
    {'name': 'Nyumatflix (Premium)', 'color': Colors.blue, 'type': 'nyumat'},
    {'name': 'VidBolt VIP (Hindi Dub)', 'color': Colors.orange, 'type': 'vidbolt'},
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

    // Auto-load Olly Embed after 4 seconds IF user does not select any server
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && showServerSelectionUI) {
        _startServer(0); // Default to Olly VIP
      }
    });
  }

  void _startServer(int index) {
    setState(() {
      activeServerIndex = index;
      showServerSelectionUI = false;
    });
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

    // 1. OLLY EMBED
    if (srv == 'olly') return isTv ? 'https://ollyembed.pages.dev/tv/$id/$s/$e?server=1' : 'https://ollyembed.pages.dev/movie/$id?server=1';
    
    // 2. NYUMATFLIX (Stellar Replaced)[cite: 17, 18]
    if (srv == 'nyumat') return isTv ? 'https://stellar.rip/en/watch/embed/tv/$id-$s-$e?theme=E50914&title=true&poster=true&autoPlay=true' : 'https://stellar.rip/en/watch/embed/movie/$id?theme=E50914&title=true&poster=true&autoPlay=true';

    // 3. VIDBOLT (Ad-Free iframe logic will be applied)
    if (srv == 'vidbolt') return isTv ? 'https://vidbolt.pro/tv/$id/$s/$e?theme=e50914&autoPlay=true&audio=hindi' : 'https://vidbolt.pro/movie/$id?theme=e50914&autoPlay=true&audio=hindi';

    // 4. VIDLINK
    return isTv ? 'https://vidlink.pro/tv/$id/$s/$e' : 'https://vidlink.pro/movie/$id';
  }

  void _initWebView() {
    setState(() {
      isVideoPlaying = false;
    });

    final srvType = servers[activeServerIndex]['type'];

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
            // UNIVERSAL AD-BLOCK & AUTOPLAY JAVASCRIPT
            _controller.runJavaScript('''
              // 1. Silent Ad Click Killer
              document.addEventListener('click', function(e) {
                var a = e.target.closest('a');
                if (a && a.target === '_blank') { e.preventDefault(); }
              }, true);
              
              window.open = function() { return null; };
              
              // 2. Fast Buffer & AutoPlay Checker
              var checkVideo = setInterval(function() {
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0) {
                  vids[0].preload = 'auto'; 
                  if (vids[0].currentTime > 0.1) {
                    VideoState.postMessage('playing');
                    clearInterval(checkVideo);
                  }
                }
              }, 500);
              
              // 3. Hide annoying server texts
              var style = document.createElement('style');
              style.innerHTML = 'div[style*="z-index"] { display: none !important; pointer-events: none !important; }';
              document.head.appendChild(style);
            ''');
          },
          // STRICT AD BLOCKER: Sirf trusted servers ko load hone do, baaki sab (ads) block.
          onNavigationRequest: (NavigationRequest request) {
             if (srvType != 'olly' && srvType != 'vidbolt') {
               final url = request.url.toLowerCase();
               if (url.contains('casino') || url.contains('bet') || url.contains('pop') || url.contains('ads')) {
                 return NavigationDecision.prevent; 
               }
             }
             return NavigationDecision.navigate;
          },
        ),
      );

    // DEEP FIX FOR OLLY & VIDBOLT (Requires Iframe)
    if (srvType == 'olly' || srvType == 'vidbolt') {
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
                // Prevent Popups inside Iframe
                document.addEventListener('click', function(e) {
                    var a = e.target.closest('a');
                    if (a && a.target === '_blank') { e.preventDefault(); }
                }, true);
                window.open = function() { return null; };
                
                setTimeout(function() { VideoState.postMessage('playing'); }, 5000);
            </script>
        </body>
        </html>
      ''';
      _controller.loadHtmlString(htmlContent, baseUrl: 'https://hannutv.app/');
    } else {
      // Nyumatflix & VidLink load directly
      _controller.loadRequest(
        Uri.parse(_generateVideoUrl()),
        headers: {'Referer': 'https://hannutv.app/'},
      );
    }

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    // 12 Sec Timeout Fallback
    Future.delayed(const Duration(seconds: 12), () {
      if (mounted && !showServerSelectionUI && !isVideoPlaying) {
        setState(() => isVideoPlaying = true);
      }
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (mounted && !showServerSelectionUI) {
      setState(() => showControls = true);
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !showServerSelectionUI) {
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
              const Text("Change Streaming Server", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("If 'Video Not Found', please select another server from the list below.", style: TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ...List.generate(servers.length, (index) {
                final srv = servers[index];
                return ListTile(
                  leading: Icon(Icons.circle, color: srv['color'], size: 16),
                  title: Text(srv['name'], style: TextStyle(color: activeServerIndex == index ? Colors.red : Colors.white, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    if (activeServerIndex != index) {
                       _startServer(index);
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (!showServerSelectionUI && await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: showServerSelectionUI 
        ? _buildServerSelectionUI() // <--- INITIAL SERVER SELECTOR (Smart UI)
        : GestureDetector(
            onTap: _startHideTimer,
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                // 1. FAST WEBVIEW PLAYER
                WebViewWidget(controller: _controller),
                
                // 2. HANNUTV WATERMARK LOGO (Right Corner)
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
                  
                // 4. TOP LEFT: BACK BUTTON
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

                // 5. BOTTOM RIGHT: SERVER & CROP BUTTONS
                if (isVideoPlaying && showControls)
                  Positioned(
                    bottom: 20,
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

  // --- SMART UI: SHOWS BEFORE VIDEO LOADS ---
  Widget _buildServerSelectionUI() {
    return Container(
      color: Colors.black,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logo.png', height: 80, errorBuilder: (_,__,___) => const SizedBox()),
          const SizedBox(height: 20),
          Text(widget.movieTitle, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          const Text("Select a streaming server to start playing", style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 40),
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 20),
                _buildServerChip(0, Icons.speed, "Fastest"),
                const SizedBox(width: 15),
                _buildServerChip(1, Icons.star, "English/Local"),
                const SizedBox(width: 15),
                _buildServerChip(2, Icons.translate, "Hindi Dub"),
                const SizedBox(width: 15),
                _buildServerChip(3, Icons.audiotrack, "Multi-Audio"),
                const SizedBox(width: 20),
              ],
            ),
          ),
          
          const SizedBox(height: 50),
          const CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
          const SizedBox(height: 15),
          const Text("Auto-starting Olly VIP in 4 seconds...", style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildServerChip(int index, IconData icon, String subtitle) {
    final srv = servers[index];
    return GestureDetector(
      onTap: () => _startServer(index),
      child: Container(
        width: 115,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: srv['color'], width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: srv['color'], size: 28),
            const SizedBox(height: 12),
            Text(srv['name'].split(' ')[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.center,),
          ],
        ),
      ),
    );
  }
}