import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  bool isLoading = true;
  bool hasError = false; 

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                isLoading = false;
                hasError = true; 
              });
            }
          },
        ),
      )
      // DEEP CODING: Stellar API strictly requires a Referer header
      ..loadRequest(
        Uri.parse(widget.videoUrl),
        headers: {
          'Referer': 'https://hannutv.app/', // Bypass referrer block
        },
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.movieTitle),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (!hasError) WebViewWidget(controller: _controller),
            
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
              
            // ISP / Network Block Checker
            if (hasError)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white54, size: 60),
                    const SizedBox(height: 16),
                    const Text(
                      "Server Blocked by Network Provider!\n\nPlease turn on any FREE VPN\n(like Turbo VPN) to play this video.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        setState(() { isLoading = true; hasError = false; });
                        _controller.reload(); 
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text("Retry Now"),
                    )
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }
}