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
  bool isFallbackActive = false; // Track if we switched to fallback

  // 🔥 TERE MONETAG DIRECT LINKS
  final List<String> monetagLinks = [
    'https://omg10.com/4/11914244',
    'https://omg10.com/4/11914245',
  ];

  // 🔥 TERA ADSTERRA SMARTLINK (Fallback)
  final String adsterraFallbackLink = 'https://www.profitableratecpmnetwork.com/qftskbqkm?key=6a0072dfddbd45e6f448fa2a00d2df90';

  @override
  void initState() {
    super.initState();
    timeLeft = widget.adDuration; 
    
    // Start with a random Monetag link
    _initWebView(monetagLinks[Random().nextInt(monetagLinks.length)]);
  }

  void _initWebView(String initialUrl) {
    // 🚀 DEEP FIX: User Agent Injection to trick aggressive scripts into thinking it's a real Chrome Browser
    final String customUserAgent = "Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36";

    _adController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(customUserAgent) // Inject Fake Chrome Agent
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if(mounted) setState(() { isAdLoading = true; });
            
            // 🚀 HEAVY FALLBACK: Agar Monetag 7 seconds me load nahi hota, Adsterra pe switch karo!
            if (!isFallbackActive) {
              fallbackTimer?.cancel();
              fallbackTimer = Timer(const Duration(seconds: 7), () {
                 if(mounted && isAdLoading) {
                   debugPrint("Monetag Timeout -> Switching to Adsterra Fallback");
                   isFallbackActive = true;
                   _adController.loadRequest(Uri.parse(adsterraFallbackLink)); 
                 }
              });
            } else {
               // Agar Adsterra bhi atak gaya 5 second baad, toh zabardasti timer chala do (no black screen lock)
               Timer(const Duration(seconds: 5), () {
                 if(mounted && !isTimerStarted) {
                    setState(() { isAdLoading = false; isTimerStarted = true; });
                    startStrictTimer();
                 }
               });
            }
          },
          onPageFinished: (String url) {
            if(mounted) {
              setState(() { isAdLoading = false; });
              fallbackTimer?.cancel();

              // 🚀 REAL VISIBILITY LOGIC: Inject script to verify body is actually rendered, not just black screen
              _adController.runJavaScript('''
                setTimeout(() => {
                   if (document.body && document.body.innerText.trim().length > 0) {
                      AdBridge.postMessage('ad_visible');
                   } else {
                      AdBridge.postMessage('ad_empty');
                   }
                }, 1500);
              ''');
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            
            // Allow initial redirects within the WebView
            if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('about:blank')) {
               // 🚀 CLICK INTERCEPTOR: Agar URL Monetag ya Adsterra ke main link se alag hai (matlab user ne ad ke andar click kiya hai), toh bahar Chrome me kholo
               if (isTimerStarted && !url.contains('omg10.com') && !url.contains('profitableratecpmnetwork')) {
                 _launchInExternalBrowser(request.url);
                 return NavigationDecision.prevent;
               }
               return NavigationDecision.navigate;
            } else {
               // market:// intent ya play store links handle karega
               _launchInExternalBrowser(request.url);
               return NavigationDecision.prevent; 
            }
          },
        ),
      )
      ..addJavaScriptChannel('AdBridge', onMessageReceived: (message) {
         // JavaScript channel se response aane par action
         if (message.message == 'ad_visible' && !isTimerStarted) {
            if(mounted) setState(() { isTimerStarted = true; });
            startStrictTimer();
         } else if (message.message == 'ad_empty' && !isFallbackActive) {
            // Agar page load hua par body khali/black hai, toh Adsterra try karo
            debugPrint("Detected Black Screen -> Switching to Adsterra");
            isFallbackActive = true;
            _adController.loadRequest(Uri.parse(adsterraFallbackLink));
         } else if (message.message == 'ad_empty' && isFallbackActive && !isTimerStarted) {
            // Agar Adsterra bhi fail hai toh kam se kam timer chalu kar do, app stuck nahi hoga
            if(mounted) setState(() { isTimerStarted = true; isAdLoading = false; });
            startStrictTimer();
         }
      });

    if (_adController.platform is AndroidWebViewController) {
      (_adController.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _adController.loadRequest(Uri.parse(initialUrl));
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

  Future<void> _launchInExternalBrowser(String urlString) async {
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
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Watch the complete Ad to support us!'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.black, // Dark background to blend nicely
        body: SafeArea(
          child: Stack(
            children: [
              // 🔥 Main Ad Viewport
              Positioned.fill(
                child: WebViewWidget(controller: _adController),
              ),
              
              // 🔥 Strict Loading Screen (Blocks interaction until ad is ready)
              if(isAdLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.redAccent),
                          const SizedBox(height: 20),
                          Text(
                            isFallbackActive ? "Connecting Alternate Server..." : "Loading Sponsored Ad...", 
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)
                          )
                        ],
                      ),
                    ),
                  ),
                ),

              // 🔥 Top Right Skip Button Frame
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
                        side: BorderSide(color: canSkip ? Colors.redAccent : Colors.white24, width: 1.5),
                      ),
                      elevation: canSkip ? 8 : 0,
                    ),
                    onPressed: canSkip ? goToNext : null, 
                    child: Text(
                      !isTimerStarted 
                          ? "Wait..."  
                          : (canSkip ? "Skip Ad >>" : "Skip in $timeLeft s"), 
                      style: TextStyle(
                        color: canSkip ? Colors.white : Colors.white54, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5
                      ),
                    ),
                  ),
                ),
              ),

              // 🔥 Bottom Left Ad Badge
              Positioned(
                bottom: 20, left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber, 
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)]
                  ),
                  child: const Text("AD", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}