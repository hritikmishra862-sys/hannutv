import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart'; 

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
  
  // 🔥 SMART TOUCH SENSOR FLAGS 🔥
  bool _isAdLoading = true;
  bool _timerStarted = false;
  bool _userJustClicked = false;
  Timer? _clickResetTimer;

  // 🚀 TERE ORIGINAL ADS KE LINKS (Monetag + Adsterra) 🚀
  final List<String> _adLinks = [
    "https://omg10.com/4/11914244", // Lovey-dovey link
    "https://omg10.com/4/11914245", // Industrious link
    "https://www.profitableratecpmnetwork.com/qftskbqkm?key=6a0072dfddbd45e6f448fa2a00d2df90" // Adsterra Smartlink
  ];

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.adDuration; 
    
    final _random = Random();
    String selectedAd = _adLinks[_random.nextInt(_adLinks.length)];

    // 🔥 SMART BYPASS: Asli Chrome Browser ka Fake User-Agent taaki Captcha na aaye
    const String fakeChromeAgent = "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36";

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setUserAgent(fakeChromeAgent) 
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
             if (mounted) setState(() => _isAdLoading = true);
          },
          onPageFinished: (String url) {
            // 🔥 DEEP LOGIC: Ad 100% load hone ke baad hi Timer shuru hoga!
            if (mounted) setState(() => _isAdLoading = false);
            if (!_timerStarted) {
               _startTimer();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            
            // 1. 🔥 THE MAGIC: Agar ungli se touch hua hai, tabhi Chrome ya Play Store khulega! 🔥
            if (_userJustClicked && !url.startsWith('about:blank')) {
              _launchInBrowser(request.url);
              _userJustClicked = false; // Redirect hone ke baad click reset kar do
              return NavigationDecision.prevent; // App ke andar web page khulne se rok diya
            }

            // 2. Agar touch NAHI hua hai (mtlb Ad auto-redirect ho raha hai)
            if (!_userJustClicked) {
              // Koi bhi aggressive auto-redirect Play Store/Intent par jaane ki koshish kare toh BLOCK kar do
              if (url.startsWith('intent://') || 
                  url.startsWith('market://') || 
                  url.contains('play.google.com') ||
                  url.startsWith('whatsapp://') ||
                  url.startsWith('tg://')) {
                return NavigationDecision.prevent; 
              }
              // Baaki internal background auto-redirects allow karo taaki ad load ho aur black screen na aaye
              return NavigationDecision.navigate;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(selectedAd));

    // Android Webview Crash Fix
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      if (_controller.platform is AndroidWebViewController) {
        (_controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }
    }

    // 🔥 FAIL-SAFE: Agar ad atak jaye aur page finish na ho paye, toh 7 sec me timer force start kar do taaki user fase na
    Future.delayed(const Duration(seconds: 7), () {
      if (!_timerStarted && mounted) {
        setState(() => _isAdLoading = false);
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

  // 🔥 PHONE KE DEFAULT BROWSER ME BHEJNE KA CODE 🔥
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
    _clickResetTimer?.cancel();
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
              // 🔥 INVISIBLE TOUCH SENSOR (Yehi tera main rakshak hai) 🔥
              Listener(
                onPointerDown: (event) {
                  // User ne screen touch ki!
                  _userJustClicked = true;
                  _clickResetTimer?.cancel();
                  // 3 second ke andar ad kuch bhi kholne ki koshish karega toh seedha Chrome khulega
                  _clickResetTimer = Timer(const Duration(seconds: 3), () {
                    _userJustClicked = false;
                  });
                },
                child: WebViewWidget(controller: _controller),
              ),
              
              // 🔥 LOADING SCREEN: Jab tak ad na aaye, ye dikhega (No Black Screen)
              if (_isAdLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          CircularProgressIndicator(color: Colors.redAccent),
                          SizedBox(height: 16),
                          Text("Loading Sponsored Ad...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        ],
                      ),
                    ),
                  ),
                ),
              
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
                          !_timerStarted 
                            ? "Wait..." 
                            : (_canSkip ? "Skip Ad" : "Skip in $_timeLeft"),
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