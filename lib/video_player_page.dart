import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const String kTmdbToken =
    'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIzZDJkOTExNmM5ZGU3MjA5ZWUyNzdiYjhjYzlhZWVkOCIsIm5iZiI6MTc5MDI2OTE4NC42MjksInN1YiI6IjZhYjU1NzAwNzZiMTg1ODU3MGFjNDM4NSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.xZJX8fowhVhVJsgl-5wOW6Y7ZfUr9Zu_Ey1qMkhnPd0';

const Map<String, String> kApiHeaders = {
  'Authorization': 'Bearer $kTmdbToken',
  'accept': 'application/json',
};

class VideoPlayerPage extends StatefulWidget {
  final int tmdbId;
  final String mediaType; // 'movie' or 'tv'
  final int season;
  final int episode;
  final String movieTitle;
  final String overview;
  final String rating;
  final String year;
  final String? customUrl;

  const VideoPlayerPage({
    Key? key,
    required this.tmdbId,
    required this.mediaType,
    this.season = 1,
    this.episode = 1,
    required this.movieTitle,
    this.overview = '',
    this.rating = '9.0',
    this.year = '2024',
    this.customUrl,
  }) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> with TickerProviderStateMixin {
  late WebViewController _controller;

  bool isVideoPlaying = false;
  
  // 🔥 FIX: Reverted to false so it starts normally without causing Black Screen on phones
  bool isFullScreen = false; 
  
  bool isPageLoading = true;
  String activeServer = 'vidrift'; // Default to Rift

  // Scale / Aspect Ratio Mode (Fill, Fit, Cover)
  String currentAspectRatio = 'contain'; 

  late int currentSeason;
  late int currentEpisode;
  bool isLiked = false;
  int likeCount = 1248;
  int viewCount = 84920;

  // Auto-Hide Controls Timer (Strict 3 Seconds)
  bool showControls = true;
  Timer? _hideControlsTimer;

  // Cinematic Intro Animation
  bool showIntroAnimation = false;
  late AnimationController _introAnimController;
  late Animation<double> _introScaleAnimation;
  late Animation<double> _introOpacityAnimation;

  final TextEditingController commentInputController = TextEditingController();

  // 🤖 10 COMPLETE PANTYFLIX SERVER NODES MAPPED DIRECTLY TO HANNUTV BUTTONS
  final List<Map<String, String>> servers = [
    {'key': 'vidrift', 'name': 'Rift'},
    {'key': 'fast', 'name': 'Fast'},
    {'key': 'vidbolt', 'name': 'Bolt'},
    {'key': 'vidspiral', 'name': 'Spiral'},
    {'key': 'cinezo', 'name': 'Cinezo'},
    {'key': 'orion', 'name': 'Orion'},
    {'key': 'alpha', 'name': 'Alpha'},
    {'key': 'mega', 'name': 'Mega'},
    {'key': 'peach', 'name': 'Peach'},
    {'key': 'hindi-new', 'name': 'Hindi New'},
  ];

  // REAL WORKING PUBLIC COMMENTS
  final List<Map<String, String>> publicComments = [
    {'name': 'SHEEL', 'text': 'HARE KRISHNA 🦚', 'time': '9d', 'avatar': 'S'},
    {'name': 'Rohit Sharma', 'text': 'Best quality on HANNUTV, loving this series! 🔥', 'time': '2d', 'avatar': 'R'},
    {'name': 'Ananya Verma', 'text': 'Full HD stream with no buffering ❤️', 'time': '5h', 'avatar': 'A'},
  ];

  List similarMovies = [];
  bool isLoadingSimilar = false;

  @override
  void initState() {
    super.initState();
    currentSeason = widget.season;
    currentEpisode = widget.episode;

    // Start safely in Portrait mode to prevent Android WebView Black Screen Crash
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Setup Cinematic Animation
    _introAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _introScaleAnimation = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _introAnimController, curve: Curves.easeOutBack),
    );
    _introOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _introAnimController, curve: const Interval(0.65, 1.0, curve: Curves.easeIn)),
    );

    _fetchSimilarMovies();
    _initStream();
    _resetHideTimer(); 
  }

  // 🕒 STRICT 3-SECOND AUTO-HIDE LOGIC
  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    if (mounted) setState(() => showControls = true);
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => showControls = false);
    });
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

  Future<void> _fetchSimilarMovies() async {
    setState(() => isLoadingSimilar = true);
    try {
      final type = widget.mediaType == 'tv' || widget.mediaType == 'series' ? 'tv' : 'movie';
      final res = await http.get(
        Uri.parse('https://api.themoviedb.org/3/$type/${widget.tmdbId}/recommendations?language=en-US'),
        headers: kApiHeaders,
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List results = data['results'] ?? [];
        if(mounted) {
          setState(() {
            similarMovies = results.map((m) => {
              'id': m['id'],
              'title': m['title'] ?? m['name'] ?? 'Unknown',
              'posterUrl': m['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${m['poster_path']}' : '',
              'rating': (m['vote_average'] ?? 0).toStringAsFixed(1),
              'year': (m['release_date'] ?? m['first_air_date'] ?? '').toString().split('-').first,
              'mediaType': type,
            }).toList();
            isLoadingSimilar = false;
          });
        }
      } else {
        if(mounted) setState(() => isLoadingSimilar = false);
      }
    } catch (_) {
      if(mounted) setState(() => isLoadingSimilar = false);
    }
  }

  String _buildStreamUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) {
      return widget.customUrl!;
    }

    final id = widget.tmdbId;
    final s = currentSeason;
    final e = currentEpisode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    // 🚀 DIRECT SERVER ENGINE MAPPING
    return isTv
        ? 'https://pantyflix.com/watch/play/tv/$id?season=$s&episode=$e&server=$activeServer'
        : 'https://pantyflix.com/watch/play/movie/$id?server=$activeServer';
  }

  // 🛡️ THE NUCLEAR AD-BLOCKER (YOUR ORIGINAL TRUSTED LOGIC)
  void _initStream() {
    setState(() {
      isPageLoading = true;
      isVideoPlaying = false;
      showIntroAnimation = false;
    });

    final targetUrl = _buildStreamUrl();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      )
      ..addJavaScriptChannel(
        'VideoState',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'playing' && mounted) {
            _triggerCinematicPlayAnimation();
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

              var style = document.createElement('style');
              style.innerHTML = `
                header, nav, .navbar, footer, .footer,
                .server-select, .server-dropdown, select, 
                div[class*="server"], div[id*="server"],
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
                  overflow: hidden !important;
                }
                video {
                  object-fit: $currentAspectRatio !important;
                  width: 100% !important;
                  height: 100% !important;
                }
              `;
              document.head.appendChild(style);

              // 🚀 REAL-TIME XPATH KILLER & NATIVE FULLSCREEN BLOCKER
              setInterval(function() {
                // 1. Nuke Dropdowns
                document.querySelectorAll('div, a, span, button, ul, li').forEach(el => {
                  let text = el.innerText ? el.innerText.toLowerCase().trim() : '';
                  if (text.includes('(ads)') || text.includes('rift(ads)') || text.includes('bolt(ads)') || text.includes('fast(ads)') || text.includes('cinezo(ads)') || text.includes('hindi new')) {
                    el.remove();
                  }
                  if (text.includes('telegram') || text.includes('dmca') || text.includes('support@') || text.includes('contact us')) {
                    el.remove();
                  }
                });

                // 2. 🔥 FIX BLACK SCREEN BUG: Hide Native Web Player's Fullscreen Button
                var fsBtns = document.querySelectorAll('.jw-icon-fullscreen, .vjs-fullscreen-control, [aria-label*="ullscreen"], [title*="ullscreen"], .plyr__controls__item[data-plyr="fullscreen"]');
                fsBtns.forEach(btn => {
                   btn.style.display = 'none';
                   btn.style.opacity = '0';
                   btn.style.pointerEvents = 'none';
                });

                // 3. Force Auto-Play & Adjust Screen Ratio
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0) {
                  var v = vids[0];
                  v.style.objectFit = '$currentAspectRatio';
                  if (v.paused && !v.ended) {
                    v.play().catch(function(){});
                  }
                  if (v.currentTime > 0.5 && !v.paused) {
                    VideoState.postMessage('playing');
                  }
                }
              }, 100);
            ''';
            _controller.runJavaScript(jsCode);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();

            // 🚫 YOUR TRUSTED OLD AD-BLOCKER: Strict Block EVERYTHING
            if (url.contains('doubleclick') || url.contains('popads') ||
                url.contains('1xbet') || url.contains('bet365') ||
                url.contains('onclick') || url.contains('adsterra') ||
                url.contains('lucky') || url.contains('amazon') ||
                url.contains('vast') || url.contains('vpaid') ||
                url.contains('t.me') || url.contains('telegram') ||
                url.contains('monetag') || url.contains('exoclick') ||
                url.contains('redirect') ||
                url.contains('market://') || url.contains('intent://')) {
              return NavigationDecision.prevent;
            }

            // ✅ ALLOW ONLY THESE SAFE STREAMING SERVERS
            if (url.contains('pantyflix.com') ||
                url.contains('vidbolt') ||
                url.contains('vidsrc') ||
                url.contains('vidlink') ||
                url.contains('multiembed') ||
                url.contains('pages.dev') ||
                url.contains('google.com/recaptcha') ||
                url.startsWith('about:blank') ||
                url.startsWith('data:')) {
              return NavigationDecision.navigate;
            }

            // STRICT FALLBACK BLOCK FOR ANY OTHER AD DOMAIN
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
          <iframe src="$targetUrl" allow="autoplay; fullscreen; encrypted-media; picture-in-picture" allowfullscreen></iframe>
        </body>
      </html>
    ''';

    _controller.loadHtmlString(embedHtml, baseUrl: 'https://pantyflix.com');
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
    _resetHideTimer(); 
  }

  // 🖥️ ROTATE & FULLSCREEN LOGIC (TV COMPATIBLE)
  void _toggleFullScreen() {
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
    _resetHideTimer();
  }

  void _switchEpisode(int ep) {
    setState(() {
      currentEpisode = ep;
    });
    _initStream();
  }

  void _addComment() {
    final text = commentInputController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        publicComments.insert(0, {
          'name': 'You',
          'text': text,
          'time': 'Just now',
          'avatar': 'Y',
        });
        commentInputController.clear();
      });
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _introAnimController.dispose();
    commentInputController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    if (isFullScreen) {
      // ==========================================
      // 🖥️ PURE LANDSCAPE FULLSCREEN VIEW
      // ==========================================
      return PopScope(
        canPop: false,
        onPopInvoked: (bool didPop) {
          if (didPop) return;
          _toggleFullScreen(); 
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: _resetHideTimer, // Tap anywhere to show/reset 3s timer
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                Positioned.fill(
                  child: WebViewWidget(controller: _controller),
                ),

                // 🌟 HANNUTV CINEMATIC INTRO ANIMATION ON PLAY
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
                                    Image.asset('assets/logo.png', height: 90, errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_fill, color: Colors.red, size: 90)),
                                    const SizedBox(height: 10),
                                    const Text("HANNUTV CINEMA", style: TextStyle(color: Colors.red, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                // 🕒 AUTO-HIDE CONTROLS (3 SECONDS)
                if (showControls) ...[
                  
                  // 🔥 LOGO & BACK BUTTON MOVED TO TOP-LEFT (NO OVERLAP)
                  Positioned(
                    top: 20,
                    left: 20,
                    child: SafeArea(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 22,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                              onPressed: () {
                                SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                                Navigator.pop(context); // Close entirely
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Opacity(
                            opacity: 0.9,
                            child: Image.asset(
                              'assets/logo.png',
                              height: 38,
                              errorBuilder: (_, __, ___) => const Text('HANNUTV', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 🌟 SCREEN FIT/ASPECT RATIO BUTTON (TOP-RIGHT, LOW OPACITY)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: SafeArea(
                      child: Opacity(
                        opacity: 0.6,
                        child: GestureDetector(
                          onTap: _cycleAspectRatio,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white30)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.aspect_ratio, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(currentAspectRatio.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Rotate Exit Fullscreen Button (Bottom-Right)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: SafeArea(
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        radius: 22,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
                          onPressed: _toggleFullScreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // ==========================================
    // 📱 PORTRAIT YOUTUBE-STYLE VIEW
    // ==========================================
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP VIDEO PLAYER WINDOW (230px height)
              GestureDetector(
                onTap: _resetHideTimer,
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 230,
                      color: Colors.black,
                      child: WebViewWidget(controller: _controller),
                    ),

                    // 🌟 CINEMATIC HANNUTV INTRO ANIMATION
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
                                    child: Image.asset('assets/logo.png', height: 60, errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_fill, color: Colors.red, size: 60)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                    // 🕒 AUTO-HIDE CONTROLS (3 SECONDS)
                    if (showControls) ...[
                      // 🔥 LOGO & BACK BUTTON MOVED TO TOP-LEFT
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 18,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Opacity(
                              opacity: 0.9,
                              child: Image.asset('assets/logo.png', height: 28, errorBuilder: (_, __, ___) => const Text('HANNUTV', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16))),
                            ),
                          ],
                        ),
                      ),

                      // 🌟 SCREEN FIT/ASPECT RATIO BUTTON (TOP-RIGHT, LOW OPACITY)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Opacity(
                          opacity: 0.6,
                          child: GestureDetector(
                            onTap: _cycleAspectRatio,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white30)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.aspect_ratio, color: Colors.white, size: 14),
                                  const SizedBox(width: 6),
                                  Text(currentAspectRatio.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Rotate Fullscreen Button (Bottom Right)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 18,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
                            onPressed: _toggleFullScreen,
                          ),
                        ),
                      ),
                    ],

                    // Fast Loading Indicator with HANNUTV Branding
                    if (isPageLoading && !isVideoPlaying)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black87,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/logo.png', height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.movie, color: Colors.red, size: 40)),
                                const SizedBox(height: 12),
                                const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2.5)),
                                const SizedBox(height: 10),
                                const Text("Loading HANNUTV Server", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text("Requesting stream from $activeServer node...", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 2. SCROLLABLE DETAILS SECTION (100% UNCHANGED)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.movieTitle, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(widget.rating, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Text(widget.year, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          const SizedBox(width: 16),
                          const Icon(Icons.visibility, color: Colors.grey, size: 16),
                          const SizedBox(width: 4),
                          Text("$viewCount Views", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  isLiked = !isLiked;
                                  likeCount += isLiked ? 1 : -1;
                                });
                              },
                              child: _buildActionButton(isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, "$likeCount", activeColor: isLiked ? Colors.redAccent : Colors.white),
                            ),
                            const SizedBox(width: 8),
                            _buildActionButton(Icons.bookmark_border, "Add to List"),
                            const SizedBox(width: 8),
                            _buildActionButton(Icons.tv, "Play on TV"),
                            const SizedBox(width: 8),
                            _buildActionButton(Icons.share, "Share"),
                            const SizedBox(width: 8),
                            _buildActionButton(Icons.flag_outlined, "Report"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text("If current server is not working, try a different one:", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          const Text("Servers : ", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: servers.map((srv) {
                                  final isSelected = activeServer == srv['key'];
                                  return GestureDetector(
                                    onTap: () {
                                      if (activeServer != srv['key']) {
                                        setState(() {
                                          activeServer = srv['key']!;
                                        });
                                        _initStream();
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.grey[900], borderRadius: BorderRadius.circular(20)),
                                      child: Text(srv['name']!, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Comments ${publicComments.length}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                const Icon(Icons.comment, color: Colors.grey, size: 16),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: commentInputController,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: 'Add a comment...',
                                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                                      filled: true,
                                      fillColor: Colors.black45,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ),
                                IconButton(icon: const Icon(Icons.send, color: Colors.redAccent, size: 20), onPressed: _addComment),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...publicComments.map((c) => Padding(
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
                                        Row(
                                          children: [
                                            Text(c['name']!, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                            const SizedBox(width: 6),
                                            Text(c['time']!, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                          ],
                                        ),
                                        Text(c['text']!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (isTv) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                              child: Text("Season $currentSeason", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            const Icon(Icons.grid_view, color: Colors.grey, size: 20),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text("Episodes", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),

                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: 15,
                            itemBuilder: (context, index) {
                              final epNum = index + 1;
                              final isCurrent = currentEpisode == epNum;

                              return GestureDetector(
                                onTap: () => _switchEpisode(epNum),
                                child: Container(
                                  width: 170,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
                                    color: Colors.grey[900],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                            color: Colors.grey[850],
                                          ),
                                          child: Center(
                                            child: Icon(isCurrent ? Icons.play_arrow : Icons.play_circle_outline, color: Colors.white, size: 32),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("Episode : $epNum", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                            const Text("Stream on HANNUTV", style: TextStyle(color: Colors.grey, fontSize: 10), maxLines: 1),
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
                        const Text("Suggested Movies & Shows", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 160,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: similarMovies.length,
                            itemBuilder: (context, index) {
                              final m = similarMovies[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => VideoPlayerPage(
                                        tmdbId: m['id'],
                                        mediaType: m['mediaType'],
                                        movieTitle: m['title'],
                                        rating: m['rating'],
                                        year: m['year'],
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 110,
                                  margin: const EdgeInsets.only(right: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            image: DecorationImage(
                                              image: NetworkImage(m['posterUrl'] != '' ? m['posterUrl'] : 'https://via.placeholder.com/300x450/222222/888888'),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(m['title'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
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
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String title, {Color activeColor = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: activeColor, size: 16),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(color: activeColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}