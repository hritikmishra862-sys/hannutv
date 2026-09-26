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
    // Start in Portrait mode (YouTube Style)
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _initSecureEngine();
  }

  // 🚀 GENERATE THE EXACT STREAM URL FOR THE WEBSITE
  String _generateWebsiteUrl() {
    final id = widget.tmdbId;
    final s = widget.season;
    final e = widget.episode;
    
    // Base URL is hidden here in backend
    if (widget.mediaType == 'tv' || widget.mediaType == 'series') {
      return 'https://pantyflix.com/watch/play/tv/$id?season=$s&episode=$e';
    } else {
      return 'https://pantyflix.com/watch/play/movie/$id';
    }
  }

  // 🛡️ THE AI AD-NUKER & BRAND REPLACER ENGINE
  void _initSecureEngine() {
    final targetUrl = _generateWebsiteUrl();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        // Desktop User Agent to avoid annoying mobile ads
        "Mozilla/5.0 (Linux; Android 13; Pixel 7 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => isPageLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => isPageLoading = false);

            // 🔥 DEEP HARDCODING: Kill Original Branding, Ads, DMCA & Support Emails
            String jsCode = '''
              // 1. Hide unwanted Layout elements (Header, Footer, Telegram, Ads)
              var style = document.createElement('style');
              style.innerHTML = `
                header, .navbar, footer, .footer, 
                a[href*="t.me"], [class*="telegram"], 
                iframe[src*="ads"], .ad-container, .ads,
                .dmca-notice, .copyright { 
                  display: none !important; 
                }
                body { background-color: #000000 !important; }
              `;
              document.head.appendChild(style);

              // 2. The AI Text Replacer Bot (Runs every 500ms)
              setInterval(function() {
                
                // Nuke specific elements containing DMCA or Support emails
                document.querySelectorAll('p, span, div, a, li').forEach(el => {
                  let txt = el.innerText ? el.innerText.toLowerCase() : '';
                  if(txt.includes('support@') || txt.includes('dmca') || txt.includes('removal') || txt.includes('telegram')) {
                    el.style.display = 'none';
                  }
                });

                // Replace the original website name with HANNUTV everywhere!
                function replaceBranding(node) {
                    if (node.nodeType === 3) { // Text node
                        if(node.nodeValue.toLowerCase().includes('pantyflix')) {
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

              }, 500);
            ''';
            _controller.runJavaScript(jsCode);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            
            // 🚫 HARD BLOCK AD NETWORKS & REDIRECTS
            if (url.contains('doubleclick') || url.contains('popads') || 
                url.contains('onclick') || url.contains('adsterra') || 
                url.contains('bet365') || url.contains('monetag') ||
                url.contains('market://') || url.contains('intent://') || 
                url.contains('t.me') || url.contains('telegram')) {
              return NavigationDecision.prevent;
            }

            // Allow safe navigation inside the webview for server switching
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(targetUrl));
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.movieTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. THE YOUTUBE-STYLE EMBEDDED WEBSITE
            Positioned.fill(
              child: WebViewWidget(controller: _controller),
            ),
            
            // 2. LOADING INDICATOR
            if (isPageLoading)
              Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}