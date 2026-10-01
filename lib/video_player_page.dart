import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:share_plus/share_plus.dart'; // 🚀 ADDED
import 'package:cloud_firestore/cloud_firestore.dart'; // 🚀 ADDED
import 'banner_ad_widget.dart'; // 🚀 Added Banner Ad Import
import 'skippable_ad_screen.dart'; // 🚀 Added Skippable Ad Import

const String kTmdbToken =
    'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIzZDJkOTExNmM5ZGU3MjA5ZWUyNzdiYjhjYzlhZWVkOCIsIm5iZiI6MTc5MDI2OTE4NC42MjksInN1YiI6IjZhYjU1NzAwNzZiMTg1ODU3MGFjNDM4NSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.xZJX8fowhVhVJsgl-5wOW6Y7ZfUr9Zu_Ey1qMkhnPd0';

const Map<String, String> kApiHeaders = {
  'Authorization': 'Bearer $kTmdbToken',
  'accept': 'application/json',
};

class VideoPlayerPage extends StatefulWidget {
  final int tmdbId;
  final String mediaType;
  final int season;
  final int episode;
  final String movieTitle;
  final String overview;
  final String rating;
  final String year;
  final String? customUrl;
  final String? mbpSignCookie; // 🚀 ADDED FOR BYPASS

  const VideoPlayerPage({
    super.key,
    required this.tmdbId,
    required this.mediaType,
    this.season = 1,
    this.episode = 1,
    required this.movieTitle,
    this.overview = '',
    this.rating = '9.0',
    this.year = '2024',
    this.customUrl,
    this.mbpSignCookie, // 🚀 ADDED FOR BYPASS
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with SingleTickerProviderStateMixin {
  late WebViewController _controller;

  bool isVideoPlaying = false;
  bool isFullScreen = false;
  bool isPageLoading = true;
  String activeServer = 'vidrift';
  int currentServerIndex = 0; // 🚀 ADDED FOR AI HEALER

  String currentAspectRatio = 'contain';

  late int currentSeason;
  late int currentEpisode;
  bool isLiked = false;
  int likeCount = 1248;
  int viewCount = 84920;

  bool showControls = true; 
  Timer? _hideControlsTimer;

  bool showIntroAnimation = false;
  late AnimationController _introAnimController;
  late Animation<double> _introScaleAnimation;
  late Animation<double> _introOpacityAnimation;

  final TextEditingController commentInputController = TextEditingController();

  final List<Map<String, String>> servers = const [
    {'key': 'vidrift', 'name': 'Rift'},
    {'key': 'fast', 'name': 'Fast'},
    {'key': 'vidbolt', 'name': 'Bolt'},
    {'key': 'cinezo', 'name': 'Cinezo'},
    {'key': 'hindi-new', 'name': 'Hindi New'},
    {'key': 'peach', 'name': 'Peach'},
    {'key': 'mega', 'name': 'Mega'},
    {'key': 'alpha', 'name': 'Alpha'},
    {'key': 'orion', 'name': 'Orion'},
    {'key': 'hindi', 'name': 'Hindi'},
    {'key': 'vidgod', 'name': 'Vidgod'},
    {'key': 'cinesrc', 'name': 'CineSrc'},
  ];

  final List<Map<String, String>> publicComments = const [
    {'name': 'SHEEL', 'text': 'HARE KRISHNA 🦚', 'time': '9d', 'avatar': 'S'},
    {
      'name': 'Rohit Sharma',
      'text': 'Best quality on HANNUTV, loving this series! 🔥',
      'time': '2d',
      'avatar': 'R'
    },
    {
      'name': 'Ananya Verma',
      'text': 'Full HD stream with no buffering ❤️',
      'time': '5h',
      'avatar': 'A'
    },
  ];

  List similarMovies = [];
  bool isLoadingSimilar = false;

  bool isTvDevice = false;

  @override
  void initState() {
    super.initState();
    currentSeason = widget.season;
    currentEpisode = widget.episode;
    activeServer = servers[0]['key']!; 

    _introAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _introScaleAnimation = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _introAnimController, curve: Curves.easeOutBack),
    );
    _introOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _introAnimController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
      ),
    );

