import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

// TMDB API Token (To fetch details, episodes & comments fast)
const String kTmdbToken =
    'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIzZDJkOTExNmM5ZGU3MjA5ZWUyNzdiYjhjYzlhZWVkOCIsIm5iZiI6MTc5MDI2OTE4NC42MjksInN1YiI6IjZhYjU1NzAwNzZiMTg1ODU3MGFjNDM4NSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.xZJX8fowhVhVJsgl-5wOW6Y7ZfUr9Zu_Ey1qMkhnPd0';

class VideoPlayerPage extends StatefulWidget {
  final int tmdbId;
  final String mediaType; // 'movie' or 'tv'
  final int season;
  final int episode;
  final String movieTitle;

  // Parameters to avoid dashboard crashes
  final String? overview; 
  final String? posterUrl;
  final String? customUrl;
  final String? preferredServer;

  const VideoPlayerPage({
    Key? key,
    required this.tmdbId,
    required this.mediaType,
    this.season = 1,
    this.episode = 1,
    required this.movieTitle,
    this.overview,
    this.posterUrl,
    this.customUrl,
    this.preferredServer,
  }) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late WebViewController _controller;
  
  bool isPlayerLoading = true;
  bool isDetailsLoading = true;
  bool isFullscreen = false;
  
  late int currentSeason;
  late int currentEpisode;
  String currentServer = 'vidrift'; // 🚀 Default Server is Rift

  Map? mediaDetails;
  List episodesList = [];
  List reviewsList = []; // For Comments Section

  @override
  void initState() {
    super.initState();
    currentSeason = widget.season;
    currentEpisode = widget.episode;

    // Start in Portrait mode (YouTube Style UI)
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    _fetchMediaDetails();
    _initPlayerEngine();
  }

  // 🚀 PANTYFLIX DIRECT URL GENERATOR (100% Match)
  String _generatePantyflixUrl() {
    if (widget.mediaType == 'tv' || widget.mediaType == 'series') {
      return 'https://pantyflix.com/watch/play/tv/${widget.tmdbId}?season=$currentSeason&episode=$currentEpisode&server=$currentServer';
    } else {
      return 'https://pantyflix.com/watch/play/movie/${widget.tmdbId}?server=$currentServer';
    }
  }

  // 🛡️ THE NUCLEAR AD-BLOCKER & PLAYER EXTRACTION ENGINE
  void _initPlayerEngine() {
    final targetUrl = _generatePantyflixUrl();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        // Desktop User Agent to bypass mobile popups
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => isPlayerLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => isPlayerLoading = false);

