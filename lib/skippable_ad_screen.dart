import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:webview_flutter/webview_flutter.dart';

class SkippableAdScreen extends StatefulWidget {
  final Widget nextScreen; // Ad khatam hone ke baad kahan jana hai (Player screen)

  const SkippableAdScreen({Key? key, required this.nextScreen}) : super(key: key);

  @override
  State<SkippableAdScreen> createState() => _SkippableAdScreenState();
}

class _SkippableAdScreenState extends State<SkippableAdScreen> {
  late final WebViewController _controller;
  int _timeLeft = 30; // 30 second ka timer (Jaisa aapne manga tha)
  bool _canSkip = false;
  Timer? _timer;

  // Aapke Adsterra aur Monetag ke links
  final List<String> _adLinks = [
    "https://www.profitableratecpmnetwork.com/qftskbqkm?key=6a0072dfddbd45e6f448fa2a00d2df90",
    "https://omg10.com/4/11914245",
    "https://omg10.com/4/11914244"
  ];

  @override
  void initState() {
    super.initState();
    
    // Random ad link select karna
    final _random = Random();
    String selectedAd = _adLinks[_random.nextInt(_adLinks.length)];

    // WebView v4.x initialization
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..loadRequest(Uri.parse(selectedAd));

    // 30 Second Timer start karna
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        if (mounted) {
          setState(() {
            _timeLeft--;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _canSkip = true;
          });
        }
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _skipAd() {
    // Ad skip karke next screen (movie player) par jana
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => widget.nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // WebView jisme Ad chalega
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
          ],
        ),
      ),
    );
  }
}