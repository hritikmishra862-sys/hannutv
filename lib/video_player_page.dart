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
  
  bool hasAutoSwitched = false; // To stop infinite fallback loops

  // DEEP FIX: VIDBOLT ADDED AS VIP SERVER (WITH DEFAULT HINDI AUDIO)
  int activeServerIndex = 0;
  final List<Map<String, dynamic>> servers = [
    {'name': 'VidBolt VIP (Auto Hindi/Fast)', 'color': Colors.redAccent, 'type': 'vidbolt'},
    {'name': 'Premium Server (English/Dual)', 'color': Colors.blue, 'type': 'stellar'},
    {'name': 'Server 3 (Multi-Audio)', 'color': Colors.green, 'type': 'vidlink'},
    {'name': 'Auto Server (Backup)', 'color': Colors.orange, 'type': 'vidsrc_net'},
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

    // 1. VIDBOLT API (Primary VIP - Direct Hindi Parameter Added)
    if (srv == 'vidbolt') {
      return isTv 
          ? 'https://vidbolt.pro/tv/$id/$s/$e?theme=e50914&autoPlay=true&audio=hindi' 
          : 'https://vidbolt.pro/movie/$id?theme=e50914&autoPlay=true&audio=hindi';
    }
    
    // 2. STELLAR (Fallback 1)
    if (srv == 'stellar') return isTv ? 'https://stellar.rip/en/watch/embed/tv/$id-$s-$e?theme=E50914&title=true&poster=true&autoPlay=true' : 'https://stellar.rip/en/watch/embed/movie/$id?theme=E50914&title=true&poster=true&autoPlay=true';

    // 3. VIDLINK (Fallback 2 - Dual Audio inside player)
    if (srv == 'vidlink') return isTv ? 'https://vidlink.pro/tv/$id/$s/$e' : 'https://vidlink.pro/movie/$id';
    
    // 4. VIDSRC NET (Backup)
    return isTv ? 'https://vidsrc.net/embed/tv?tmdb=$id&season=$s&episode=$e' : 'https://vidsrc.net/embed/movie?tmdb=$id';
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
          // DEEP AUTO-FALLBACK: Agar VidBolt par movie na mile, toh Stellar par switch kardo
          else if (message.message == 'not_found' && !hasAutoSwitched && mounted) {
            hasAutoSwitched = true; 
            setState(() {
              activeServerIndex = 1; // Auto-shift to Stellar
            });
            _initWebView(); // Reload automatically
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // DEEP JAVASCRIPT INJECTION: Ad Killer, AutoPlay & "Video Not Found" Detector
            _controller.runJavaScript('''
              // 1. Silent Ad Click Killer (Prevents popup ads from opening)
              document.addEventListener('click', function(e) {
                var a = e.target.closest('a');
                if (a && a.target === '_blank') { e.preventDefault(); }
              }, true);
              
              window.open = function() { return null; };
              
              // 2. Video Not Found Auto-Detector
              var checkError = setInterval(function() {
                var bodyText = document.body.innerText || "";
                if (bodyText.includes("Video Not Found") || bodyText.includes("404") || bodyText.includes("not found")) {
                  VideoState.postMessage('not_found');
                  clearInterval(checkError);
                }
              }, 1000);
              
              // 3. Fast Buffer & State Checker
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
              
              // 4. Hide server text overlays (To clean the UI)
              var style = document.createElement('style');
              style.innerHTML = 'div[style*="z-index"] { display: none !important; pointer-events: none !important; }';
              document.head.appendChild(style);
            ''');
          },
          // STRICT AD BLOCKER (WHITELIST MODE) - VidBolt added to allowed list
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            // Sirf trusted servers ko load hone do, baaki sab (ads) block.
            if (!url.contains('vidbolt') && !url.contains('vidlink') && !url.contains('vidsrc') && !url.contains('stellar')) {
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

    // Audio Autoplay Bypass for Android
    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    // Fallback loading timeout (Player screen dikhane ke liye)
    Future.delayed(const Duration(seconds: 10), () {
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
              const Text("Note: VidBolt tries to load Hindi Audio automatically. If it fails, the app will switch to Premium Server.", style: TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
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
                        hasAutoSwitched = false; // Reset fallback trigger
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
    // POPSCOPE: Ad-Hijack protection.
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
              // 1. FAST RAW WEBVIEW PLAYER (VIDBOLT INTEGRATED)
              WebViewWidget(controller: _controller),
              
              // 2. RIGHT CORNER WATERMARK LOGO (Transparent)
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
}