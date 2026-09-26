import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  bool showControls = true;
  Timer? _hideTimer;
  bool isPageLoading = true;
  late String currentServerKey;
  String? resolvedDirectStreamUrl;

  final List<Map<String, dynamic>> allServers = [
    {
      'key': 'vidbolt',
      'name': 'VidBolt Ultra HD',
      'sub': '1080p Hindi Fast Server',
      'color': Colors.orangeAccent,
      'lang': 'hindi',
    },
    {
      'key': 'netmirror_vip',
      'name': 'HANNUTV VIP (NetMirror)',
      'sub': 'Official API Direct Stream (No 404)',
      'color': Colors.redAccent,
      'lang': 'hindi',
    },
    {
      'key': 'olly',
      'name': 'Olly Embed VIP',
      'sub': 'Fast HLS Hindi Stream',
      'color': Colors.purpleAccent,
      'lang': 'hindi',
    },
    {
      'key': 'vega',
      'name': 'Vega Multi-Audio 4K',
      'sub': 'Dual Audio Hindi/Eng',
      'color': Colors.teal,
      'lang': 'hindi',
    },
    {
      'key': 'flixorent',
      'name': 'Flixorent HD',
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

    _loadStreamEngine();
    _startHideTimer();
  }

  Future<void> _loadStreamEngine() async {
    setState(() {
      isPageLoading = true;
      isVideoPlaying = false;
      resolvedDirectStreamUrl = null;
    });

    if (currentServerKey == 'netmirror_vip') {
        final id = widget.tmdbId;
        final s = widget.season;
        final e = widget.episode;
        final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';
        
        final apiUrl = isTv
          ? 'https://net27.cc/api/embed-tmdb/$id?type=tv&s=$s&e=$e'
          : 'https://net27.cc/api/embed-tmdb/$id';

        try {
            final response = await http.get(Uri.parse(apiUrl));
            if (response.statusCode == 200) {
                final jsonResponse = json.decode(response.body);
                if (jsonResponse['ok'] == true && jsonResponse['streams'] != null && jsonResponse['streams'].isNotEmpty) {
                   
                   String streamUrl = jsonResponse['streams'][0]['url'];
                   setState(() {
                       resolvedDirectStreamUrl = streamUrl;
                   });
                   _initSecurePlayer(resolvedDirectStreamUrl!);
                   return;
                } else if(jsonResponse['ok'] == true && jsonResponse['mp4'] != null) {
                    setState(() {
                       resolvedDirectStreamUrl = jsonResponse['mp4'];
                   });
                   _initSecurePlayer(resolvedDirectStreamUrl!);
                   return;
                }
            }
        } catch (e) {
            print("Error fetching NetMirror API: $e");
        }
        
        setState(() {
            currentServerKey = 'vidbolt'; 
        });
        _initSecurePlayer(_generateFallbackUrl());
    } else {
        _initSecurePlayer(_generateFallbackUrl());
    }
  }

  String _generateFallbackUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) {
      return widget.customUrl!;
    }

    final id = widget.tmdbId;
    final s = widget.season;
    final e = widget.episode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

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

  void _switchServer(String newServerKey) {
    setState(() {
      currentServerKey = newServerKey;
    });
    _loadStreamEngine();
    _startHideTimer();
  }


  void _initSecurePlayer(String targetUrl) {
    String spoofedBaseUrl = 'https://hannutv.app/';
    if (currentServerKey == 'vidbolt') spoofedBaseUrl = 'https://vidbolt.pro/';

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

            String jsCode = '''
              setInterval(function() {
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0) {
                  var v = vids[0];
                  if (v.currentTime > 0 && !v.paused) {
                    VideoState.postMessage('playing');
                  }
                }
              }, 1000);
            ''';
            _controller.runJavaScript(jsCode);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            
            if (url.contains('doubleclick') || url.contains('popads') || 
                url.contains('onclick') || url.contains('adsterra') || 
                url.contains('bet365') || url.contains('monetag') ||
                url.contains('market://') || url.contains('intent://')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    String htmlContent;
    if(currentServerKey == 'netmirror_vip' && resolvedDirectStreamUrl != null) {
         htmlContent = '''
            <!DOCTYPE html>
            <html>
              <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <style>
                  * { margin: 0; padding: 0; box-sizing: border-box; }
                  html, body { width: 100%; height: 100%; background-color: #000000; overflow: hidden; display: flex; align-items: center; justify-content: center; }
                  video { width: 100%; height: 100%; object-fit: contain; background: #000; }
                </style>
              </head>
              <body>
                <video src="$resolvedDirectStreamUrl" autoplay playsinline controls></video>
                <script>
                    var v = document.querySelector('video');
                    if (v) {
                        v.play().catch(function(){});
                        v.addEventListener('playing', function() {
                            VideoState.postMessage('playing');
                        });
                    }
                </script>
              </body>
            </html>
          ''';
    } else {
        htmlContent = '''
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
    }

    _controller.loadHtmlString(htmlContent, baseUrl: spoofedBaseUrl);

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }
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

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSrv = allServers.firstWhere((s) => s['key'] == currentServerKey, orElse: () => allServers[0]);

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
                child: Container(color: Colors.black, child: WebViewWidget(controller: _controller)),
              ),
              Positioned(
                top: 16, right: 16,
                child: SafeArea(child: IgnorePointer(child: Opacity(opacity: 0.5, child: Image.asset('assets/logo.png', height: 30)))),
              ),
              if (isPageLoading && !isVideoPlaying)
                Positioned(
                  bottom: 40, left: 20,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.redAccent, width: 1)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2)),
                          const SizedBox(width: 10),
                          Text("Connecting: ${currentSrv['name']}...", style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (showControls)
                Positioned(
                  top: 16, left: 16, right: 80,
                  child: SafeArea(
                    child: Row(
                      children: [
                        Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22), onPressed: () => Navigator.pop(context))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(widget.movieTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 6)]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
              if (showControls)
                Positioned(
                  bottom: 16, right: 16,
                  child: SafeArea(
                    child: GestureDetector(
                      onTap: _showServerSelector,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.redAccent, width: 1.2)),
                        child: Row(
                          children: [
                            const Icon(Icons.swap_horiz, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 6),
                            Text("Server: ${currentSrv['name']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
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