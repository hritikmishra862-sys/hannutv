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

  // 🔥 MONETAG & ADSTERRA DEEP INTEGRATION
  final List<String> adNetworks = [
    'https://omg10.com/4/11914244', // Monetag 1
    'https://omg10.com/4/11914245', // Monetag 2
  ];

  // Adsterra ka Full Screen Banner Bypass
  final String adsterraHtml = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <style>body{margin:0;padding:0;background:#000;display:flex;justify-content:center;align-items:center;height:100vh;}</style>
    </head>
    <body>
      <script type="text/javascript">
        atOptions = { 'key' : 'a39df283f6ad10c34e229e5715bceff5', 'format' : 'iframe', 'height' : 250, 'width' : 300, 'params' : {} };
      </script>
      <script type="text/javascript" src="https://www.highrevenueformat.com/a39df283f6ad10c34e229e5715bceff5/invoke.js"></script>
    </body>
    </html>
  ''';

  @override
  void initState() {
    super.initState();
    timeLeft = widget.adDuration; 
    _initWebView();
  }

  void _initWebView() {
    // 50% chance Monetag, 50% Adsterra taaki fill rate 100% rahe
    bool useHtml = Random().nextBool(); 

    _adController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if(mounted) setState(() { isAdLoading = true; });
            
            // 🔥 FAIL-SAFE: Agar Monetag 6 second me load nahi hua, toh Adsterra thok do!
            fallbackTimer?.cancel();
            fallbackTimer = Timer(const Duration(seconds: 6), () {
               if(mounted && isAdLoading && !useHtml) {
                 _adController.loadHtmlString(adsterraHtml); 
               }
            });
          },
          onPageFinished: (String url) {
            if(mounted) {
              setState(() { isAdLoading = false; });
              fallbackTimer?.cancel();

              // 🔥 STRICT LOGIC: Jab page 100% load hoga TABHI timer chalega!
              if (!isTimerStarted) {
                isTimerStarted = true;
                startStrictTimer();
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            
            // 🔥 DEEP FIX: Redirect hone do taaki black screen na aaye (WebView ke andar)
            if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('about:blank')) {
               return NavigationDecision.navigate;
            } else {
               // 🔥 Agar link Play Store (market://) ya Telegram ka hai toh external Chrome me kholo!
               _launchInExternalBrowser(request.url);
               return NavigationDecision.prevent; 
            }
          },
        ),
      );

    if (_adController.platform is AndroidWebViewController) {
      (_adController.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    if (useHtml) {
      _adController.loadHtmlString(adsterraHtml);
    } else {
      _adController.loadRequest(Uri.parse(adNetworks[Random().nextInt(adNetworks.length)]));
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
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wait for the Ad to finish!'),
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
                          Text("Loading Sponsored Ad...", style: TextStyle(color: Colors.white70, fontSize: 13))
                        ],
                      ),
                    ),
                  ),
                ),

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
                          ? "Wait..."  
                          : (canSkip ? "Skip Ad >>" : "Skip in $timeLeft s"), 
                      style: TextStyle(
                        color: canSkip ? Colors.white : Colors.white54, 
                        fontWeight: FontWeight.bold
                      ),
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