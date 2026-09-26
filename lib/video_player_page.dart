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
  final String preferredServer; // 'netmirror_live', 'netmirror_embed', 'vidbolt_hd', 'vega'

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

  // 🤖 VIP HARDCODED SERVERS (NETMIRROR & ULTRA HD)
  final List<Map<String, dynamic>> allServers = [
    {
      'key': 'netmirror_live',
      'name': 'HANNUTV Ultra (NetMirror Live)',
      'sub': '1080p Pure Stream (No Ads)',
      'color': Colors.redAccent,
    },
    {
      'key': 'netmirror_embed',
      'name': 'NetMirror Dedicated VIP',
      'sub': 'Dual Audio Hindi HD',
      'color': Colors.orange,
    },
    {
      'key': 'vidbolt_hd',
      'name': 'VidBolt VIP Ultra HD',
      'sub': 'High Bitrate Multi-Audio',
      'color': Colors.purpleAccent,
    },
    {
      'key': 'vega_hd',
      'name': 'Vega Multi 4K',
      'sub': 'Zero Lag Cloud Stream',
      'color': Colors.teal,
    },
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
    final query = Uri.encodeComponent(widget.movieTitle);

    // 🚀 1. NETMIRROR LIVE DIRECT PORTAL
    if (currentServerKey == 'netmirror_live') {
      return 'https://netmirror.center/search?q=$query';
    }

    // 🚀 2. NETMIRROR DIRECT EMBED ENGINE
    if (currentServerKey == 'netmirror_embed') {
      return isTv
          ? 'https://netmirror.center/embed/tv?id=$id&s=$s&e=$e'
          : 'https://netmirror.center/embed/movie?id=$id';
    }

    // 🚀 3. VIDBOLT ULTRA HD (FORCED HIGH QUALITY)
    if (currentServerKey == 'vidbolt_hd') {
      return isTv
          ? 'https://vidbolt.pro/tv/$id/$s/$e?quality=1080p&theme=e50914&autoPlay=true&audio=hindi'
          : 'https://vidbolt.pro/movie/$id?quality=1080p&theme=e50914&autoPlay=true&audio=hindi';
    }

    // 🚀 4. VEGA 4K STREAM
    return isTv
        ? 'https://vidsrc.to/embed/tv/$id/$s/$e'
        : 'https://vidsrc.to/embed/movie/$id';
  }

  void _initWebView() {
    final targetUrl = _generateVideoUrl();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        "Mozilla/5.0 (Linux; Android 13; SM-S918B Build/TP1A.220624.014) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36",
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

            // 🛡️ WORLD'S BEST ANDROID AD-KILLER + NETMIRROR DEEP BYPASS ENGINE
            String jsCode = '''
              // 1. Force Pure Dark Cinema Mode
              document.documentElement.style.backgroundColor = '#000000';
              document.body.style.backgroundColor = '#000000';

              // 2. Kill Popups, Alerts, Prompts completely
              window.open = function() { return null; };
              window.alert = function() { return null; };
              window.confirm = function() { return null; };

              // 3. Ultra Nuke NetMirror/Vidbolt Logos, Headers, Footers & Anti-Adblock
              setInterval(function() {
                // Kill AdBlock Detection Modals & Extension warnings
                document.querySelectorAll('div, section, modal, aside, p, h2, span, header, footer, nav').forEach(el => {
                  let text = el.innerText.toLowerCase();
                  if (text.includes('adblock') || 
                      text.includes('ad-blocker') || 
                      text.includes('disable adblock') || 
                      text.includes('please disable') ||
                      text.includes('inside an iframe') ||
                      text.includes('netmirror') ||
                      text.includes('net mirror')) {
                    
                    // If it is top header logo of netmirror, hide it
                    if (el.tagName === 'HEADER' || el.tagName === 'NAV' || el.className.includes('logo') || el.className.includes('header')) {
                      el.style.display = 'none';
                    } else if (!el.querySelector('video') && !el.querySelector('iframe')) {
                      el.remove();
                    }
                  }
                });

                // Remove ads, banner images and click overlays
                document.querySelectorAll('div, a, span, img').forEach(el => {
                  let style = window.getComputedStyle(el);
                  if ((style.position === 'fixed' || style.position === 'absolute') && 
                      style.zIndex > 1000 && 
                      el.tagName !== 'IFRAME' && 
                      el.tagName !== 'VIDEO' &&
                      !el.contains(document.querySelector('video'))) {
                    el.remove();
                  }
                });

                // If on NetMirror search page, click the first movie card automatically!
                if (window.location.href.includes('search')) {
                  let cards = document.querySelectorAll('.card, .movie-card, .search-result, .item, a[href*="/watch/"], a[href*="/movie/"], a[href*="/tv/"]');
                  if (cards.length > 0 && !window._cardClicked) {
                    window._cardClicked = true;
                    cards[0].click();
                  }
                }

                // Auto Play & Video Detection
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0) {
                  var v = vids[0];
                  v.style.backgroundColor = '#000000';
                  if (v.paused) {
                    v.play().catch(function(){});
                  }
                  if (v.currentTime > 0 && !v.paused) {
                    VideoState.postMessage('playing');
                  }
                }
              }, 300);
            ''';
            _controller.runJavaScript(jsCode);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();

            // Block ads & redirects
            if (url.contains('doubleclick') ||
                url.contains('popads') ||
                url.contains('1xbet') ||
                url.contains('bet365') ||
                url.contains('onclick') ||
                url.contains('monetag') ||
                url.contains('exoclick') ||
                url.contains('redirect') ||
                url.contains('adsterra')) {
              return NavigationDecision.prevent;
            }

            // Allow safe player URLs
            if (url.contains('hannutv.app') ||
                url.contains('netmirror') ||
                url.contains('vidbolt') ||
                url.contains('ollyembed') ||
                url.contains('pages.dev') ||
                url.contains('vidsrc') ||
                url.contains('vidlink') ||
                url.contains('stellar.rip') ||
                url.startsWith('about:blank') ||
                url.startsWith('data:')) {
              return NavigationDecision.navigate;
            }

            return NavigationDecision.prevent;
          },
        ),
      );

    _controller.loadRequest(
      Uri.parse(targetUrl),
      headers: {
        'Referer': 'https://netmirror.center/',
        'Origin': 'https://netmirror.center',
      },
    );

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  void _seekRelative(int seconds) {
    _startHideTimer();
    final js = '''
      (function() {
        var vids = document.getElementsByTagName('video');
        if (vids.length > 0) {
          vids[0].currentTime += $seconds;
        }
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
                "Change Streaming Engine",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(allServers.length, (index) {
                final srv = allServers[index];
                final isSelected = currentServerKey == srv['key'];
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.greenAccent : Colors.grey,
                  ),
                  title: Text(
                    srv['name'],
                    style: TextStyle(
                      color: isSelected ? Colors.redAccent : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    srv['sub'],
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
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
    final currentSrv = allServers.firstWhere(
      (s) => s['key'] == currentServerKey,
      orElse: () => allServers[0],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. PURE BLACK WEBVIEW (NETMIRROR POWERED)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: WebViewWidget(controller: _controller),
              ),
            ),

            // 2. HANNUTV WATERMARK LOGO
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

            // 3. LOADING / BUFFERING
            if (isPageLoading && !isVideoPlaying)
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
                          "Loading: ${currentSrv['name']}...",
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 4. TOP CONTROLS (BACK & MOVIE TITLE)
            if (showControls)
              Positioned(
                top: 16,
                left: 16,
                right: 80,
                child: SafeArea(
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.movieTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 5. CENTER FAST SEEK BUTTONS (-10s / +10s)
            if (showControls)
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _seekRelative(-10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.replay_10, color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(width: 80),
                    GestureDetector(
                      onTap: () => _seekRelative(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.forward_10, color: Colors.white, size: 36),
                      ),
                    ),
                  ],
                ),
              ),

            // 6. BOTTOM CONTROLS (SERVER SWITCHER & CROP)
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.redAccent, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.swap_horiz, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                "Engine: ${currentSrv['name']}",
                                style: const TextStyle(
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
    );
  }
}