            // 🔥 THE MASTER JS BYPASS: Destroys the website and keeps ONLY the video player
            String jsCode = '''
              // 1. Force Black Background & Prevent Scroll
              document.body.style.backgroundColor = '#000000';
              document.documentElement.style.overflow = 'hidden';
              document.body.style.overflow = 'hidden';

              // 2. Kill Native Popups
              window.open = function() { return null; };
              window.alert = function() { return null; };

              // 3. THE NUCLEAR OPTION: Find the Player and Nuke Everything Else
              let adKiller = setInterval(function() {
                let iframes = document.getElementsByTagName('iframe');
                for(let i=0; i<iframes.length; i++) {
                  let src = iframes[i].src.toLowerCase();
                  
                  // If we find the Pantyflix stream iframe (Rift/Spiral/Vidsrc)
                  if(src.includes('rift') || src.includes('spiral') || src.includes('player') || src.includes('embed') || src.includes('vidsrc')) {
                    let playerIframe = iframes[i];
                    
                    // Nuke the entire website's HTML body
                    document.body.innerHTML = ''; 
                    
                    // Make player full screen inside the WebView
                    playerIframe.style.position = 'fixed';
                    playerIframe.style.top = '0';
                    playerIframe.style.left = '0';
                    playerIframe.style.width = '100vw';
                    playerIframe.style.height = '100vh';
                    playerIframe.style.zIndex = '2147483647';
                    playerIframe.style.border = 'none';
                    
                    // Put the player back into the empty body
                    document.body.appendChild(playerIframe);
                    document.body.style.backgroundColor = '#000000';
                    
                    clearInterval(adKiller); // Stop loop once successful
                    break;
                  }
                }
                
                // Temporary hide ads before Nuclear Nuke happens
                document.querySelectorAll('[class*="ad"], [id*="ad"], header, footer, a[href*="t.me"]').forEach(e => e.style.display = 'none');
              }, 200);
            ''';
            _controller.runJavaScript(jsCode);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            
            // 🚫 STRICT BLOCK: Stop Lucky Draw and Ads from loading entirely
            if (url.contains('adsterra') || url.contains('popads') || 
                url.contains('lucky') || url.contains('bet365') || 
                url.contains('telegram') || url.contains('t.me') ||
                url.contains('market://') || url.contains('intent://')) {
              return NavigationDecision.prevent; 
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(targetUrl));
  }

  // 🔄 FETCH TMDB DETAILS, EPISODES & REVIEWS (For the UI below player)
  Future<void> _fetchMediaDetails() async {
    final type = widget.mediaType == 'tv' || widget.mediaType == 'series' ? 'tv' : 'movie';
    final detailUrl = 'https://api.themoviedb.org/3/$type/${widget.tmdbId}?language=en-US';
    final reviewUrl = 'https://api.themoviedb.org/3/$type/${widget.tmdbId}/reviews?language=en-US&page=1';
    
    try {
      final res = await http.get(Uri.parse(detailUrl), headers: {'Authorization': 'Bearer $kTmdbToken', 'accept': 'application/json'});
      final revRes = await http.get(Uri.parse(reviewUrl), headers: {'Authorization': 'Bearer $kTmdbToken', 'accept': 'application/json'});

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            mediaDetails = data;
            if (revRes.statusCode == 200) {
              reviewsList = json.decode(revRes.body)['results'] ?? [];
            }
            isDetailsLoading = false;
          });
        }

        if (type == 'tv' && data['seasons'] != null) {
          _fetchEpisodes(currentSeason);
        }
      }
    } catch (e) {
      if (mounted) setState(() => isDetailsLoading = false);
    }
  }

  Future<void> _fetchEpisodes(int season) async {
    if (mounted) setState(() => currentSeason = season);
    final url = 'https://api.themoviedb.org/3/tv/${widget.tmdbId}/season/$season?language=en-US';
    try {
      final res = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $kTmdbToken', 'accept': 'application/json'});
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            episodesList = json.decode(res.body)['episodes'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint("Episodes fetch error");
    }
  }

  // 🔄 CHANGE SERVER OR EPISODE
  void _changeStream({String? newServer, int? newEpisode}) {
    if (newServer != null) currentServer = newServer;
    if (newEpisode != null) currentEpisode = newEpisode;
    
    setState(() => isPlayerLoading = true);
    _controller.loadRequest(Uri.parse(_generatePantyflixUrl()));
  }

  // 📱 FULLSCREEN TOGGLE
  void _toggleFullscreen() {
    setState(() {
      isFullscreen = !isFullscreen;
    });
    if (isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        if (isFullscreen) {
          _toggleFullscreen();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 🎬 1. TOP SECTION: YOUTUBE STYLE PLAYER (16:9 Aspect Ratio)
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: isFullscreen ? MediaQuery.of(context).size.height : MediaQuery.of(context).size.width * (9 / 16),
                    color: Colors.black,
                    child: WebViewWidget(controller: _controller),
                  ),
                  
                  // Loader while video page is fetching
                  if (isPlayerLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black87,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 10),
                              Text("Loading selected server...", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              SizedBox(height: 5),
                              Text("Requesting a playable link from this server...", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Back Button (Hide in fullscreen)
                  if (!isFullscreen)
                    Positioned(
                      top: 10, left: 10,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                  // Fullscreen Button
                  Positioned(
                    bottom: 10, right: 10,
                    child: IconButton(
                      icon: Icon(isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 30),
                      onPressed: _toggleFullscreen,
                    ),
                  ),
                ],
              ),

              // 📜 2. BOTTOM SECTION: DETAILS, SERVERS & EPISODES (Like Screenshot)
              if (!isFullscreen)
                Expanded(
                  child: isDetailsLoading 
                    ? const Center(child: CircularProgressIndicator(color: Colors.white24))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            
                            // Title
                            Text(
                              widget.movieTitle,
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            
                            // Rating & Year
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  mediaDetails?['vote_average']?.toStringAsFixed(1) ?? "N/A", 
                                  style: const TextStyle(color: Colors.white70, fontSize: 16)
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  mediaDetails?['release_date']?.split('-')[0] ?? mediaDetails?['first_air_date']?.split('-')[0] ?? "2024",
                                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Action Buttons (Add to List, Play on TV, etc.)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildOutlinedButton(Icons.bookmark_border, "Add to List"),
                                _buildOutlinedButton(Icons.tv, "Play on TV"),
                                _buildOutlinedButton(Icons.share, "Share"),
                                _buildOutlinedButton(Icons.flag_outlined, "Report"),
                              ],
                            ),
                            const SizedBox(height: 30),

                            // 🎛️ SERVER SELECTION
                            const Text(
                              "If current server is not working, try a different one:",
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text("Servers : ", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 10),
                                ChoiceChip(
                                  label: const Text("Rift"),
                                  selected: currentServer == 'vidrift',
                                  selectedColor: Colors.white,
                                  backgroundColor: Colors.transparent,
                                  shape: StadiumBorder(side: BorderSide(color: currentServer == 'vidrift' ? Colors.transparent : Colors.white24)),
                                  labelStyle: TextStyle(color: currentServer == 'vidrift' ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                                  onSelected: (_) => _changeStream(newServer: 'vidrift'),
                                ),
                                const SizedBox(width: 10),
                                ChoiceChip(
                                  label: const Text("Spiral"),
                                  selected: currentServer == 'vidspiral',
                                  selectedColor: Colors.white,
                                  backgroundColor: Colors.transparent,
                                  shape: StadiumBorder(side: BorderSide(color: currentServer == 'vidspiral' ? Colors.transparent : Colors.white24)),
                                  labelStyle: TextStyle(color: currentServer == 'vidspiral' ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                                  onSelected: (_) => _changeStream(newServer: 'vidspiral'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),

                            // 💬 COMMENTS SECTION
                            if (reviewsList.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111111), // Dark card color
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Comments ${reviewsList.length}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundImage: reviewsList[0]['author_details']?['avatar_path'] != null 
                                            ? NetworkImage('https://image.tmdb.org/t/p/w200${reviewsList[0]['author_details']['avatar_path']}')
                                            : null,
                                          child: reviewsList[0]['author_details']?['avatar_path'] == null ? const Icon(Icons.person) : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "${reviewsList[0]['author']} • 9d", 
                                                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                reviewsList[0]['content'] ?? "Awesome movie!", 
                                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),
                            ],

                            // 📺 EPISODES LIST (Only for TV Shows)
                            if (isTv && mediaDetails?['seasons'] != null) ...[
                              // Season Button
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white24),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: currentSeason,
                                    dropdownColor: Colors.grey[900],
                                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Episodes", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                  Icon(Icons.grid_view, color: Colors.white54),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              episodesList.isEmpty 
                                ? const Center(child: CircularProgressIndicator(color: Colors.white24))
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 1.5,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                    itemCount: episodesList.length,
                                    itemBuilder: (context, index) {
                                      final ep = episodesList[index];
                                      bool isPlaying = currentEpisode == ep['episode_number'];
                                      
                                      return GestureDetector(
                                        onTap: () => _changeStream(newEpisode: ep['episode_number']),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: isPlaying ? Colors.white : Colors.transparent, width: 2),
                                            image: DecorationImage(
                                              image: NetworkImage(
                                                ep['still_path'] != null 
                                                  ? 'https://image.tmdb.org/t/p/w500${ep['still_path']}' 
                                                  : 'https://via.placeholder.com/500x281/222222/888888?text=EP',
                                              ),
                                              fit: BoxFit.cover,
                                              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                Text(
                                                  "Episode : ${ep['episode_number']}",
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  ep['name'] ?? '',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                            ],
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}