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
  final String overview; 
  final String rating;
  final String year;
  final String? customUrl;
  final bool isPixelflix; 

  const VideoPlayerPage({
    super.key,
    required this.tmdbId,
    required this.mediaType,
    this.season = 1,
    this.episode = 1,
    required this.movieTitle,
    this.overview = '',
    this.rating = '9.0',
    this.year = '2024',
    this.customUrl,
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

  // 🚀 RESTORED MISSING VARIABLES TO FIX ERRORS 🚀
  String activeServer = 'vidrift';
  List similarMovies = [];
  bool isLoadingSimilar = false;

  final TextEditingController commentInputController = TextEditingController();
  final List<Map<String, String>> publicComments = [
    {'name': 'SHEEL', 'text': 'HARE KRISHNA 🦚', 'time': '9d', 'avatar': 'S'},
    {'name': 'Rohit Sharma', 'text': 'Best quality on HANNUTV, loving this series! 🔥', 'time': '2d', 'avatar': 'R'},
  ];

  // 🚀 SERVER LIST RESTORED AS REQUESTED 🚀
  final List<Map<String, String>> servers = const [
    {'key': 'vidrift', 'name': 'Rift'},
    {'key': 'fast', 'name': 'Fast'},
    {'key': 'vidbolt', 'name': 'Bolt'},
    {'key': 'cinezo', 'name': 'Cinezo'},
    {'key': 'hindi-new', 'name': 'Hindi New'},
    {'key': 'peach', 'name': 'Peach'},
    {'key': 'mega', 'name': 'Mega'},
    {'key': 'alpha', 'name': 'Alpha'},
    {'key': 'orion', 'name': 'Orion'},
    {'key': 'hindi', 'name': 'Hindi'},
    {'key': 'vidgod', 'name': 'Vidgod'},
    {'key': 'cinesrc', 'name': 'CineSrc'},
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
    
    _fetchSimilarMovies(); // 🚀 Fetching suggested movies
    _initStream();
  }

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

  Future<void> _fetchSimilarMovies() async {
    setState(() => isLoadingSimilar = true);
    try {
      final type = widget.mediaType == 'tv' || widget.mediaType == 'series' ? 'tv' : 'movie';
      final res = await http.get(Uri.parse('https://api.themoviedb.org/3/$type/${widget.tmdbId}/recommendations?language=en-US'), headers: kApiHeaders);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List results = data['results'] ?? [];
        if (mounted) {
          setState(() {
            similarMovies = results.map((m) => {
              'id': m['id'],
              'title': m['title'] ?? m['name'] ?? 'Unknown',
              'posterUrl': m['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${m['poster_path']}' : '',
              'rating': (m['vote_average'] ?? 0).toStringAsFixed(1),
              'year': (m['release_date'] ?? m['first_air_date'] ?? '').toString().split('-').first,
              'mediaType': type,
            }).toList();
            isLoadingSimilar = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingSimilar = false);
    }
  }

  // 🚀 DEEP LOGIC: CLEAN EMBED URLS (No Website/No Adult Ads) 🚀
  String _buildStreamUrl() {
    if (widget.customUrl != null && widget.customUrl!.isNotEmpty) {
      return widget.customUrl!;
    }
    
    final id = widget.tmdbId;
    final s = currentSeason;
    final e = currentEpisode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    // Pixelflix Direct Clean Embed
    if (widget.isPixelflix) {
      if (activeServer == 'vidbolt') return isTv ? 'https://vidbolt.xyz/tv/$id/$s/$e' : 'https://vidbolt.xyz/movie/$id';
      return isTv ? 'https://vidsrc.pm/embed/tv?tmdb=$id&season=$s&episode=$e' : 'https://vidsrc.pm/embed/movie/$id';
    }

    // Pantyflix Direct Clean Embeds
    if (activeServer == 'fast' || activeServer == 'alpha') {
      return isTv ? 'https://vidsrc.net/embed/tv?tmdb=$id&season=$s&episode=$e' : 'https://vidsrc.net/embed/movie/$id';
    } else if (activeServer == 'vidbolt') {
      return isTv ? 'https://vidbolt.xyz/tv/$id/$s/$e' : 'https://vidbolt.xyz/movie/$id';
    } else if (activeServer == 'hindi-new' || activeServer == 'hindi') {
      return isTv ? 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e' : 'https://multiembed.mov/?video_id=$id&tmdb=1';
    } else if (activeServer == 'cinezo' || activeServer == 'orion') {
      return isTv ? 'https://player.autoembed.cc/embed/tv/$id/$s/$e' : 'https://player.autoembed.cc/embed/movie/$id';
    }
    
    return isTv ? 'https://vidlink.pro/tv/$id/$s/$e' : 'https://vidlink.pro/movie/$id';
  }

  void _initStream() {
    setState(() { isPageLoading = true; });
    final targetUrl = _buildStreamUrl();
    final targetUri = Uri.parse(targetUrl);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => isPageLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => isPageLoading = false);

            // 🚀 ADS BLOCKER SCRIPT 🚀
            String jsCode = '''
              const nukeAds = () => {
                  document.body.style.backgroundColor = '#000000';
                  document.documentElement.style.backgroundColor = '#000000';
                  
                  const adClasses = ['.ad', '.ads', '.popup', '#captcha', '.human-verify', '[id*="verify"]', '[class*="verify"]', 'iframe[src*="challenge"]', '.cf-turnstile', 'a[target="_blank"]'];
                  document.querySelectorAll(adClasses.join(',')).forEach(el => el.style.display = 'none !important');
                  
                  document.body.style.pointerEvents = 'none';
                  
                  const video = document.querySelector('video') || document.querySelector('iframe');
                  if(video) {
                      video.style.position = 'fixed';
                      video.style.top = '0';
                      video.style.left = '0';
                      video.style.width = '100vw';
                      video.style.height = '100vh';
                      video.style.zIndex = '2147483647';
                      video.style.pointerEvents = 'auto'; 
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
            // 🚀 NO ADULT SITES OR REDIRECTS ALLOWED 🚀
            if (url.contains('vidsrc') || url.contains('vidlink') || url.contains('vidbolt') || url.contains('multiembed') || url.contains('autoembed') || url.contains('pixelflix') || url.contains('pantyflix') || url.contains('googleapis') || url.startsWith('data:') || url.startsWith('blob:')) {
                return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent; 
          },
        ),
      );

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    // 🚀 Sandbox Fix 🚀
    _controller.loadRequest(
      targetUri,
      headers: {
        "Referer": "https://${targetUri.host}/",
        "Origin": "https://${targetUri.host}"
      }
    );
  }

  void _cycleAspectRatio() {
    setState(() {
      if (currentAspectRatio == 'contain') { currentAspectRatio = 'cover'; } 
      else if (currentAspectRatio == 'cover') { currentAspectRatio = 'fill'; } 
      else { currentAspectRatio = 'contain'; }
    });

    _controller.runJavaScript("var vids = document.getElementsByTagName('video'); if (vids.length > 0) { vids[0].style.objectFit = '$currentAspectRatio'; }");
  }

  // 🚀 FIXED: _switchEpisode METHOD RESTORED 🚀
  void _switchEpisode(int ep) {
    setState(() {
      currentEpisode = ep;
    });
    _initStream();
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
                    
                    // 🚀 GOOGLE STUDIO UI: Dual AI Analysis (Green Status Boxes) 🚀
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFF141619), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Dual AI Analysis:", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(color: widget.isPixelflix ? Colors.transparent : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: widget.isPixelflix ? Colors.white12 : Colors.green)),
                            child: Row(
                              children: [
                                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.greenAccent, blurRadius: 4)])),
                                const SizedBox(width: 10),
                                const Text("Hannutv1: Online (VIP Node)", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(color: widget.isPixelflix ? Colors.cyan.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(20), border: Border.all(color: widget.isPixelflix ? Colors.cyan : Colors.white12)),
                            child: Row(
                              children: [
                                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.cyanAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.cyanAccent, blurRadius: 4)])),
                                const SizedBox(width: 10),
                                const Text("Hannutv2: Online (Pixelflix Node)", style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: Text("Tap node to instant switch", style: TextStyle(color: Colors.grey, fontSize: 10)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 🚀 GOOGLE STUDIO UI: HANNUTV2 PIXELFLIX STREAMS 🚀
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFF141619), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(widget.isPixelflix ? "HANNUTV2 PIXELFLIX STREAMS" : "HANNUTV1 VIP STREAMS", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                              const Text("12/12 Nodes Online", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text("Dual-node engine active:", style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic)),
                          const SizedBox(height: 10),
                          
                          // 🚀 SERVERS ADDED TO GOOGLE STUDIO UI 🚀
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                const Text("Servers: ", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                ...servers.map((srv) {
                                  final isSelected = activeServer == srv['key'];
                                  return InkWell(
                                    onTap: () {
                                      setState(() { activeServer = srv['key']!; });
                                      _initStream();
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white : Colors.grey[900], 
                                        borderRadius: BorderRadius.circular(20)
                                      ),
                                      child: Row(
                                        children: [
                                          Container(width: 6, height: 6, decoration: BoxDecoration(color: isSelected ? Colors.green : Colors.grey, shape: BoxShape.circle)),
                                          const SizedBox(width: 6),
                                          Text(srv['name']!, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 🚀 GOOGLE STUDIO UI: Season & Audio Pills 🚀
                    if (widget.mediaType == 'tv' || widget.mediaType == 'series') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          InkWell(
                            onTap: _showSeasonPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                              child: Column(
                                children: [
                                  const Text("Season", style: TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)),
                                  Text(currentSeason.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
                            child: Column(
                              children: const [
                                Icon(Icons.volume_up, color: Colors.white, size: 14),
                                Text("Original Audio", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
                            child: Column(
                              children: [
                                Text(episodesList.length.toString(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                                const Text("Episodes", style: TextStyle(color: Colors.grey, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
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
                                onTap: () => _switchEpisode(epNum), // 🚀 FIXED: Call to _switchEpisode 🚀
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
                    
                    // 🚀 BANNER AD ADDED 🚀
                    const CustomBannerAd(
                      htmlBannerCode: '''
                        <script type="text/javascript">
                          atOptions = {
                            'key' : 'a39df283f6ad10c34e229e5715bceff5',
                            'format' : 'iframe',
                            'height' : 50,
                            'width' : 320,
                            'params' : {}
                          };
                        </script>
                        <script type="text/javascript" src="https://www.highrevenueformat.com/a39df283f6ad10c34e229e5715bceff5/invoke.js"></script>
                      ''',
                    ),
                    const SizedBox(height: 18),

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
                    const SizedBox(height: 20),

                    // 🚀 SUGGESTED MOVIES ADDED 🚀
                    if (similarMovies.isNotEmpty) ...[
                      const Text(
                        "Suggested Movies & Shows",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: similarMovies.length,
                          itemBuilder: (context, index) {
                            final m = similarMovies[index];
                            return InkWell(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => SkippableAdScreen(
                                          adDuration: 30,
                                          nextScreen: VideoPlayerPage(
                                            tmdbId: m['id'],
                                            mediaType: m['mediaType'],
                                            movieTitle: m['title'],
                                            rating: m['rating'],
                                            year: m['year'],
                                            isPixelflix: widget.isPixelflix, 
                                          ),
                                        ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 110,
                                margin: const EdgeInsets.only(right: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          image: DecorationImage(
                                            image: NetworkImage(
                                              m['posterUrl'] != ''
                                                  ? m['posterUrl']
                                                  : 'https://via.placeholder.com/300x450/222222/888888',
                                            ),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      m['title'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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