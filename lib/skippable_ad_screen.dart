import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart'; 
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

  // 🔥 DEEP CODING: Monetag + Adsterra Direct Links Mix
  final List<String> adLinks = [
    'https://omg10.com/4/11914244', // Monetag
    'https://omg10.com/4/11914245', // Monetag
    'https://www.highrevenueformat.com/a39df283f6ad10c34e229e5715bceff5/invoke.js' // Adsterra Fallback
  ];

  late String currentAdUrl;

  @override
  void initState() {
    super.initState();
    timeLeft = widget.adDuration; 
    currentAdUrl = adLinks[Random().nextInt(adLinks.length)];

    _adController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if(mounted) setState(() { isAdLoading = true; });
            
            // 🔥 DEEP LOGIC: Agar 5 second tak page load na ho, toh Adsterra load kar do
            fallbackTimer = Timer(const Duration(seconds: 5), () {
               if(mounted && isAdLoading) {
                 _adController.loadRequest(Uri.parse(adLinks.last)); 
               }
            });
          },
          onPageFinished: (String url) {
            if(mounted) {
              setState(() { isAdLoading = false; });
              fallbackTimer?.cancel();

              // 🔥 STRICT LOGIC: Ad poora load hone par hi timer start hoga
              if (!isTimerStarted) {
                isTimerStarted = true;
                startStrictTimer();
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            
            // 🔥 DEEP LOGIC: Ad pe CLICK karte hi Chrome Browser me khulega!
            if (!url.contains(currentAdUrl.toLowerCase()) && !url.contains('about:blank')) {
               _launchInBrowser(request.url);
               return NavigationDecision.prevent; // App ke andar ad redirect block kiya
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(currentAdUrl));

    if (_adController.platform is AndroidWebViewController) {
      (_adController.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

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

  // 🔥 CLICK HONE PAR CHROME BROWSER KHOLNE KA CODE
  Future<void> _launchInBrowser(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Browser launch error: $e");
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
    return PopScope(
      canPop: false, // 🔴 BACK BUTTON STRICTLY BLOCKED
      onPopInvoked: (didPop) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait for the Ad to finish!'),
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
              // 🔥 Ad Content Area (Touchable)
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
                          Text("Loading Sponsored Ad...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
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
                        ? "Wait..."  
                        : (canSkip ? "Skip Ad >>" : "Skip in $timeLeft s"), 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              Positioned(
                bottom: 20,
                left: 20,
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