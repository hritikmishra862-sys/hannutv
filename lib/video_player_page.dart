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
    this.preferredServer = 'netmirror_vip',
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

  // 👑 VIP HARDCODED SERVERS
  final List<Map<String, dynamic>> allServers = [
    {
      'key': 'netmirror_vip',
      'name': 'HANNUTV VIP (NetMirror)',
      'sub': 'Official Direct URL (No White Screen / 404)',
      'color': Colors.redAccent,
      'lang': 'hindi',
    },
    {
      'key': 'vidbolt',
      'name': 'VidBolt VIP Ultra HD',
      'sub': '1080p Hindi Dub + High Bitrate',
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
    }
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

    _initStreamEngine();
    _startHideTimer();
  }

  void _switchServer(String newServerKey) {
    setState(() {
      currentServerKey = newServerKey;
      isPageLoading = true;
      isVideoPlaying = false;
    });
    _initStreamEngine();
    _startHideTimer();
  }

  // 🚀 GENERATE URL (No API, Direct Bypass)
  String _generateServerUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) {
      return widget.customUrl!;
    }

    final id = widget.tmdbId;
    final s = widget.season;
    final e = widget.episode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    // ⚡ NETMIRROR DIRECT HASH URL
    if (currentServerKey == 'netmirror_vip' || currentServerKey.contains('netmirror')) {
      return isTv
          ? 'https://net27.cc/#w=$id-tv-$s-$e'
          : 'https://net27.cc/#w=$id-movie';
    }

    if (currentServerKey == 'vidbolt') {
      return isTv
          ? 'https://vidbolt.pro/tv/$id/$s/$e?quality=1080p&theme=e50914&autoPlay=true&audio=hindi'
          : 'https://vidbolt.pro/movie/$id?quality=1080p&theme=e50914&autoPlay=true&audio=hindi';
    }

    if (currentServerKey == 'olly') {
      return isTv
          ? 'https://ollyembed.pages.dev/tv/$id/$s/$e?server=1'
          : 'https://ollyembed.pages.dev/movie/$id?server=1';
    }

    if (currentServerKey == 'vega') {
      return isTv
          ? 'https://vidsrc.to/embed/tv/$id/$s/$e'
          : 'https://vidsrc.to/embed/movie/$id';
    }

    return isTv
        ? 'https://vidsrc.pro/embed/tv/$id/$s/$e'
        : 'https://vidsrc.pro/embed/movie/$id';
  }

  // 🛡️ THE 10000000000% BYPASS ENGINE
  void _initStreamEngine() {
    final targetUrl = _generateServerUrl();
    bool loadAsIframe = currentServerKey == 'vidbolt' || currentServerKey == 'olly';

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

            // 🔥 AI AUTO-CLICKER & AD-NUKER (Fixed Reconnect & Dual Audio)
            String jsCode = '''
              document.documentElement.style.backgroundColor = '#000000';
              document.body.style.backgroundColor = '#000000';

              // Hide only specific garbage elements, DO NOT hide Player Controls (.jw-settings, .vjs-menu)
              var style = document.createElement('style');
              style.innerHTML = `
                header, footer, nav, aside, .sidebar, .logo, .ad-container, iframe[src*="ads"], 
                [class*="telegram"], [id*="telegram"], a[href*="t.me"] { display: none !important; }
                body, html { overflow: hidden !important; background: black !important; }
              `;
              document.head.appendChild(style);

              let targetLang = '${selectedLanguage.toLowerCase()}';

              setInterval(function() {
                // 1. Auto click "Server 1" or "Server 2"
                let buttons = document.querySelectorAll('button, div.server, .btn, .server-item, li');
                buttons.forEach(btn => {
                   let text = btn.innerText.toLowerCase();
                   
                   // Click Play if visible
                   if (text.includes('play') && !window._autoClickedPlay) {
                      btn.click();
                      window._autoClickedPlay = true;
                   }

                   // Match Server
                   if (targetLang === 'hindi' && (text.includes('server 1') || text.includes('hindi')) && !window._langClicked) {
                      btn.click(); window._langClicked = true;
                   } else if (targetLang === 'english' && (text.includes('server 2') || text.includes('english')) && !window._langClicked) {
                      btn.click(); window._langClicked = true;
                   }
                });

                // 2. Kill Popups but IGNORE Player Controls (Allows Dual Audio)
                document.querySelectorAll('div, a, span, img').forEach(el => {
                  let style = window.getComputedStyle(el);
                  let cls = el.className ? el.className.toString().toLowerCase() : '';
                  let txt = el.innerText ? el.innerText.toLowerCase() : '';

                  // Kill Telegram overlays
                  if(txt.includes('telegram') || txt.includes('join our') || txt.includes('bet365')) {
                      el.remove();
                      return;
                  }

                  if ((style.position === 'fixed' || style.position === 'absolute') && 
                      style.zIndex > 500 && 
                      el.tagName !== 'IFRAME' && 
                      el.tagName !== 'VIDEO') {
                    
                    // 🛡️ DUAL AUDIO PROTECTOR: DO NOT Remove JWPlayer / VideoJS menus
                    if (cls.includes('jw-') || cls.includes('vjs') || cls.includes('plyr') || 
                        cls.includes('control') || cls.includes('setting') || cls.includes('menu')) {
                        return;
                    }
                    el.remove();
                  }
                });

                // 3. Auto Play Video
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
              }, 500);
            ''';
            _controller.runJavaScript(jsCode);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            
            // 🚫 FIXED RECONNECT BUG: DO NOT BLOCK VIDEO STREAMS (.m3u8, .mp4, hakuna)
            if (url.contains('.m3u8') || url.contains('.mp4') || url.contains('hakunaymatata') || url.contains('videodelivery')) {
                return NavigationDecision.navigate;
            }

            // 🚫 BLOCK ADS
            if (url.contains('doubleclick') || url.contains('popads') || 
                url.contains('onclick') || url.contains('adsterra') || 
                url.contains('bet365') || url.contains('monetag') ||
                url.contains('market://') || url.contains('intent://') || 
                url.contains('t.me') || url.contains('telegram')) {
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      );

    if (loadAsIframe) {
      String spoofedBaseUrl = currentServerKey == 'vidbolt' ? 'https://vidbolt.pro/' : 'https://hannutv.app/';
      final embedHtml = '''
        <!DOCTYPE html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              html, body { width: 100%; height: 100%; background-color: #000000; overflow: hidden; }
              iframe { width: 100vw; height: 100vh; border: none; background-color: #000000; }
            </style>
          </head>
          <body>
            <iframe src="$targetUrl" allow="autoplay; fullscreen; encrypted-media" allowfullscreen></iframe>
          </body>
        </html>
      ''';
      _controller.loadHtmlString(embedHtml, baseUrl: spoofedBaseUrl);
    } else {
      _controller.loadRequest(Uri.parse(targetUrl));
    }

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }
  }

  void _seekRelative(int seconds) {
    _startHideTimer();
    final js = '''
      (function() {
        var v = null;
        var iframes = document.getElementsByTagName('iframe');
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
        return StatefulBuilder(
          builder: (context, setModalState) {
            final list = currentServers;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Switch Server", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text("Hindi"),
                            selected: selectedLanguage == 'hindi',
                            selectedColor: Colors.redAccent,
                            onSelected: (val) {
                              setModalState(() => selectedLanguage = 'hindi');
                              setState(() => selectedLanguage = 'hindi');
                              _initStreamEngine(); 
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text("English"),
                            selected: selectedLanguage == 'english',
                            selectedColor: Colors.blueAccent,
                            onSelected: (val) {
                              setModalState(() => selectedLanguage = 'english');
                              setState(() => selectedLanguage = 'english');
                              _initStreamEngine();
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
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? Colors.greenAccent : Colors.grey,
                      ),
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
          }
        );
      },
    ).then((_) => _startHideTimer());
  }

  void toggleCrop() {
    setState(() => isCropped = !isCropped);
    _controller.runJavaScript('''
      var v = null;
      var iframes = document.getElementsByTagName('iframe');
      if(iframes.length > 0) {
         var doc = iframes[0].contentDocument || iframes[0].contentWindow.document;
         if(doc) v = doc.querySelector('video');
      }
      if(!v) v = document.querySelector('video');
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
        body: GestureDetector(
          onTap: _startHideTimer,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: WebViewWidget(controller: _controller),
                ),
              ),

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
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

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
                            "Connecting: ${currentSrv['name']}...",
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (showControls)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 80,
                  child: SafeArea(
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
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
      ),
    );
  }
}