import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'videoplayerpage.dart';
import 'skippable_ad_screen.dart';

const String kTmdbToken =
    'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIzZDJkOTExNmM5ZGU3MjA5ZWUyNzdiYjhjYzlhZWVkOCIsIm5iZiI6MTc5MDI2OTE4NC42MjksInN1YiI6IjZhYjU1NzAwNzZiMTg1ODU3MGFjNDM4NSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.xZJX8fowhVhVJsgl-5wOW6Y7ZfUr9Zu_Ey1qMkhnPd0';

const Map<String, String> kApiHeaders = {
  'Authorization': 'Bearer $kTmdbToken',
  'accept': 'application/json',
};

List<Map<String, dynamic>> continueWatchingList = [];

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  bool isNextAd10Sec = true;

  List<Map<String, dynamic>> trendingList = [];
  List<Map<String, dynamic>> bollywoodList = [];
  List<Map<String, dynamic>> hollywoodList = [];
  List<Map<String, dynamic>> animeList = [];
  List<Map<String, dynamic>> actionList = [];
  List<Map<String, dynamic>> comedyList = [];
  List<Map<String, dynamic>> horrorList = [];
  List<Map<String, dynamic>> searchResults = [];

  bool isLoading = true;
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();
  Timer? debounce;

  final PageController pageController = PageController();
  Timer? carouselTimer;
  int currentPage = 0;

  String selectedPlatform = 'all';

  final List<Map<String, dynamic>> ottPlatforms = const [
    {'name': 'HANNUTV VIP', 'color': Colors.red, 'providerId': 'all'},
    {'name': 'NETFLIX', 'color': Colors.redAccent, 'providerId': '8'},
    {'name': 'PRIME VIDEO', 'color': Colors.blueAccent, 'providerId': '9'},
    {'name': 'APPLE TV', 'color': Colors.white70, 'providerId': '350'},
    {'name': 'CRUNCHYROLL', 'color': Colors.orangeAccent, 'providerId': '283'},
    {'name': 'DISNEY', 'color': Colors.lightBlueAccent, 'providerId': '337'},
    {'name': 'HULU', 'color': Colors.greenAccent, 'providerId': '15'},
    {'name': 'HBO MAX', 'color': Colors.deepPurpleAccent, 'providerId': '1899'},
  ];

  @override
  void initState() {
    super.initState();
    loadAllDashboards();
    startCarousel();
  }

  void startCarousel() {
    carouselTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (pageController.hasClients && trendingList.isNotEmpty) {
        int next = currentPage + 1;
        if (next >= (trendingList.length > 5 ? 5 : trendingList.length)) {
          next = 0;
        }
        pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    carouselTimer?.cancel();
    pageController.dispose();
    searchController.dispose();
    debounce?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> parseData(http.Response response, {String? forceMediaType}) {
    if (response.statusCode != 200) return [];
    final List rawData = json.decode(response.body)['results'] ?? [];
    return rawData.where((m) => m['media_type'] != 'person').map((m) {
      return {
        'id': m['id'],
        'title': m['title'] ?? m['name'] ?? 'Unknown',
        'overview': m['overview'] ?? '',
        'posterUrl': m['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${m['poster_path']}' : '',
        'backdropUrl': m['backdrop_path'] != null ? 'https://image.tmdb.org/t/p/original${m['backdrop_path']}' : '',
        'rating': (m['vote_average'] ?? 0.0).toStringAsFixed(1),
        'year': (m['release_date'] ?? m['first_air_date'] ?? '').toString().split('-').first,
        'mediaType': forceMediaType ?? m['media_type'] ?? 'movie',
      };
    }).toList();
  }

  Future<void> loadAllDashboards([String? providerId]) async {
    setState(() {
      isLoading = true;
      selectedPlatform = providerId ?? 'all';
    });

    try {
      String base = 'https://api.themoviedb.org/3';
      String prov = (providerId != null && providerId != 'all') ? '&with_watch_providers=$providerId&watch_region=US' : '';

      var responses = await Future.wait([
        http.get(Uri.parse('$base/trending/all/day?language=en-US$prov'), headers: kApiHeaders),
        http.get(Uri.parse('$base/discover/movie?language=hi-IN&with_original_language=hi&sort_by=popularity.desc$prov'), headers: kApiHeaders),
        http.get(Uri.parse('$base/discover/movie?language=en-US&with_original_language=en&sort_by=popularity.desc$prov'), headers: kApiHeaders),
        http.get(Uri.parse('$base/discover/tv?language=en-US&with_genres=16&sort_by=popularity.desc$prov'), headers: kApiHeaders),
        http.get(Uri.parse('$base/discover/movie?language=en-US&with_genres=28&sort_by=popularity.desc$prov'), headers: kApiHeaders),
        http.get(Uri.parse('$base/discover/tv?language=en-US&with_genres=35&sort_by=popularity.desc$prov'), headers: kApiHeaders),
        http.get(Uri.parse('$base/discover/movie?language=en-US&with_genres=27&sort_by=popularity.desc$prov'), headers: kApiHeaders),
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

    if (debounce?.isActive ?? false) debounce!.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () async {
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

  void showSupportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('HANNUTV Support & Community', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  launchUrl(Uri.parse('https://t.me/HANNUTV'), mode: LaunchMode.externalApplication);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Icon(Icons.send, color: Colors.blueAccent, size: 28),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Request Movie & Series', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          Text('Join Official Telegram', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                  launchUrl(Uri.parse('https://whatsapp.com/channel/0029VbE2Pb17z4kmfjF04P0v'), mode: LaunchMode.externalApplication);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: Colors.greenAccent, size: 28),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Direct Streaming Updates', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          Text('Join WhatsApp Channel', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void launchPlayerDirect(Map<String, dynamic> media) {
    continueWatchingList.removeWhere((m) => m['id'] == media['id']);
    continueWatchingList.insert(0, media);

    final type = media['mediaType'] ?? 'movie';
    final tId = media['id'] is int ? media['id'] : int.tryParse(media['id'].toString()) ?? 0;
    int currentAdDuration = isNextAd10Sec ? 10 : 30;
    isNextAd10Sec = !isNextAd10Sec;

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
          ),
        ),
      ),
    ).then((_) => setState(() {}));
  }

  Widget buildHorizontalList(String title, List<Map<String, dynamic>> moviesData) {
    if (moviesData.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: moviesData.length,
            itemBuilder: (context, index) {
              final media = moviesData[index];
              return InkWell(
                onTap: () => launchPlayerDirect(media),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 145,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(
                              (media['posterUrl'] != null && media['posterUrl'] != '')
                                  ? media['posterUrl']
                                  : 'https://via.placeholder.com/300x450/222222/888888',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 10),
                                    const SizedBox(width: 4),
                                    Text(media['rating'] ?? '8.0',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        media['title'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF0F0F0F),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset('assets/logo.png', height: 28, errorBuilder: (_, __, ___) => const Icon(Icons.movie, color: Colors.red)),
                          const SizedBox(width: 8),
                          const Text('HANNUTV',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () => setState(() => isSearching = true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.headset_mic, color: Colors.redAccent),
                            onPressed: showSupportOptions,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isSearching)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          controller: searchController,
                          style: const TextStyle(color: Colors.white),
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search Movies, Shows, Anime...',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
                    if (!isSearching) ...[
                      Stack(
                        children: [
                          SizedBox(
                            height: 250,
                            child: trendingList.isEmpty
                                ? Container(color: Colors.black26)
                                : PageView.builder(
                                    controller: pageController,
                                    itemCount: trendingList.length > 5 ? 5 : trendingList.length,
                                    onPageChanged: (index) {
                                      setState(() {
                                        currentPage = index;
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image: NetworkImage(
                                              (trendingList[index]['backdropUrl'] != null && trendingList[index]['backdropUrl'] != '')
                                                  ? trendingList[index]['backdropUrl']
                                                  : 'https://images.unsplash.com/photo-1616530940355-351fabd9524b?q=80&w=600',
                                            ),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [const Color(0xFF0F0F0F), Colors.black.withOpacity(0.4), Colors.transparent],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          if (trendingList.isNotEmpty)
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                        child: const Text('EXCLUSIVE',
                                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.star, color: Colors.amber, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        trendingList[currentPage]['rating'] ?? '8.5',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    trendingList[currentPage]['title'] ?? 'Title',
                                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () => launchPlayerDirect(trendingList[currentPage]),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.play_arrow, color: Colors.black, size: 18),
                                          SizedBox(width: 6),
                                          Text('Play Now',
                                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
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
                        child: Text('Watch on OTT Channels',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: ottPlatforms.length,
                          itemBuilder: (context, index) {
                            final srv = ottPlatforms[index];
                            final isSelected = selectedPlatform == srv['providerId'];
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () {
                                  searchController.clear();
                                  setState(() => isSearching = false);
                                  loadAllDashboards(srv['providerId']);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.redAccent : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: srv['color'], width: 1.5),
                                  ),
                                  child: Center(
                                    child: Text(
                                      srv['name'],
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : srv['color'],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final movie = searchResults[index];
                          return InkWell(
                            onTap: () => launchPlayerDirect(movie),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: NetworkImage(
                                          (movie['posterUrl'] != null && movie['posterUrl'] != '')
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
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    else ...[
                      if (continueWatchingList.isNotEmpty) buildHorizontalList('Continue Watching', continueWatchingList),
                      buildHorizontalList('HANNUTV Trending', trendingList),
                      buildHorizontalList('Bollywood Hindi Movies', bollywoodList),
                      buildHorizontalList('Hollywood English Movies', hollywoodList),
                      buildHorizontalList('Anime Hub', animeList),
                      buildHorizontalList('Action Movies', actionList),
                      buildHorizontalList('Comedy Shows', comedyList),
                      buildHorizontalList('Horror Movies', horrorList),
                    ],
                    const SizedBox(height: 40),
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