import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
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
  List netmirrorLiveFeed = [];
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

  final List<Map<String, dynamic>> ottPlatforms = [
    {"name": "🔥 HANNUTV LIVE", "color": Colors.red, "providerId": "hannutv"},
    {"name": "NETFLIX", "color": Colors.redAccent, "providerId": "8"},
    {"name": "PRIME", "color": Colors.blueAccent, "providerId": "119"},
    {"name": "HOTSTAR", "color": Colors.green, "providerId": "122"},
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
              'mediaType': forceMediaType ?? (m['media_type'] ?? 'movie'),
            })
        .toList();
  }

  Future<void> loadAllDashboards({String? providerId}) async {
    setState(() => isLoading = true);
    try {
      String base = 'https://api.themoviedb.org/3';
      String prov = (providerId != null && providerId != 'hannutv')
          ? '&with_watch_providers=$providerId&watch_region=IN'
          : '';

      String trendUrl = (providerId != null && providerId != 'hannutv')
          ? '$base/discover/tv?language=en-US&sort_by=popularity.desc$prov'
          : '$base/trending/all/day?language=en-US';

      var responses = await Future.wait([
        http.get(Uri.parse(trendUrl), headers: kApiHeaders),
        http.get(Uri.parse('$base/trending/all/week?language=en-US'), headers: kApiHeaders),
        http.get(Uri.parse('$base/discover/movie?language=en-US&with_genres=28$prov&sort_by=popularity.desc'), headers: kApiHeaders),
        http.get(Uri.parse('$base/discover/tv?language=en-US&with_genres=35$prov&sort_by=popularity.desc'), headers: kApiHeaders),
        http.get(Uri.parse('$base/discover/movie?language=en-US&with_genres=27$prov&sort_by=popularity.desc'), headers: kApiHeaders),
        http.get(Uri.parse('$base/discover/tv?language=en-US&with_genres=18$prov&sort_by=popularity.desc'), headers: kApiHeaders),
      ]);

      setState(() {
        trendingList = parseData(responses[0], forceMediaType: (providerId != null && providerId != 'hannutv') ? 'tv' : null);
        netmirrorLiveFeed = parseData(responses[1]);
        actionList = parseData(responses[2], forceMediaType: 'movie');
        comedyList = parseData(responses[3], forceMediaType: 'tv');
        horrorList = parseData(responses[4], forceMediaType: 'movie');
        dramaList = parseData(responses[5], forceMediaType: 'tv');
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
      final url = 'https://api.themoviedb.org/3/search/multi?query=${Uri.encodeComponent(value)}&language=en-US&include_adult=false';
      final res = await http.get(Uri.parse(url), headers: kApiHeaders);
      setState(() {
        searchResults = parseData(res);
        isLoading = false;
      });
    });
  }

  Future<void> _openTelegram() async {
    if (!await launchUrl(Uri.parse('https://t.me/HANNUTV'),
        mode: LaunchMode.externalApplication)) {
      debugPrint('Telegram error');
    }
  }

  void openMediaDetails(Map media) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MediaDetailScreen(mediaItem: media)),
    ).then((_) => setState(() {}));
  }

  // 🚀 DIRECT NETMIRROR LIVE SEARCH PORTAL (The Bypass)
  void _openLiveNetMirrorSearch(String query) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NetMirrorWebPortal(searchQuery: query),
      ),
    );
  }

  void _showLiveSearchDialog() {
    TextEditingController liveSearchController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("⚡ HANNUTV Live Search", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: liveSearchController,
            style: const TextStyle(color: Colors.white),
            autofocus: true,
            decoration: const InputDecoration(hintText: "Directly search inside NetMirror...", hintStyle: TextStyle(color: Colors.grey)),
            onSubmitted: (val) {
              Navigator.pop(context);
              if (val.isNotEmpty) _openLiveNetMirrorSearch(val);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                if (liveSearchController.text.isNotEmpty) _openLiveNetMirrorSearch(liveSearchController.text);
              },
              child: const Text("Search", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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
                                      hintText: 'Search TMDB Database...',
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
                          // ⚡ LIVE NETMIRROR DIRECT SEARCH BUTTON
                          IconButton(
                            icon: const Icon(Icons.flash_on, color: Colors.redAccent, size: 28),
                            tooltip: "Live NetMirror Search",
                            onPressed: _showLiveSearchDialog, 
                          ),
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
                          onPressed: () => openMediaDetails(trendingList[_currentPage]),
                          icon: const Icon(Icons.play_arrow, size: 24),
                          label: const Text('Play Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  )
              ],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Text('Watch on OTT & Channels', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                    onTap: () => openMediaDetails(movie),
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
              _buildHorizontalList('🔥 HANNUTV (NetMirror Official)', netmirrorLiveFeed),
              _buildHorizontalList('Trending Now', trendingList),
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
          if ((mediaType == 'tv' || mediaType == 'series') && details!['seasons'] != null && (details!['seasons'] as List).isNotEmpty) {
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
    setState(() {
      isLoadingEpisodes = true;
      selectedSeason = seasonNumber;
    });
    try {
      final response = await http.get(Uri.parse('https://api.themoviedb.org/3/tv/${widget.mediaItem['id']}/season/$seasonNumber?language=en-US'), headers: kApiHeaders);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          episodes = (data['episodes'] as List? ?? []).map((ep) => {'episodeNumber': ep['episode_number'], 'name': ep['name'], 'overview': ep['overview'], 'stillUrl': ep['still_path'] != null ? 'https://image.tmdb.org/t/p/w500${ep['still_path']}' : ''}).toList();
          isLoadingEpisodes = false;
        });
      } else {
        setState(() => isLoadingEpisodes = false);
      }
    } catch (e) {
      setState(() => isLoadingEpisodes = false);
    }
  }

  void _showServerSelectionAndPlay(String title, {int? season, int? episode}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Server to Play", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.flash_on, color: Colors.redAccent, size: 30),
                title: const Text("HANNUTV VIP (NetMirror)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Official API Direct Stream (No 404 Error)", style: TextStyle(color: Colors.grey)),
                onTap: () {
                  Navigator.pop(context);
                  _launchPlayerFinal(title, 'netmirror_vip', season: season, episode: episode);
                },
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.high_quality, color: Colors.orangeAccent, size: 30),
                title: const Text("VidBolt Ultra HD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("1080p Hindi Fast Server", style: TextStyle(color: Colors.grey)),
                onTap: () {
                  Navigator.pop(context);
                  _launchPlayerFinal(title, 'vidbolt', season: season, episode: episode);
                },
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.speed, color: Colors.purpleAccent, size: 30),
                title: const Text("Olly Embed VIP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Fast HLS Hindi Stream", style: TextStyle(color: Colors.grey)),
                onTap: () {
                  Navigator.pop(context);
                  _launchPlayerFinal(title, 'olly', season: season, episode: episode);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _launchPlayerFinal(String title, String serverKey, {int? season, int? episode}) {
    continueWatchingList.removeWhere((m) => m['id'] == widget.mediaItem['id']);
    Map currentMedia = Map.from(widget.mediaItem);
    final type = widget.mediaItem['mediaType'] ?? 'movie';
    if (type == 'tv' || type == 'series') {
      currentMedia['savedSeason'] = season ?? 1;
      currentMedia['savedEpisode'] = episode ?? 1;
    }
    continueWatchingList.insert(0, currentMedia);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          tmdbId: widget.mediaItem['id'] is int ? widget.mediaItem['id'] : int.tryParse(widget.mediaItem['id'].toString()) ?? 0,
          mediaType: type,
          season: season ?? 1,
          episode: episode ?? 1,
          movieTitle: title,
          preferredServer: serverKey, 
        ),
      ),
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
                    decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(details != null && details!['backdropUrl'] != '' ? details!['backdropUrl'] : (widget.mediaItem['backdropUrl'] ?? '')), fit: BoxFit.cover)),
                    child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF0F0F0F), Colors.transparent]))),
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
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14)),
                                  onPressed: () => _showServerSelectionAndPlay(details?['title'] ?? 'Movie'),
                                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                                  label: const Text('Select Server & Play', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ] else if ((mediaType == 'tv' || mediaType == 'series') && details?['seasons'] != null && (details!['seasons'] as List).isNotEmpty) ...[
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
                              onChanged: (int? newValue) {
                                if (newValue != null) fetchEpisodes(newValue);
                              },
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
                                      leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(ep['stillUrl'] != '' ? ep['stillUrl'] : 'https://via.placeholder.com/300x168/222222/888888?text=EP', width: 110, height: 70, fit: BoxFit.cover)),
                                      title: Text('${ep['episodeNumber']}. ${ep['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      subtitle: Text(ep['overview'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                                        onPressed: () => _showServerSelectionAndPlay('S${selectedSeason}E${ep['episodeNumber']} - ${ep['name']}', season: selectedSeason, episode: ep['episodeNumber']),
                                      ),
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

// 🌐 NETMIRROR DIRECT LIVE PORTAL WIDGET (The Deep Bypass)
class NetMirrorWebPortal extends StatefulWidget {
  final String? searchQuery;
  const NetMirrorWebPortal({Key? key, this.searchQuery}) : super(key: key);
  @override
  State<NetMirrorWebPortal> createState() => _NetMirrorWebPortalState();
}

class _NetMirrorWebPortalState extends State<NetMirrorWebPortal> {
  late WebViewController _portalController;
  bool isPageLoading = true;

  @override
  void initState() {
    super.initState();
    String targetUrl = widget.searchQuery != null 
        ? 'https://netmirror.center/search?keyword=${Uri.encodeComponent(widget.searchQuery!)}'
        : 'https://netmirror.center/';

    _portalController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => isPageLoading = false);
            // 🛡️ Remove NetMirror Ads & Logos
            _portalController.runJavaScript('''
              setInterval(function() {
                document.querySelectorAll('iframe[src*="ads"], div[class*="ad"], .logo, header').forEach(el => el.style.display = 'none');
              }, 500);
            ''');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            if (url.contains('adsterra') || url.contains('popads') || url.contains('bet365')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(targetUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("NetMirror Official Feed", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _portalController),
          if (isPageLoading) const Center(child: CircularProgressIndicator(color: Colors.red)),
        ],
      ),
    );
  }
}