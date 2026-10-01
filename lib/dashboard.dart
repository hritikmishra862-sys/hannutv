import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
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

  bool isLoading = true;
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();

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

      String prov = (providerId != null && providerId != 'all')
          ? '&with_watch_providers=$providerId&watch_region=US'
          : '';

      String animeFilter = (providerId == '283') ? '&with_genres=16' : '';

      String trendUrl = (providerId != null && providerId != 'all')
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
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("HANNUTV Support",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  if (!await launchUrl(Uri.parse('https://t.me/HANNUTV'),
                      mode: LaunchMode.externalApplication)) {}
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.send,
                          color: Colors.blueAccent, size: 30),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Request for New Movie",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text("Join Telegram",
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12)),
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
                  if (!await launchUrl(
                      Uri.parse(
                          'https://whatsapp.com/channel/0029VbE2Pb17z4kmfjF04P0v'),
                      mode: LaunchMode.externalApplication)) {}
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.chat,
                          color: Colors.greenAccent, size: 30),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("New Movie Updates",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text("Join WhatsApp Channel",
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text("App Version: v1.0.0",
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🚀 REPLACED launchPlayerDirect WITH MODAL SELECTOR 🚀
  void launchPlayerDirect(Map media) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ServerSelectionModal(
        media: media,
        onSelect: (bool isServer2) {
          continueWatchingList.removeWhere((m) => m['id'] == media['id']);
          continueWatchingList.insert(0, media);

          final type = media['mediaType'] ?? 'movie';
          final tId = media['id'] is int
              ? media['id']
              : int.tryParse(media['id'].toString()) ?? 0;

          int currentAdDuration = _isNextAd10Sec ? 10 : 30;
          _isNextAd10Sec = !_isNextAd10Sec;

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
                  isPixelflix: isServer2, // Pass flag to player
                ),
              ),
            ),
          ).then((_) => setState(() {}));
        },
      ),
    );
  }

  Widget _buildFocusableItem(
      {required Widget child, required VoidCallback onTap}) {
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
                const SnackBar(
                    content: Text("No new notifications",
                        style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.redAccent),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.notifications_active,
                  color: Colors.white, size: 28),
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
                  child: trendingList.isEmpty
                      ? Container(color: Colors.black)
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: trendingList.length > 5
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
                        isSearching
                            ? Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
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
                                      hintText:
                                          'Search Movies & Shows on HANNUTV...',
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
                                  child: Image.asset(
                                    'assets/logo.png',
                                    height: 35,
                                    errorBuilder: (_, __, ___) => const Text(
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
                        if (!isSearching)
                          _TvFocusButton(
                            onTap: () => setState(() => isSearching = true),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.search,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (trendingList.isNotEmpty && !isSearching)
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
                          onTap: () =>
                              launchPlayerDirect(trendingList[_currentPage]),
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
                            onPressed: () => launchPlayerDirect(
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
                          backgroundColor: isSelected
                              ? Colors.redAccent
                              : Colors.grey[900],
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
            else if (isSearching)
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
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final movie = searchResults[index];
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

  const _TvFocusItem({Key? key, required this.child, required this.onTap})
      : super(key: key);

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
                width: _hasFocus ? 4 : 0),
            boxShadow: _hasFocus
                ? [BoxShadow(color: Colors.redAccent.withOpacity(0.6), blurRadius: 10)]
                : [],
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
            boxShadow: _hasFocus
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

// 🚀 SERVER ANALYZER MODAL (Green / Red Status for Pixelflix & Pantyflix) 🚀
class _ServerSelectionModal extends StatefulWidget {
  final Map media;
  final Function(bool) onSelect;
  const _ServerSelectionModal({required this.media, required this.onSelect});

  @override
  State<_ServerSelectionModal> createState() => _ServerSelectionModalState();
}

class _ServerSelectionModalState extends State<_ServerSelectionModal> {
  bool isLoading1 = true;
  bool isAvailable1 = false;
  bool isLoading2 = true;
  bool isAvailable2 = false;

  @override
  void initState() {
    super.initState();
    _checkServers();
  }

  Future<void> _checkServers() async {
    final type = widget.media['mediaType'] ?? 'movie';
    final id = widget.media['id'];

    // Server 1 (Pantyflix)
    final url1 = type == 'tv'
        ? 'https://pantyflix.com/watch/play/tv/$id?season=1&episode=1&server=vidrift'
        : 'https://pantyflix.com/watch/play/movie/$id?server=vidrift';
    // Server 2 (Pixelflix)
    final url2 = type == 'tv'
        ? 'https://pixelflix.cc/watch/tv/$id?season=1&episode=1'
        : 'https://pixelflix.cc/watch/movie/$id';

    // Ping Server 1
    try {
      final res1 =
          await http.head(Uri.parse(url1)).timeout(const Duration(seconds: 4));
      if (mounted) {
        setState(() {
          isAvailable1 = (res1.statusCode == 200 ||
              res1.statusCode == 403 ||
              res1.statusCode == 302);
          isLoading1 = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        isAvailable1 = false;
        isLoading1 = false;
      });
    }

    // Ping Server 2
    try {
      final res2 =
          await http.head(Uri.parse(url2)).timeout(const Duration(seconds: 4));
      if (mounted) {
        setState(() {
          isAvailable2 = (res2.statusCode == 200 ||
              res2.statusCode == 403 ||
              res2.statusCode == 302);
          isLoading2 = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        isAvailable2 = false;
        isLoading2 = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              border: Border(
                  top: BorderSide(
                      color: Colors.redAccent.withOpacity(0.5), width: 2))),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10)),
                      margin: const EdgeInsets.only(bottom: 20))),
              Row(
                children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(widget.media['posterUrl'] ?? '',
                          width: 60,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.movie,
                              color: Colors.grey))),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text("Watch ${widget.media['title']}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        const Text("Deep Analyzing Servers...",
                            style: TextStyle(color: Colors.grey, fontSize: 12))
                      ])),
                ],
              ),
              const SizedBox(height: 24),
              // Server 1 Button (Pantyflix)
              _buildServerBtn(
                  title: "HANNUTV 1",
                  subtitle: "Cinema HD Node",
                  isLoading: isLoading1,
                  isAvailable: isAvailable1,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSelect(false);
                  }),
              const SizedBox(height: 12),
              // Server 2 Button (Pixelflix)
              _buildServerBtn(
                  title: "HANNUTV 2",
                  subtitle: "Ultra HD Cloud",
                  isLoading: isLoading2,
                  isAvailable: isAvailable2,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSelect(true);
                  }),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerBtn(
      {required String title,
      required String subtitle,
      required bool isLoading,
      required bool isAvailable,
      required VoidCallback onTap}) {
    Color statusColor = isLoading
        ? Colors.amber
        : (isAvailable ? Colors.greenAccent : Colors.redAccent);
    String statusText =
        isLoading ? "Checking..." : (isAvailable ? "Online" : "Offline");
    return InkWell(
      onTap: onTap, // Let user click even if offline
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: statusColor.withOpacity(0.5), width: 1.5)),
        child: Row(
          children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(Icons.dns_rounded, color: statusColor, size: 20)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12))
                ])),
            if (isLoading)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.amber, strokeWidth: 2))
            else
              Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: statusColor, blurRadius: 6)
                        ])),
                const SizedBox(width: 8),
                Text(statusText,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12))
              ]),
          ],
        ),
      ),
    );
  }
}