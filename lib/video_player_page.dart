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

  const VideoPlayerPage({
    Key? key,
    required this.tmdbId,
    required this.mediaType,
    this.season = 1,
    this.episode = 1,
    required this.movieTitle,
  }) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late WebViewController _controller;
  bool isPageLoading = true;

  @override
  void initState() {
    super.initState();
    // Default to clean YouTube-style portrait mode
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _initSecureEngine();
  }

  // 🚀 EXACT LIVE URL ROUTE OF THE SOURCE WEBSITE (MATCHING SCREENSHOT)
  String _generateWebsiteUrl() {
    final id = widget.tmdbId;
    final s = widget.season;
    final e = widget.episode;
    
    if (widget.mediaType == 'tv' || widget.mediaType == 'series') {
      return 'https://pantyflix.com/watch/play/tv/$id?season=$s&episode=$e';
    } else {
      return 'https://pantyflix.com/watch/play/movie/$id';
    }
  }

  void _initSecureEngine() {
    final targetUrl = _generateWebsiteUrl();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        "Mozilla/5.0 (Linux; Android 13; SM-S918B Build/TP1A.220624.014) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36",
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => isPageLoading = true);
          },
          onPageFinished: (String url) {
            // Instant Loading Reveal (No black blocking overlay)
            if (mounted) setState(() => isPageLoading = false);

            // 🛡️ WORLD'S BEST AI AD-NUKER, BRAND REPLACER & UI PURIFIER
            String jsCode = '''
              // 1. Force Pure Black Theme & Clean Viewport
              document.documentElement.style.backgroundColor = '#000000';
              document.body.style.backgroundColor = '#000000';

              // 2. Kill Popups & Redirects completely
              window.open = function() { return null; };
              window.alert = function() { return null; };
              window.confirm = function() { return null; };

              // 3. Inject CSS to hide Navbar, Footer, Telegram, DMCA & Ads
              var style = document.createElement('style');
              style.innerHTML = `
                header, nav, .navbar, footer, .footer, 
                a[href*="t.me"], a[href*="telegram"], [class*="telegram"], 
                iframe[src*="ads"], .ad-container, .ads, .ad-banner, .popup-overlay,
                .dmca-notice, .copyright, [href*="mailto:"] { 
                  display: none !important; 
                }
                body { 
                  background-color: #000000 !important; 
                  color: #ffffff !important;
                }
              `;
              document.head.appendChild(style);

              // 4. Real-time AI Nuke & Brand Replace (Every 300ms)
              setInterval(function() {
                // A. Unmute & Force Play Video when available
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0) {
                  var v = vids[0];
                  v.style.backgroundColor = '#000000';
                  v.muted = false;
                  v.volume = 1.0;
                  if (v.paused && !v.ended) {
                    v.play().catch(function(){});
                  }
                }

                // B. Nuke DMCA, Telegram & Support Emails from DOM
                document.querySelectorAll('p, span, div, a, li, h2, h3').forEach(el => {
                  let txt = el.innerText ? el.innerText.toLowerCase() : '';
                  if (txt.includes('support@') || 
                      txt.includes('dmca') || 
                      txt.includes('removal') || 
                      txt.includes('telegram') ||
                      txt.includes('contact us:')) {
                    el.style.display = 'none';
                  }
                });

                // C. Replace Original Website Name with HANNUTV
                function replaceBranding(node) {
                  if (node.nodeType === 3) {
                    if (node.nodeValue && node.nodeValue.toLowerCase().includes('pantyflix')) {
                      node.nodeValue = node.nodeValue.replace(/pantyflix/gi, 'HANNUTV');
                    }
                  } else if (node.nodeType === 1 && node.nodeName !== "SCRIPT" && node.nodeName !== "STYLE") {
                    for (let i = 0; i < node.childNodes.length; i++) {
                      replaceBranding(node.childNodes[i]);
                    }
                  }
                }
                replaceBranding(document.body);

                if (document.title.toLowerCase().includes('pantyflix')) {
                  document.title = document.title.replace(/pantyflix/gi, 'HANNUTV');
                }
              }, 300);
            ''';
            _controller.runJavaScript(jsCode);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();

            // 🚫 HARD BLOCK ALL AD NETWORKS & TELEGRAM REDIRECTS
            if (url.contains('doubleclick') ||
                url.contains('popads') ||
                url.contains('onclick') ||
                url.contains('adsterra') ||
                url.contains('bet365') ||
                url.contains('1xbet') ||
                url.contains('monetag') ||
                url.contains('market://') ||
                url.contains('intent://') ||
                url.contains('t.me') ||
                url.contains('telegram')) {
              return NavigationDecision.prevent;
            }

            // ✅ Allow internal server switching (Rift, Spiral, Hydra, etc.) & episode changes
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
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

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. PURE YOUTUBE-STYLE LIVE WEBVIEW CONTAINER (EXACT SCREENSHOT UI)
            Positioned.fill(
              child: WebViewWidget(controller: _controller),
            ),

            // 2. TOP BACK BUTTON & HANNUTV BRAND WATERMARK
            Positioned(
              top: 8,
              left: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // 3. FAST SPINNER ONLY FOR INITIAL 1.5 SECONDS (No video blocking)
            if (isPageLoading)
              Positioned(
                top: 90,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.redAccent, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2.5),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "HANNUTV: Loading Selected Server...",
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
