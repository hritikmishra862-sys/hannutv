import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart'; // Naya add kiya hai click handling ke liye
import 'dart:async';
import 'dart:math';

class SkippableAdScreen extends StatefulWidget {
  final int adDuration;
  final Widget nextScreen;

  const SkippableAdScreen({
    super.key,
    required this.adDuration,
    required this.nextScreen,
  });

  @override
  State<SkippableAdScreen> createState() => _SkippableAdScreenState();
}

class _SkippableAdScreenState extends State<SkippableAdScreen> {
  late int timeLeft;
  Timer? timer;
  Timer? fallbackTimer;
  bool canSkip = false;
  late WebViewController _adController;
  
  bool isAdLoading = true;
  bool isTimerStarted = false; 

  final List<String> monetagLinks = [
    'https://omg10.com/4/11914244',
    'https://omg10.com/4/11914245'
  ];

  @override
  void initState() {
    super.initState();
    timeLeft = widget.adDuration; 

    String selectedAdUrl = monetagLinks[Random().nextInt(monetagLinks.length)];

    _adController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if(mounted) setState(() { isAdLoading = true; });
            
            // 🔥 DEEP FIX: Human verification ya popads ko bypass karne ke liye
            fallbackTimer = Timer(const Duration(seconds: 4), () {
               if(mounted && isAdLoading) {
                 _adController.reload(); 
               }
            });
          },
          onPageFinished: (String url) {
            if(mounted) {
              setState(() { 
                isAdLoading = false; 
              });
              fallbackTimer?.cancel();

              // 🔥 DEEP LOGIC: Ad poora load hone par hi strict timer shuru hoga
              if (!isTimerStarted) {
                isTimerStarted = true;
                startStrictTimer();
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            
            // 🔥 DEEP FIX: Agar user Ad par click karta hai toh usko browser mein khol do
            if (!url.contains('omg10.com')) {
               _launchInBrowser(url);
               return NavigationDecision.prevent; // Webview mein doosra ad mat khulne do
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(selectedAdUrl));

    if (_adController.platform is AndroidWebViewController) {
      (_adController.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  // 🔥 DEEP LOGIC: Strict Timer
  void startStrictTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft > 0) {
        if(mounted){
          setState(() {
            timeLeft--;
            if (timeLeft <= 0) {
              canSkip = true;
            }
          });
        }
      } else {
        t.cancel();
        if (!canSkip) {
          setState(() { canSkip = true; });
        }
      }
    });
  }

  // Browser mein ad kholne ka function
  Future<void> _launchInBrowser(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void goToNext() {
    timer?.cancel();
    fallbackTimer?.cancel();
    if (mounted) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => widget.nextScreen)
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 DEEP LOGIC: Back button band kiya gaya hai
    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wait for the Ad to finish to continue!'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: WebViewWidget(controller: _adController),
              ),
              
              if(isAdLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.redAccent),
                          SizedBox(height: 16),
                          Text("Loading Ad...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        ],
                      ),
                    ),
                  ),
                ),

              Positioned(
                top: 20,
                right: 20,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSkip ? Colors.redAccent : Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: BorderSide(color: canSkip ? Colors.redAccent : Colors.white30),
                    ),
                  ),
                  onPressed: canSkip ? goToNext : null, 
                  child: Text(
                    !isTimerStarted 
                        ? "Loading..."  
                        : (canSkip ? "Skip Ad >>" : "Skip in $timeLeft s"), 
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "Ad",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}