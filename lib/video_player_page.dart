import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// 🌉 NATIVE METHODCHANNEL SERVICE FOR NETMIRROR CNCVERSE
class CNCVerseService {
  static const MethodChannel _channel =
      MethodChannel('com.horis.cncverse/stream');

  static Future<String?> getStreamUrl({
    required String title,
    required String mediaType,
    String provider = 'netflix',
    int season = 1,
    int episode = 1,
  }) async {
    try {
      final String? url = await _channel.invokeMethod<String>('getStreamUrl', {
        'title': title,
        'mediaType': mediaType,
        'provider': provider,
        'season': season,
        'episode': episode,
      });
      return url;
    } on PlatformException catch (e) {
      debugPrint("CNCVerse MethodChannel Exception: ${e.message}");
      return null;
    } catch (e) {
      debugPrint("CNCVerse General Error: $e");
      return null;
    }
  }
}

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
    this.preferredServer = 'netmirror_net27',
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
  String? nativeDirectStreamUrl;

  // 🤖 6 ALL-IN-ONE WORKING HIGH-SPEED SERVERS
  final List<Map<String, dynamic>> allServers = [
    {
      'key': 'netmirror_net27',
      'name': 'HANNUTV (NetMirror net27)',
      'sub': 'Official NetMirror Cloud Engine (Hindi / Multi)',
      'color': Colors.redAccent,
      'lang': 'hindi',
    },
    {
      'key': 'vidbolt',
      'name': 'VidBolt VIP Ultra HD',
      'sub': 'Dual Audio Hindi + 1080p High Bitrate',
      'color': Colors.orangeAccent,
      'lang': 'hindi',
    },
    {
      'key': 'olly',
      'name': 'Olly Stream VIP',
      'sub': 'Fast HLS Hindi Direct (No Ads)',
      'color': Colors.purpleAccent,
      'lang': 'hindi',
    },
    {
      'key': 'vega',
      'name': 'Vega Multi-Audio 4K',
      'sub': 'Dual Audio Hindi/Eng Cloud',
      'color': Colors.teal,
      'lang': 'hindi',
    },
    {
      'key': 'flixorent',
      'name': 'Flixorent Ultra',
      'sub': 'English Subtitles 1080p',
      'color': Colors.blueAccent,
      'lang': 'english',
    },
    {
      'key': 'vidlink',
      'name': 'VidLink English Pro',
      'sub': 'English HD Direct Node',
      'color': Colors.green,
      'lang': 'english',
    },
  ];

  String selectedLanguage = 'hindi';

  List<Map<String, dynamic>> get currentServers =>
      allServers.where((s) => s['lang'] == selectedLanguage).toList();

  @override
  void initState() {
    super.initState();
    currentServerKey = widget.preferredServer;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _loadStreamEngine();
    _startHideTimer();
  }

  Future<void> _loadStreamEngine() async {
    setState(() {
      isPageLoading = true;
      isVideoPlaying = false;
    });

    _initPureBlackWebView();
  }

  void _switchServer(String newServerKey) {
    setState(() {
      currentServerKey = newServerKey;
    });
    _loadStreamEngine();
    _startHideTimer();
  }

  // 🚀 GENERATE THE EXACT STREAM URL FOR EACH SERVER
  String _generateTargetUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) {
      return widget.customUrl!;
    }

    final id = widget.tmdbId;
    final s = widget.season;
    final e = widget.episode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    // 🌟 1. NETMIRROR OFFICIAL NET27 DIRECT HASH ENGINE
    if (currentServerKey == 'netmirror_net27') {
      return isTv
          ? 'https://net27.cc/#w=$id-tv-$s-$e'
          : 'https://net27.cc/#w=$id-movie';
    }

    // 🌟 2. VIDBOLT ULTRA HD (FORCED DUAL AUDIO & 1080P)
    if (currentServerKey == 'vidbolt') {
      return isTv
          ? 'https://vidbolt.pro/tv/$id/$s/$e?quality=1080p&theme=e50914&autoPlay=true&audio=hindi'
          : 'https://vidbolt.pro/movie/$id?quality=1080p&theme=e50914&autoPlay=true&audio=hindi';
    }

    // 🌟 3. OLLY STREAM VIP
    if (currentServerKey == 'olly') {
      return isTv
          ? 'https://ollyembed.pages.dev/tv/$id/$s/$e?server=1'
          : 'https://ollyembed.pages.dev/movie/$id?server=1';
    }

    // 🌟 4. VEGA 4K MULTI-AUDIO
    if (currentServerKey == 'vega') {
      return isTv
          ? 'https://vidsrc.to/embed/tv/$id/$s/$e'
          : 'https://vidsrc.to/embed/movie/$id';
    }

    // 🌟 5. FLIXORENT ENGLISH
    if (currentServerKey == 'flixorent') {
      return isTv
          ? 'https://vidsrc.pro/embed/tv/$id/$s/$e'
          : 'https://vidsrc.pro/embed/movie/$id';
    }

    // 🌟 6. VIDLINK ENGLISH
    return isTv
        ? 'https://vidlink.pro/tv/$id/$s/$e'
        : 'https://vidlink.pro/movie/$id';
  }

  // 🎬 PURE BLACK ZERO-WHITE-SCREEN WEBVIEW ENGINE WITH AUDIO UNLOCKER
  void _initPureBlackWebView() {
    final targetUrl = _generateTargetUrl();

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

            // 🛡️ WORLD'S BEST AD-KILLER + DUAL AUDIO UNLOCKER + ZERO WHITE FLASH
            String jsCode = '''
              // 1. Force Pure Black Screen
              document.documentElement.style.backgroundColor = '#000000';
              document.body.style.backgroundColor = '#000000';

              // 2. Kill Popups completely
              window.open = function() { return null; };
              window.alert = function() { return null; };
              window.confirm = function() { return null; };

              // 3. Audio & Subtitle Track Auto-Unlocker
              setInterval(function() {
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0) {
                  var v = vids[0];
                  v.style.backgroundColor = '#000000';
                  
                  // Unmute and Enable Multi Audio
                  v.muted = false;
                  v.volume = 1.0;

                  if (v.paused) {
                    v.play().catch(function(){});
                  }
                  if (v.currentTime > 0 && !v.paused) {
                    VideoState.postMessage('playing');
                  }
                }

                // 4. Kill AdBlock warnings, overlays & NetMirror headers
                document.querySelectorAll('div, section, modal, aside, p, h2, span, header, nav').forEach(el => {
                  let text = el.innerText.toLowerCase();
                  if (text.includes('adblock') || 
                      text.includes('ad-blocker') || 
                      text.includes('disable adblock') || 
                      text.includes('please disable') ||
                      text.includes('inside an iframe') ||
                      text.includes('netmirror') ||
                      text.includes('net mirror')) {
                    if (el.tagName === 'HEADER' || el.tagName === 'NAV') {
                      el.style.display = 'none';
                    } else if (!el.querySelector('video') && !el.querySelector('iframe')) {
                      el.remove();
                    }
                  }
                });

                // Remove banner ads & overlays
                document.querySelectorAll('div, a, span, img').forEach(el => {
                  let style = window.getComputedStyle(el);
                  if ((style.position === 'fixed' || style.position === 'absolute') && 
                      style.zIndex > 1000 && 
                      el.tagName !== 'IFRAME' && 
                      el.tagName !== 'VIDEO') {
                    el.remove();
                  }
                });
              }, 300);
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
                url.contains('adsterra')) {
              return NavigationDecision.prevent;
            }

            if (url.contains('hannutv.app') ||
                url.contains('net27.cc') ||
                url.contains('net52.cc') ||
                url.contains('net77.cc') ||
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

    // Load with Net27 / NetMirror Referer Headers
    _controller.loadRequest(
      Uri.parse(targetUrl),
      headers: {
        'Referer': 'https://net27.cc/',
        'Origin': 'https://net27.cc',
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
        final list = currentServers;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Switch Video Server",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text("Hindi"),
                        selected: selectedLanguage == 'hindi',
                        selectedColor: Colors.redAccent,
                        onSelected: (val) {
                          Navigator.pop(context);
                          setState(() {
                            selectedLanguage = 'hindi';
                            currentServerKey = 'netmirror_net27';
                          });
                          _switchServer('netmirror_net27');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text("English"),
                        selected: selectedLanguage == 'english',
                        selectedColor: Colors.blueAccent,
                        onSelected: (val) {
                          Navigator.pop(context);
                          setState(() {
                            selectedLanguage = 'english';
                            currentServerKey = 'flixorent';
                          });
                          _switchServer('flixorent');
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...List.generate(list.length, (index) {
                final srv = list[index];
                final isSelected = currentServerKey == srv['key'];
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
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
            // 1. PURE BLACK WEBVIEW CONTAINER (NET27 / NETMIRROR POWERED)
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

            // 3. BUFFERING / CONNECTING BADGE
            if (isPageLoading && !isVideoPlaying)
              Positioned(
                bottom: 40,
                left: 20,
                child: SafeArea(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                          child: CircularProgressIndicator(
                              color: Colors.red, strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Connecting: ${currentSrv['name']}...",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
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
                                "Server: ${currentSrv['name']}",
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
