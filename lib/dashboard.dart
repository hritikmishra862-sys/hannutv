import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'video_player_page.dart';

const String kTmdbToken = 'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIzZDJkOTExNmM5ZGU3MjA5ZWUyNzdiYjhjYzlhZWVkOCIsIm5iZiI6MTc5MDI2OTE4NC42MjksInN1YiI6IjZhYjU1NzAwNzZiMTg1ODU3MGFjNDM4NSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.xZJX8fowhVhVJsgl-5wOW6Y7ZfUr9Zu_Ey1qMkhnPd0';

const Map<String, String> kApiHeaders = {
  'Authorization': 'Bearer $kTmdbToken',
  'accept': 'application/json',
};

// GLOBAL LIST FOR CONTINUE WATCHING
List<Map> continueWatchingList = [];

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);
  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  List movies = [];
  bool isLoading = true;
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();
  
  // LIVE SEARCH DEBOUNCER
  Timer? _debounce;
  
  final PageController _pageController = PageController();
  Timer? _carouselTimer;
  int _currentPage = 0;

  final List<Map<String, dynamic>> ottPlatforms = [
    {"name": "NETFLIX", "color": Colors.redAccent},
    {"name": "PRIME", "color": Colors.blueAccent},
    {"name": "HOTSTAR", "color": Colors.green},
    {"name": "SONYLIV", "color": Colors.orange},
    {"name": "ZEE5", "color": Colors.purple},
  ];

  final List<String> categories = ["Action", "Anime", "Comedy", "Horror", "Romance", "Sci-Fi"];

  @override
  void initState() {
    super.initState();
    fetchTmdbData('');
    _startCarousel();
  }

  void _startCarousel() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_pageController.hasClients && movies.isNotEmpty) {
        _currentPage++;
        if (_currentPage >= (movies.length > 5 ? 5 : movies.length)) {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> fetchTmdbData(String query) async {
    setState(() => isLoading = true);
    try {
      final String url = query.isEmpty
          ? 'https://api.themoviedb.org/3/trending/all/day?language=en-US'
          : 'https://api.themoviedb.org/3/search/multi?query=${Uri.encodeComponent(query)}&language=en-US';

      final response = await http.get(Uri.parse(url), headers: kApiHeaders);
      if (response.statusCode == 200) {
        final List rawData = json.decode(response.body)['results'] ?? [];
        
        setState(() {
          movies = rawData.where((m) => m['media_type'] != 'person').map((m) => {
            'id': m['id'],
            'title': m['title'] ?? m['name'] ?? 'Unknown',
            'overview': m['overview'] ?? '',
            'posterUrl': m['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${m['poster_path']}' : '',
            'backdropUrl': m['backdrop_path'] != null ? 'https://image.tmdb.org/t/p/original${m['backdrop_path']}' : '',
            'rating': (m['vote_average'] ?? 0).toStringAsFixed(1),
            'year': (m['release_date'] ?? m['first_air_date'] ?? '').toString().split('-').first,
            'mediaType': m['media_type'] ?? 'movie',
          }).toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    // 300ms SUPERFAST DEBOUNCE - Type karte hi list update hogi
    _debounce = Timer(const Duration(milliseconds: 300), () {
      fetchTmdbData(value);
    });
  }

  Future<void> _openTelegram() async {
    final Uri url = Uri.parse('https://t.me/HANNUTV');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Telegram error');
    }
  }

  void openMediaDetails(Map media) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => MediaDetailScreen(mediaItem: media))).then((_) {
      // BACK AANE PAR DASHBOARD UPDATE HOGA TAAKI CONTINUE WATCHING DIKHE
      setState(() {}); 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent, color: Colors.red, size: 30),
            onPressed: _openTelegram,
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 400,
                  child: movies.isEmpty
                      ? Container(color: Colors.black)
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: movies.length > 5 ? 5 : movies.length,
                          onPageChanged: (index) => _currentPage = index,
                          itemBuilder: (context, index) {
                            return Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(
                                    movies[index]['backdropUrl'] != ''
                                        ? movies[index]['backdropUrl']
                                        : 'https://images.unsplash.com/photo-1616530940355-351fabd9524b?q=80&w=600',
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [const Color(0xFF0F0F0F), Colors.transparent, Colors.black.withOpacity(0.9)],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        isSearching
                            ? Expanded(
                                child: TextField(
                                  controller: searchController,
                                  style: const TextStyle(color: Colors.white),
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText: 'Search Movies, Series...',
                                    border: InputBorder.none,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          isSearching = false;
                                          searchController.clear();
                                          fetchTmdbData('');
                                        });
                                      },
                                    ),
                                  ),
                                  onChanged: onSearchChanged, // LIVE SEARCH ENABLED
                                ),
                              )
                            : Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Image.asset('assets/logo.png', height: 35),
                                ),
                              ),
                        if (!isSearching)
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.white, size: 28),
                            onPressed: () => setState(() => isSearching = true),
                          ),
                      ],
                    ),
                  ),
                ),
                if (movies.isNotEmpty && !isSearching)
                  Positioned(
                    bottom: 20, left: 16, right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movies[_currentPage]['title'] ?? 'Title',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 6),
                            Text('${movies[_currentPage]['rating']}  •  ${movies[_currentPage]['year']}  •  ${(movies[_currentPage]['mediaType']).toString().toUpperCase()}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white, foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          ),
                          onPressed: () => openMediaDetails(movies[_currentPage]),
                          icon: const Icon(Icons.play_arrow, size: 24),
                          label: const Text('Play Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  )
              ],
            ),
            
            // CONTINUE WATCHING SECTION
            if (continueWatchingList.isNotEmpty && !isSearching) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Text('Continue Watching', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                height: 170, // Height thodi badhai taaki S2E4 text aa sake
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: continueWatchingList.length,
                  itemBuilder: (context, index) {
                    final media = continueWatchingList[index];
                    return GestureDetector(
                      onTap: () => openMediaDetails(media),
                      child: Container(
                        width: 110,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 130,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(media['posterUrl'] != '' ? media['posterUrl'] : 'https://via.placeholder.com/300x450/222222/888888'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 40)),
                            ),
                            const SizedBox(height: 4),
                            Text(media['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            
                            // SHOW SAVED SEASON AND EPISODE ON DASHBOARD
                            if (media['savedSeason'] != null)
                              Text('S${media['savedSeason']} E${media['savedEpisode']}', style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Text('Watch on OTT', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: ottPlatforms.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[900],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(color: ottPlatforms[index]['color'], width: 1.5),
                      ),
                      onPressed: () {
                        searchController.clear();
                        fetchTmdbData(ottPlatforms[index]['name']);
                      },
                      child: Text(ottPlatforms[index]['name'], style: TextStyle(color: ottPlatforms[index]['color'], fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Text('Categories', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      backgroundColor: Colors.grey[850],
                      labelStyle: const TextStyle(color: Colors.white),
                      label: Text(categories[index]),
                      onPressed: () {
                        searchController.clear();
                        fetchTmdbData(categories[index]);
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 10.0),
              child: Text(
                searchController.text.isEmpty ? 'Trending Now' : 'Search Results',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator(color: Colors.red)))
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, childAspectRatio: 0.65, crossAxisSpacing: 12, mainAxisSpacing: 12,
                    ),
                    itemCount: movies.length,
                    itemBuilder: (context, index) {
                      final movie = movies[index];
                      return GestureDetector(
                        onTap: () => openMediaDetails(movie),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      movie['posterUrl'] != '' ? movie['posterUrl'] : 'https://via.placeholder.com/300x450/222222/888888?text=NO+POSTER',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              movie['title'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── DETAILS SCREEN ───────────
class MediaDetailScreen extends StatefulWidget {
  final Map mediaItem;
  const MediaDetailScreen({Key? key, required this.mediaItem}) : super(key: key);

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  Map? details;
  List episodes = [];
  bool isLoadingDetails = true;
  bool isLoadingEpisodes = false;
  int? selectedSeason;

  @override
  void initState() {
    super.initState();
    fetchDetails();
  }

  Future<void> fetchDetails() async {
    final mediaType = widget.mediaItem['mediaType'] ?? 'movie';
    final id = widget.mediaItem['id'];

    try {
      final response = await http.get(Uri.parse('https://api.themoviedb.org/3/$mediaType/$id?language=en-US'), headers: kApiHeaders);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          details = {
            'title': data['title'] ?? data['name'] ?? '',
            'overview': data['overview'] ?? '',
            'backdropUrl': data['backdrop_path'] != null ? 'https://image.tmdb.org/t/p/original${data['backdrop_path']}' : '',
            'seasons': data['seasons'] != null ? (data['seasons'] as List).map((s) => {'seasonNumber': s['season_number'], 'episodeCount': s['episode_count']}).toList() : [],
          };
          isLoadingDetails = false;
          if ((mediaType == 'tv') && details!['seasons'] != null && (details!['seasons'] as List).isNotEmpty) {
            // DEEP FIX: Resume from exactly where user left off
            selectedSeason = widget.mediaItem['savedSeason'] ?? details!['seasons'][0]['seasonNumber'];
            if (selectedSeason != null) fetchEpisodes(selectedSeason!);
          }
        });
      } else {
        setState(() => isLoadingDetails = false);
      }
    } catch (e) {
      setState(() => isLoadingDetails = false);
    }
  }

  Future<void> fetchEpisodes(int seasonNumber) async {
    setState(() { isLoadingEpisodes = true; selectedSeason = seasonNumber; });
    try {
      final response = await http.get(Uri.parse('https://api.themoviedb.org/3/tv/${widget.mediaItem['id']}/season/$seasonNumber?language=en-US'), headers: kApiHeaders);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          episodes = (data['episodes'] as List? ?? []).map((ep) => {
            'episodeNumber': ep['episode_number'],
            'name': ep['name'],
            'overview': ep['overview'],
            'stillUrl': ep['still_path'] != null ? 'https://image.tmdb.org/t/p/w500${ep['still_path']}' : '',
          }).toList();
          isLoadingEpisodes = false;
        });
      } else {
        setState(() => isLoadingEpisodes = false);
      }
    } catch (e) {
      setState(() => isLoadingEpisodes = false);
    }
  }

  void launchPlayer(String title, {int? season, int? episode}) {
    final id = widget.mediaItem['id'];
    final type = widget.mediaItem['mediaType'] ?? 'movie';
    
    // REMOVE OLD ENTRY AND ADD NEW ONE TO TOP (WITH SEASON & EPISODE INFO)
    continueWatchingList.removeWhere((m) => m['id'] == id);
    Map currentMedia = Map.from(widget.mediaItem);
    if (type == 'tv' || type == 'series') {
      currentMedia['savedSeason'] = season ?? 1;
      currentMedia['savedEpisode'] = episode ?? 1;
    }
    continueWatchingList.insert(0, currentMedia);

    String finalUrl = '';

    if (type == 'tv' || type == 'series') {
      final s = season ?? 1;
      final e = episode ?? 1;
      finalUrl = 'https://stellar.rip/hi/watch/embed/tv/$id-$s-$e?theme=E50914&title=true&poster=true&autoPlay=true&nextButton=true&autoNext=true';
    } else {
      finalUrl = 'https://stellar.rip/hi/watch/embed/movie/$id?theme=E50914&title=true&poster=true&autoPlay=true';
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => VideoPlayerPage(
      videoUrl: finalUrl,
      movieTitle: title,
    )));
  }

  void _showDownloadPopup(BuildContext context, String contentTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Download: $contentTitle", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              ListTile(leading: const Icon(Icons.download, color: Colors.red), title: const Text("1080p (Full HD)"), onTap: () => Navigator.pop(context)),
              ListTile(leading: const Icon(Icons.download, color: Colors.white70), title: const Text("720p (HD)"), onTap: () => Navigator.pop(context)),
              ListTile(leading: const Icon(Icons.download, color: Colors.white70), title: const Text("480p (SD)"), onTap: () => Navigator.pop(context)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaType = widget.mediaItem['mediaType'] ?? 'movie';

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: isLoadingDetails
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(details != null && details!['backdropUrl'] != '' ? details!['backdropUrl'] : (widget.mediaItem['backdropUrl'] ?? '')),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF0F0F0F), Colors.transparent]),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(details?['title'] ?? widget.mediaItem['title'] ?? '', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(details?['overview'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.4)),
                        const SizedBox(height: 20),
                        
                        if (mediaType == 'movie') ...[
                          Row(
                            children: [
                              Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: () => launchPlayer(details?['title'] ?? 'Movie'), icon: const Icon(Icons.play_arrow, color: Colors.white), label: const Text('Play Movie', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
                              const SizedBox(width: 10),
                              Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: () => _showDownloadPopup(context, details?['title'] ?? 'Movie'), icon: const Icon(Icons.download, color: Colors.white), label: const Text('Download', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
                            ],
                          ),
                        ] else if (mediaType == 'tv' && details?['seasons'] != null && (details!['seasons'] as List).isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
                            child: DropdownButton<int>(
                              value: selectedSeason,
                              isExpanded: true,
                              underline: const SizedBox(),
                              dropdownColor: Colors.grey[900],
                              items: (details!['seasons'] as List).map<DropdownMenuItem<int>>((season) {
                                return DropdownMenuItem<int>(value: season['seasonNumber'], child: Text('Season ${season['seasonNumber']}  (${season['episodeCount']} Episodes)', style: const TextStyle(color: Colors.white)));
                              }).toList(),
                              onChanged: (int? newValue) { if (newValue != null) fetchEpisodes(newValue); },
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('Episodes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          isLoadingEpisodes
                              ? const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: Colors.red)))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: episodes.length,
                                  itemBuilder: (context, index) {
                                    final ep = episodes[index];
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(ep['stillUrl'] != '' ? ep['stillUrl'] : 'https://via.placeholder.com/300x168/222222/888888?text=EP', width: 110, height: 70, fit: BoxFit.cover),
                                      ),
                                      title: Text('${ep['episodeNumber']}. ${ep['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      subtitle: Text(ep['overview'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      
                                      // HIGHLIGHT THE SAVED EPISODE
                                      tileColor: (selectedSeason == widget.mediaItem['savedSeason'] && ep['episodeNumber'] == widget.mediaItem['savedEpisode']) ? Colors.grey[850] : null,
                                      
                                      trailing: IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 32), onPressed: () => launchPlayer('S${selectedSeason}E${ep['episodeNumber']} - ${ep['name']}', season: selectedSeason, episode: ep['episodeNumber'])),
                                    );
                                  },
                                ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}