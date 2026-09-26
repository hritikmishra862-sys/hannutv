import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'video_player_page.dart';

const String kTmdbToken =
    'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIzZDJkOTExNmM5ZGU3MjA5ZWUyNzdiYjhjYzlhZWVkOCIsIm5iZiI6MTc5MDI2OTE4NC42MjksInN1YiI6IjZhYjU1NzAwNzZiMTg1ODU3MGFjNDM4NSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.xZJX8fowhVhVJsgl-5wOW6Y7ZfUr9Zu_Ey1qMkhnPd0';

const Map<String, String> kApiHeaders = {
  'Authorization': 'Bearer $kTmdbToken',
  'accept': 'application/json',
};

List<Map> continueWatchingList = [];

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);
  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  List trendingList = [];
  List actionList = [];
  List comedyList = [];
  List horrorList = [];
  List dramaList = [];
  List searchResults = [];

  bool isLoading = true;
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();

  Timer? _debounce;
  final PageController _pageController = PageController();
  Timer? _carouselTimer;
  int _currentPage = 0;

  // OTT Watch Provider Channels (Pantyflix VIP, Netflix, Prime, Hotstar, Jio, etc.)
  final List<Map<String, dynamic>> ottPlatforms = [
    {"name": "🔥 PANTYFLIX VIP", "color": Colors.red, "providerId": "pantyflix"},
    {"name": "NETFLIX", "color": Colors.redAccent, "providerId": "8"},
    {"name": "PRIME", "color": Colors.blueAccent, "providerId": "119"},
    {"name": "HOTSTAR", "color": Colors.green, "providerId": "122"},
    {"name": "SONYLIV", "color": Colors.orange, "providerId": "237"},
    {"name": "ZEE5", "color": Colors.purple, "providerId": "232"},
  ];

  @override
  void initState() {
    super.initState();
    loadAllDashboards();
    _startCarousel();
  }

  void _startCarousel() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_pageController.hasClients && trendingList.isNotEmpty) {
        _currentPage++;
        if (_currentPage >= (trendingList.length > 5 ? 5 : trendingList.length)) {
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

  List parseData(http.Response response, {String? forceMediaType}) {
    if (response.statusCode != 200) return [];
    final List rawData = json.decode(response.body)['results'] ?? [];
    return rawData
        .where((m) => m['media_type'] != 'person')
        .map((m) => {
              'id': m['id'],
              'title': m['title'] ?? m['name'] ?? 'Unknown',
              'overview': m['overview'] ?? '',
              'posterUrl': m['poster_path'] != null
                  ? 'https://image.tmdb.org/t/p/w500${m['poster_path']}'
                  : '',
              'backdropUrl': m['backdrop_path'] != null
                  ? 'https://image.tmdb.org/t/p/original${m['backdrop_path']}'
                  : '',
              'rating': (m['vote_average'] ?? 0).toStringAsFixed(1),
              'year': (m['release_date'] ?? m['first_air_date'] ?? '')
                  .toString()
                  .split('-')
                  .first,
              'mediaType': forceMediaType ?? (m['media_type'] ?? 'movie'),
            })
        .toList();
  }

  Future<void> loadAllDashboards({String? providerId}) async {
    setState(() => isLoading = true);
    try {
      String base = 'https://api.themoviedb.org/3';
      String prov = (providerId != null && providerId != 'pantyflix')
          ? '&with_watch_providers=$providerId&watch_region=IN'
          : '';

      String trendUrl = (providerId != null && providerId != 'pantyflix')
          ? '$base/discover/tv?language=en-US&sort_by=popularity.desc$prov'
          : '$base/trending/all/day?language=en-US';

      var responses = await Future.wait([
        http.get(Uri.parse(trendUrl), headers: kApiHeaders),
        http.get(Uri.parse('$base/discover/movie?language=en-US&with_genres=28$prov&sort_by=popularity.desc'), headers: kApiHeaders),
        http.get(Uri.parse('$base/discover/tv?language=en-US&with_genres=35$prov&sort_by=popularity.desc'), headers: kApiHeaders),
        http.get(Uri.parse('$base/discover/movie?language=en-US&with_genres=27$prov&sort_by=popularity.desc'), headers: kApiHeaders),
        http.get(Uri.parse('$base/discover/tv?language=en-US&with_genres=18$prov&sort_by=popularity.desc'), headers: kApiHeaders),
      ]);

      setState(() {
        trendingList = parseData(responses[0], forceMediaType: (providerId != null && providerId != 'pantyflix') ? 'tv' : null);
        actionList = parseData(responses[1], forceMediaType: 'movie');
        comedyList = parseData(responses[2], forceMediaType: 'tv');
        horrorList = parseData(responses[3], forceMediaType: 'movie');
        dramaList = parseData(responses[4], forceMediaType: 'tv');
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // 🔍 DIRECT MULTI-SEARCH (ALL PANTYFLIX TITLES SUPPORTED)
  void onSearchChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        isSearching = false;
        searchResults = [];
      });
      return;
    }
    setState(() => isSearching = true);
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => isLoading = true);
      try {
        final url = 'https://api.themoviedb.org/3/search/multi?query=${Uri.encodeComponent(value)}&language=en-US&include_adult=false';
        final res = await http.get(Uri.parse(url), headers: kApiHeaders);
        setState(() {
          searchResults = parseData(res);
          isLoading = false;
        });
      } catch (_) {
        setState(() => isLoading = false);
      }
    });
  }

  Future<void> _openTelegram() async {
    if (!await launchUrl(Uri.parse('https://t.me/HANNUTV'),
        mode: LaunchMode.externalApplication)) {
      debugPrint('Telegram error');
    }
  }

  // 🚀 DIRECT LAUNCH PLAYER WITH FULL SCREENSHOT UI & DETAILS
  void launchPlayerDirect(Map media) {
    continueWatchingList.removeWhere((m) => m['id'] == media['id']);
    continueWatchingList.insert(0, media);

    final type = media['mediaType'] ?? 'movie';
    final tId = media['id'] is int ? media['id'] : int.tryParse(media['id'].toString()) ?? 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          tmdbId: tId,
          mediaType: type,
          season: 1,
          episode: 1,
          movieTitle: media['title'] ?? 'Title',
          overview: media['overview'] ?? '',
          rating: media['rating'] ?? '9.0',
          year: media['year'] ?? '2024',
        ),
      ),
    ).then((_) => setState(() {}));
  }

  Widget _buildHorizontalList(String title, List moviesData) {
    if (moviesData.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: moviesData.length,
            itemBuilder: (context, index) {
              final media = moviesData[index];
              return GestureDetector(
                onTap: () => launchPlayerDirect(media),
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
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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
                  child: trendingList.isEmpty
                      ? Container(color: Colors.black)
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: trendingList.length > 5 ? 5 : trendingList.length,
                          onPageChanged: (index) => _currentPage = index,
                          itemBuilder: (context, index) {
                            return Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(trendingList[index]['backdropUrl'] != '' ? trendingList[index]['backdropUrl'] : 'https://images.unsplash.com/photo-1616530940355-351fabd9524b?q=80&w=600'),
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
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(color: Colors.redAccent),
                                  ),
                                  child: TextField(
                                    controller: searchController,
                                    style: const TextStyle(color: Colors.white),
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: 'Search Movies & TV Series...',
                                      border: InputBorder.none,
                                      prefixIcon: const Icon(Icons.search, color: Colors.redAccent),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white),
                                        onPressed: () {
                                          setState(() {
                                            isSearching = false;
                                            searchController.clear();
                                            searchResults.clear();
                                          });
                                        },
                                      ),
                                    ),
                                    onChanged: onSearchChanged,
                                  ),
                                ),
                              )
                            : Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Image.asset('assets/logo.png', height: 35, errorBuilder: (_, __, ___) => const Text('HANNUTV', style: TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold))),
                                ),
                              ),
                        if (!isSearching) ...[
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.white, size: 28),
                            onPressed: () => setState(() => isSearching = true),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (trendingList.isNotEmpty && !isSearching)
                  Positioned(
                    bottom: 20, left: 16, right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trendingList[_currentPage]['title'] ?? 'Title', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24)),
                          onPressed: () => launchPlayerDirect(trendingList[_currentPage]),
                          icon: const Icon(Icons.play_arrow, size: 24),
                          label: const Text('Play Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  )
              ],
            ),
            
            // OTT FILTERS
            const Padding(padding: EdgeInsets.fromLTRB(16, 20, 16, 10), child: Text('Watch on OTT & Channels', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        setState(() => isSearching = false);
                        loadAllDashboards(providerId: ottPlatforms[index]['providerId']); 
                      },
                      child: Text(ottPlatforms[index]['name'], style: TextStyle(color: ottPlatforms[index]['color'], fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  );
                },
              ),
            ),

            if (isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator(color: Colors.red)))
            else if (isSearching)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.65, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final movie = searchResults[index];
                  return GestureDetector(
                    onTap: () => launchPlayerDirect(movie),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: NetworkImage(movie['posterUrl'] != '' ? movie['posterUrl'] : 'https://via.placeholder.com/300x450/222222/888888'), fit: BoxFit.cover)))),
                        const SizedBox(height: 6),
                        Text(movie['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                },
              )
            else ...[
              _buildHorizontalList('🔥 Trending Now', trendingList),
              if (continueWatchingList.isNotEmpty) _buildHorizontalList('Continue Watching', continueWatchingList),
              _buildHorizontalList('Action Movies', actionList),
              _buildHorizontalList('Comedy Shows', comedyList),
              _buildHorizontalList('Horror Movies', horrorList),
              _buildHorizontalList('Drama & Romance Shows', dramaList),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
