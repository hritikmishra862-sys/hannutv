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
  bool isPageLoaded = false;
  
  // SUPERFAST MULTI-SERVER ARCHITECTURE
  int activeServerIndex = 0;
  final List<Map<String, dynamic>> servers = [
    {'name': 'VIP Server (Dual Audio / Fast)', 'color': Colors.green, 'type': 'vidlink'},
    {'name': 'Auto Server (Medium)', 'color': Colors.orange, 'type': 'vidsrc'},
    {'name': 'Premium Server (English UI)', 'color': Colors.blue, 'type': 'stellar'},
  ];

  @override
  void initState() {
    super.initState();
    // Screen ko Fullscreen Landscape karna
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft, 
      DeviceOrientation.landscapeRight
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    _initWebView();
  }

  String _generateVideoUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) return widget.customUrl!;
    
    final srv = servers[activeServerIndex]['type'];
    final id = widget.tmdbId;
    final s = widget.season;
    final e = widget.episode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    // DIRECT LINKS (No middle-man)
    if (srv == 'vidlink') return isTv ? 'https://vidlink.pro/tv/$id/$s/$e' : 'https://vidlink.pro/movie/$id';
    if (srv == 'vidsrc') return isTv ? 'https://vidsrc.to/embed/tv/$id/$s/$e' : 'https://vidsrc.to/embed/movie/$id';
    return isTv ? 'https://stellar.rip/en/watch/embed/tv/$id-$s-$e?theme=E50914&title=true&poster=true&autoPlay=true' : 'https://stellar.rip/en/watch/embed/movie/$id?theme=E50914&title=true&poster=true&autoPlay=true';
  }

  void _initWebView() {
    setState(() => isPageLoaded = false);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black) // Pura background black, no white flash
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => isPageLoaded = true);
          },
          // DEEP FIX: Pura aggressive ad-blocker hata diya hai jo stream rok raha tha.
          // Ab sirf gande domains block honge, baaki player ko saans lene ki puri azaadi hai.
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            if (url.contains('casino') || url.contains('bet') || url.contains('xxx')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse(_generateVideoUrl()), 
        headers: {'Referer': 'https://hannutv.app/'}
      );

    // Audio Mute Bypass
    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }
  }

  void _showServerSelector() {
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
              const Text("Dual Audio tip: Use VIP Server. Click the ⚙️ or CC icon in the player to change language.", style: TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
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
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // RAW WEBVIEW PLAYER (No extra layers causing bugs)
          WebViewWidget(controller: _controller),
          
          // SIMPLE LOADING SCREEN
          if (!isPageLoaded)
            Container(
              color: Colors.black,
              width: double.infinity, height: double.infinity,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.red),
                    const SizedBox(height: 16),
                    Text("Loading ${servers[activeServerIndex]['name']}...", style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            
          // TOP LEFT: BACK BUTTON
          Positioned(
            top: 20, left: 20,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24), onPressed: () => Navigator.pop(context)),
              ),
            ),
          ),

          // TOP RIGHT: SERVER BUTTON
          Positioned(
            top: 20, right: 20,
            child: SafeArea(
              child: GestureDetector(
                onTap: _showServerSelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: servers[activeServerIndex]['color'], size: 12),
                      const SizedBox(width: 6),
                      const Text("Servers", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}