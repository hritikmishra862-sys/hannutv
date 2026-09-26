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
  
  bool showServerSelectionUI = true;

  // PROVIDER MANAGER
  int activeServerIndex = 0;
  bool isAutoSwitching = false; 

  final List<Map<String, dynamic>> servers = [
    {'name': 'Olly VIP (Fastest)', 'color': Colors.redAccent, 'type': 'olly'},
    {'name': 'Nyumatflix (Local)', 'color': Colors.blue, 'type': 'nyumat'},
    {'name': 'Vega-Next (HubCloud)', 'color': Colors.purple, 'type': 'vega'}, 
    {'name': 'Flixorent (Debrid)', 'color': Colors.teal, 'type': 'flixorent'}, 
    {'name': 'VidBolt VIP (Hindi)', 'color': Colors.orange, 'type': 'vidbolt'},
    {'name': 'VidLink (Multi)', 'color': Colors.green, 'type': 'vidlink'},
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _startServer(int index) {
    setState(() {
      activeServerIndex = index;
      showServerSelectionUI = false;
      isAutoSwitching = false;
      isVideoPlaying = false;
    });
    _initWebView();
    _startHideTimer();
  }

  // 0.1 SECOND AUTO-FALLBACK ENGINE
  void _triggerAutoFallback() {
    if (isAutoSwitching) return; 
    setState(() { isAutoSwitching = true; });

    // Instantly switch to next server in 100 milliseconds
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        int nextServer = (activeServerIndex + 1) % servers.length;
        _startServer(nextServer);
      }
    });
  }

  String _generateVideoUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) return widget.customUrl!;
    
    final srv = servers[activeServerIndex]['type'];
    final id = widget.tmdbId;
    final s = widget.season;
    final e = widget.episode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    if (srv == 'olly') return isTv ? 'https://ollyembed.pages.dev/tv/$id/$s/$e?server=1' : 'https://ollyembed.pages.dev/movie/$id?server=1';
    if (srv == 'nyumat') return isTv ? 'https://stellar.rip/en/watch/embed/tv/$id-$s-$e?theme=E50914&title=true&poster=true&autoPlay=true' : 'https://stellar.rip/en/watch/embed/movie/$id?theme=E50914&title=true&poster=true&autoPlay=true';
    if (srv == 'vega') return isTv ? 'https://vidsrc.to/embed/tv/$id/$s/$e' : 'https://vidsrc.to/embed/movie/$id';
    if (srv == 'flixorent') return isTv ? 'https://vidsrc.pro/embed/tv/$id/$s/$e' : 'https://vidsrc.pro/embed/movie/$id';
    if (srv == 'vidbolt') return isTv ? 'https://vidbolt.pro/tv/$id/$s/$e?theme=e50914&autoPlay=true&audio=hindi' : 'https://vidbolt.pro/movie/$id?theme=e50914&autoPlay=true&audio=hindi';
    return isTv ? 'https://vidlink.pro/tv/$id/$s/$e' : 'https://vidlink.pro/movie/$id';
  }

  void _initWebView() {
    final srvType = servers[activeServerIndex]['type'];
    final currentHost = Uri.parse(_generateVideoUrl()).host; // Main server host

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'VideoState',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'playing' && mounted) {
            setState(() => isVideoPlaying = true);
          } else if (message.message == 'not_found' && mounted) {
            _triggerAutoFallback();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // THE ULTIMATE AD-KILLER & BLACK SCREEN FIXER
            String jsCode = '''
              // 1. Completely disable window.open to stop new tabs
              window.open = function() { return null; };
              
              // 2. Intercept all clicks to prevent hijack
              document.addEventListener('click', function(e) {
                var a = e.target.closest('a');
                if (a && a.target === '_blank') { 
                  e.preventDefault(); 
                  e.stopPropagation();
                }
              }, true);

              // 3. Black Screen Fix: Force Video Tag to Front & Destroy Ad Overlays
              setInterval(function() {
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0) {
                  // Make video absolute top priority
                  vids[0].style.zIndex = '999999';
                  vids[0].style.position = 'absolute';
                  vids[0].style.top = '0';
                  vids[0].style.left = '0';
                  vids[0].style.width = '100%';
                  vids[0].style.height = '100%';
                  vids[0].style.display = 'block';
                  vids[0].style.visibility = 'visible';
                  vids[0].style.opacity = '1';
                  
                  // Auto trigger play message if moving
                  if (vids[0].currentTime > 0.1) {
                    VideoState.postMessage('playing');
                  }
                }
                
                // Destroy high z-index ad divs
                document.querySelectorAll('div').forEach(el => {
                  let style = window.getComputedStyle(el);
                  if (style.zIndex > 100 && el.tagName !== 'VIDEO') {
                    el.remove();
                  }
                });
              }, 500);
              
              // 4. Ultra-Fast Error Detector
              setInterval(function() {
                var text = document.body.innerText.toLowerCase();
                if (text.includes("video not found") || text.includes("404") || text.includes("server error") || text.includes("reload")) {
                    VideoState.postMessage('not_found');
                }
              }, 100);
            ''';

            _controller.runJavaScript(jsCode);
          },
          
          // STRICT FLUTTER LEVEL NETWORK BLOCKER
          // Agar player redirect hokar kisi ghatiya ad site par ja raha hai, usko block kar dega
          onNavigationRequest: (NavigationRequest request) {
             final url = request.url.toLowerCase();
             
             // Agar main video URL se bahar ja raha hai aur usme ad/bet keywords hain -> BLOCK
             if (!url.contains(currentHost) && !url.contains('hannutv.app')) {
                 if (url.contains('casino') || url.contains('bet') || url.contains('pop') || 
                     url.contains('ads') || url.contains('track') || url.contains('porn') || 
                     url.contains('xxx') || url.contains('redirect')) {
                   return NavigationDecision.prevent; 
                 }
             }
             return NavigationDecision.navigate;
          },
        ),
      );

    // IFRAME WRAPPER FOR EMBED SITES
    if (srvType == 'olly' || srvType == 'vidbolt' || srvType == 'vega' || srvType == 'flixorent') {
       final String htmlContent = '''
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>body, html { margin: 0; padding: 0; width: 100%; height: 100%; background-color: #000; overflow: hidden; } iframe { width: 100%; height: 100%; border: none; }</style>
        </head>
        <body>
            <iframe id="video-player" src="${_generateVideoUrl()}" width="100%" height="100%" frameborder="0" allowfullscreen="true" sandbox="allow-scripts allow-same-origin allow-presentation"></iframe>
            <script>
                window.open = function() { return null; };
                setInterval(function() {
                  var text = document.body.innerText.toLowerCase();
                  if (text.includes("video not found") || text.includes("404")) {
                      VideoState.postMessage('not_found');
                  }
                }, 100);
            </script>
        </body>
        </html>
      ''';
      _controller.loadHtmlString(htmlContent, baseUrl: 'https://hannutv.app/');
    } else {
      _controller.loadRequest(
        Uri.parse(_generateVideoUrl()),
        headers: {'Referer': 'https://hannutv.app/'},
      );
    }

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    // 10 Sec absolute fallback
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && !showServerSelectionUI && !isVideoPlaying) {
         _triggerAutoFallback();
      }
    });
  }

  // --- MANUAL AD KILLER & FORCE PLAY ---
  void _forcePlayAndBypassAds() {
    _controller.runJavaScript('''
      // Nuke everything except the video tag
      document.querySelectorAll('div, a, span, img').forEach(el => {
        let style = window.getComputedStyle(el);
        if(style.position === 'absolute' || style.position === 'fixed') {
           el.remove();
        }
      });
      // Force Play
      var vids = document.getElementsByTagName('video');
      if (vids.length > 0) { 
        vids[0].play(); 
        vids[0].style.zIndex = '999999';
        vids[0].style.display = 'block';
      }
      var iframes = document.getElementsByTagName('iframe');
      if (iframes.length > 0) {
        iframes[0].contentWindow.postMessage('{"event":"command","func":"playVideo","args":""}', '*');
      }
    ''');
    setState(() { isVideoPlaying = true; }); 
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
              const Text("Provider Manager", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...List.generate(servers.length, (index) {
                final srv = servers[index];
                return ListTile(
                  leading: Icon(Icons.dns, color: srv['color'], size: 18),
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
      }
    ''');
    _startHideTimer();
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
        ? _buildServerSelectionUI() 
        : GestureDetector(
            onTap: _startHideTimer,
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                // 1. FAST WEBVIEW PLAYER
                WebViewWidget(controller: _controller),
                
                // 2. HANNUTV WATERMARK LOGO
                if (isVideoPlaying)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: SafeArea(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.5,
                          child: Image.asset('assets/logo.png', height: 35, errorBuilder: (_, __, ___) => const SizedBox()),
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
                        Image.asset('assets/logo.png', height: 60, errorBuilder: (_, __, ___) => const Text('HANNUTV', style: TextStyle(color: Colors.red, fontSize: 30, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 30),
                        const CircularProgressIndicator(color: Colors.red),
                        const SizedBox(height: 15),
                        Text("Connecting to ${servers[activeServerIndex]['name']}...", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 30),
                        // FORCE PLAY BUTTON ON LOADING SCREEN
                        ElevatedButton.icon(
                          onPressed: _forcePlayAndBypassAds,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text("Force Play"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  
                // 4. TOP LEFT: BACK BUTTON
                if (showControls)
                  Positioned(
                    top: 20,
                    left: 20,
                    child: SafeArea(
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                        child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24), onPressed: () => Navigator.pop(context)),
                      ),
                    ),
                  ),

                // 5. PERMANENT FLOATING "AD KILLER" BUTTON (Visible when controls show)
                if (showControls)
                  Positioned(
                    top: 20,
                    right: isVideoPlaying ? 80 : 20, 
                    child: SafeArea(
                      child: ElevatedButton.icon(
                        onPressed: _forcePlayAndBypassAds,
                        icon: const Icon(Icons.block, color: Colors.white, size: 16),
                        label: const Text("Kill Ad & Play"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                      ),
                    ),
                  ),

                // 6. BOTTOM RIGHT: SERVER & CROP BUTTONS
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
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                children: [
                                  Icon(Icons.dns, color: servers[activeServerIndex]['color'], size: 14),
                                  const SizedBox(width: 6),
                                  const Text("Servers", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                            child: IconButton(
                              icon: Icon(isCropped ? Icons.fullscreen_exit : Icons.crop_free, color: Colors.white, size: 24),
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

  // --- USER SELECTION UI ---
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
          const Text("Select a streaming provider to start playing", style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 40),
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 20),
                _buildServerChip(0, Icons.speed, "Fastest"),
                const SizedBox(width: 10),
                _buildServerChip(1, Icons.star, "English"),
                const SizedBox(width: 10),
                _buildServerChip(2, Icons.cloud, "Vega Node"),
                const SizedBox(width: 10),
                _buildServerChip(3, Icons.dns, "Flixorent"),
                const SizedBox(width: 10),
                _buildServerChip(4, Icons.translate, "Hindi Dub"),
                const SizedBox(width: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerChip(int index, IconData icon, String subtitle) {
    final srv = servers[index];
    return GestureDetector(
      onTap: () => _startServer(index),
      child: Container(
        width: 110,
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
            Text(srv['name'].split(' ')[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.center,),
          ],
        ),
      ),
    );
  }
}