    _fetchSimilarMovies();
    _checkDeviceType(); 
  }

  void _checkDeviceType() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        isTvDevice = size.width > size.height && size.width > 600; 
        if (isTvDevice) {
           isFullScreen = true; 
        } else {
           SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
           SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      });
      _startControlsTimer();
      _initStream();
    });
  }

  void _startControlsTimer() {
    _hideControlsTimer?.cancel();
    if (mounted) setState(() => showControls = true);
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => showControls = false);
    });
  }

  void _toggleControlPanel() {
    if (showControls) {
      setState(() => showControls = false);
      _hideControlsTimer?.cancel();
    } else {
      _startControlsTimer();
    }
  }

  void _triggerCinematicPlayAnimation() {
    if (showIntroAnimation || isVideoPlaying) return;
    setState(() {
      showIntroAnimation = true;
      isVideoPlaying = true;
      isPageLoading = false;
    });

    _introAnimController.forward().then((_) {
      if (mounted) setState(() => showIntroAnimation = false);
    });
  }

  // 🚀 ADDED: AI AUTO-HEALER
  void _autoSwitchServer() {
    if (currentServerIndex < servers.length - 1) {
      setState(() {
        currentServerIndex++;
        activeServer = servers[currentServerIndex]['key']!;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("AI Auto-Fix: Connecting to ${servers[currentServerIndex]['name']}..."), backgroundColor: Colors.green)
      );
      _initStream();
    }
  }

  Future<void> _fetchSimilarMovies() async {
    setState(() => isLoadingSimilar = true);
    try {
      final type =
          widget.mediaType == 'tv' || widget.mediaType == 'series'
              ? 'tv'
              : 'movie';
      final res = await http.get(
        Uri.parse(
          'https://api.themoviedb.org/3/$type/${widget.tmdbId}/recommendations?language=en-US',
        ),
        headers: kApiHeaders,
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List results = data['results'] ?? [];
        if (mounted) {
          setState(() {
            similarMovies =
                results
                    .map(
                      (m) => {
                        'id': m['id'],
                        'title': m['title'] ?? m['name'] ?? 'Unknown',
                        'posterUrl':
                            m['poster_path'] != null
                                ? 'https://image.tmdb.org/t/p/w500${m['poster_path']}'
                                : '',
                        'rating': (m['vote_average'] ?? 0).toStringAsFixed(1),
                        'year':
                            (m['release_date'] ?? m['first_air_date'] ?? '')
                                .toString()
                                .split('-')
                                .first,
                        'mediaType': type,
                      },
                    )
                    .toList();
            isLoadingSimilar = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoadingSimilar = false);
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingSimilar = false);
    }
  }

  // 🚀 ADDED: MBP BYPASS DECODER
  String _decodeMbpBypassUrl() {
    if (widget.mbpSignCookie != null && widget.mbpSignCookie!.contains('urlprefix=')) {
      try {
        String base64Str = widget.mbpSignCookie!.split('urlprefix=')[1].split(';')[0];
        String decodedUrl = utf8.decode(base64Decode(base64Str));
        return "$decodedUrl/index.m3u8"; 
      } catch (e) {
        return widget.customUrl ?? ''; 
      }
    }
    return '';
  }

  String _buildStreamUrl() {
    if (widget.mbpSignCookie != null) return _decodeMbpBypassUrl(); // 🚀 TRIGGER BYPASS
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) {
      return widget.customUrl!;
    }

    final id = widget.tmdbId;
    final s = currentSeason;
    final e = currentEpisode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    return isTv
        ? 'https://pantyflix.com/watch/play/tv/$id?season=$s&episode=$e&server=$activeServer'
        : 'https://pantyflix.com/watch/play/movie/$id?server=$activeServer';
  }

  void _initStream() {
    setState(() {
      isPageLoading = true;
      isVideoPlaying = false;
      showIntroAnimation = false;
    });

    final targetUrl = _buildStreamUrl();

    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..setUserAgent(
            isTvDevice
                ? "Mozilla/5.0 (SMART-TV; Linux; Tizen 5.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/5.0 TV Safari/538.1"
                : "Mozilla/5.0 (Linux; Android 13; SM-S918B Build/TP1A.220624.014) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36",
          )
          ..addJavaScriptChannel(
            'VideoState',
            onMessageReceived: (JavaScriptMessage message) {
              if (message.message == 'playing' && mounted) {
                _triggerCinematicPlayAnimation();
              }
              // 🚀 ADDED: AI LISTENER FOR ERRORS
              if (message.message == 'server_failed' && mounted) {
                _autoSwitchServer();
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

                String jsCode = '''
              document.documentElement.style.backgroundColor = '#000000';
              document.body.style.backgroundColor = '#000000';

              window.open = function() { return null; };
              window.alert = function() { return null; };
              window.confirm = function() { return null; };

              var style = document.createElement('style');
              style.innerHTML = `
                header, nav, .navbar, footer, .footer,
                .server-select, .server-dropdown, select[name*="server"], 
                div[class*="server-dropdown"], div[class*="server-btn"],
                a[href*="t.me"], a[href*="telegram"], [class*="telegram"], 
                iframe[src*="ads"], .ad-container, .ads, .ad-banner, .popup-overlay,
                .dmca-notice, .copyright, [href*="mailto:"] { 
                  display: none !important; 
                  opacity: 0 !important;
                  pointer-events: none !important;
                  visibility: hidden !important;
                }
                body { 
                  background-color: #000000 !important; 
                  color: #ffffff !important;
                  overflow: hidden !important;
                }
              `;
              document.head.appendChild(style);

              const aiObserver = new MutationObserver((mutations) => {
                mutations.forEach((mutation) => {
                  mutation.addedNodes.forEach((node) => {
                    if (node.nodeType === 1) {
                      let text = node.innerText ? node.innerText.toLowerCase() : '';
                      let className = node.className ? node.className.toString().toLowerCase() : '';
                      let idName = node.id ? node.id.toString().toLowerCase() : '';

                      if (text.includes('rift(ads)') || text.includes('rift (ads)') || 
                          text.includes('adblock') || text.includes('captcha') || text.includes('robot') ||
                          text.includes('telegram') || text.includes('dmca') || text.includes('support@') ||
                          className.includes('ad-') || className.includes('banner') || className.includes('popup') ||
                          idName.includes('ad-') || className.includes('server-select')) {
                        node.remove();
                      }
                    }
                  });
                });
              });
              aiObserver.observe(document.body, { childList: true, subtree: true });

              setInterval(function() {
                // 🚀 ADDED: AI DETECTS SERVER ERROR
                let errorText = document.body.innerText.toLowerCase();
                if (errorText.includes("failed to respond") || errorText.includes("can't play right now") || errorText.includes("usually temporary")) {
                  VideoState.postMessage('server_failed');
                }

                var vids = document.getElementsByTagName('video');
                if (vids.length > 0) {
                  var v = vids[0];
                  v.style.backgroundColor = '#000000';
                  v.style.objectFit = '$currentAspectRatio';
                  
                  v.style.position = 'fixed';
                  v.style.top = '0';
                  v.style.left = '0';
                  v.style.width = '100vw';
                  v.style.height = '100vh';
                  v.style.zIndex = '999999';

                  v.muted = false;
                  v.volume = 1.0;
                  if (v.paused && !v.ended) {
                    v.play().catch(function(){});
                  }
                  if (v.currentTime > 0.5 && !v.paused) {
                    VideoState.postMessage('playing');
                  }
                }

                var fsBtns = document.querySelectorAll('.jw-icon-fullscreen, .vjs-fullscreen-control, [aria-label*="ullscreen"], [title*="ullscreen"], .plyr__controls__item[data-plyr="fullscreen"]');
                fsBtns.forEach(btn => { btn.style.display = 'none'; btn.style.opacity = '0'; btn.style.pointerEvents = 'none'; });

                var playBtns = document.querySelectorAll('.play-btn, .vjs-big-play-button, .jw-display-icon-container, [aria-label="Play"], button[title*="Play"], .play-icon, #play-button');
                playBtns.forEach(function(b) { b.click(); });
              }, 200);
            ''';
                _controller.runJavaScript(jsCode);
              },
              onNavigationRequest: (NavigationRequest request) {
                final url = request.url.toLowerCase();

                if (url.contains('doubleclick') ||
                    url.contains('popads') ||
                    url.contains('1xbet') ||
                    url.contains('bet365') ||
                    url.contains('onclick') ||
                    url.contains('monetag') ||
                    url.contains('exoclick') ||
                    url.contains('redirect') ||
                    url.contains('adsterra') ||
                    url.contains('t.me') ||
                    url.contains('telegram') ||
                    url.contains('googleads') ||
                    url.contains('googlesyndication')) {
                  return NavigationDecision.prevent;
                }

                if (url.contains('pantyflix.com') ||
                    url.contains('vidbolt') ||
                    url.contains('vidsrc') ||
                    url.contains('vidlink') ||
                    url.contains('multiembed') ||
                    url.contains('pages.dev') ||
                    url.startsWith('about:blank') ||
                    url.startsWith('data:')) {
                  return NavigationDecision.navigate;
                }

                return NavigationDecision.prevent;
              },
            ),
          );

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

    _controller.loadHtmlString(embedHtml, baseUrl: 'https://pantyflix.com');

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  void _cycleAspectRatio() {
    setState(() {
      if (currentAspectRatio == 'contain') {
        currentAspectRatio = 'cover';
      } else if (currentAspectRatio == 'cover') {
        currentAspectRatio = 'fill';
      } else {
        currentAspectRatio = 'contain';
      }
    });

    _controller.runJavaScript('''
      var vids = document.getElementsByTagName('video');
      if (vids.length > 0) {
        vids[0].style.objectFit = '$currentAspectRatio';
      }
    ''');
    _startControlsTimer();
  }

  void _toggleFullScreen() {
    if (isTvDevice) return; 

    setState(() {
      isFullScreen = !isFullScreen;
    });

    if (isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _startControlsTimer();
  }

  void _switchEpisode(int ep) {
    setState(() {
      currentEpisode = ep;
    });
    _initStream();
  }

  // 🚀 ADDED: SHARE DEEP LINK LOGIC
  void _shareDeepLink() {
    String deepLink = 'https://hannutv.blogspot.com/watch?id=${widget.tmdbId}&type=${widget.mediaType}';
    Share.share('Watch ${widget.movieTitle} on HANNUTV for free! 🍿\n\nDirect Play Link:\n$deepLink');
  }

  // 🚀 ADDED: LIVE FIREBASE COMMENT UPLOAD
  void _addLiveComment() async {
    final text = commentInputController.text.trim();
    if (text.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('comments_${widget.tmdbId}').add({
          'name': 'HANNUTV User',
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
          'avatar': 'U'
        });
      } catch (e) {
        setState(() {
          publicComments.insert(0, {
            'name': 'You',
            'text': text,
            'time': 'Just now',
            'avatar': 'Y',
          });
        });
      }
      commentInputController.clear();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _introAnimController.dispose();
    commentInputController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  Widget _buildFocusableItem({
    required Widget child,
    required VoidCallback onTap,
    BorderRadius? borderRadius,
  }) {
    return _TvFocusButton(
      onTap: onTap,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      child: child,
    );
  }

  Widget _buildTVLayout() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: WebViewWidget(controller: _controller),
          ),
          if (showIntroAnimation)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _introAnimController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _introOpacityAnimation.value,
                        child: Transform.scale(
                          scale: _introScaleAnimation.value,
                          child: Image.asset('assets/logo.png', height: 120, errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_fill, color: Colors.red, size: 120)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          if (showControls) ...[
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.9), Colors.black.withOpacity(0.4), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 40,
              right: 40,
              bottom: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.movieTitle, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 24),
                      const SizedBox(width: 8),
                      Text(widget.rating, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      Text(widget.year, style: const TextStyle(color: Colors.grey, fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildFocusableItem(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(10),
                        child: _buildActionButton(Icons.arrow_back, "Back", activeColor: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      _buildFocusableItem(
                        onTap: _cycleAspectRatio,
                        borderRadius: BorderRadius.circular(10),
                        child: _buildActionButton(Icons.aspect_ratio, currentAspectRatio.toUpperCase(), activeColor: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("Servers:", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: servers.length,
                      itemBuilder: (context, index) {
                        final srv = servers[index];
                        final isSelected = activeServer == srv['key'];
                        return _buildFocusableItem(
                          onTap: () {
                            if (activeServer != srv['key']) {
                              setState(() => activeServer = srv['key']!);
                              _initStream();
                            }
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.grey[900], borderRadius: BorderRadius.circular(20)),
                            child: Text(srv['name']!, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          Positioned(
            top: 30,
            left: 40,
            child: _buildFocusableItem(
              onTap: _toggleControlPanel,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Opacity(
                  opacity: 0.9,
                  child: Image.asset('assets/logo.png', height: 45, errorBuilder: (_, __, ___) => const Text('HANNUTV', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 24))),
                ),
              ),
            ),
          ),
          if (isPageLoading && !isVideoPlaying)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/logo.png', height: 60, errorBuilder: (_, __, ___) => const Icon(Icons.movie, color: Colors.red, size: 60)),
                      const SizedBox(height: 20),
                      const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 3)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isTvDevice) return _buildTVLayout(); 

    if (isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: WebViewWidget(controller: _controller)),
            Positioned(
              top: 14,
              right: 20,
              child: SafeArea(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.85,
                    child: Image.asset(
                      'assets/logo.png',
                      height: 38,
                      errorBuilder:
                          (_, __, ___) => const Text(
                            'HANNUTV',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ),
            if (showIntroAnimation)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _introAnimController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _introOpacityAnimation.value,
                          child: Transform.scale(
                            scale: _introScaleAnimation.value,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/logo.png',
                                  height: 90,
                                  errorBuilder:
                                      (_, __, ___) => const Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.red,
                                        size: 90,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  "HANNUTV CINEMA",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 20,
              left: 20,
              child: SafeArea(
                child: _buildFocusableItem(
                  onTap: _toggleControlPanel,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Opacity(
                      opacity: 0.9,
                      child: Image.asset(
                        'assets/logo.png',
                        height: 38,
                        errorBuilder:
                            (_, __, ___) => const Text(
                              'HANNUTV',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showControls) ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(color: Colors.black38),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: SafeArea(
                  child: _buildFocusableItem(
                    onTap: () {
                      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: const CircleAvatar(
                      backgroundColor: Colors.black87,
                      radius: 22,
                      child: Icon(Icons.close, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                child: SafeArea(
                  child: _buildFocusableItem(
                    onTap: _cycleAspectRatio,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.aspect_ratio,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currentAspectRatio.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: SafeArea(
                  child: _buildFocusableItem(
                    onTap: _toggleFullScreen,
                    borderRadius: BorderRadius.circular(22),
                    child: const CircleAvatar(
                      backgroundColor: Colors.black87,
                      radius: 22,
                      child: Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _startControlsTimer,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 230,
                    color: Colors.black,
                    child: WebViewWidget(controller: _controller),
                  ),
                  Positioned(
                    top: 10,
                    right: 14,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.85,
                        child: Image.asset(
                          'assets/logo.png',
                          height: 34,
                          errorBuilder:
                              (_, __, ___) => const Text(
                                'HANNUTV',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                  if (showIntroAnimation)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _introAnimController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _introOpacityAnimation.value,
                                child: Transform.scale(
                                  scale: _introScaleAnimation.value,
                                  child: Image.asset(
                                    'assets/logo.png',
                                    height: 60,
                                    errorBuilder:
                                        (_, __, ___) => const Icon(
                                          Icons.play_circle_fill,
                                          color: Colors.red,
                                          size: 60,
                                        ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _buildFocusableItem(
                      onTap: _toggleControlPanel,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Opacity(
                          opacity: 0.9,
                          child: Image.asset(
                            'assets/logo.png',
                            height: 28,
                            errorBuilder:
                                (_, __, ___) => const Text(
                                  'HANNUTV',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showControls) ...[
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(color: Colors.black38),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _buildFocusableItem(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(18),
                        child: const CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 18,
                          child: Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 48,
                      child: _buildFocusableItem(
                        onTap: _cycleAspectRatio,
                        borderRadius: BorderRadius.circular(16),
                        child: const CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 16,
                          child: Icon(
                            Icons.aspect_ratio,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: _buildFocusableItem(
                        onTap: _toggleFullScreen,
                        borderRadius: BorderRadius.circular(16),
                        child: const CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 16,
                          child: Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (isPageLoading && !isVideoPlaying)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black87,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/logo.png',
                                height: 40,
                                errorBuilder:
                                    (_, __, ___) => const Icon(
                                      Icons.movie,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              const SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  color: Colors.redAccent,
                                  strokeWidth: 2.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "Loading HANNUTV Server",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Requesting stream from $activeServer node...",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.movieTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          widget.rating,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.year,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.visibility,
                          color: Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "$viewCount Views",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFocusableItem(
                            onTap: () {
                              setState(() {
                                isLiked = !isLiked;
                                likeCount += isLiked ? 1 : -1;
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: _buildActionButton(
                              isLiked
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_alt_outlined,
                              "$likeCount",
                              activeColor:
                                  isLiked ? Colors.redAccent : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildFocusableItem(
                            onTap: () {},
                            borderRadius: BorderRadius.circular(20),
                            child: _buildActionButton(
                              Icons.bookmark_border,
                              "Add to List",
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildFocusableItem(
                            onTap: () {},
                            borderRadius: BorderRadius.circular(20),
                            child: _buildActionButton(
                              Icons.tv,
                              "Play on TV",
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildFocusableItem(
                            onTap: _shareDeepLink, // 🚀 ADDED ACTION
                            borderRadius: BorderRadius.circular(20),
                            child: _buildActionButton(Icons.share, "Share"),
                          ),
                          const SizedBox(width: 8),
                          _buildFocusableItem(
                            onTap: () {},
                            borderRadius: BorderRadius.circular(20),
                            child: _buildActionButton(
                              Icons.flag_outlined,
                              "Report",
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "If current server is not working, try a different one:",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text(
                            "Servers : ",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ...servers.map((srv) {
                            final isSelected = activeServer == srv['key'];
                            return _buildFocusableItem(
                              onTap: () {
                                if (activeServer != srv['key']) {
                                  setState(() {
                                    activeServer = srv['key']!;
                                  });
                                  _initStream();
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.grey[900],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  srv['name']!,
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.black
                                            : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    
                    // 🚀 WORLD'S BEST HARDCODING: Aapka Original Banner Script (320x50) 🚀
                    const CustomBannerAd(
                      htmlBannerCode: '''
                        <script type="text/javascript">
                          atOptions = {
                            'key' : 'a39df283f6ad10c34e229e5715bceff5',
                            'format' : 'iframe',
                            'height' : 50,
                            'width' : 320,
                            'params' : {}
                          };
                        </script>
                        <script type="text/javascript" src="https://www.highrevenueformat.com/a39df283f6ad10c34e229e5715bceff5/invoke.js"></script>
                      ''',
                    ),
                    
                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Comments ${publicComments.length}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Icon(
                                Icons.comment,
                                color: Colors.grey,
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: commentInputController,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Add a comment...',
                                    hintStyle: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                    filled: true,
                                    fillColor: Colors.black45,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              _buildFocusableItem(
                                onTap: _addLiveComment, // 🚀 ADDED LIVE ACTION
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.send,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 🚀 ADDED: LIVE FIREBASE STREAM (Fallback me aapka list loop bhi hai)
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('comments_${widget.tmdbId}').orderBy('timestamp', descending: true).snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError || !snapshot.hasData) {
                                return Column(
                                  children: publicComments.map((c) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(radius: 14, backgroundColor: Colors.redAccent, child: Text(c['avatar']!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [Text(c['name']!, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(width: 6), Text(c['time']!, style: const TextStyle(color: Colors.grey, fontSize: 10))]),
                                              Text(c['text']!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                );
                              }
                              var docs = snapshot.data!.docs;
                              if (docs.isEmpty) return const Text("Be the first to comment!", style: TextStyle(color: Colors.grey));
                              
                              return Column(
                                children: docs.map((doc) {
                                  var data = doc.data() as Map<String, dynamic>;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(radius: 14, backgroundColor: Colors.redAccent, child: Text(data['avatar'] ?? 'U', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [Text(data['name'] ?? 'User', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(width: 6), const Text('Live', style: TextStyle(color: Colors.green, fontSize: 10))]),
                                              Text(data['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (widget.mediaType == 'tv' ||
                        widget.mediaType == 'series') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "Season $currentSeason",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.grid_view,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Episodes",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 15,
                          itemBuilder: (context, index) {
                            final epNum = index + 1;
                            final isCurrent = currentEpisode == epNum;

                            return _buildFocusableItem(
                              onTap: () => _switchEpisode(epNum),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 170,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      isCurrent
                                          ? Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          )
                                          : null,
                                  color: isCurrent ? Colors.green : Colors.grey[900], // 🚀 ADDED: Green Color For Active
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(8),
                                              ),
                                          color: Colors.grey[850],
                                        ),
                                        child: Center(
                                          child: Icon(
                                            isCurrent
                                                ? Icons.play_arrow
                                                : Icons.play_circle_outline,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Episode : $epNum",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Text(
                                            "Stream on HANNUTV",
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                            ),
                                            maxLines: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (similarMovies.isNotEmpty) ...[
                      const Text(
                        "Suggested Movies & Shows",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: similarMovies.length,
                          itemBuilder: (context, index) {
                            final m = similarMovies[index];
                            return _buildFocusableItem(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => SkippableAdScreen(
                                          adDuration: 30, // Suggested me 30s fix kiya hai
                                          nextScreen: VideoPlayerPage(
                                            tmdbId: m['id'],
                                            mediaType: m['mediaType'],
                                            movieTitle: m['title'],
                                            rating: m['rating'],
                                            year: m['year'],
                                          ),
                                        ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 110,
                                margin: const EdgeInsets.only(right: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          image: DecorationImage(
                                            image: NetworkImage(
                                              m['posterUrl'] != ''
                                                  ? m['posterUrl']
                                                  : 'https://via.placeholder.com/300x450/222222/888888',
                                            ),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      m['title'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String title, {
    Color activeColor = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: activeColor, size: 16),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: activeColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TvFocusItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TvFocusItem({Key? key, required this.child, required this.onTap}) : super(key: key);

  @override
  State<_TvFocusItem> createState() => _TvFocusItemState();
}

class _TvFocusItemState extends State<_TvFocusItem> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (mounted) {
          setState(() => _hasFocus = hasFocus);
        }
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hasFocus ? Colors.redAccent : Colors.transparent, 
              width: _hasFocus ? 4 : 0
            ),
            boxShadow: _hasFocus ? [BoxShadow(color: Colors.redAccent.withOpacity(0.6), blurRadius: 10)] : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _TvFocusButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _TvFocusButton({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_TvFocusButton> createState() => _TvFocusButtonState();
}

class _TvFocusButtonState extends State<_TvFocusButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (mounted) setState(() => _hasFocus = hasFocus);
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: widget.borderRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: _hasFocus ? Colors.redAccent : Colors.transparent,
              width: _hasFocus ? 3.5 : 0,
            ),
            boxShadow:
                _hasFocus
                    ? [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.65),
                        blurRadius: 10,
                        spreadRadius: 1.5,
                      ),
                    ]
                    : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}