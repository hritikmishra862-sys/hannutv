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

  final TextEditingController commentInputController = TextEditingController();
  final List<Map<String, String>> publicComments = [
    {'name': 'SHEEL', 'text': 'HARE KRISHNA 🦚', 'time': '9d', 'avatar': 'S'},
    {'name': 'Rohit Sharma', 'text': 'Best quality on HANNUTV, loving this series! 🔥', 'time': '2d', 'avatar': 'R'},
  ];

  // 🚀 SERVERS LIST PRESERVED EXACTLY AS IT WAS 🚀
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

  String activeServer = 'vidrift';
  bool isLiked = false;
  int likeCount = 1248;
  int viewCount = 84920;
  bool showControls = true; 
  Timer? _hideControlsTimer;
  bool showIntroAnimation = false;
  late AnimationController _introAnimController;
  late Animation<double> _introScaleAnimation;
  late Animation<double> _introOpacityAnimation;
  bool isTvDevice = false;

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
    
    _initStream();
  }

  void _startControlsTimer() {
    _hideControlsTimer?.cancel();
    if (mounted) setState(() => showControls = true);
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => showControls = false);
    });
  }

  void _toggleControlPanel() {
    if (showControls) {
      setState(() => showControls = false);
      _hideControlsTimer?.cancel();
    } else {
      _startControlsTimer();
    }
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

  // 🚀 CLEAN EMBED LOGIC: Fixes Redirection, Sandbox & Adult Ads 🚀
  String _buildStreamUrl() {
    final id = widget.tmdbId;
    final s = currentSeason;
    final e = currentEpisode;
    final isTv = widget.mediaType == 'tv' || widget.mediaType == 'series';

    if (widget.isPixelflix) {
      return isTv ? 'https://vidsrc.pm/embed/tv?tmdb=$id&season=$s&episode=$e' : 'https://vidsrc.pm/embed/movie/$id';
    } 

    if (activeServer == 'fast') return isTv ? 'https://vidsrc.net/embed/tv?tmdb=$id&season=$s&episode=$e' : 'https://vidsrc.net/embed/movie/$id';
    if (activeServer == 'vidbolt') return isTv ? 'https://vidbolt.xyz/tv/$id/$s/$e' : 'https://vidbolt.xyz/movie/$id';
    if (activeServer == 'hindi-new' || activeServer == 'hindi') return isTv ? 'https://multiembed.mov/?video_id=$id&tmdb=1&s=$s&e=$e' : 'https://multiembed.mov/?video_id=$id&tmdb=1';
    if (activeServer == 'cinezo' || activeServer == 'orion') return isTv ? 'https://player.autoembed.cc/embed/tv/$id/$s/$e' : 'https://player.autoembed.cc/embed/movie/$id';
    
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

            // 🚀 AGGRESSIVE AD-BLOCKER JS 🚀
            String jsCode = '''
              const nukeAds = () => {
                  document.body.style.backgroundColor = '#000000';
                  document.documentElement.style.backgroundColor = '#000000';
                  
                  const badClasses = ['.ad', '.ads', '.popup', '#captcha', '.human-verify', '[id*="verify"]', '[class*="verify"]', 'iframe[src*="challenge"]', '.cf-turnstile', 'a[target="_blank"]'];
                  document.querySelectorAll(badClasses.join(',')).forEach(el => el.remove());
                  
                  document.body.style.pointerEvents = 'none';
                  
                  let video = document.querySelector('video') || document.querySelector('iframe');
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
              setInterval(nukeAds, 300);
            ''';
            _controller.runJavaScript(jsCode);
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            // 🚀 PREVENTS ALL REDIRECTS 🚀
            if (url.contains('vidsrc') || url.contains('vidlink') || url.contains('vidbolt') || url.contains('multiembed') || url.contains('autoembed') || url.contains('googleapis') || url.startsWith('data:')) {
                return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent; 
          },
        ),
      );

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

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
    _hideControlsTimer?.cancel();
    commentInputController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Widget _buildFocusableItem({
    required Widget child,
    required VoidCallback onTap,
    BorderRadius? borderRadius,
  }) {
    return _TvFocusButton(
      onTap: onTap,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _startControlsTimer,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 230,
                    color: Colors.black,
                    child: WebViewWidget(controller: _controller),
                  ),
                  Positioned(
                    top: 10,
                    right: 14,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.85,
                        child: Image.asset(
                          'assets/logo.png',
                          height: 34,
                          errorBuilder: (_, __, ___) => const Text('HANNUTV', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _buildFocusableItem(
                      onTap: _toggleControlPanel,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Opacity(
                          opacity: 0.9,
                          child: Image.asset(
                            'assets/logo.png',
                            height: 28,
                            errorBuilder: (_, __, ___) => const Text('HANNUTV', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showControls) ...[
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(color: Colors.black38),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _buildFocusableItem(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(18),
                        child: const CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 18,
                          child: Icon(Icons.chevron_left, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 48,
                      child: _buildFocusableItem(
                        onTap: _cycleAspectRatio,
                        borderRadius: BorderRadius.circular(16),
                        child: const CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 16,
                          child: Icon(Icons.aspect_ratio, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: _buildFocusableItem(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(16),
                        child: const CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 16,
                          child: Icon(Icons.fullscreen, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                  if (isPageLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black87,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset('assets/logo.png', height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.movie, color: Colors.red, size: 40)),
                              const SizedBox(height: 12),
                              const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2.5)),
                              const SizedBox(height: 10),
                              const Text("Loading HANNUTV Server", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.movieTitle, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18), const SizedBox(width: 4),
                        Text(widget.rating, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Text(widget.year, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        const SizedBox(width: 16),
                        const Icon(Icons.visibility, color: Colors.grey, size: 16), const SizedBox(width: 4),
                        Text("$viewCount Views", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFocusableItem(
                            onTap: () { setState(() { isLiked = !isLiked; likeCount += isLiked ? 1 : -1; }); },
                            borderRadius: BorderRadius.circular(20),
                            child: _buildActionButton(isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, "$likeCount", activeColor: isLiked ? Colors.redAccent : Colors.white),
                          ),
                          const SizedBox(width: 8),
                          _buildFocusableItem(onTap: () {}, borderRadius: BorderRadius.circular(20), child: _buildActionButton(Icons.bookmark_border, "Add to List")),
                          const SizedBox(width: 8),
                          _buildFocusableItem(onTap: () {}, borderRadius: BorderRadius.circular(20), child: _buildActionButton(Icons.tv, "Play on TV")),
                          const SizedBox(width: 8),
                          _buildFocusableItem(onTap: () {}, borderRadius: BorderRadius.circular(20), child: _buildActionButton(Icons.share, "Share")),
                          const SizedBox(width: 8),
                          _buildFocusableItem(onTap: () {}, borderRadius: BorderRadius.circular(20), child: _buildActionButton(Icons.flag_outlined, "Report")),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text("If current server is not working, try a different one:", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 10),
                    
                    // 🚀 SERVERS LOGIC WORKING NOW 🚀
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text("Servers : ", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          ...servers.map((srv) {
                            final isSelected = activeServer == srv['key'];
                            return _buildFocusableItem(
                              onTap: () {
                                if (activeServer != srv['key']) {
                                  setState(() { activeServer = srv['key']!; });
                                  _initStream();
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.grey[900], borderRadius: BorderRadius.circular(20)),
                                child: Text(srv['name']!, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    
                    // 🚀 CUSTOM BANNER 🚀
                    const CustomBannerAd(
                      htmlBannerCode: '''
                        <script type="text/javascript">
                          atOptions = { 'key' : 'a39df283f6ad10c34e229e5715bceff5', 'format' : 'iframe', 'height' : 50, 'width' : 320, 'params' : {} };
                        </script>
                        <script type="text/javascript" src="https://www.highrevenueformat.com/a39df283f6ad10c34e229e5715bceff5/invoke.js"></script>
                      ''',
                    ),
                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Comments ${publicComments.length}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              const Icon(Icons.comment, color: Colors.grey, size: 16),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: commentInputController,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: InputDecoration(hintText: 'Add a comment...', hintStyle: const TextStyle(color: Colors.grey, fontSize: 12), filled: true, fillColor: Colors.black45, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
                                ),
                              ),
                              _buildFocusableItem(
                                onTap: _addComment,
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.send, color: Colors.redAccent, size: 20)),
                              ),
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
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    if (widget.mediaType == 'tv' || widget.mediaType == 'series') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                            child: Text("Season $currentSeason", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const Icon(Icons.grid_view, color: Colors.grey, size: 20),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text("Episodes", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 15,
                          itemBuilder: (context, index) {
                            final epNum = index + 1;
                            final isCurrent = currentEpisode == epNum;
                            return _buildFocusableItem(
                              onTap: () => _switchEpisode(epNum),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 170,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: isCurrent ? Border.all(color: Colors.white, width: 2) : null, color: Colors.grey[900]),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: Container(decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(8)), color: Colors.grey[850]), child: Center(child: Icon(isCurrent ? Icons.play_arrow : Icons.play_circle_outline, color: Colors.white, size: 32)))),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Episode : $epNum", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          const Text("Stream on HANNUTV", style: TextStyle(color: Colors.grey, fontSize: 10), maxLines: 1),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String title, {Color activeColor = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: activeColor, size: 16),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(color: activeColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TvFocusButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;
  const _TvFocusButton({required this.child, required this.onTap, required this.borderRadius});
  @override
  State<_TvFocusButton> createState() => _TvFocusButtonState();
}

class _TvFocusButtonState extends State<_TvFocusButton> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) { if (mounted) setState(() => _hasFocus = hasFocus); },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: widget.borderRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(color: _hasFocus ? Colors.redAccent : Colors.transparent, width: _hasFocus ? 3.5 : 0),
            boxShadow: _hasFocus ? [BoxShadow(color: Colors.redAccent.withOpacity(0.65), blurRadius: 10, spreadRadius: 1.5)] : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}