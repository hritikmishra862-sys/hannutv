import 'dart:ui'; // 🚀 ADDED FOR PREMIUM GLASS BLUR
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:crypto/crypto.dart'; // 🚀 ADDED FOR MOVIEBOX API
import 'video_player_page.dart';
import 'skippable_ad_screen.dart'; 

const String kTmdbToken =
    'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIzZDJkOTExNmM5ZGU3MjA5ZWUyNzdiYjhjYzlhZWVkOCIsIm5iZiI6MTc5MDI2OTE4NC42MjksInN1YiI6IjZhYjU1NzAwNzZiMTg1ODU3MGFjNDM4NSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.xZJX8fowhVhVJsgl-5wOW6Y7ZfUr9Zu_Ey1qMkhnPd0';

const Map<String, String> kApiHeaders = {
  'Authorization': 'Bearer $kTmdbToken',
  'accept': 'application/json',
};

List<Map> continueWatchingList = [];

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  // 🚀 MAGIC VARIABLE: 10s aur 30s ad ko alternate ghumane ke liye 🚀
  bool _isNextAd10Sec = true; 

  List trendingList = [];
  List bollywoodList = [];
  List hollywoodList = [];
  List animeList = [];
  List actionList = [];
  List comedyList = [];
  List horrorList = [];
  List searchResults = [];
  List pixelflixResults = []; // 🚀 ADDED FOR PIXELFLIX SEARCH

  bool isLoading = true;
  bool isSearching = false;
  bool isPixelflixSearch = false; // 🚀 ADDED TOGGLE FOR 2ND SEARCH BAR

  final TextEditingController searchController = TextEditingController();
  final TextEditingController pixelflixController = TextEditingController(); // 🚀 2ND SEARCH CONTROLLER

  Timer? _debounce;
  final PageController _pageController = PageController();
  Timer? _carouselTimer;
  int _currentPage = 0;
  String selectedPlatform = 'all';

  final List<Map<String, dynamic>> ottPlatforms = const [
    {"name": "🔥 HANNUTV VIP", "color": Colors.red, "providerId": "all"},
    {"name": "NETFLIX", "color": Colors.redAccent, "providerId": "8"},
    {"name": "PRIME VIDEO", "color": Colors.blueAccent, "providerId": "9"},
    {"name": "APPLE TV+", "color": Colors.white70, "providerId": "350"},
    {"name": "CRUNCHYROLL", "color": Colors.orangeAccent, "providerId": "283"},
    {"name": "DISNEY+", "color": Colors.lightBlueAccent, "providerId": "337"},
    {"name": "HULU", "color": Colors.greenAccent, "providerId": "15"},
    {"name": "HBO MAX", "color": Colors.deepPurpleAccent, "providerId": "1899"},
    {"name": "MGM+", "color": Colors.amber, "providerId": "34"},
    {"name": "PARAMOUNT+", "color": Colors.blue, "providerId": "2303"},
    {"name": "PEACOCK", "color": Colors.tealAccent, "providerId": "387"},
    {"name": "SHUDDER", "color": Colors.red, "providerId": "99"},
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
    pixelflixController.dispose(); // 🚀 ADDED
    _debounce?.cancel();
    super.dispose();
  }

  List parseData(http.Response response, {String? forceMediaType}) {
    if (response.statusCode != 200) return [];
    final List rawData = json.decode(response.body)['results'] ?? [];
    return rawData
        .where((m) => m['media_type'] != 'person')
        .map(
          (m) => {
            'id': m['id'],
            'title': m['title'] ?? m['name'] ?? 'Unknown',
            'overview': m['overview'] ?? '',
            'posterUrl':
                m['poster_path'] != null
                    ? 'https://image.tmdb.org/t/p/w500${m['poster_path']}'
                    : '',
            'backdropUrl':
                m['backdrop_path'] != null
                    ? 'https://image.tmdb.org/t/p/original${m['backdrop_path']}'
                    : '',
            'rating': (m['vote_average'] ?? 0).toStringAsFixed(1),
            'year':
                (m['release_date'] ?? m['first_air_date'] ?? '')
                    .toString()
                    .split('-')
                    .first,
            'mediaType': forceMediaType ?? (m['media_type'] ?? 'movie'),
          },
        )
        .toList();
  }

  Future<void> loadAllDashboards({String? providerId}) async {
    setState(() {
      isLoading = true;
      selectedPlatform = providerId ?? 'all';
    });
    try {
      String base = 'https://api.themoviedb.org/3';

      String prov =
          (providerId != null && providerId != 'all')
              ? '&with_watch_providers=$providerId&watch_region=US'
              : '';

      String animeFilter = (providerId == '283') ? '&with_genres=16' : '';

      String trendUrl =
          (providerId != null && providerId != 'all')
              ? '$base/discover/movie?language=en-US&sort_by=popularity.desc$prov$animeFilter'
              : '$base/trending/all/day?language=en-US';

      var responses = await Future.wait([
        http.get(Uri.parse(trendUrl), headers: kApiHeaders),
        http.get(
          Uri.parse(
            '$base/discover/movie?language=hi-IN&with_original_language=hi&sort_by=popularity.desc',
          ),
          headers: kApiHeaders,
        ),
        http.get(
          Uri.parse(
            '$base/discover/movie?language=en-US&with_original_language=en&sort_by=popularity.desc',
          ),
          headers: kApiHeaders,
        ),
        http.get(
          Uri.parse(
            '$base/discover/tv?language=en-US&with_genres=16&sort_by=popularity.desc',
          ),
          headers: kApiHeaders,
        ),
        http.get(
          Uri.parse(
            '$base/discover/movie?language=en-US&with_genres=28$prov&sort_by=popularity.desc',
          ),
          headers: kApiHeaders,
        ),
        http.get(
          Uri.parse(
            '$base/discover/tv?language=en-US&with_genres=35$prov&sort_by=popularity.desc',
          ),
          headers: kApiHeaders,
        ),
        http.get(
          Uri.parse(
            '$base/discover/movie?language=en-US&with_genres=27$prov&sort_by=popularity.desc',
          ),
          headers: kApiHeaders,
        ),
      ]);

      setState(() {
        trendingList = parseData(responses[0]);
        bollywoodList = parseData(responses[1], forceMediaType: 'movie');
        hollywoodList = parseData(responses[2], forceMediaType: 'movie');
        animeList = parseData(responses[3], forceMediaType: 'tv');
        actionList = parseData(responses[4], forceMediaType: 'movie');
        comedyList = parseData(responses[5], forceMediaType: 'tv');
        horrorList = parseData(responses[6], forceMediaType: 'movie');
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // 🚀 ADDED: MOVIEBOX PRO BACKGROUND FETCH FOR DUAL PLAYER
  Future<Map?> _checkMovieBoxProAvailability(String title) async {
    try {
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String reversed = timestamp.split('').reversed.join('');
      String hash = md5.convert(utf8.encode(reversed)).toString();
      String xClientToken = "$timestamp,$hash"; 

      final res = await http.post(
        Uri.parse('https://api6.aoneroom.com/wefeed-mobile-bff/subject-api/search'),
        headers: {'Content-Type': 'application/json;charset=UTF-8', 'User-Agent': 'MovieBoxPro/16.2.1 (Android 12; Pixel 6)', 'X-M-Version': '4.0.02', 'X-Client-Token': xClientToken},
        body: json.encode({"keyword": title, "type": 0, "page": 1, "pageSize": 5})
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'] ?? [];
        if (data.isNotEmpty) {
           return {
             'id': data[0]['id'],
             'mbpSignCookie': "urlprefix=aHR0cHM6Ly9zYmNkbjIuaGFrdW5heW1hdGF0YS5jb20=" 
           };
        }
      }
    } catch (_) {}
    return null;
  }

  // 🚀 ADDED: PIXELFLIX SEARCH API INTEGRATION
  Future<void> _searchPixelflix(String query) async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('https://api.themoviedb.org/3/search/multi?query=${Uri.encodeComponent(query)}&language=en-US&include_adult=false'), headers: kApiHeaders);
      final tmdbData = parseData(res);
      // Format specifically for Pixelflix Server
      setState(() {
        pixelflixResults = tmdbData.map((m) => {
          ...m,
          'isPixelflix': true, // Custom flag for player to know it's Server 2
        }).toList();
        isLoading = false;
      });
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

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
        final url =
            'https://api.themoviedb.org/3/search/multi?query=${Uri.encodeComponent(value)}&language=en-US&include_adult=false';
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

  void _showSupportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // 🚀 CHANGED FOR GLASS UI
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // 🚀 PREMIUM GLASS BLUR
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65), // 🚀 PREMIUM GLASS BLUR
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("HANNUTV Support", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      if (!await launchUrl(Uri.parse('https://t.me/HANNUTV'), mode: LaunchMode.externalApplication)) {}
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.send, color: Colors.blueAccent, size: 30),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text("Request for New Movie", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              Text("Join Telegram", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      if (!await launchUrl(Uri.parse('https://whatsapp.com/channel/0029VbE2Pb17z4kmfjF04P0v'), mode: LaunchMode.externalApplication)) {}
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.chat, color: Colors.greenAccent, size: 30),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text("New Movie Updates", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              Text("Join WhatsApp Channel", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text("App Version: v1.0.0 VIP", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 🚀 ADDED: DUAL PLAYER BOTTOM SHEET (HANNUTV 1 & 2)
  void launchPlayerDirect(Map media) {
    continueWatchingList.removeWhere((m) => m['id'] == media['id']);
    continueWatchingList.insert(0, media);

    // DUAL PLAYER GLASS MODAL[cite: 48, 49]
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 🚀 GLASSMORPHISM
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool isCheckingMbp = true;
            Map? mbpData;

            // Fetch MovieBox in background
            if (isCheckingMbp) {
              _checkMovieBoxProAvailability(media['title'] ?? '').then((result) {
                if (mounted) {
                  setModalState(() {
                    mbpData = result;
                    isCheckingMbp = false;
                  });
                }
              });
            }

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // 🚀 1000% PREMIUM BLUR
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7), // Semi-transparent black
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2), width: 1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 200, width: double.infinity,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), image: DecorationImage(image: NetworkImage(media['backdropUrl'] != '' ? media['backdropUrl'] : media['posterUrl']), fit: BoxFit.cover), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)]),
                      ),
                      const SizedBox(height: 20),
                      Text("Watch ${media['title']}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      const Text("Select Server to Watch:", style: TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // HANNUTV 1 (Pantyflix)
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.9), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              onPressed: () {
                                Navigator.pop(context);
                                _playVideo(media, null, media['isPixelflix'] == true);
                              },
                              child: const Text("HANNUTV 1", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // HANNUTV 2 (MovieBox Pro VIP)
                          Expanded(
                            child: isCheckingMbp 
                              ? const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2)))
                              : mbpData != null
                                ? ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.1), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.redAccent.withOpacity(0.5)))),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      media['id'] = mbpData!['id']; 
                                      _playVideo(media, mbpData!['mbpSignCookie'], false);
                                    },
                                    child: const Text("HANNUTV 2", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[900], padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    onPressed: null,
                                    child: const Text("Offline", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  // 🚀 ACTUAL VIDEO PLAYER LAUNCHER WITH YOUR 10s/30s LOGIC
  void _playVideo(Map media, String? mbpCookie, bool isPixelflix) {
    final type = media['mediaType'] ?? 'movie';
    final tId = media['id'] is int ? media['id'] : int.tryParse(media['id'].toString()) ?? 0;
    int currentAdDuration = _isNextAd10Sec ? 10 : 30;
    _isNextAd10Sec = !_isNextAd10Sec; 

    // Custom Pixelflix URL formatting
    String? customPixelflixUrl;
    if (isPixelflix) {
      customPixelflixUrl = type == 'tv' ? "https://pixelflix.cc/tv/$tId-1-1/" : "https://pixelflix.cc/movie/$tId/";
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SkippableAdScreen(
          adDuration: currentAdDuration,
          nextScreen: VideoPlayerPage(
            tmdbId: tId,
            mediaType: type,
            season: 1,
            episode: 1,
            movieTitle: media['title'] ?? 'Title',
            overview: media['overview'] ?? '',
            rating: media['rating'] ?? '9.0',
            year: media['year'] ?? '2024',
            mbpSignCookie: mbpCookie,
            customUrl: customPixelflixUrl,
          ),
        ),
      ),
    ).then((_) => setState(() {}));
  }

  Widget _buildFocusableItem({required Widget child, required VoidCallback onTap}) {
    return _TvFocusItem(onTap: onTap, child: child);
  }

  Widget _buildHorizontalList(String title, List moviesData) {
    if (moviesData.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: moviesData.length,
            itemBuilder: (context, index) {
              final media = moviesData[index];
              return _TvFocusButton(
                onTap: () => launchPlayerDirect(media),
                borderRadius: BorderRadius.circular(8),
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
                            image: NetworkImage(
                              media['posterUrl'] != ''
                                  ? media['posterUrl']
                                  : 'https://via.placeholder.com/300x450/222222/888888',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white70,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        media['title'] ?? '',
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
          _TvFocusItem(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No new notifications", style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.notifications_active, color: Colors.white, size: 28),
            ),
          ),
          _TvFocusButton(
            onTap: _showSupportOptions,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.support_agent, color: Colors.red, size: 30),
            ),
          ),
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
                  child:
                      trendingList.isEmpty
                          ? Container(color: Colors.black)
                          : PageView.builder(
                            controller: _pageController,
                            itemCount:
                                trendingList.length > 5
                                    ? 5
                                    : trendingList.length,
                            onPageChanged: (index) => _currentPage = index,
                            itemBuilder: (context, index) {
                              return Container(
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      trendingList[index]['backdropUrl'] != ''
                                          ? trendingList[index]['backdropUrl']
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
                      colors: [
                        const Color(0xFF0F0F0F),
                        Colors.transparent,
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        // 🚀 ADDED: DUAL SEARCH BAR LOGIC
                        isSearching || isPixelflixSearch
                            ? Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(25),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // 🚀 GLASS BLUR
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(25),
                                        border: Border.all(color: Colors.redAccent),
                                      ),
                                      child: TextField(
                                        controller: isPixelflixSearch ? pixelflixController : searchController,
                                        style: const TextStyle(color: Colors.white),
                                        autofocus: true,
                                        decoration: InputDecoration(
                                          hintText: isPixelflixSearch ? 'Search Pixelflix...' : 'Search HANNUTV...',
                                          hintStyle: const TextStyle(color: Colors.grey),
                                          border: InputBorder.none,
                                          prefixIcon: const Icon(
                                            Icons.search,
                                            color: Colors.redAccent,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                isSearching = false;
                                                isPixelflixSearch = false;
                                                searchController.clear();
                                                pixelflixController.clear();
                                                searchResults.clear();
                                                pixelflixResults.clear();
                                              });
                                            },
                                          ),
                                        ),
                                        onChanged: isPixelflixSearch ? (v) {
                                          if (v.isEmpty) { setState(() { pixelflixResults = []; }); return; }
                                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                                          _debounce = Timer(const Duration(milliseconds: 500), () => _searchPixelflix(v));
                                        } : onSearchChanged,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Image.asset(
                                    'assets/logo.png',
                                    height: 35,
                                    errorBuilder:
                                        (_, __, ___) => const Text(
                                          'HANNUTV',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                        if (!isSearching && !isPixelflixSearch)
                          Row(
                            children: [
                              _TvFocusButton(
                                onTap: () => setState(() => isPixelflixSearch = true),
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.explore, color: Colors.blueAccent, size: 26), // 🚀 PIXELFLIX SEARCH ICON
                                ),
                              ),
                              _TvFocusButton(
                                onTap: () => setState(() => isSearching = true),
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.search, color: Colors.white, size: 28),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                if (trendingList.isNotEmpty && !isSearching && !isPixelflixSearch)
                  Positioned(
                    bottom: 20,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trendingList[_currentPage]['title'] ?? 'Title',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        _TvFocusButton(
                          onTap: () => launchPlayerDirect(trendingList[_currentPage]),
                          borderRadius: BorderRadius.circular(8),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 24,
                              ),
                            ),
                            onPressed:
                                () => launchPlayerDirect(
                                  trendingList[_currentPage],
                                ),
                            icon: const Icon(Icons.play_arrow, size: 24),
                            label: const Text(
                              'Play Now',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Text(
                'Watch on OTT & Channels',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: ottPlatforms.length,
                itemBuilder: (context, index) {
                  final srv = ottPlatforms[index];
                  final isSelected = selectedPlatform == srv['providerId'];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: _TvFocusButton(
                      onTap: () {
                        searchController.clear();
                        setState(() => isSearching = false);
                        loadAllDashboards(providerId: srv['providerId']);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isSelected ? Colors.redAccent : Colors.grey[900],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(color: srv['color'], width: 1.5),
                        ),
                        onPressed: () {
                          searchController.clear();
                          setState(() => isSearching = false);
                          loadAllDashboards(providerId: srv['providerId']);
                        },
                        child: Text(
                          srv['name'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : srv['color'],
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Colors.red),
                ),
              )
            else if (isSearching || isPixelflixSearch)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: isPixelflixSearch ? pixelflixResults.length : searchResults.length,
                itemBuilder: (context, index) {
                  final movie = isPixelflixSearch ? pixelflixResults[index] : searchResults[index];
                  return _TvFocusButton(
                    onTap: () => launchPlayerDirect(movie),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: NetworkImage(
                                  movie['posterUrl'] != ''
                                      ? movie['posterUrl']
                                      : 'https://via.placeholder.com/300x450/222222/888888',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          movie['title'] ?? '',
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
                  );
                },
              )
            else ...[
              _buildHorizontalList('🔥 HANNUTV Trending', trendingList),
              if (continueWatchingList.isNotEmpty)
                _buildHorizontalList(
                  'Continue Watching',
                  continueWatchingList,
                ),
              _buildHorizontalList('Bollywood Hindi Movies', bollywoodList),
              _buildHorizontalList('Hollywood English Movies', hollywoodList),
              _buildHorizontalList('Anime Hub ⛩️', animeList),
              _buildHorizontalList('Action Movies', actionList),
              _buildHorizontalList('Comedy Shows', comedyList),
              _buildHorizontalList('Horror Movies', horrorList),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _TvFocusItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TvFocusItem({Key? key, required this.child, required this.onTap}) : super(key: key);

  @override
  State<_TvFocusItem> createState() => _TvFocusItemState();
}

class _TvFocusItemState extends State<_TvFocusItem> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (mounted) {
          setState(() => _hasFocus = hasFocus);
        }
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hasFocus ? Colors.redAccent : Colors.transparent, 
              width: _hasFocus ? 4 : 0
            ),
            boxShadow: _hasFocus ? [BoxShadow(color: Colors.redAccent.withOpacity(0.6), blurRadius: 10)] : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _TvFocusButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _TvFocusButton({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_TvFocusButton> createState() => _TvFocusButtonState();
}

class _TvFocusButtonState extends State<_TvFocusButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (mounted) setState(() => _hasFocus = hasFocus);
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: widget.borderRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: _hasFocus ? Colors.redAccent : Colors.transparent,
              width: _hasFocus ? 3.5 : 0,
            ),
            boxShadow:
                _hasFocus
                    ? [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.65),
                        blurRadius: 10,
                        spreadRadius: 1.5,
                      ),
                    ]
                    : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}