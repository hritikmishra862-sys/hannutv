import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

// TMDB API Token (To fetch details & episodes directly in player page)
const String kTmdbToken =
    'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIzZDJkOTExNmM5ZGU3MjA5ZWUyNzdiYjhjYzlhZWVkOCIsIm5iZiI6MTc5MDI2OTE4NC42MjksInN1YiI6IjZhYjU1NzAwNzZiMTg1ODU3MGFjNDM4NSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.xZJX8fowhVhVJsgl-5wOW6Y7ZfUr9Zu_Ey1qMkhnPd0';

class VideoPlayerPage extends StatefulWidget {
  final int tmdbId;
  final String mediaType; // 'movie' or 'tv'
  final int season;
  final int episode;
  final String movieTitle;

  const VideoPlayerPage({
    Key? key,
    required this.tmdbId,
    required this.mediaType,
    this.season = 1,
    this.episode = 1,
    required this.movieTitle,
  }) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late WebViewController _controller;
  
  bool isPageLoading = true;
  bool isDetailsLoading = true;
  
  late int currentSeason;
  late int currentEpisode;
  String currentServer = 'vidrift'; // 🚀 Default Server is Rift

  Map? mediaDetails;
  List episodesList = [];

  // Available Servers on Pantyflix
  final List<Map<String, String>> availableServers = [
    {'key': 'vidrift', 'name': 'Rift VIP (Ad-Free)'},
    {'key': 'vidbolt', 'name': 'Bolt (Ultra HD)'},
    {'key': 'fast', 'name': 'Fast Stream'},
  ];

  @override
  void initState() {
    super.initState();
    currentSeason = widget.season;
    currentEpisode = widget.episode;

    // Keep portrait mode for YouTube style layout
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    _fetchMediaDetails();
    _initPlayerEngine();
  }

  // 🚀 PANTYFLIX DIRECT URL GENERATOR
  String _generatePantyflixUrl() {
    if (widget.mediaType == 'tv' || widget.mediaType == 'series') {
      return 'https://pantyflix.com/watch/play/tv/${widget.tmdbId}?season=$currentSeason&episode=$currentEpisode&server=$currentServer';
    } else {
      return 'https://pantyflix.com/watch/play/movie/${widget.tmdbId}?server=$currentServer';
    }
  }

  // 🛡️ THE DEEP AD-BLOCKER & PLAYER ISOLATION ENGINE
  void _initPlayerEngine() {
    final targetUrl = _generatePantyflixUrl();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => isPageLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => isPageLoading = false);

