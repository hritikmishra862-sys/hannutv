import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'banner_ad_widget.dart'; // 🚀 Preserved Ad Widget
import 'skippable_ad_screen.dart'; // 🚀 Preserved Skippable Ad Screen

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
  final bool isServer2; // 🚀 TRUE = Pixelflix, FALSE = Pantyflix

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
    this.isServer2 = false,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> with SingleTickerProviderStateMixin {
  late WebViewController _controller;

  bool isVideoPlaying = false;
  bool isFullScreen = false;
  bool isPageLoading = true;
  
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

  final List<Map<String, String>> publicComments = const [
    {'name': 'SHEEL', 'text': 'HARE KRISHNA 🦚', 'time': '9d', 'avatar': 'S'},
    {'name': 'Rohit Sharma', 'text': 'Best quality on HANNUTV, loving this series! 🔥', 'time': '2d', 'avatar': 'R'},
  ];

  @override
  void initState() {
    super.initState();
    currentSeason = widget.season;
    currentEpisode = widget.episode;

    _introAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _introScaleAnimation = Tween<double>(begin: 0.7, end: 1.3).animate(CurvedAnimation(parent: _introAnimController, curve: Curves.easeOutBack));
    _introOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _introAnimController, curve: const Interval(0.65, 1.0, curve: Curves.easeIn)));

    _checkDeviceType(); 
  }

  void _checkDeviceType() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    if (showControls) { setState(() => showControls = false); _hideControlsTimer?.cancel(); } 
    else { _startControlsTimer(); }
  }

  void _triggerCinematicPlayAnimation() {
    if (showIntroAnimation || isVideoPlaying) return;
    setState(() { showIntroAnimation = true; isVideoPlaying = true; isPageLoading = false; });
    _introAnimController.forward().then((_) { if (mounted) setState(() => showIntroAnimation = false); });
  }

  // 🚀 URL GENERATOR FOR PIXELFLIX AND PANTYFLIX
  String _buildStreamUrl() {
    final id = widget.tmdbId;
    final s = currentSeason;
    final e = currentEpisode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    // 🚀 PIXELFLIX SERVER (HANNUTV 2) 🚀
    if (widget.isServer2) {
      return isTv
          ? 'https://pixelflix.cc/watch/tv/$id?season=$s&episode=$e'
          : 'https://pixelflix.cc/watch/movie/$id';
    }

    // 🚀 PANTYFLIX SERVER (HANNUTV 1) 🚀
    return isTv
        ? 'https://pantyflix.com/watch/play/tv/$id?season=$s&episode=$e&server=vidrift'
        : 'https://pantyflix.com/watch/play/movie/$id?server=vidrift';
  }

  void _initStream() {
    setState(() { isPageLoading = true; isVideoPlaying = false; showIntroAnimation = false; });
    final targetUrl = _buildStreamUrl();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13; SM-S918B Build/TP1A.220624.014) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36")
      ..addJavaScriptChannel(
        'VideoState',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'playing' && mounted) { _triggerCinematicPlayAnimation(); }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) { if (mounted) setState(() => isPageLoading = true); },
          onPageFinished: (String url) {
            if (mounted) setState(() => isPageLoading = false);

            // 🚀 ADS BLOCKER JAVASCRIPT PRESERVED 100% 🚀
            String jsCode = '''
              document.documentElement.style.backgroundColor = '#000000';
              document.body.style.backgroundColor = '#000000';

              // Popups को ब्लॉक करने के लिए
              window.open = function() { return null; };
              window.alert = function() { return null; };
              window.confirm = function() { return null; };

              // CSS से Ads छुपाने के लिए
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

              // DOM में आने वाले नए Ads को तुरंत डिलीट करने के लिए
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

              // Video को ज़बरदस्ती प्ले और फुल स्क्रीन करने के लिए
              setInterval(function() {
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
            // Block all ads
            if (url.contains('doubleclick') || url.contains('popads') || url.contains('1xbet') || url.contains('bet365')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    // 🚀 FIXED: SANDBOX ERROR REMOVED BY USING DIRECT LOAD REQUEST 🚀
    _controller.loadRequest(Uri.parse(targetUrl));
  }

  void _cycleAspectRatio() {
    setState(() {
      if (currentAspectRatio == 'contain') currentAspectRatio = 'cover';
      else if (currentAspectRatio == 'cover') currentAspectRatio = 'fill';
      else currentAspectRatio = 'contain';
    });
    _controller.runJavaScript("var vids = document.getElementsByTagName('video'); if (vids.length > 0) { vids[0].style.objectFit = '$currentAspectRatio'; }");
    _startControlsTimer();
  }

  void _toggleFullScreen() {
    setState(() => isFullScreen = !isFullScreen);
    if (isFullScreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _startControlsTimer();
  }

  void _switchEpisode(int ep) {
    setState(() => currentEpisode = ep);
    _initStream();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _introAnimController.dispose();
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
            Positioned.fill(child: WebViewWidget(controller: _controller)),
            Positioned(
              top: 14, right: 20,
              child: SafeArea(child: IgnorePointer(child: Opacity(opacity: 0.85, child: Image.asset('assets/logo.png', height: 38, errorBuilder: (_, __, ___) => const Text('HANNUTV', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)))))),
            ),
            if (showControls) ...[
              Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black38))),
              Positioned(top: 20, right: 20, child: SafeArea(child: InkWell(onTap: () { SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); Navigator.pop(context); }, child: const CircleAvatar(backgroundColor: Colors.black87, child: Icon(Icons.close, color: Colors.white))))),
              Positioned(bottom: 20, right: 20, child: SafeArea(child: InkWell(onTap: _toggleFullScreen, child: const CircleAvatar(backgroundColor: Colors.black87, child: Icon(Icons.fullscreen_exit, color: Colors.white))))),
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
                  Container(width: double.infinity, height: 230, color: Colors.black, child: WebViewWidget(controller: _controller)),
                  
                  // HANNUTV LOGO
                  Positioned(top: 10, right: 14, child: IgnorePointer(child: Opacity(opacity: 0.85, child: Image.asset('assets/logo.png', height: 34, errorBuilder: (_, __, ___) => const Text('HANNUTV', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)))))),
                  
                  if (showIntroAnimation)
                    Positioned.fill(child: IgnorePointer(child: Center(child: AnimatedBuilder(animation: _introAnimController, builder: (context, child) { return Opacity(opacity: _introOpacityAnimation.value, child: Transform.scale(scale: _introScaleAnimation.value, child: Image.asset('assets/logo.png', height: 60, errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_fill, color: Colors.red, size: 60)))); })))),
                  
                  if (showControls) ...[
                    Positioned.fill(child: IgnorePointer(child: Container(color: Colors.black38))),
                    Positioned(top: 10, left: 10, child: InkWell(onTap: () => Navigator.pop(context), child: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.chevron_left, color: Colors.white)))),
                    Positioned(bottom: 8, right: 8, child: InkWell(onTap: _toggleFullScreen, child: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.fullscreen, color: Colors.white)))),
                  ],
                  
                  // LOADING SCREEN WITH LOGO
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
                              Text("Connecting to HANNUTV ${widget.isServer2 ? '2' : '1'}...", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.movieTitle, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18), const SizedBox(width: 4),
                        Text(widget.rating, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12), Text(widget.year, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Ads Blocker / Banner Ad Component Preserved
                    const CustomBannerAd(
                      htmlBannerCode: '''<script type="text/javascript">atOptions = { 'key' : 'a39df283f6ad10c34e229e5715bceff5', 'format' : 'iframe', 'height' : 50, 'width' : 320, 'params' : {} };</script><script type="text/javascript" src="https://www.highrevenueformat.com/a39df283f6ad10c34e229e5715bceff5/invoke.js"></script>''',
                    ),
                    const SizedBox(height: 18),
                    
                    // HORIZONTAL EPISODES LIST
                    if (widget.mediaType == 'tv' || widget.mediaType == 'series') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Text("Season ${widget.season}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text("Episodes", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal, itemCount: 15,
                          itemBuilder: (context, index) {
                            final epNum = index + 1;
                            final isCurrent = currentEpisode == epNum;
                            return InkWell(
                              onTap: () => _switchEpisode(epNum),
                              child: Container(
                                width: 170, margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: isCurrent ? Border.all(color: Colors.redAccent, width: 2) : null, color: Colors.grey[900]),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: Container(decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(8)), color: Colors.grey[850]), child: Center(child: Icon(isCurrent ? Icons.play_arrow : Icons.play_circle_outline, color: Colors.white, size: 32)))),
                                    Padding(padding: const EdgeInsets.all(8.0), child: Text("Episode : $epNum", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // LIVE COMMENTS SECTION
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Live Comments", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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
                                            Row(children: [Text(c['name']!, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(width: 6), Text(c['time']!, style: const TextStyle(color: Colors.grey, fontSize: 10))]),
                                            Text(c['text']!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
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