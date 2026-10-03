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
  Timer? safetyTimer;
  Timer? fallbackSwitchTimer;
  bool canSkip = false;
  late WebViewController _adController;

  bool isAdLoading = true;
  bool isTimerStarted = false;
  int currentAdSourceIndex = 0;

  // 🚀 HIGH-CPM DIRECT SMARTLINKS (ADSTERRA + MONETAG)
  final List<String> adUrls = [
    'https://www.profitableratecpmnetwork.com/qftskbqkm?key=6a0072dfddbd45e6f448fa2a00d2df90', // Adsterra Smartlink 1
    'https://omg10.com/4/11914244', // Monetag Lovey-dovey 11914244
    'https://omg10.com/4/11914245', // Monetag Industrious 11914245
  ];

  @override
  void initState() {
    super.initState();
    timeLeft = widget.adDuration;
    currentAdSourceIndex = Random().nextInt(adUrls.length);

    _initAdEngine();
  }

  void _initAdEngine() {
    final targetUrl = adUrls[currentAdSourceIndex];

    _adController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF141414))
      ..setUserAgent(
        "Mozilla/5.0 (Linux; Android 13; SM-S918B Build/TP1A.220624.014) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36",
      )
      ..addJavaScriptChannel(
        'AdStateChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'ad_rendered' && mounted) {
            _onAdSuccessfullyRendered();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                isAdLoading = true;
              });
            }

            fallbackSwitchTimer?.cancel();
            fallbackSwitchTimer = Timer(const Duration(seconds: 4), () {
              if (mounted && isAdLoading) {
                _tryAlternateAdNetwork();
              }
            });
          },
          onPageFinished: (String url) {
            String detectJs = '''
              (function() {
                document.body.style.backgroundColor = '#141414';
                function checkContent() {
                  if (document.body && (document.body.innerText.length > 5 || document.images.length > 0 || document.getElementsByTagName('iframe').length > 0)) {
                    AdStateChannel.postMessage('ad_rendered');
                  }
                }
                checkContent();
                setTimeout(checkContent, 1000);
                setTimeout(checkContent, 2000);
              })();
            ''';
            _adController.runJavaScript(detectJs);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();

            if (url.startsWith('http://') ||
                url.startsWith('https://') ||
                url.startsWith('about:blank') ||
                url.startsWith('data:')) {
              return NavigationDecision.navigate;
            }

            _launchExternal(request.url);
            return NavigationDecision.prevent;
          },
          onWebResourceError: (WebResourceError error) {
            _tryAlternateAdNetwork();
          },
        ),
      );

    if (_adController.platform is AndroidWebViewController) {
      final androidController = _adController.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    _adController.loadRequest(
      Uri.parse(targetUrl),
      headers: {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Upgrade-Insecure-Requests': '1',
      },
    );

    safetyTimer?.cancel();
    safetyTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !isTimerStarted) {
        _onAdSuccessfullyRendered();
      }
    });
  }

  void _onAdSuccessfullyRendered() {
    if (mounted) {
      setState(() {
        isAdLoading = false;
      });
      fallbackSwitchTimer?.cancel();

      if (!isTimerStarted) {
        isTimerStarted = true;
        _startCountdown();
      }
    }
  }

  void _tryAlternateAdNetwork() {
    if (!mounted || isTimerStarted) return;
    currentAdSourceIndex = (currentAdSourceIndex + 1) % adUrls.length;
    _adController.loadRequest(Uri.parse(adUrls[currentAdSourceIndex]));
  }

  void _startCountdown() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft > 0) {
        if (mounted) {
          setState(() {
            timeLeft--;
            if (timeLeft <= 0) {
              canSkip = true;
            }
          });
        }
      } else {
        t.cancel();
        if (mounted) {
          setState(() {
            canSkip = true;
          });
        }
      }
    });
  }

  Future<void> _launchExternal(String urlString) async {
    try {
      final Uri uri = Uri.parse(urlString);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _goToDestination() {
    timer?.cancel();
    safetyTimer?.cancel();
    fallbackSwitchTimer?.cancel();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => widget.nextScreen),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    safetyTimer?.cancel();
    fallbackSwitchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait for the sponsored ad to finish!'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: WebViewWidget(controller: _adController),
              ),
              if (isAdLoading)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF0F0F0F),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.redAccent, width: 2),
                            ),
                            child: const SizedBox(
                              width: 38,
                              height: 38,
                              child: CircularProgressIndicator(
                                color: Colors.redAccent,
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            "Loading Sponsored Offer...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Connecting high-speed ad servers",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 18,
                right: 18,
                child: IgnorePointer(
                  ignoring: !canSkip,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canSkip ? Colors.redAccent : Colors.black.withOpacity(0.75),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(
                          color: canSkip ? Colors.redAccent : Colors.white30,
                          width: 1.5,
                        ),
                      ),
                      elevation: canSkip ? 6 : 0,
                    ),
                    onPressed: canSkip ? _goToDestination : null,
                    child: Text(
                      !isTimerStarted
                          ? "Loading Ad..."
                          : (canSkip ? "Skip Ad >>" : "Skip in $timeLeft s"),
                      style: TextStyle(
                        color: canSkip ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 18,
                left: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Text(
                    "Ad",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}