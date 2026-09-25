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
  
  bool isVideoPlaying = false;
  bool isCropped = false;

  @override
  void initState() {
    super.initState();
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'VideoState',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'playing' && mounted) {
            setState(() {
              isVideoPlaying = true;
            });
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _controller.runJavaScript('''
              // TOUCH RELOAD FIX
              window.open = function() { return null; };
              
              // DEEP CODING FOR FAST BUFFERING (Force Preload & Auto playback tracking)
              var checkVideo = setInterval(function() {
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0) {
                  vids[0].preload = 'auto'; // Force background download
                  if (vids[0].currentTime > 0.1) {
                    VideoState.postMessage('playing');
                    clearInterval(checkVideo);
                  }
                }
              }, 500);
              
              // HIDE SERVER TEXTS (Spica/Sirius hide karega)
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

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && !isVideoPlaying) {
        setState(() => isVideoPlaying = true);
      }
    });
  }

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
          WebViewWidget(controller: _controller),
          
          if (!isVideoPlaying)
            Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 60,
                    errorBuilder: (_, __, ___) => const Text(
                      'HANNUTV',
                      style: TextStyle(color: Colors.red, fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const CircularProgressIndicator(color: Colors.red),
                  const SizedBox(height: 15),
                  const Text(
                    "Connecting to Premium Server...",
                    style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            
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