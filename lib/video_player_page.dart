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
  final String overview;
  final String rating;
  final String year;
  final List seasons;
  final String preferredServer; // Added parameter to match constructor call

  const VideoPlayerPage({
    Key? key,
    required this.tmdbId,
    required this.mediaType,
    required this.season,
    required this.episode,
    required this.movieTitle,
    this.customUrl,
    this.overview = '',
    this.rating = '9.0',
    this.year = '2024',
    this.seasons = const [],
    this.preferredServer = 'vidrift',
  }) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late WebViewController _controller;

  bool isVideoPlaying = false;
  bool isFullScreen = false;
  bool isPageLoading = true;
  late String activeServer;
  late int currentSeason;
  late int currentEpisode;

  // 🤖 PANTYFLIX VERIFIED SERVERS
  final List<Map<String, String>> pantyflixServers = [
    {'key': 'vidrift', 'name': 'Rift'},
    {'key': 'spiral', 'name': 'Spiral'},
    {'key': 'hydra', 'name': 'Hydra'},
    {'key': 'vidbolt', 'name': 'VidBolt VIP'},
  ];

  @override
  void initState() {
    super.initState();
    activeServer = widget.preferredServer;
    currentSeason = widget.season;
    currentEpisode = widget.episode;

    // Portrait Mode by Default (YouTube Style UI)
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _initPantyFlixStream();
  }

  void _initPantyFlixStream() {
    setState(() {
      isPageLoading = true;
      isVideoPlaying = false;
    });

    final targetUrl = _buildPantyflixUrl();

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
          onPageFinished: (String url) {
            // 🛡️ WORLD'S BEST PANTYFLIX AD-KILLER & BRANDING NUKER
            String jsCode = '''
              document.documentElement.style.backgroundColor = '#000000';
              document.body.style.backgroundColor = '#000000';

              window.open = function() { return null; };
              window.alert = function() { return null; };
              window.confirm = function() { return null; };

              setInterval(function() {
                // A. Video Auto Play & Unmute
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

                // B. Auto click play triggers
                var playBtns = document.querySelectorAll('.play-btn, .vjs-big-play-button, .jw-display-icon-container, [aria-label="Play"], button[title*="Play"], .play-icon');
                playBtns.forEach(function(b) { b.click(); });

                // C. Kill Pantyflix Telegram, Footer, DMCA, support emails & Ads
                document.querySelectorAll('div, a, span, img, section, modal, aside, p, h2, header, footer, nav').forEach(el => {
                  let text = el.innerText ? el.innerText.toLowerCase() : '';
                  let href = el.href ? el.href.toLowerCase() : '';
                  let className = el.className ? el.className.toString().toLowerCase() : '';
                  let style = window.getComputedStyle(el);

                  // Remove Telegram & DMCA / Contact
                  if (text.includes('telegram') || text.includes('dmca') || text.includes('support@pantyflix') || href.includes('t.me') || text.includes('contact us')) {
                    el.remove();
                  }

                  // Remove Navbar/Header
                  if (el.tagName === 'HEADER' || el.tagName === 'NAV' || className.includes('header') || className.includes('navbar')) {
                    el.style.display = 'none';
                  }

                  // Remove Floating Ad Overlays
                  if ((style.position === 'fixed' || style.position === 'absolute') && 
                      style.zIndex > 1000 && 
                      el.tagName !== 'IFRAME' && 
                      el.tagName !== 'VIDEO' &&
                      !el.contains(document.querySelector('video'))) {
                    el.remove();
                  }

                  // Banners
                  if (className.includes('banner') || className.includes('ad-') || className.includes('popup')) {
                    el.remove();
                  }
                });
              }, 200);
            ''';
            _controller.runJavaScript(jsCode);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();

            // 🚫 Block Ads & Telegram links
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
                url.contains('telegram')) {
              return NavigationDecision.prevent;
            }

            // ✅ Allow safe streaming embed links
            if (url.contains('pantyflix.com') ||
                url.contains('vidbolt') ||
                url.contains('vidsrc') ||
                url.contains('vidlink') ||
                url.contains('pages.dev') ||
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
        'Referer': 'https://pantyflix.com/',
        'Origin': 'https://pantyflix.com',
      },
    );

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  String _buildPantyflixUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) {
      return widget.customUrl!;
    }

    final id = widget.tmdbId;
    final s = currentSeason;
    final e = currentEpisode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    // 🚀 PANTYFLIX DIRECT ROUTED URL PATTERN
    if (isTv) {
      return 'https://pantyflix.com/watch/play/tv/$id/$s/$e?server=$activeServer';
    } else {
      return 'https://pantyflix.com/watch/play/movie/$id?server=$activeServer';
    }
  }

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
  }

  void _switchEpisode(int s, int ep) {
    setState(() {
      currentSeason = s;
      currentEpisode = ep;
    });
    _initPantyFlixStream();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: WebViewWidget(controller: _controller),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
                  onPressed: _toggleFullScreen,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 📱 YOUTUBE-STYLE PORTRAIT UI (MATCHING SCREENSHOT)
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP VIDEO PLAYER WINDOW
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 230,
                  color: Colors.black,
                  child: WebViewWidget(controller: _controller),
                ),

                // Top Back Button
                Positioned(
                  top: 8,
                  left: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 18,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),

                // Top Watermark Logo
                Positioned(
                  top: 12,
                  right: 12,
                  child: Opacity(
                    opacity: 0.6,
                    child: Image.asset('assets/logo.png', height: 24, errorBuilder: (_, __, ___) => const Text('HANNUTV', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                  ),
                ),

                // FullScreen Rotate Button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 16,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
                      onPressed: _toggleFullScreen,
                    ),
                  ),
                ),

                // Loading Indicator
                if (isPageLoading && !isVideoPlaying)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 35,
                              height: 35,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Loading selected server",
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Requesting a playable link from $activeServer...",
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // 2. SCROLLABLE DETAILS & EPISODES SECTION
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Movie / Series Title
                    Text(
                      widget.movieTitle,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),

                    // Rating & Year
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(widget.rating, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Text(widget.year, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Action Buttons (Add to List, Play on TV, Share, Report)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
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

                    // Server Section Title
                    const Text(
                      "If current server is not working, try a different one:",
                      style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 10),

                    // Servers Switcher Tabs (Rift, Spiral, Hydra, etc.)
                    Row(
                      children: [
                        const Text("Servers : ", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        ...pantyflixServers.map((srv) {
                          final isSelected = activeServer == srv['key'];
                          return GestureDetector(
                            onTap: () {
                              if (activeServer != srv['key']) {
                                setState(() {
                                  activeServer = srv['key']!;
                                });
                                _initPantyFlixStream();
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.grey[900],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                srv['name']!,
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Comments Preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Comments  1", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.redAccent,
                                child: Icon(Icons.person, color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text("HANNUTV User", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text("Awesome HD Quality 🔥", style: TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Episodes Section (If TV Show)
                    if (widget.mediaType == 'tv' || widget.mediaType == 'series') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "Season $currentSeason",
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const Icon(Icons.grid_view, color: Colors.grey, size: 20),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text("Episodes", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),

                      // Episode Cards List (Horizontal Grid like Pantyflix)
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 15,
                          itemBuilder: (context, index) {
                            final epNum = index + 1;
                            final isCurrent = currentEpisode == epNum;
                            return GestureDetector(
                              onTap: () => _switchEpisode(currentSeason, epNum),
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
                                          image: DecorationImage(
                                            image: NetworkImage(
                                              'https://image.tmdb.org/t/p/w500/image.jpg',
                                            ),
                                            fit: BoxFit.cover,
                                            onError: (_, __) => null,
                                          ),
                                          color: Colors.grey[850],
                                        ),
                                        child: Center(
                                          child: Icon(
                                            isCurrent ? Icons.play_arrow : Icons.play_circle_outline,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Episode : $epNum", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          const Text("Playing next on HANNUTV", style: TextStyle(color: Colors.grey, fontSize: 10), maxLines: 1),
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

  Widget _buildActionButton(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
