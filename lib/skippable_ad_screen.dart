import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
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
  bool canSkip = false;
  late WebViewController _adController;
  
  bool isAdLoading = true;
  bool isTimerStarted = false; // 🔥 Timer Start Control Flag

  // 🔥 TERE DONO NAYE MONETAG LINKS 🔥
  final List<String> monetagLinks = [
    'https://omg10.com/4/11914244',
    'https://omg10.com/4/11914245'
  ];

  @override
  void initState() {
    super.initState();
    timeLeft = widget.adDuration;
    
    // Randomly select between the two links to maximize revenue
    String selectedAdUrl = monetagLinks[Random().nextInt(monetagLinks.length)];

    // Initialize Ad WebView
    _adController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if(mounted) setState(() { isAdLoading = true; });
          },
          onPageFinished: (String url) {
            if(mounted) {
              setState(() { 
                isAdLoading = false; 
              });
              // 🔥 JAISE HI AD POORA LOAD HOGA, TIMER START HOGA 🔥
              if (!isTimerStarted) {
                isTimerStarted = true;
                startTimer();
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
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

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft > 0) {
        if(mounted){
          setState(() {
            timeLeft--;
            // 🔥 Skip button appear at last 2 seconds 🔥
            if (timeLeft <= 2) {
              canSkip = true;
            }
          });
        }
      } else {
        t.cancel();
        goToNext();
      }
    });
  }

  void goToNext() {
    timer?.cancel();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 PopScope: Deep hardware Back Button lock 🔥
    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please watch or skip the ad to continue!'),
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
              // 🔥 Monetag Ad Full Screen WebView 🔥
              Positioned.fill(
                child: WebViewWidget(controller: _adController),
              ),
              
              // Loading Indicator jab tak website load na ho
              if(isAdLoading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.redAccent),
                ),

              // Top Right Timer / Skip Button
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
                        ? "Loading Ad..."  // Ad load hone se pehle ka text
                        : (canSkip ? "Skip Ad >>" : "Skip in $timeLeft s"), // Load hone ke baad ka text
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),

              // "Ad" badge Bottom Left
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