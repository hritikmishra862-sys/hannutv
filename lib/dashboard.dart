import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'video_player_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);
  @override
  DashboardPageState createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  List movies = [];
  bool isLoading = true;
  bool isSearching = false;
  TextEditingController searchController = TextEditingController();

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
  }

  Future<void> fetchTmdbData(String query) async {
    setState(() { isLoading = true; });
    try {
      final String url = query.isEmpty 
          ? 'http://localhost:3000/api/trending' 
          : 'http://localhost:3000/api/search?q=${Uri.encodeComponent(query)}';
          
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          movies = responseData['data'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() { isLoading = false; });
      }
    } catch (e) {
      setState(() { isLoading = false; });
    }
  }

  // Telegram Support Function
  Future<void> _openTelegram() async {
    final Uri url = Uri.parse('https://t.me/YOUR_USERNAME'); // Apna Telegram username daal
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not open Telegram');
    }
  }

  void openMediaDetails(Map media) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => MediaDetailScreen(mediaItem: media)));
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
            onPressed: _openTelegram, // Telegram Button
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top App Updated Banner
            Container(
              width: double.infinity,
              color: Colors.green.withOpacity(0.2),
              padding: const EdgeInsets.only(top: 40, bottom: 8, left: 16, right: 16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Text("App Updated to v1.0 (Latest)", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            // Hero Banner
            Stack(
              children: [
                Container(
                  height: 400,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(
                        movies.isNotEmpty && movies[0]['backdropUrl'] != '' 
                            ? movies[0]['backdropUrl'] 
                            : 'https://images.unsplash.com/photo-1616530940355-351fabd9524b?q=80&w=600'
                      ),
                      fit: BoxFit.cover,
                    ),
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
                              onSubmitted: (value) => fetchTmdbData(value),
                            ),
                          )
                        : Expanded(
                            // Yahan ONYXTUBE ki jagah HANNUTV ka logo laga diya
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
                if (movies.isNotEmpty)
                  Positioned(
                    bottom: 20, left: 16, right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movies[0]['title'] ?? 'Title', 
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 6),
                            Text('${movies[0]['rating']}  •  ${movies[0]['year']}  •  ${movies[0]['type'].toString().toUpperCase()}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white, foregroundColor: Colors.black, 
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          ),
                          onPressed: () => openMediaDetails(movies[0]),
                          icon: const Icon(Icons.play_arrow, size: 28),
                          label: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  )
              ],
            ),
            
            // OTT Platforms Section
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
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opening ${ottPlatforms[index]['name']} Catalog...')));
                      },
                      child: Text(ottPlatforms[index]['name'], style: TextStyle(color: ottPlatforms[index]['color'], fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  );
                },
              ),
            ),

            // Categories
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
                      onPressed: () => fetchTmdbData(categories[index]),
                    ),
                  );
                },
              ),
            ),
            
            // Trending Grid
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 10.0),
              child: Text(
                searchController.text.isEmpty ? 'Trending Now' : 'Search Results', 
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
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
                                  image: NetworkImage(movie['posterUrl'] != '' ? movie['posterUrl'] : 'https://via.placeholder.com/300x450/222222/888888?text=NO+POSTER'),
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

// Ye Details Screen hai jahan Download aur Play ka option aayega
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
    final mediaType = widget.mediaItem['mediaType'];
    final id = widget.mediaItem['id'];
    
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/api/details/$mediaType/$id'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        setState(() {
          details = data;
          isLoadingDetails = false;
          if (mediaType == 'tv' && data['seasons'] != null && data['seasons'].isNotEmpty) {
            selectedSeason = data['seasons'][0]['seasonNumber'];
            fetchEpisodes(selectedSeason!);
          }
        });
      }
    } catch (e) {
      setState(() { isLoadingDetails = false; });
    }
  }

  Future<void> fetchEpisodes(int seasonNumber) async {
    setState(() { isLoadingEpisodes = true; selectedSeason = seasonNumber; });
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/api/season/${widget.mediaItem['id']}/$seasonNumber'));
      if (response.statusCode == 200) {
        setState(() {
          episodes = json.decode(response.body)['data'] ?? [];
          isLoadingEpisodes = false;
        });
      }
    } catch (e) {
      setState(() { isLoadingEpisodes = false; });
    }
  }

  // Play Video Function
  void launchPlayer(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          videoUrl: 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
          movieTitle: title,
        ),
      ),
    );
  }

  // Download Options Dialog
  void _showDownloadPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Download Quality", 
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.red),
                title: const Text("1080p (Full HD)", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Downloading in 1080p...")));
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.white70),
                title: const Text("720p (HD)", style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.white70),
                title: const Text("480p (SD)", style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaType = widget.mediaItem['mediaType'];

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
                      image: NetworkImage(details!['backdropUrl'] != '' ? details!['backdropUrl'] : widget.mediaItem['backdropUrl']),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        colors: [const Color(0xFF0F0F0F), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(details!['title'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(details!['overview'], style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 20),
                      
                      if (mediaType == 'movie') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14)),
                                onPressed: () => launchPlayer(details!['title']),
                                icon: const Icon(Icons.play_arrow, color: Colors.white),
                                label: const Text('Play Movie', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], padding: const EdgeInsets.symmetric(vertical: 14)),
                                onPressed: () => _showDownloadPopup(context), // Download Button
                                icon: const Icon(Icons.download, color: Colors.white),
                                label: const Text('Download', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ] else if (mediaType == 'tv' && details!['seasons'] != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
                          child: DropdownButton<int>(
                            value: selectedSeason,
                            isExpanded: true,
                            underline: const SizedBox(),
                            dropdownColor: Colors.grey[900],
                            items: (details!['seasons'] as List).map<DropdownMenuItem<int>>((season) {
                              return DropdownMenuItem<int>(
                                value: season['seasonNumber'],
                                child: Text('Season ${season['seasonNumber']}  (${season['episodeCount']} Episodes)', style: const TextStyle(color: Colors.white)),
                              );
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
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      ep['stillUrl'] != '' ? ep['stillUrl'] : 'https://via.placeholder.com/150x84/222222/888888?text=EP',
                                      width: 120, height: 80, fit: BoxFit.cover,
                                    ),
                                  ),
                                  title: Text('${ep['episodeNumber']}. ${ep['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(ep['overview'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.download, color: Colors.grey, size: 28),
                                        onPressed: () => _showDownloadPopup(context), // Episode Download Button
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
                                        onPressed: () => launchPlayer('S${selectedSeason}E${ep['episodeNumber']} - ${ep['name']}'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                      ]
                    ],
                  ),
                )
              ],
            ),
          ),
    );
  }
}