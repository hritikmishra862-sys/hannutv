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
  bool canSkip = false;
  late WebViewController _adController;
  
  bool isAdLoading = true;
  bool isTimerStarted = false; 

  // 🔥 DEEP CODING: Tere Monetag aur Adsterra ke links
  final List<String> adLinks = [
    'https://omg10.com/4/11914244', 
    'https://omg10.com/4/11914245',
    'https://www.highrevenueformat.com/a39df283f6ad10c34e229e5715bceff5/invoke.js' 
  ];

  late String currentAdUrl;

  @override
  void initState() {
    super.initState();
    timeLeft = widget.adDuration; 
    currentAdUrl = adLinks[Random().nextInt(adLinks.length)];

    // 🔥 DEEP SHIELD HTML: Ye code ad ko apne aap redirect hone se rokega, 
    // aur jab koi touch karega tabhi AdClick channel ke zariye Chrome khulega.
    final String secureAdHtml = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          body, html { margin: 0; padding: 0; background-color: #050505; height: 100vh; overflow: hidden; display: flex; align-items: center; justify-content: center;}
          .ad-wrapper { position: relative; width: 100%; height: 100%; }
          iframe { width: 100%; height: 100%; border: none; }
          /* Transparent layer to catch clicks and stop aggressive ads */
          .click-shield { position: absolute; top: 0; left: 0; width: 100%; height: 100%; z-index: 99999; cursor: pointer; }
        </style>
      </head>
      <body>
        <div class="ad-wrapper">
          <!-- iframe sandbox auto-redirects block karta hai -->
          <iframe src="$currentAdUrl" sandbox="allow-scripts allow-same-origin allow-forms"></iframe>
          <!-- User jab screen touch karega toh ye div click pakad lega -->
          <div class="click-shield" onclick="AdClick.postMessage('clicked')"></div>
        </div>
        <script>
          // Ad load hone ke 2.5 second baad Flutter ko timer start karne ka signal
          setTimeout(() => AdReady.postMessage('start_timer'), 2500);
        </script>
      </body>
      </html>
    ''';

    _adController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('AdReady', onMessageReceived: (message) {
         if (message.message == 'start_timer' && !isTimerStarted) {
            if(mounted) setState(() { isAdLoading = false; isTimerStarted = true; });
            startStrictTimer();
         }
      })
      ..addJavaScriptChannel('AdClick', onMessageReceived: (message) {
         // 🔥 Jab user screen par touch karega, seedha Chrome khulega
         if (message.message == 'clicked') {
            _launchInExternalBrowser(currentAdUrl);
         }
      })
      ..loadHtmlString(secureAdHtml); 

    if (_adController.platform is AndroidWebViewController) {
      (_adController.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    
    // Backup timer in case HTML script fails to send message
    Future.delayed(const Duration(seconds: 4), () {
       if (!isTimerStarted && mounted) {
          setState(() { isAdLoading = false; isTimerStarted = true; });
          startStrictTimer();
       }
    });
  }

  // 🔥 STRICT TIMER LOGIC: Ad chahe jaisa ho, Timer rukega nahi
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
        if (!canSkip && mounted) {
          setState(() { canSkip = true; });
        }
      }
    });
  }

  // 🔥 CHROME BROWSER ME AD KHOLNE KA CODE
  Future<void> _launchInExternalBrowser(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Browser error: $e");
    }
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
    return PopScope(
      canPop: false, // 🔴 Back Button Strictly Blocked
      onPopInvoked: (didPop) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Watch the Ad to support HANNUTV!'),
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
                          Text("Connecting to Secure Ad Server...", style: TextStyle(color: Colors.white70, fontSize: 13))
                        ],
                      ),
                    ),
                  ),
                ),

              // Skip Button
              Positioned(
                top: 20,
                right: 20,
                child: IgnorePointer(
                  ignoring: !canSkip,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canSkip ? Colors.redAccent : Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(color: canSkip ? Colors.redAccent : Colors.white24),
                      ),
                      elevation: canSkip ? 5 : 0,
                    ),
                    onPressed: canSkip ? goToNext : null, 
                    child: Text(
                      !isTimerStarted 
                          ? "Loading..."  
                          : (canSkip ? "Skip Ad >>" : "Skip in $timeLeft s"), 
                      style: TextStyle(
                        color: canSkip ? Colors.white : Colors.white54, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ),
              ),

              // AD Badge
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