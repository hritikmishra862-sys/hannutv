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
    this.preferredServer = 'vidbolt',
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
  Timer? _aiFallbackTimer;

  bool isAiResolving = true;
  String aiStatusText = "AI Engine: Scanning & Auto-Bypassing Ads...";
  int currentServerIndex = 0;

  // 🤖 5 ULTRA FAST ZERO-AD DIRECT EMBED PROVIDERS
  final List<Map<String, dynamic>> allServers = [
    {
      'key': 'vidbolt',
      'name': 'VidBolt VIP Ultra HD',
      'sub': 'Fast Hindi Dub + 1080p Stream (No Ads)',
      'color': Colors.redAccent,
    },
    {
      'key': 'vidsrc_icu',
      'name': 'HANNUTV Cloud Node',
      'sub': 'Superfast HLS Multi-Audio',
      'color': Colors.orangeAccent,
    },
    {
      'key': 'vidsrc_to',
      'name': 'Vega Multi-Audio 4K',
      'sub': 'Dual Audio Hindi/Eng Cloud',
      'color': Colors.purpleAccent,
    },
    {
      'key': 'vidlink',
      'name': 'VidLink English Pro',
      'sub': 'English HD Direct Node',
      'color': Colors.green,
    },
    {
      'key': 'superembed',
      'name': 'Multi-Stream VIP',
      'sub': 'Instant 1-Click Stream',
      'color': Colors.blueAccent,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Match requested server
    int initialIndex = allServers.indexWhere((s) => s['key'] == widget.preferredServer);
    currentServerIndex = initialIndex != -1 ? initialIndex : 0;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initAiStreamPlayer();
    _startHideTimer();
  }

  void _initAiStreamPlayer() {
    _aiFallbackTimer?.cancel();
    setState(() {
      isAiResolving = true;
      isVideoPlaying = false;
      aiStatusText = "AI Sentinel: Connecting to ${allServers[currentServerIndex]['name']}...";
    });

    _buildCleanWebView();

    // 🛡️ BACKGROUND AI SENTINEL (If stream doesn't play in 7s, auto-switch to next server)
    _aiFallbackTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && !isVideoPlaying) {
        _autoFallbackNextServer();
      }
    });
  }

  void _autoFallbackNextServer() {
    if (isVideoPlaying || !mounted) return;
    setState(() {
      currentServerIndex = (currentServerIndex + 1) % allServers.length;
      aiStatusText = "AI Engine: Switching to backup server ${allServers[currentServerIndex]['name']}...";
    });
    _initAiStreamPlayer();
  }

  void _manualSwitchServer(int index) {
    _aiFallbackTimer?.cancel();
    setState(() {
      currentServerIndex = index;
    });
    _initAiStreamPlayer();
  }

  String _generateStreamUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) {
      return widget.customUrl!;
    }

    final id = widget.tmdbId;
    final s = widget.season;
    final e = widget.episode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';
    final srvKey = allServers[currentServerIndex]['key'];

    // 1. VidBolt High Bitrate (Hindi + 1080p)
    if (srvKey == 'vidbolt') {
      return isTv
          ? 'https://vidbolt.pro/tv/$id/$s/$e?quality=1080p&theme=e50914&autoPlay=true&audio=hindi'
          : 'https://vidbolt.pro/movie/$id?quality=1080p&theme=e50914&autoPlay=true&audio=hindi';
    }

    // 2. VidSrc ICU Fast Embed
    if (srvKey == 'vidsrc_icu') {
      return isTv
          ? 'https://vidsrc.icu/embed/tv/$id/$s/$e'
          : 'https://vidsrc.icu/embed/movie/$id';
    }

    // 3. VidSrc TO 4K Cloud
    if (srvKey == 'vidsrc_to') {
      return isTv
          ? 'https://vidsrc.to/embed/tv/$id/$s/$e'
          : 'https://vidsrc.to/embed/movie/$id';
    }

    // 4. VidLink Pro
    if (srvKey == 'vidlink') {
      return isTv
          ? 'https://vidlink.pro/tv/$id/$s/$e'
          : 'https://vidlink.pro/movie/$id';
    }

    // 5. SuperEmbed Multi
    return isTv
        ? 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e'
        : 'https://multiembed.mov/?video_id=$id&tmdb=1';
  }

  void _buildCleanWebView() {
    final targetUrl = _generateStreamUrl();

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
            _aiFallbackTimer?.cancel();
            setState(() {
              isVideoPlaying = true;
              isAiResolving = false;
            });
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // 🛡️ WORLD'S BEST BACKGROUND AI AD-KILLER & AUTO-CLICK SCRIPT
            String jsCode = '''
              // Force Black Screen
              document.documentElement.style.backgroundColor = '#000000';
              document.body.style.backgroundColor = '#000000';

              // Prevent all redirects and popups
              window.open = function() { return null; };
              window.alert = function() { return null; };
              window.confirm = function() { return null; };

              // AI Real-time Loop (Every 200ms)
              setInterval(function() {
                // A. Video Detection & Force Unmute Play
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0) {
                  var v = vids[0];
                  v.style.backgroundColor = '#000000';
                  v.muted = false;
                  v.volume = 1.0;

                  if (v.paused && !v.ended) {
                    v.play().catch(function(){});
                  }
                  if (v.currentTime > 0.5 && !v.paused) {
                    VideoState.postMessage('playing');
                  }
                }

                // B. Auto Click Play Buttons & Server Items
                var playBtns = document.querySelectorAll('.play-btn, .vjs-big-play-button, .jw-display-icon-container, [aria-label="Play"], button[title*="Play"], .play-icon, #play-button, .button-play');
                playBtns.forEach(function(b) {
                  b.click();
                });

                // C. Kill All Banner Ads, Modals, Overlays, Floating Frames
                document.querySelectorAll('div, a, span, img, section, modal, aside, p, header, nav').forEach(el => {
                  let text = el.innerText ? el.innerText.toLowerCase() : '';
                  let className = el.className ? el.className.toString().toLowerCase() : '';
                  let idName = el.id ? el.id.toString().toLowerCase() : '';
                  let style = window.getComputedStyle(el);

                  // AdBlock Warnings
                  if (text.includes('adblock') || 
                      text.includes('ad-blocker') || 
                      text.includes('disable adblock') || 
                      text.includes('please disable') ||
                      text.includes('inside an iframe')) {
                    if (el.tagName === 'HEADER' || el.tagName === 'NAV') {
                      el.style.display = 'none';
                    } else if (!el.querySelector('video') && !el.querySelector('iframe')) {
                      el.remove();
                    }
                  }

                  // Floating Overlays
                  if ((style.position === 'fixed' || style.position === 'absolute') && 
                      style.zIndex > 1000 && 
                      el.tagName !== 'IFRAME' && 
                      el.tagName !== 'VIDEO' &&
                      !el.contains(document.querySelector('video'))) {
                    el.remove();
                  }

                  // Ads & Banners
                  if (className.includes('banner') || className.includes('ad-') || className.includes('popup') || idName.includes('ad-')) {
                    el.remove();
                  }
                });
              }, 200);
            ''';
            _controller.runJavaScript(jsCode);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();

            // 🚫 HARD BLOCK AD REDIRECTS & BETTING NETWORKS
            if (url.contains('doubleclick') ||
                url.contains('popads') ||
                url.contains('1xbet') ||
                url.contains('bet365') ||
                url.contains('onclick') ||
                url.contains('monetag') ||
                url.contains('exoclick') ||
                url.contains('redirect') ||
                url.contains('adsterra') ||
                url.contains('betway') ||
                url.contains('parimatch') ||
                url.contains('syndication') ||
                url.contains('traffic')) {
              return NavigationDecision.prevent;
            }

            // ✅ ALLOW ONLY STREAMING SERVERS
            if (url.contains('hannutv.app') ||
                url.contains('vidbolt') ||
                url.contains('vidsrc') ||
                url.contains('vidlink') ||
                url.contains('multiembed') ||
                url.contains('pages.dev') ||
                url.contains('stellar.rip') ||
                url.startsWith('about:blank') ||
                url.startsWith('data:')) {
              return NavigationDecision.navigate;
            }

            return NavigationDecision.prevent;
          },
        ),
      );

    // Fullcontainer HTML Iframe wrapper for maximum security & 0% white screen
    final embedHtml = '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            html, body { width: 100%; height: 100%; background-color: #000000; overflow: hidden; }
            iframe { width: 100%; height: 100%; border: none; background-color: #000000; }
          </style>
        </head>
        <body>
          <iframe 
            id="player-frame"
            src="$targetUrl" 
            allow="autoplay; fullscreen; encrypted-media; picture-in-picture" 
            allowfullscreen>
          </iframe>
        </body>
      </html>
    ''';

    _controller.loadHtmlString(embedHtml, baseUrl: 'https://hannutv.app');

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  void _seekRelative(int seconds) {
    _startHideTimer();
    final js = '''
      (function() {
        var frame = document.getElementById('player-frame');
        var doc = frame ? (frame.contentDocument || frame.contentWindow.document) : document;
        var vids = doc ? doc.getElementsByTagName('video') : document.getElementsByTagName('video');
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
                final isSelected = currentServerIndex == index;
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
                    if (currentServerIndex != index) {
                      _manualSwitchServer(index);
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
      var frame = document.getElementById('player-frame');
      var doc = frame ? (frame.contentDocument || frame.contentWindow.document) : document;
      var vids = doc ? doc.getElementsByTagName('video') : document.getElementsByTagName('video');
      if (vids.length > 0) {
        vids[0].style.objectFit = '${isCropped ? "cover" : "contain"}';
      }
    ''');
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _aiFallbackTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSrv = allServers[currentServerIndex];

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
            // 1. PURE BLACK WEBVIEW CONTAINER (0% WHITE FLASH)
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

            // 3. SMART AI SENTINEL OVERLAY (Until video starts playing)
            if (isAiResolving && !isVideoPlaying)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 45,
                          height: 45,
                          child: CircularProgressIndicator(
                            color: Colors.redAccent,
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          aiStatusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Active Node: ${currentSrv['name']}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
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
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 22),
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
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 6)
                            ],
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
                        child: const Icon(Icons.replay_10,
                            color: Colors.white, size: 36),
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
                        child: const Icon(Icons.forward_10,
                            color: Colors.white, size: 36),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: Colors.redAccent, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.swap_horiz,
                                  color: Colors.redAccent, size: 16),
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
