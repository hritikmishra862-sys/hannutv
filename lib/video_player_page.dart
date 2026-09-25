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
  
  bool isVideoLoading = true; // HANNUTV Loading Screen State
  bool isCropped = false;
  
  // AUTO-HIDE UI CONTROLS
  bool showControls = true; 
  Timer? _hideTimer;
  
  // SUPERFAST MULTI-SERVER ARCHITECTURE
  int activeServerIndex = 0;
  final List<Map<String, dynamic>> servers = [
    {'name': 'VIP Server (Dual Audio / SuperFast)', 'color': Colors.green, 'type': 'vidlink'},
    {'name': 'Auto Server (Fast & Clean)', 'color': Colors.greenAccent, 'type': 'vidsrc'},
    {'name': 'Premium Server (English UI)', 'color': Colors.orange, 'type': 'stellar'},
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
    // Force Screen to Landscape and Hide Notification/Navigation Bars
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  String _generateVideoUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) return widget.customUrl!;
    
    final srv = servers[activeServerIndex]['type'];
    final id = widget.tmdbId;
    final s = widget.season;
    final e = widget.episode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    // 1. VIP SERVER (VidLink) - Best for Dual Audio & Fast Loading
    if (srv == 'vidlink') return isTv ? 'https://vidlink.pro/tv/$id/$s/$e' : 'https://vidlink.pro/movie/$id';
    // 2. AUTO SERVER (VidSrc) - SuperFast Alternative
    if (srv == 'vidsrc') return isTv ? 'https://vidsrc.to/embed/tv/$id/$s/$e' : 'https://vidsrc.to/embed/movie/$id';
    // 3. PREMIUM SERVER (Stellar)
    if (srv == 'stellar') return isTv ? 'https://stellar.rip/en/watch/embed/tv/$id-$s-$e?theme=E50914&title=true&poster=true&autoPlay=true' : 'https://stellar.rip/en/watch/embed/movie/$id?theme=E50914&title=true&poster=true&autoPlay=true';
    // 4. BACKUP SERVER
    return isTv ? 'https://cinesrc.st/embed/tv/$id?s=$s&e=$e&autoplay=true' : 'https://cinesrc.st/embed/movie/$id?autoplay=true';
  }

  void _initWebView() {
    setState(() => isVideoLoading = true);
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // DEEP FIX: Background strictly black, prevents white flashes
      ..setBackgroundColor(Colors.black) 
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // DEEP FIX: Only kill simple popups (window.open), DO NOT block stream CDNs
            _controller.runJavaScript('''
              window.open = function() { return null; };
              // Hide annoying server texts seamlessly
              var style = document.createElement('style');
              style.innerHTML = 'div[style*="z-index"] { display: none !important; }';
              document.head.appendChild(style);
            ''');
          },
          // REMOVED onNavigationRequest COMPLETELY: This is what caused the White Screen. 
          // Now the stream will load 1000% without being blocked by Flutter.
        ),
      )
      ..loadRequest(Uri.parse(_generateVideoUrl()), headers: {'Referer': 'https://hannutv.app/'});

    // ANDROID AUDIO AUTOPLAY BYPASS
    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    // SUPERFAST BYPASS: HANNUTV Loading screen will forcefully disappear after exactly 3.5 seconds
    // No more waiting for CORS or video tags to respond. It just works.
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted && isVideoLoading) {
        setState(() => isVideoLoading = false);
      }
    });
  }

  // 3-SECOND AUTO-HIDE LOGIC
  void _startHideTimer() {
    _hideTimer?.cancel();
    if (mounted) setState(() => showControls = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => showControls = false);
    });
  }

  void _showServerSelector() {
    _hideTimer?.cancel(); // Menu open hone par buttons hide nahi honge
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
              const Text("Dual Audio tip: Use VIP Server. Click the ⚙️ or 🎧 icon inside the player to change language.", style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
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
                      _initWebView(); // Change server and reload
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

  // CROP / FULLSCREEN TOGGLE
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
    _startHideTimer(); // Button dabane ke baad timer reset
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    // Back aane par phone seedha (Portrait) ho jayega aur status bar wapas aayegi
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        // Kahi bhi touch karne par buttons 3 sec ke liye wapas aayenge
        onPointerDown: (_) => _startHideTimer(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // MAIN VIDEO PLAYER (Always Black Background, No White Screen)
            Container(
              color: Colors.black,
              child: WebViewWidget(controller: _controller),
            ),
            
            // HANNUTV LOADING SCREEN (Disappears automatically after 3.5s)
            if (isVideoLoading)
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
            AnimatedOpacity(
              opacity: (!isVideoLoading && showControls) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Positioned(
                top: 20, left: 20,
                child: SafeArea(
                  child: IgnorePointer(
                    ignoring: !showControls,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                      child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24), onPressed: () => Navigator.pop(context)),
                    ),
                  ),
                ),
              ),
            ),

            // TOP RIGHT: SERVER & CROP BUTTONS (Auto hides after 3s)
            AnimatedOpacity(
              opacity: (!isVideoLoading && showControls) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Positioned(
                top: 20, right: 20,
                child: SafeArea(
                  child: IgnorePointer(
                    ignoring: !showControls,
                    child: Row(
                      children: [
                        // SERVER CHANGE BUTTON
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
            ),
          ],
        ),
      ),
    );
  }
}