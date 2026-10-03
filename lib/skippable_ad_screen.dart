import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'dart:async';
import 'dart:math';

class SkippableAdScreen extends StatefulWidget {
  final Widget nextScreen; 
  final int adDuration; 

  const SkippableAdScreen({
    Key? key, 
    required this.nextScreen,
    this.adDuration = 30, 
  }) : super(key: key);

  @override
  State<SkippableAdScreen> createState() => _SkippableAdScreenState();
}

class _SkippableAdScreenState extends State<SkippableAdScreen> {
  late final WebViewController _controller;
  late int _timeLeft; 
  bool _canSkip = false;
  Timer? _timer;
  bool _timerStarted = false;

  // 🚀 MONETAG & ADSTERRA LINKS 🚀
  final List<String> _adLinks = [
    "https://omg10.com/4/11914244", 
    "https://omg10.com/4/11914245", 
    "https://www.profitableratecpmnetwork.com/qftskbqkm?key=6a0072dfddbd45e6f448fa2a00d2df90"
  ];

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.adDuration; 
    
    final _random = Random();
    String selectedAd = _adLinks[_random.nextInt(_adLinks.length)];

    // 🔥 SMART CODING: Asli Chrome Browser ka Fake User-Agent daala hai taaki Captcha na aaye
    const String fakeChromeAgent = "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36";

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setUserAgent(fakeChromeAgent) 
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // Ad load hote hi timer start
            if (!_timerStarted) {
               _startTimer();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            
            // 🔥 DEEP LOGIC: Agar URL Play Store ka hai ya Monetag ke main server se bahar ka hai (mtlb click hua hai), toh Browser me kholo
            if (url.startsWith('intent://') || 
                url.startsWith('market://') || 
                url.contains('play.google.com') ||
                (_timerStarted && !url.contains('omg10.com') && !url.contains('profitableratecpmnetwork'))) {
              
              _launchInBrowser(request.url);
              return NavigationDecision.prevent; // App me ad tab kharab hone se roko
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(selectedAd));

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    // 🔥 FAIL-SAFE: Agar Captcha aa bhi gaya aur load complete nahi hua, toh 3 second me timer zabardasti start kar do
    Future.delayed(const Duration(seconds: 3), () {
      if (!_timerStarted && mounted) {
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _timerStarted = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        if (mounted) setState(() => _timeLeft--);
      } else {
        if (mounted) setState(() => _canSkip = true);
        _timer?.cancel();
      }
    });
  }

  // 🚀 AD PE CLICK KARNE PAR CHROME ME BHEJNE WALA FUNCTION 🚀
  Future<void> _launchInBrowser(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch $urlString");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _skipAd() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => widget.nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, 
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // WebView jisme Full Screen Ad chalega
              WebViewWidget(controller: _controller),
              
              // Skip Button Overlay
              Positioned(
                top: 15,
                right: 15,
                child: GestureDetector(
                  onTap: _canSkip ? _skipAd : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: _canSkip ? Colors.white : Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _canSkip ? Colors.white : Colors.grey),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _canSkip ? "Skip Ad" : "Skip in $_timeLeft",
                          style: TextStyle(
                            color: _canSkip ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (_canSkip) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.skip_next, color: Colors.black, size: 20),
                        ]
                      ],
                    ),
                  ),
                ),
              ),

              // Ad Badge
              Positioned(
                bottom: 20, left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                  child: const Text("Ad", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  } 
}