import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String movieTitle;

  const VideoPlayerPage({
    Key? key,
    required this.videoUrl,
    required this.movieTitle,
  }) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final WebViewController _controller;
  
  // Custom Loading State
  bool isVideoPlaying = false;
  bool isCropped = false;

  @override
  void initState() {
    super.initState();
    
    // SCREEN KO TEDHA (LANDSCAPE) AUR FULLSCREEN KARNA
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      
      // JAVASCRIPT CHANNEL (Video actual play hone ka wait karega)
      ..addJavaScriptChannel(
        'VideoState',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'playing' && mounted) {
            setState(() {
              isVideoPlaying = true; // HANNUTV Logo hata dega
            });
          }
        },
      )
      
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // DEEP CODING JAVASCRIPT INJECTION
            _controller.runJavaScript('''
              // 1. TOUCH RELOAD FIX: Ads aur popups ko silently kill karna
              window.open = function() { return null; };
              
              // 2. CHECK IF VIDEO STARTED: Jab video 0.1s chal jaye tabhi flutter ko batao
              var checkVideo = setInterval(function() {
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0 && vids[0].currentTime > 0.1) {
                  VideoState.postMessage('playing');
                  clearInterval(checkVideo);
                }
              }, 500);
              
              // 3. HIDE SERVER TOASTS: Spica/Sirius wale background texts ko hide karna
              var style = document.createElement('style');
              style.innerHTML = 'div[style*="z-index"] { display: none !important; }';
              document.head.appendChild(style);
            ''');
          },
        ),
      )
      ..loadRequest(
        Uri.parse(widget.videoUrl),
        headers: {
          'Referer': 'https://hannutv.app/', 
        },
      );

    // AUDIO MUTE BYPASS
    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    // FALLBACK: Agar 15 second tak stream na chale, toh bhi logo hata do taaki user player dekh sake
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && !isVideoPlaying) {
        setState(() => isVideoPlaying = true);
      }
    });
  }

  // CROP / FILL SCREEN LOGIC
  void toggleCrop() {
    setState(() {
      isCropped = !isCropped;
    });
    _controller.runJavaScript('''
      var vids = document.getElementsByTagName('video');
      if (vids.length > 0) {
        vids[0].style.objectFit = '${isCropped ? "cover" : "contain"}';
        vids[0].style.width = '100%';
        vids[0].style.height = '100%';
      }
    ''');
  }

  @override
  void dispose() {
    // Back aane par phone ko normal (Portrait) mode mein laana
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. MAIN VIDEO PLAYER
          WebViewWidget(controller: _controller),
          
          // 2. CUSTOM HANNUTV LOADING SCREEN (Jab tak video connect/start na ho)
          if (!isVideoPlaying)
            Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/logo.png',
                    height: 60,
                    errorBuilder: (_, __, ___) => const Text(
                      'HANNUTV',
                      style: TextStyle(color: Colors.red, fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Loading Indicator
                  const CircularProgressIndicator(color: Colors.red),
                  const SizedBox(height: 15),
                  const Text(
                    "Starting Stream...",
                    style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            
          // 3. BACK BUTTON
          if (isVideoPlaying)
            Positioned(
              top: 20,
              left: 20,
              child: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),

          // 4. CROP / ZOOM BUTTON (Video ko full fit karne ke liye)
          if (isVideoPlaying)
            Positioned(
              top: 20,
              right: 20,
              child: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isCropped ? Icons.fullscreen_exit : Icons.crop_free,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: toggleCrop,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}