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
  final String preferredServer;

  const VideoPlayerPage({
    Key? key,
    required this.tmdbId,
    required this.mediaType,
    required this.season,
    required this.episode,
    required this.movieTitle,
    this.customUrl,
    this.preferredServer = 'netmirror_live',
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
  bool isPageLoading = true;
  late String currentServerKey;

  // 🤖 VIP HARDCODED SERVERS
  final List<Map<String, dynamic>> allServers = [
    {
      'key': 'netmirror_live',
      'name': 'HANNUTV Ultra (NetMirror Live)',
      'sub': '1080p Pure Stream (No Ads)',
      'color': Colors.redAccent,
    },
    {
      'key': 'vidbolt_hd',
      'name': 'VidBolt VIP Ultra HD',
      'sub': 'High Bitrate Multi-Audio',
      'color': Colors.orange,
    },
    {
      'key': 'olly',
      'name': 'Olly Stream VIP',
      'sub': 'Fast Server',
      'color': Colors.purpleAccent,
    }
  ];

  @override
  void initState() {
    super.initState();
    currentServerKey = widget.preferredServer;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initWebView();
    _startHideTimer();
  }

  void _switchServer(String newServerKey) {
    setState(() {
      currentServerKey = newServerKey;
      isPageLoading = true;
      isVideoPlaying = false;
    });
    _initWebView();
    _startHideTimer();
  }

  String _generateVideoUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) {
      return widget.customUrl!;
    }

    final id = widget.tmdbId;
    final s = widget.season;
    final e = widget.episode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';
    
    // 100% Match query for NetMirror
    String cleanTitle = widget.movieTitle.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
    final query = Uri.encodeComponent(cleanTitle);

    // 🚀 1. NETMIRROR LIVE DIRECT PORTAL (The Master Bypass)
    if (currentServerKey == 'netmirror_live') {
      // It opens search page, and our JS will auto-click the result
      return isTv 
        ? 'https://netmirror.center/search?keyword=$query tv'
        : 'https://netmirror.center/search?keyword=$query';
    }

    // 🚀 2. VIDBOLT ULTRA HD
    if (currentServerKey == 'vidbolt_hd') {
      return isTv
          ? 'https://vidbolt.pro/tv/$id/$s/$e?quality=1080p&theme=e50914&autoPlay=true&audio=hindi'
          : 'https://vidbolt.pro/movie/$id?quality=1080p&theme=e50914&autoPlay=true&audio=hindi';
    }

    // 🚀 3. OLLY
    return isTv
        ? 'https://ollyembed.pages.dev/tv/$id/$s/$e?server=1'
        : 'https://ollyembed.pages.dev/movie/$id?server=1';
  }

  void _initWebView() {
    final targetUrl = _generateVideoUrl();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", // Desktop UA avoids mobile limits
      )
      ..addJavaScriptChannel(
        'VideoState',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'playing' && mounted) {
            setState(() {
              isVideoPlaying = true;
              isPageLoading = false;
            });
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => isPageLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => isPageLoading = false);

            // 🛡️ THE 1200000000000% LOGIC JS BYPASS ENGINE
            String jsCode = '''
              // Force Dark Background
              document.documentElement.style.backgroundColor = '#000000';
              document.body.style.backgroundColor = '#000000';

              // Kill Alerts
              window.open = function() { return null; };
              window.alert = function() { return null; };

              // 1. IF ON SEARCH PAGE -> AUTO CLICK FIRST RESULT
              if (window.location.href.includes('search')) {
                 let cards = document.querySelectorAll('a.film-poster, .flw-item a, .item a, a[href*="/movie/"], a[href*="/tv/"]');
                 if (cards.length > 0 && !window._cardClicked) {
                    window._cardClicked = true;
                    // For TV shows, we must ensure it goes to right season/episode. 
                    // But first, let's just click the media.
                    window.location.href = cards[0].href;
                 }
              }

              // 2. ULTIMATE AD & LOGO NUKER
              var style = document.createElement('style');
              style.innerHTML = `
                header, footer, nav, aside, .sidebar, .logo, .ad, iframe[src*="ads"] { 
                  display: none !important; 
                }
                body, html { overflow: hidden !important; background: black !important; }
              `;
              document.head.appendChild(style);

              setInterval(function() {
                // Remove Popups
                document.querySelectorAll('div, a, span, img').forEach(el => {
                  let style = window.getComputedStyle(el);
                  if ((style.position === 'fixed' || style.position === 'absolute') && 
                      style.zIndex > 1000 && 
                      el.tagName !== 'IFRAME' && 
                      el.tagName !== 'VIDEO') {
                    el.remove();
                  }
                });

                // Find Main Player Iframe and force Fullscreen
                var iframes = document.getElementsByTagName('iframe');
                for(let i=0; i<iframes.length; i++) {
                   if(iframes[i].src.includes('player') || iframes[i].src.includes('embed') || iframes[i].id === 'iframe-embed') {
                      iframes[i].style.position = 'fixed';
                      iframes[i].style.top = '0';
                      iframes[i].style.left = '0';
                      iframes[i].style.width = '100vw';
                      iframes[i].style.height = '100vh';
                      iframes[i].style.zIndex = '999999';
                      VideoState.postMessage('playing');
                   }
                }

                // Detect native video tags
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0) {
                  vids[0].style.backgroundColor = '#000000';
                  if (vids[0].currentTime > 0 && !vids[0].paused) {
                    VideoState.postMessage('playing');
                  }
                }
              }, 500);
            ''';
            _controller.runJavaScript(jsCode);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();

            // 🚫 HARD BLOCK AD NETWORKS
            if (url.contains('doubleclick') || url.contains('popads') ||
                url.contains('1xbet') || url.contains('bet365') ||
                url.contains('onclick') || url.contains('monetag') ||
                url.contains('adsterra') || url.contains('redirect')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    _controller.loadRequest(Uri.parse(targetUrl));

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }
  }

  void _seekRelative(int seconds) {
    _startHideTimer();
    final js = '''
      (function() {
        var iframes = document.getElementsByTagName('iframe');
        var v = null;
        if(iframes.length > 0) {
           var doc = iframes[0].contentDocument || iframes[0].contentWindow.document;
           if(doc) v = doc.querySelector('video');
        }
        if(!v) v = document.querySelector('video');
        if (v) v.currentTime += $seconds;
      })();
    ''';
    _controller.runJavaScript(js);
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (mounted) setState(() => showControls = true);
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => showControls = false);
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
              const Text("Select Server", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...List.generate(allServers.length, (index) {
                final srv = allServers[index];
                final isSelected = currentServerKey == srv['key'];
                return ListTile(
                  leading: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? Colors.greenAccent : Colors.grey),
                  title: Text(srv['name'], style: TextStyle(color: isSelected ? Colors.redAccent : Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(srv['sub'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    if (currentServerKey != srv['key']) {
                      _switchServer(srv['key']);
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
      var v = document.querySelector('iframe').contentDocument.querySelector('video') || document.querySelector('video');
      if (v) v.style.objectFit = '${isCropped ? "cover" : "contain"}';
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
    final currentSrv = allServers.firstWhere((s) => s['key'] == currentServerKey, orElse: () => allServers[0]);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _startHideTimer,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(color: Colors.black, child: WebViewWidget(controller: _controller)),
              ),
              Positioned(
                top: 16, right: 16,
                child: SafeArea(child: IgnorePointer(child: Opacity(opacity: 0.5, child: Image.asset('assets/logo.png', height: 30)))),
              ),
              if (isPageLoading && !isVideoPlaying)
                Positioned(
                  bottom: 40, left: 20,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.redAccent, width: 1)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2)),
                          const SizedBox(width: 10),
                          Text("Connecting: ${currentSrv['name']}...", style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (showControls)
                Positioned(
                  top: 16, left: 16, right: 80,
                  child: SafeArea(
                    child: Row(
                      children: [
                        Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22), onPressed: () => Navigator.pop(context))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(widget.movieTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
              if (showControls)
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(onTap: () => _seekRelative(-10), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.replay_10, color: Colors.white, size: 36))),
                      const SizedBox(width: 80),
                      GestureDetector(onTap: () => _seekRelative(10), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.forward_10, color: Colors.white, size: 36))),
                    ],
                  ),
                ),
              if (showControls)
                Positioned(
                  bottom: 16, right: 16,
                  child: SafeArea(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _showServerSelector,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.redAccent, width: 1.2)),
                            child: Row(
                              children: [
                                const Icon(Icons.swap_horiz, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 6),
                                Text("Engine: ${currentSrv['name']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle), child: IconButton(icon: Icon(isCropped ? Icons.fullscreen_exit : Icons.crop_free, color: Colors.white, size: 20), onPressed: toggleCrop)),
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