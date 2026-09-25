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
  final String? customUrl; // Cloud uploads ke liye

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
  
  // AUTO-HIDE LOGIC
  bool showControls = true; 
  Timer? _hideTimer;
  
  // MULTI-SERVER ARCHITECTURE (Dual Audio & Fast Buffering)
  int activeServerIndex = 0;
  final List<Map<String, dynamic>> servers = [
    {'name': 'VIP Server (Dual Audio / SuperFast)', 'color': Colors.green, 'type': 'vidlink'},
    {'name': 'Premium Server (English UI)', 'color': Colors.green, 'type': 'stellar'},
    {'name': 'Auto Server (Medium)', 'color': Colors.orange, 'type': 'vidsrc'},
    {'name': 'Backup Server (Slow)', 'color': Colors.red, 'type': 'cinesrc'},
  ];

  @override
  void initState() {
    super.initState();
    _setupLandscapeMode();
    _initWebView();
    _startHideTimer();
  }

  void _setupLandscapeMode() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  String _generateVideoUrl() {
    // Agar custom cloud upload hai
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) return widget.customUrl!;
    
    final srv = servers[activeServerIndex]['type'];
    final id = widget.tmdbId;
    final s = widget.season;
    final e = widget.episode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    // SERVER 1: VIP SERVER (VidLink) - Native Dual Audio Selector
    if (srv == 'vidlink') return isTv ? 'https://vidlink.pro/tv/$id/$s/$e' : 'https://vidlink.pro/movie/$id';
    
    // SERVER 2: PREMIUM (Stellar)
    if (srv == 'stellar') return isTv ? 'https://stellar.rip/en/watch/embed/tv/$id-$s-$e?theme=E50914&title=true&poster=true&autoPlay=true' : 'https://stellar.rip/en/watch/embed/movie/$id?theme=E50914&title=true&poster=true&autoPlay=true';
    
    // SERVER 3: AUTO (Vidsrc)
    if (srv == 'vidsrc') return isTv ? 'https://vidsrc.to/embed/tv/$id/$s/$e' : 'https://vidsrc.to/embed/movie/$id';
    
    // SERVER 4: BACKUP (Cinesrc)
    return isTv ? 'https://cinesrc.st/embed/tv/$id?s=$s&e=$e&autoplay=true' : 'https://cinesrc.st/embed/movie/$id?autoplay=true';
  }

  void _initWebView() {
    setState(() => isVideoPlaying = false);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('VideoState', onMessageReceived: (message) {
        if (message.message == 'playing' && mounted) setState(() => isVideoPlaying = true);
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // DEEP CODING: Kill Ads, FAST BUFFER (5s limit), and UI Cleanup
            _controller.runJavaScript('''
              window.open = function() { return null; };
              var checkVideo = setInterval(function() {
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0) {
                  vids[0].preload = 'auto'; // FORCE FAST BACKGROUND BUFFER
                  if (vids[0].currentTime > 0.1) {
                    VideoState.postMessage('playing');
                    clearInterval(checkVideo);
                  }
                }
              }, 500);
              var style = document.createElement('style');
              style.innerHTML = 'div[style*="z-index"] { display: none !important; }';
              document.head.appendChild(style);
            ''');
          },
          onNavigationRequest: (request) {
            // Sirf player links allow karo, baaki saare ads block
            if (!request.url.contains(servers[activeServerIndex]['type']) && !request.url.contains('stellar') && !request.url.contains('vidlink') && !request.url.contains('vidsrc')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_generateVideoUrl()), headers: {'Referer': 'https://hannutv.app/'});

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    // FAST 5 SECOND TIMEOUT - Agar video API slow hai toh bhi controls dikha do
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && !isVideoPlaying) setState(() => isVideoPlaying = true);
    });
  }

  // AUTO-HIDE UI CONTROLS AFTER 3 SECONDS
  void _startHideTimer() {
    _hideTimer?.cancel();
    if (mounted) setState(() => showControls = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => showControls = false);
    });
  }

  // BOTTOM SHEET TO CHANGE SERVERS
  void _showServerSelector() {
    _hideTimer?.cancel(); // Menu khulne par hide mat karo
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
              const Text("Dual Audio tip: Click the ⚙️ or 🎧 icon in the player to change language.", style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
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
                      _initWebView(); // Naya server load karo
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
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Screen pe tap karte hi buttons dikhenge aur 3 sec me gayab honge
        onTap: _startHideTimer, 
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            
            if (!isVideoPlaying)
              Container(
                color: Colors.black,
                width: double.infinity, height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/logo.png', height: 60, errorBuilder: (_, __, ___) => const Text('HANNUTV', style: TextStyle(color: Colors.red, fontSize: 30, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 30),
                    const CircularProgressIndicator(color: Colors.red),
                    const SizedBox(height: 15),
                    Text("Connecting to ${servers[activeServerIndex]['name']}...", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              
            // TOP LEFT: BACK BUTTON (Auto hides after 3s)
            if (isVideoPlaying)
              AnimatedOpacity(
                opacity: showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Positioned(
                  top: 20, left: 20,
                  child: SafeArea(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                      child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24), onPressed: () => Navigator.pop(context)),
                    ),
                  ),
                ),
              ),

            // TOP RIGHT: SERVER & CROP BUTTONS (Auto hides after 3s)
            if (isVideoPlaying)
              AnimatedOpacity(
                opacity: showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Positioned(
                  top: 20, right: 20,
                  child: SafeArea(
                    child: Row(
                      children: [
                        // SERVER CHANGE BUTTON (Shows Green/Orange/Red dot)
                        GestureDetector(
                          onTap: _showServerSelector,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
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
                        // CROP BUTTON
                        Container(
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                          child: IconButton(icon: Icon(isCropped ? Icons.fullscreen_exit : Icons.crop_free, color: Colors.white, size: 24), onPressed: toggleCrop),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}