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

  // DEEP FIX: 4 NEW SERVERS OPTIMIZED FOR HINDI DUB & DUAL AUDIO
  int activeServerIndex = 0;
  final List<Map<String, dynamic>> servers = [
    {'name': 'Server 1 (Auto Hindi/English)', 'color': Colors.green, 'type': 'vidsrc_net'},
    {'name': 'Server 2 (Multi-Audio VIP)', 'color': Colors.greenAccent, 'type': 'vidlink'},
    {'name': 'Server 3 (Dual Audio Mix)', 'color': Colors.orange, 'type': 'autoembed'},
    {'name': 'Server 4 (Backup Fast)', 'color': Colors.blue, 'type': 'vidsrc_to'},
  ];

  @override
  void initState() {
    super.initState();
    
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

    // SERVER 1: VidSrc NET (Often defaults to Hindi/Local IP)
    if (srv == 'vidsrc_net') return isTv ? 'https://vidsrc.net/embed/tv?tmdb=$id&season=$s&episode=$e' : 'https://vidsrc.net/embed/movie?tmdb=$id';
    
    // SERVER 2: VidLink (Has internal gear icon for audio tracks)
    if (srv == 'vidlink') return isTv ? 'https://vidlink.pro/tv/$id/$s/$e' : 'https://vidlink.pro/movie/$id';
    
    // SERVER 3: AutoEmbed (Scrapes multiple dual-audio sources)
    if (srv == 'autoembed') return isTv ? 'https://autoembed.co/tv/tmdb/$id-$s-$e' : 'https://autoembed.co/movie/tmdb/$id';
    
    // SERVER 4: VidSrc TO (Reliable backup)
    return isTv ? 'https://vidsrc.to/embed/tv/$id/$s/$e' : 'https://vidsrc.to/embed/movie/$id';
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
            // SILENT AD KILLER & FAST BUFFERING (No White Screen)
            _controller.runJavaScript('''
              document.addEventListener('click', function(e) {
                var a = e.target.closest('a');
                if (a && a.target === '_blank') { e.preventDefault(); }
              }, true);
              
              window.open = function() { return null; };
              
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
              
              var style = document.createElement('style');
              style.innerHTML = 'div[style*="z-index"] { display: none !important; pointer-events: none !important; }';
              document.head.appendChild(style);
            ''');
          },
        ),
      )
      ..loadRequest(
        Uri.parse(_generateVideoUrl()),
        headers: {'Referer': 'https://hannutv.app/'},
      );

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

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
              const Text("Language Tip: Agar ek server par English/Korean hai, toh doosra server try karein. Kuch servers player ke andar ⚙️ icon se Hindi change karne dete hain.", style: TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _startHideTimer,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            
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

            if (isVideoPlaying && showControls)
              Positioned(
                top: 20,
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
    );
  }
}