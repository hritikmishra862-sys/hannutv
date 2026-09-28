import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:webview_flutter/webview_flutter.dart';

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

  // 🚀 WORLD'S BEST HARDCODING: Sirf Full-Screen Direct Links 🚀
  final List<String> _fullScreenAdLinks = [
    "https://omg10.com/4/11914245", // Industrious link
    "https://omg10.com/4/11914244", // Lovey-dovey link
  ];

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.adDuration; // 🚀 Dashboard se 10s ya 30s aayega
    
    final _random = Random();
    String selectedAd = _fullScreenAdLinks[_random.nextInt(_fullScreenAdLinks.length)];

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      // Direct Link load kar rahe hain taaki 100% Full Screen Ad aaye
      ..loadRequest(Uri.parse(selectedAd));

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        if (mounted) setState(() => _timeLeft--);
      } else {
        if (mounted) setState(() => _canSkip = true);
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
          ],
        ),
      ),
    );
  }
}