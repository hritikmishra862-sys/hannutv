import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'banner_ad_widget.dart';
import 'skippable_ad_screen.dart';

const String kTmdbToken =
    'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIzZDJkOTExNmM5ZGU3MjA5ZWUyNzdiYjhjYzlhZWVkOCIsIm5iZiI6MTc5MDI2OTE4NC42MjksInN1YiI6IjZhYjU1NzAwNzZiMTg1ODU3MGFjNDM4NSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.xZJX8fowhVhVJsgl-5wOW6Y7ZfUr9Zu_Ey1qMkhnPd0';

const Map<String, String> kApiHeaders = {
  'Authorization': 'Bearer $kTmdbToken',
  'accept': 'application/json',
};

class VideoPlayerPage extends StatefulWidget {
  final int tmdbId;
  final String mediaType;
  final int season;
  final int episode;
  final String movieTitle;
  final String rating;
  final String year;
  final bool isPixelflix; 

  const VideoPlayerPage({
    super.key,
    required this.tmdbId,
    required this.mediaType,
    this.season = 1,
    this.episode = 1,
    required this.movieTitle,
    this.rating = '9.0',
    this.year = '2024',
    this.isPixelflix = false,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late WebViewController _controller;
  bool isPageLoading = true;
  String currentAspectRatio = 'contain';

  late int currentSeason;
  late int currentEpisode;
  int totalSeasons = 1;
  
  List<dynamic> episodesList = [];
  bool isLoadingEpisodes = false;

  final TextEditingController commentInputController = TextEditingController();
  final List<Map<String, String>> publicComments = [
    {'name': 'SHEEL', 'text': 'HARE KRISHNA 🦚', 'time': '9d', 'avatar': 'S'},
    {'name': 'Rohit Sharma', 'text': 'Best quality on HANNUTV, loving this series! 🔥', 'time': '2d', 'avatar': 'R'},
  ];

  @override
  void initState() {
    super.initState();
    currentSeason = widget.season;
    currentEpisode = widget.episode;
    
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    if (widget.mediaType == 'tv' || widget.mediaType == 'series') {
      _fetchTvDetails();
      _fetchEpisodesForSeason(currentSeason);
    }
    
    _initStream();
  }

  // 🚀 FETCH DYNAMIC SEASONS AND EPISODES FROM TMDB 🚀
  Future<void> _fetchTvDetails() async {
    try {
      final res = await http.get(Uri.parse('https://api.themoviedb.org/3/tv/${widget.tmdbId}?language=en-US'), headers: kApiHeaders);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          totalSeasons = data['number_of_seasons'] ?? 1;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchEpisodesForSeason(int seasonNum) async {
    setState(() { isLoadingEpisodes = true; episodesList = []; });
    try {
      final res = await http.get(Uri.parse('https://api.themoviedb.org/3/tv/${widget.tmdbId}/season/$seasonNum?language=en-US'), headers: kApiHeaders);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          episodesList = data['episodes'] ?? [];
          isLoadingEpisodes = false;
        });
      }
    } catch (_) {
      setState(() { isLoadingEpisodes = false; });
    }
  }

  String _buildStreamUrl() {
    final id = widget.tmdbId;
    final s = currentSeason;
    final e = currentEpisode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    if (widget.isPixelflix) {
      return isTv ? 'https://pixelflix.cc/watch/tv/$id?season=$s&episode=$e' : 'https://pixelflix.cc/watch/movie/$id';
    }
    return isTv ? 'https://pantyflix.com/watch/play/tv/$id?season=$s&episode=$e&server=vidrift' : 'https://pantyflix.com/watch/play/movie/$id?server=vidrift';
  }

  void _initStream() {
    setState(() { isPageLoading = true; });
    final targetUrl = _buildStreamUrl();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => isPageLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => isPageLoading = false);

            // 🚀 ABSOLUTE AD-BLOCKER JS: DESTROY CAPTCHA AND BRING VIDEO TO TOP 🚀
            String jsCode = '''
              const nukeAds = () => {
                  document.body.style.backgroundColor = '#000000';
                  document.documentElement.style.backgroundColor = '#000000';
                  
                  // Hide common ad/captcha overlays
                  const adClasses = ['.ad', '.ads', '.popup', '#captcha', '.human-verify', '[id*="verify"]', '[class*="verify"]', 'iframe[src*="challenge"]', '.cf-turnstile'];
                  document.querySelectorAll(adClasses.join(',')).forEach(el => el.style.display = 'none !important');
                  
                  // Disable clicks on body to prevent invisible popups
                  document.body.style.pointerEvents = 'none';
                  
                  // Force video to top layer and enable clicks ONLY on video
                  const video = document.querySelector('video');
                  if(video) {
                      video.style.position = 'fixed';
                      video.style.top = '0';
                      video.style.left = '0';
                      video.style.width = '100vw';
                      video.style.height = '100vh';
                      video.style.zIndex = '2147483647';
                      video.style.pointerEvents = 'auto'; // Re-enable clicks for video player
                      video.style.objectFit = '$currentAspectRatio';
                      
                      if (video.paused && !video.ended) {
                          video.play().catch(function(){});
                      }
                  }
              };
              setInterval(nukeAds, 500);
            ''';
            _controller.runJavaScript(jsCode);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            // 🚀 STRICT NAVIGATION BLOCKER 🚀
            if (url.contains('pixelflix') || url.contains('pantyflix') || url.contains('vidrift') || url.contains('googleapis') || url.startsWith('data:')) {
                return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent; // Block EVERYTHING else (captchas, popups, redirections)
          },
        ),
      );

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    // 🚀 Sandbox Fix: Direct Load Request 🚀
    _controller.loadRequest(Uri.parse(targetUrl));
  }

  void _cycleAspectRatio() {
    setState(() {
      if (currentAspectRatio == 'contain') { currentAspectRatio = 'cover'; } 
      else if (currentAspectRatio == 'cover') { currentAspectRatio = 'fill'; } 
      else { currentAspectRatio = 'contain'; }
    });

    _controller.runJavaScript("var vids = document.getElementsByTagName('video'); if (vids.length > 0) { vids[0].style.objectFit = '$currentAspectRatio'; }");
  }

  void _addComment() {
    final text = commentInputController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        publicComments.insert(0, {'name': 'You', 'text': text, 'time': 'Just now', 'avatar': 'Y'});
        commentInputController.clear();
      });
    }
  }

  void _showSeasonPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: totalSeasons,
            itemBuilder: (context, index) {
              final seasonNum = index + 1;
              return ListTile(
                title: Text("Season $seasonNum", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() { currentSeason = seasonNum; currentEpisode = 1; });
                  _fetchEpisodesForSeason(seasonNum);
                  _initStream();
                },
              );
            },
          ),
        );
      }
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: double.infinity, height: 230, color: Colors.black,
                  child: WebViewWidget(controller: _controller),
                ),
                Positioned(
                  top: 10, left: 10,
                  child: InkWell(
                    onTap: () {
                      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                      Navigator.pop(context);
                    },
                    child: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.arrow_back, color: Colors.white)),
                  ),
                ),
                Positioned(
                  bottom: 10, right: 10,
                  child: InkWell(
                    onTap: _cycleAspectRatio,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          const Icon(Icons.aspect_ratio, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(currentAspectRatio.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isPageLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset('assets/logo.png', height: 50, errorBuilder: (_, __, ___) => const Icon(Icons.movie, color: Colors.red, size: 50)),
                            const SizedBox(height: 20),
                            const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 3)),
                            const SizedBox(height: 10),
                            Text("Connecting to ${widget.isPixelflix ? 'HANNUTV 2' : 'HANNUTV 1'}...", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.movieTitle, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18), const SizedBox(width: 4),
                        Text(widget.rating, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12), Text(widget.year, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    
                    // 🚀 DISPLAY CURRENT SERVER HANNUTV 1 or 2 🚀
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.dns, color: Colors.greenAccent, size: 20),
                              const SizedBox(width: 10),
                              Text("Streaming from: ${widget.isPixelflix ? 'HANNUTV 2' : 'HANNUTV 1'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.greenAccent, blurRadius: 5)])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    const CustomBannerAd(
                      htmlBannerCode: '''<script type="text/javascript">atOptions = { 'key' : 'a39df283f6ad10c34e229e5715bceff5', 'format' : 'iframe', 'height' : 50, 'width' : 320, 'params' : {} };</script><script type="text/javascript" src="https://www.highrevenueformat.com/a39df283f6ad10c34e229e5715bceff5/invoke.js"></script>''',
                    ),
                    const SizedBox(height: 18),
                    
                    // 🚀 DYNAMIC SEASON / EPISODE SELECTOR 🚀
                    if (widget.mediaType == 'tv' || widget.mediaType == 'series') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: _showSeasonPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                children: [
                                  Text("Season $currentSeason", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                                  const Icon(Icons.arrow_drop_down, color: Colors.black),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text("Episodes", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      
                      if (isLoadingEpisodes) 
                         const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                      else if (episodesList.isEmpty)
                         const Text("No episodes found for this season.", style: TextStyle(color: Colors.grey))
                      else
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal, 
                            itemCount: episodesList.length,
                            itemBuilder: (context, index) {
                              final epData = episodesList[index];
                              final epNum = epData['episode_number'] ?? (index + 1);
                              final epName = epData['name'] ?? "Episode $epNum";
                              final isCurrent = currentEpisode == epNum;
                              
                              return InkWell(
                                onTap: () {
                                  setState(() { currentEpisode = epNum; });
                                  _initStream();
                                },
                                child: Container(
                                  width: 170, margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: isCurrent ? Border.all(color: Colors.redAccent, width: 2) : null, color: Colors.grey[900]),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)), color: Colors.grey[850],
                                            image: epData['still_path'] != null ? DecorationImage(image: NetworkImage('https://image.tmdb.org/t/p/w500${epData['still_path']}'), fit: BoxFit.cover) : null,
                                          ), 
                                          child: Center(child: Icon(isCurrent ? Icons.play_arrow : Icons.play_circle_outline, color: Colors.white, size: 32))
                                        )
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0), 
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("EP $epNum", style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                            Text(epName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],

                    // LIVE COMMENTS SECTION
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Live Comments", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: commentInputController, style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: InputDecoration(hintText: 'Add a comment...', hintStyle: const TextStyle(color: Colors.grey, fontSize: 12), filled: true, fillColor: Colors.black45, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.send, color: Colors.redAccent), onPressed: _addComment),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...publicComments.map((c) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(radius: 14, backgroundColor: Colors.redAccent, child: Text(c['avatar']!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [Text(c['name']!, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(width: 6), Text(c['time']!, style: const TextStyle(color: Colors.grey, fontSize: 10))]),
                                            Text(c['text']!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}