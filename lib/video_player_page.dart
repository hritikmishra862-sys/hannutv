import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

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

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late WebViewController _controller;

  bool isVideoPlaying = false;
  bool isFullScreen = false;
  bool isPageLoading = true;
  String activeServer = 'vidrift'; // Default Rift Server

  late int currentSeason;
  late int currentEpisode;
  bool isLiked = false;
  int likeCount = 1248;
  int viewCount = 84920;

  // 🤖 PANTYFLIX WORKING SERVERS (RIFT, SPIRAL, HYDRA, VIDBOLT)
  final List<Map<String, String>> servers = [
    {'key': 'vidrift', 'name': 'Rift'},
    {'key': 'spiral', 'name': 'Spiral'},
    {'key': 'hydra', 'name': 'Hydra'},
    {'key': 'vidbolt', 'name': 'VidBolt VIP'},
  ];

  // REALISTIC PUBLIC COMMENTS FOR OTT APP
  final List<Map<String, String>> publicComments = [
    {'name': 'SHEEL', 'text': 'HARE KRISHNA 🦚', 'time': '9d', 'avatar': 'S'},
    {'name': 'Rohit Sharma', 'text': 'Best quality on HANNUTV, loving this series! 🔥', 'time': '2d', 'avatar': 'R'},
    {'name': 'Ananya Verma', 'text': 'Full HD stream with no buffering ❤️', 'time': '5h', 'avatar': 'A'},
  ];

  @override
  void initState() {
    super.initState();
    currentSeason = widget.season;
    currentEpisode = widget.episode;

    // Start in Portrait mode (YouTube Style UI)
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _initStream();
  }

  String _buildPantyflixStreamUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) {
      return widget.customUrl!;
    }

    final id = widget.tmdbId;
    final s = currentSeason;
    final e = currentEpisode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    // 🚀 DIRECT PANTYFLIX STREAM URL ENGINE
    if (activeServer == 'vidrift') {
      return isTv
          ? 'https://pantyflix.com/watch/play/tv/$id?season=$s&episode=$e&server=vidrift'
          : 'https://pantyflix.com/watch/play/movie/$id?server=vidrift';
    }
    if (activeServer == 'spiral') {
      return isTv
          ? 'https://vidsrc.icu/embed/tv/$id/$s/$e'
          : 'https://vidsrc.icu/embed/movie/$id';
    }
    if (activeServer == 'hydra') {
      return isTv
          ? 'https://vidsrc.to/embed/tv/$id/$s/$e'
          : 'https://vidsrc.to/embed/movie/$id';
    }

    // VidBolt VIP
    return isTv
        ? 'https://vidbolt.pro/tv/$id/$s/$e?quality=1080p&theme=e50914&autoPlay=true&audio=hindi'
        : 'https://vidbolt.pro/movie/$id?quality=1080p&theme=e50914&autoPlay=true&audio=hindi';
  }

  void _initStream() {
    setState(() {
      isPageLoading = true;
      isVideoPlaying = false;
    });

    final targetUrl = _buildPantyflixStreamUrl();

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

            // 🛡️ WORLD'S BEST AD-KILLER, AUTO-PLAY & BRANDING NUKER
            String jsCode = '''
              // Force Black Screen
              document.documentElement.style.backgroundColor = '#000000';
              document.body.style.backgroundColor = '#000000';

              // Prevent all redirects and popups
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
                var playBtns = document.querySelectorAll('.play-btn, .vjs-big-play-button, .jw-display-icon-container, [aria-label="Play"], button[title*="Play"], .play-icon, #play-button');
                playBtns.forEach(function(b) { b.click(); });

                // C. Kill Pantyflix Telegram, Header, Footer, DMCA, support emails & Ads
                document.querySelectorAll('div, a, span, img, section, modal, aside, p, h2, header, footer, nav').forEach(el => {
                  let text = el.innerText ? el.innerText.toLowerCase() : '';
                  let href = el.href ? el.href.toLowerCase() : '';
                  let className = el.className ? el.className.toString().toLowerCase() : '';
                  let style = window.getComputedStyle(el);

                  // Remove Telegram & DMCA / Contact
                  if (text.includes('telegram') || text.includes('dmca') || text.includes('support@') || href.includes('t.me') || text.includes('contact us')) {
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

            // 🚫 HARD BLOCK ADS & BETTING POPUPS
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

            // ✅ ALLOW ONLY STREAMING SERVERS
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

  void _switchEpisode(int ep) {
    setState(() {
      currentEpisode = ep;
    });
    _initStream();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
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

    // 📱 EXACT SCREENSHOT YOUTUBE PORTRAIT LAYOUT
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP VIDEO PLAYER WINDOW (230px height, fixed ratio)
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 230,
                  color: Colors.black,
                  child: WebViewWidget(controller: _controller),
                ),

                // Top Back Arrow
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

                // Fullscreen Button
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

                // Fast Loading Spinner
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

            // 2. SCROLLABLE DETAILS SECTION (EXACT SCREENSHOT BUTTONS & SERVERS)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      widget.movieTitle,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),

                    // Star Rating, Year & Views Count
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

                    // Action Buttons Row (Like, Add to List, Play on TV, Share, Report)
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
                            child: _buildActionButton(
                              isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                              "$likeCount",
                              activeColor: isLiked ? Colors.redAccent : Colors.white,
                            ),
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

                    // Server Section Title
                    const Text(
                      "If current server is not working, try a different one:",
                      style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 10),

                    // Server Switcher Buttons (Rift, Spiral, Hydra, VidBolt)
                    Row(
                      children: [
                        const Text("Servers : ", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        ...servers.map((srv) {
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

                    // Real Comments Section
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
                              Text("Comments ${publicComments.length}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              const Icon(Icons.comment, color: Colors.grey, size: 16),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...publicComments.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.redAccent,
                                  child: Text(c['avatar']!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
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

                      // Real Episodes Grid Cards
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

  Widget _buildActionButton(IconData icon, String title, {Color activeColor = Colors.white}) {
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
          Text(title, style: TextStyle(color: activeColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
