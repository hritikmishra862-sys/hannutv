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
  Timer? _fallbackTimer;

  bool showServerSelectionUI = true;
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
    _fallbackTimer?.cancel();
    setState(() {
      activeServerIndex = index;
      showServerSelectionUI = false;
      isAutoSwitching = false;
      isVideoPlaying = false;
    });
    _initWebView();
    _startHideTimer();
  }

  void _triggerAutoFallback() {
    if (isAutoSwitching || !mounted) return;
    setState(() => isAutoSwitching = true);

    // 1.5s delay to allow player iframe to initialize without instant jumping
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        int nextServer = (activeServerIndex + 1) % servers.length;
        _startServer(nextServer);
      }
    });
  }

  String _generateVideoUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) {
      return widget.customUrl!;
    }

    final srv = servers[activeServerIndex]['type'];
    final id = widget.tmdbId;
    final s = widget.season;
    final e = widget.episode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    if (srv == 'olly') {
      return isTv
          ? 'https://ollyembed.pages.dev/tv/$id/$s/$e?server=1'
          : 'https://ollyembed.pages.dev/movie/$id?server=1';
    }
    if (srv == 'nyumat') {
      return isTv
          ? 'https://stellar.rip/en/watch/embed/tv/$id-$s-$e?theme=E50914&title=true&poster=true&autoPlay=true'
          : 'https://stellar.rip/en/watch/embed/movie/$id?theme=E50914&title=true&poster=true&autoPlay=true';
    }
    if (srv == 'vega') {
      return isTv
          ? 'https://vidsrc.to/embed/tv/$id/$s/$e'
          : 'https://vidsrc.to/embed/movie/$id';
    }
    if (srv == 'flixorent') {
      return isTv
          ? 'https://vidsrc.pro/embed/tv/$id/$s/$e'
          : 'https://vidsrc.pro/embed/movie/$id';
    }
    if (srv == 'vidbolt') {
      return isTv
          ? 'https://vidbolt.pro/tv/$id/$s/$e?theme=e50914&autoPlay=true&audio=hindi'
          : 'https://vidbolt.pro/movie/$id?theme=e50914&autoPlay=true&audio=hindi';
    }

    return isTv
        ? 'https://vidlink.pro/tv/$id/$s/$e'
        : 'https://vidlink.pro/movie/$id';
  }

  void _initWebView() {
    final targetUrl = _generateVideoUrl();
    final currentHost = Uri.parse(targetUrl).host;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'VideoState',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'playing' && mounted) {
            _fallbackTimer?.cancel();
            setState(() => isVideoPlaying = true);
          } else if (message.message == 'not_found' && mounted) {
            _triggerAutoFallback();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            String jsCode = '''
              window.open = function() { return null; };
              
              // Safe DOM Ad Killer: Removes popups without breaking player iframe
              setInterval(function() {
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0) {
                  var v = vids[0];
                  if (v.currentTime > 0 && !v.paused) {
                    VideoState.postMessage('playing');
                  }
                }
                
                // Only nuke external ad overlays, preserve iframe & controls
                document.querySelectorAll('div, a, span, img').forEach(el => {
                  let style = window.getComputedStyle(el);
                  if ((style.position === 'fixed' || style.position === 'absolute') && 
                      style.zIndex > 1000 && 
                      el.id !== 'video-player' && 
                      el.tagName !== 'IFRAME' && 
                      el.tagName !== 'VIDEO') {
                    el.remove();
                  }
                });
              }, 500);

              // 404 & Server Error auto scanner
              setInterval(function() {
                var text = document.body.innerText.toLowerCase();
                if (text.includes("we couldn't find this content") || 
                    text.includes("video not found") || 
                    text.includes("media not available") || 
                    text.includes("404 not found")) {
                  VideoState.postMessage('not_found');
                }
              }, 1000);
            ''';
            _controller.runJavaScript(jsCode);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            if (!url.contains(currentHost) && 
                !url.contains('pages.dev') && 
                !url.contains('stellar.rip') && 
                !url.contains('vidsrc') && 
                !url.contains('vidbolt') && 
                !url.contains('vidlink') && 
                !url.contains('hannutv.app')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            _triggerAutoFallback();
          },
        ),
      );

    _controller.loadRequest(
      Uri.parse(targetUrl),
      headers: {'Referer': 'https://hannutv.app/'},
    );

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    // 15 seconds fallback safety timer if stream never loads
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !showServerSelectionUI && !isVideoPlaying) {
        _triggerAutoFallback();
      }
    });
  }

  void _forcePlayAndBypassAds() {
    _controller.runJavaScript('''
      var vids = document.getElementsByTagName('video');
      if (vids.length > 0) { 
        vids[0].play(); 
      }
      var iframes = document.getElementsByTagName('iframe');
      if (iframes.length > 0) {
        iframes[0].contentWindow.postMessage('{"event":"command","func":"playVideo","args":""}', '*');
      }
    ''');
    setState(() => isVideoPlaying = true);
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (mounted && !showServerSelectionUI) {
      setState(() => showControls = true);
    }
    _hideTimer = Timer(const Duration(seconds: 4), () {
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Provider Manager",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(servers.length, (index) {
                final srv = servers[index];
                return ListTile(
                  leading: Icon(Icons.dns, color: srv['color'], size: 18),
                  title: Text(
                    srv['name'],
                    style: TextStyle(
                      color: activeServerIndex == index ? Colors.red : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
    _fallbackTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
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
                    // 1. WEBVIEW EMBED PLAYER
                    Positioned.fill(
                      child: WebViewWidget(controller: _controller),
                    ),

                    // 2. HANNUTV WATERMARK OVERLAY
                    Positioned(
                      top: 16,
                      right: 16,
                      child: SafeArea(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 0.5,
                            child: Image.asset(
                              'assets/logo.png',
                              height: 30,
                              errorBuilder: (_, __, ___) => const Text(
                                'HANNUTV',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 3. TRANSPARENT LOADING OVERLAY (NO BLACK SCREEN BLOCK)
                    if (!isVideoPlaying)
                      Positioned(
                        bottom: 40,
                        left: 20,
                        child: SafeArea(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.redAccent, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Connecting: ${servers[activeServerIndex]['name']}...",
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // 4. CONTROLS OVERLAY (BACK & SERVERS)
                    if (showControls)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: SafeArea(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ),

                    if (showControls)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: SafeArea(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _showServerSelector,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.dns, color: servers[activeServerIndex]['color'], size: 14),
                                      const SizedBox(width: 6),
                                      const Text(
                                        "Servers",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    isCropped ? Icons.fullscreen_exit : Icons.crop_free,
                                    color: Colors.white,
                                    size: 20,
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

  Widget _buildServerSelectionUI() {
    return Container(
      color: Colors.black,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logo.png', height: 70, errorBuilder: (_, __, ___) => const SizedBox()),
          const SizedBox(height: 16),
          Text(
            widget.movieTitle,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text("Select a streaming provider to start", style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 30),
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
        width: 105,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: srv['color'], width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: srv['color'], size: 24),
            const SizedBox(height: 10),
            Text(
              srv['name'].split(' ')[0],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