            // 🔥 MAGIC JS: Removes EVERYTHING except the video player
            // Kills "Lucky Draw", Transparent Ad Overlays, Headers, Footers
            String jsCode = '''
              // 1. Force Black Background & Prevent Scroll inside WebView
              document.body.style.backgroundColor = '#000000';
              document.documentElement.style.overflow = 'hidden';
              document.body.style.overflow = 'hidden';

              // 2. Kill Popups completely
              window.open = function() { return null; };
              window.alert = function() { return null; };

              // 3. Inject CSS to hide all website garbage
              var style = document.createElement('style');
              style.innerHTML = `
                header, nav, footer, .sidebar, .comments, .related, 
                [class*="telegram"], a[href*="t.me"], 
                [class*="ad-"], iframe[src*="ad"] { 
                  display: none !important; 
                }
                /* Make the player container take the full WebView space */
                #player-area, .player-wrapper, iframe {
                  position: fixed !important;
                  top: 0 !important;
                  left: 0 !important;
                  width: 100vw !important;
                  height: 100vh !important;
                  z-index: 9999 !important;
                  background: black !important;
                }
              `;
              document.head.appendChild(style);

              // 4. Continuous Nuke for Invisible Click-Jackers (Lucky Draw Fix)
              setInterval(function() {
                document.querySelectorAll('div, a, span').forEach(el => {
                  let style = window.getComputedStyle(el);
                  let zIdx = parseInt(style.zIndex);
                  
                  // If it's an invisible overlay trying to steal clicks, KILL IT
                  if ((style.position === 'fixed' || style.position === 'absolute') && 
                      zIdx > 100 && 
                      el.tagName !== 'IFRAME' && 
                      el.tagName !== 'VIDEO') {
                     
                     // Protect player controls, kill the rest
                     let cls = el.className ? el.className.toString().toLowerCase() : '';
                     if (!cls.includes('jw-') && !cls.includes('vjs') && !cls.includes('plyr')) {
                         el.remove();
                     }
                  }
                });

                // Auto Play
                var vids = document.getElementsByTagName('video');
                if (vids.length > 0 && vids[0].paused) {
                  vids[0].play().catch(e => console.log("Autoplay blocked"));
                }
              }, 500);
            ''';
            _controller.runJavaScript(jsCode);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            
            // 🚫 STRICT BLOCK: If it's not pantyflix or a video host, BLOCK IT!
            if (url.contains('adsterra') || url.contains('popads') || 
                url.contains('lucky') || url.contains('bet365') || 
                url.contains('telegram') || url.contains('t.me') ||
                url.contains('market://') || url.contains('intent://')) {
              return NavigationDecision.prevent; // THIS STOPS THE LUCKY DRAW POPUP
            }
            
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(targetUrl));
  }

  // 🔄 FETCH TMDB DETAILS FOR BOTTOM SECTION
  Future<void> _fetchMediaDetails() async {
    final type = widget.mediaType == 'tv' || widget.mediaType == 'series' ? 'tv' : 'movie';
    final url = 'https://api.themoviedb.org/3/$type/${widget.tmdbId}?language=en-US';
    
    try {
      final res = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $kTmdbToken', 'accept': 'application/json'});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          mediaDetails = data;
          isDetailsLoading = false;
        });

        if (type == 'tv' && data['seasons'] != null) {
          _fetchEpisodes(currentSeason);
        }
      }
    } catch (e) {
      setState(() => isDetailsLoading = false);
    }
  }

  Future<void> _fetchEpisodes(int season) async {
    setState(() => currentSeason = season);
    final url = 'https://api.themoviedb.org/3/tv/${widget.tmdbId}/season/$season?language=en-US';
    try {
      final res = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $kTmdbToken', 'accept': 'application/json'});
      if (res.statusCode == 200) {
        setState(() {
          episodesList = json.decode(res.body)['episodes'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Episodes fetch error");
    }
  }

  // 🔄 CHANGE SERVER OR EPISODE
  void _changeStream({String? newServer, int? newEpisode}) {
    if (newServer != null) currentServer = newServer;
    if (newEpisode != null) currentEpisode = newEpisode;
    
    setState(() => isPageLoading = true);
    _controller.loadRequest(Uri.parse(_generatePantyflixUrl()));
  }

  // 📱 FULLSCREEN TOGGLE
  void _toggleFullscreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenPlayer(controller: _controller),
      ),
    ).then((_) {
      // Revert to portrait when coming back from fullscreen
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // 🎬 TOP SECTION: YOUTUBE STYLE PLAYER (16:9 Aspect Ratio)
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: WebViewWidget(controller: _controller),
                  ),
                ),
                
                // Loader while video page is fetching
                if (isPageLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.redAccent),
                            SizedBox(height: 10),
                            Text("Bypassing Ads & Loading Stream...", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Back Button
                Positioned(
                  top: 10, left: 10,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),

                // Fullscreen Button
                Positioned(
                  bottom: 10, right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen, color: Colors.white, size: 30),
                    onPressed: () => _toggleFullscreen(context),
                  ),
                ),
              ],
            ),

            // 📜 BOTTOM SECTION: DETAILS, SERVERS & EPISODES
            Expanded(
              child: isDetailsLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        // Title & Rating
                        Text(
                          widget.movieTitle,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              mediaDetails?['vote_average']?.toStringAsFixed(1) ?? "N/A", 
                              style: const TextStyle(color: Colors.white70, fontSize: 14)
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)),
                              child: Text(isTv ? "Series" : "Movie", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Overview
                        Text(
                          mediaDetails?['overview'] ?? "No description available.",
                          style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 24),

                        // 🎛️ SERVER SELECTION
                        const Text("Select Server (Rift Recommended)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: availableServers.map((srv) {
                            bool isSelected = currentServer == srv['key'];
                            return ChoiceChip(
                              label: Text(srv['name']!),
                              selected: isSelected,
                              selectedColor: Colors.redAccent,
                              backgroundColor: Colors.grey[900],
                              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
                              onSelected: (_) => _changeStream(newServer: srv['key']),
                            );
                          }).toList(),
                        ),
                        
                        const SizedBox(height: 30),

                        // 📺 EPISODES LIST (Only for TV Shows)
                        if (isTv && mediaDetails?['seasons'] != null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Episodes", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              
                              // Season Dropdown
                              DropdownButton<int>(
                                value: currentSeason,
                                dropdownColor: Colors.grey[900],
                                underline: const SizedBox(),
                                icon: const Icon(Icons.arrow_drop_down, color: Colors.redAccent),
                                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                items: (mediaDetails!['seasons'] as List).map<DropdownMenuItem<int>>((s) {
                                  return DropdownMenuItem<int>(
                                    value: s['season_number'],
                                    child: Text("Season ${s['season_number']}"),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) _fetchEpisodes(val);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          
                          episodesList.isEmpty 
                            ? const Center(child: CircularProgressIndicator(color: Colors.red))
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: episodesList.length,
                                itemBuilder: (context, index) {
                                  final ep = episodesList[index];
                                  bool isPlaying = currentEpisode == ep['episode_number'];
                                  
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            ep['still_path'] != null 
                                              ? 'https://image.tmdb.org/t/p/w200${ep['still_path']}' 
                                              : 'https://via.placeholder.com/200x112/222222/888888?text=EP',
                                            width: 100, height: 60, fit: BoxFit.cover,
                                          ),
                                        ),
                                        if (isPlaying)
                                          Container(
                                            color: Colors.black54,
                                            width: 100, height: 60,
                                            child: const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 30),
                                          ),
                                      ],
                                    ),
                                    title: Text(
                                      "${ep['episode_number']}.${ep['name']}",
                                      style: TextStyle(color: isPlaying ? Colors.redAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      "${ep['runtime'] ?? '--'} min",
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                    onTap: () {
                                      // Click episode to play
                                      _changeStream(newEpisode: ep['episode_number']);
                                    },
                                  );
                                },
                              )
                        ]
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

// 🎬 FULLSCREEN PLAYER WIDGET
class FullscreenPlayer extends StatefulWidget {
  final WebViewController controller;
  const FullscreenPlayer({Key? key, required this.controller}) : super(key: key);

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  @override
  void initState() {
    super.initState();
    // Force Landscape for Fullscreen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: WebViewWidget(controller: widget.controller),
            ),
            Positioned(
              top: 16, left: 16,
              child: SafeArea(
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                    onPressed: () {
                      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}