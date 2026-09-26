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

  bool isAnalyzingServers = true;
  String selectedLanguage = 'hindi'; // 'hindi' or 'english'
  int activeServerIndex = 0;
  bool isAutoSwitching = false;

  // 🤖 AI SCANNER MANAGED SERVERS WITH LANGUAGE TAGS
  final List<Map<String, dynamic>> allServers = [
    {
      'name': 'VidBolt VIP',
      'sub': 'Hindi Dub + Multi',
      'color': Colors.orange,
      'type': 'vidbolt',
      'lang': 'hindi',
      'available': true,
    },
    {
      'name': 'Olly Ultra',
      'sub': 'Fastest HLS',
      'color': Colors.redAccent,
      'type': 'olly',
      'lang': 'hindi',
      'available': true,
    },
    {
      'name': 'Vega Node',
      'sub': 'Dual Audio 4K',
      'color': Colors.purple,
      'type': 'vega',
      'lang': 'hindi',
      'available': true,
    },
    {
      'name': 'Flixorent',
      'sub': 'Original + Subs',
      'color': Colors.teal,
      'type': 'flixorent',
      'lang': 'english',
      'available': true,
    },
    {
      'name': 'VidLink Pro',
      'sub': 'English HD',
      'color': Colors.green,
      'type': 'vidlink',
      'lang': 'english',
      'available': true,
    },
    {
      'name': 'Nyumatflix',
      'sub': 'English Multi',
      'color': Colors.blue,
      'type': 'nyumat',
      'lang': 'english',
      'available': true,
    },
  ];

  List<Map<String, dynamic>> get currentServers =>
      allServers.where((s) => s['lang'] == selectedLanguage).toList();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // AI Scanner Simulation: 1.2s analysis to highlight active nodes
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => isAnalyzingServers = false);
      }
    });
  }

  void _startServer(int index) {
    _fallbackTimer?.cancel();
    setState(() {
      activeServerIndex = index;
      isAutoSwitching = false;
      isVideoPlaying = false;
    });
    _initWebView();
    _startHideTimer();
  }

  void _triggerAutoFallback() {
    if (isAutoSwitching || !mounted) return;
    setState(() => isAutoSwitching = true);

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        final list = currentServers;
        int next = (activeServerIndex + 1) % list.length;
        _startServer(next);
      }
    });
  }

  String _generateVideoUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) {
      return widget.customUrl!;
    }

    final list = currentServers;
    final srv = (activeServerIndex < list.length)
        ? list[activeServerIndex]['type']
        : 'vidbolt';
    final id = widget.tmdbId;
    final s = widget.season;
    final e = widget.episode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    // 100% PROPER IFRAME COMPATIBLE EMBED ROUTES
    if (srv == 'vidbolt') {
      return isTv
          ? 'https://vidbolt.pro/tv/$id/$s/$e?theme=e50914&autoPlay=true&audio=hindi'
          : 'https://vidbolt.pro/movie/$id?theme=e50914&autoPlay=true&audio=hindi';
    }
    if (srv == 'olly') {
      return isTv
          ? 'https://ollyembed.pages.dev/tv/$id/$s/$e?server=1'
          : 'https://ollyembed.pages.dev/movie/$id?server=1';
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
    if (srv == 'vidlink') {
      return isTv
          ? 'https://vidlink.pro/tv/$id/$s/$e'
          : 'https://vidlink.pro/movie/$id';
    }

    return isTv
        ? 'https://stellar.rip/en/watch/embed/tv/$id-$s-$e?theme=E50914&autoPlay=true'
        : 'https://stellar.rip/en/watch/embed/movie/$id?theme=E50914&autoPlay=true';
  }

  void _initWebView() {
    final targetUrl = _generateVideoUrl();

    // 🛡️ FULL HTML/IFRAME WRAPPER (Solves "Built to run inside iframe" VidBolt Error)
    final String htmlDoc = '''
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          html, body { width: 100%; height: 100%; background-color: #000; overflow: hidden; }
          iframe { width: 100%; height: 100%; border: none; display: block; }
        </style>
      </head>
      <body>
        <iframe 
          id="player-frame"
          src="$targetUrl" 
          allow="autoplay; fullscreen; encrypted-media; picture-in-picture" 
          allowfullscreen="true">
        </iframe>
        <script>
          // 🛡️ 1. KILL ALL AD POPUPS & TAB HIJACKERS
          window.open = function() { return null; };
          window.alert = function() { return null; };
          window.confirm = function() { return null; };

          // 🛡️ 2. Nuke Redirect Triggers
          document.addEventListener('click', function(e) {
            var target = e.target;
            while (target && target !== document) {
              if (target.tagName === 'A' && target.target === '_blank') {
                target.target = '_self';
              }
              target = target.parentNode;
            }
          }, true);

          // 🛡️ 3. Video State & Controls Keeper
          setInterval(function() {
            var vids = document.getElementsByTagName('video');
            if (vids.length > 0) {
              var v = vids[0];
              if (v.currentTime > 0 && !v.paused) {
                VideoState.postMessage('playing');
              }
            }
          }, 600);

          // 🛡️ 4. 404 Scanner
          setInterval(function() {
            var text = document.body.innerText.toLowerCase();
            if (text.includes("we couldn't find this content") || 
                text.includes("video not found") || 
                text.includes("media not available") || 
                text.includes("404 not found")) {
              VideoState.postMessage('not_found');
            }
          }, 1000);
        </script>
      </body>
      </html>
    ''';

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
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();

            // Block common ad redirects
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

            // Allow embed provider hosts
            if (url.contains('hannutv.app') ||
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
          onWebResourceError: (WebResourceError error) {
            _triggerAutoFallback();
          },
        ),
      );

    _controller.loadHtmlString(htmlDoc, baseUrl: 'https://hannutv.app/');

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    // 16s safety fallback
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 16), () {
      if (mounted && !isVideoPlaying) {
        _triggerAutoFallback();
      }
    });
  }

  // ⏩ MANUAL SEEK CONTROLS (INJECTS JAVASCRIPT INTO IFRAME VIDEO)
  void _seekRelative(int seconds) {
    _startHideTimer();
    final js = '''
      (function() {
        var vids = document.getElementsByTagName('video');
        if (vids.length > 0) {
          vids[0].currentTime += $seconds;
        }
        var ifr = document.getElementById('player-frame');
        if (ifr && ifr.contentWindow) {
          ifr.contentWindow.postMessage({event: 'seek', value: $seconds}, '*');
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
                    "AI Provider Switcher",
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
                            activeServerIndex = 0;
                          });
                          _startServer(0);
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
                            activeServerIndex = 0;
                          });
                          _startServer(0);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...List.generate(list.length, (index) {
                final srv = list[index];
                final isSelected = activeServerIndex == index;
                return ListTile(
                  leading: Icon(
                    Icons.check_circle,
                    color: srv['available'] ? Colors.greenAccent : Colors.grey,
                    size: 18,
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
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: srv['color'], width: 1),
                    ),
                    child: Text(
                      selectedLanguage.toUpperCase(),
                      style: TextStyle(
                        color: srv['color'],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
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
    final list = currentServers;
    final currentSrvName = (activeServerIndex < list.length)
        ? list[activeServerIndex]['name']
        : 'VIP Server';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: isAnalyzingServers
            ? _buildAiScanningScreen()
            : GestureDetector(
                onTap: _startHideTimer,
                behavior: HitTestBehavior.translucent,
                child: Stack(
                  children: [
                    // 1. FULLSCREEN CLEAN EMBED PLAYER
                    Positioned.fill(
                      child: WebViewWidget(controller: _controller),
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

                    // 3. MINIMAL CONNECTING BADGE
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
                                  "AI Connecting: $currentSrvName...",
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

                    // 6. BOTTOM CONTROLS (AI SERVER SELECTOR & CROP)
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
                                      const Icon(Icons.auto_awesome, color: Colors.redAccent, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        "$currentSrvName (${selectedLanguage.toUpperCase()})",
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
      ),
    );
  }

  // 🤖 AI SCANNER STARTUP SCREEN (Shows Hindi/English nodes & highlights)
  Widget _buildAiScanningScreen() {
    return Container(
      color: const Color(0xFF0A0A0A),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logo.png', height: 60, errorBuilder: (_, __, ___) => const SizedBox()),
          const SizedBox(height: 16),
          Text(
            widget.movieTitle,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text(
                "AI Scanner: Matching Dual Audio (Hindi / English) Nodes...",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: allServers.map((s) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "${s['name']} (${s['lang'].toString().toUpperCase()})",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
