import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:app_links/app_links.dart'; 
import 'package:package_info_plus/package_info_plus.dart'; // 🚀 NAYA ADD KIYA: Version check karne ke liye
import 'package:url_launcher/url_launcher.dart'; // 🚀 NAYA ADD KIYA: Update link open karne ke liye
import 'dashboard.dart';
import 'video_player_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔥 Background Notification Hit: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    announcement: true,
    badge: true,
    carPlay: false,
    criticalAlert: true,
    provisional: false,
    sound: true,
  );

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, 
    badge: true, 
    sound: true, 
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('🔥 Foreground Notification Hit!');
    if (message.notification != null) {
      print('Title: ${message.notification?.title}');
    }
  });

  messaging.getToken().then((token) {
    print("📲 FIREBASE DEVICE TOKEN: $token");
  });

  runApp(const HannuTvApp());
}

class HannuTvApp extends StatelessWidget {
  const HannuTvApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const HannuTvAppWrapper();
  }
}

class HannuTvAppWrapper extends StatefulWidget {
  const HannuTvAppWrapper({Key? key}) : super(key: key);
  @override
  State<HannuTvAppWrapper> createState() => _HannuTvAppWrapperState();
}

class _HannuTvAppWrapperState extends State<HannuTvAppWrapper> {
  late AppLinks _appLinks; 
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener(); 
  }

  void _initDeepLinkListener() async {
    _appLinks = AppLinks();
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleDeepLink(initialUri);
    } catch (e) { print(e); }

    _sub = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) _handleDeepLink(uri);
    }, onError: (err) {});
  }

  void _handleDeepLink(Uri uri) {
    if (uri.path.contains('/watch')) {
      String? idStr = uri.queryParameters['id'];
      String? type = uri.queryParameters['type'] ?? 'movie';
      if (idStr != null) {
        int id = int.tryParse(idStr) ?? 0;
        if (id != 0) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => VideoPlayerPage(
                tmdbId: id, mediaType: type, movieTitle: "Shared Stream",
              )
            )
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'HANNUTV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red, brightness: Brightness.dark),
      ),
      home: const SplashScreen(),
    );
  }
}

// ── SPLASH SCREEN (Deep Kill Switch & Version Logic) ──────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool isMaintenance = false;
  bool isUpdateRequired = false; // 🚀 NAYA: Update check flag
  String maintenanceMsg = "System Upgrade in Progress. Please update HANNUTV.";
  String updateLink = "https://hannutv.blogspot.com/"; // 🚀 NAYA: Default Link
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    checkMaintenance();
  }

  Future<void> checkMaintenance() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      // Hardcoded Fast Fetch (0 seconds cache for instant kill switch action)
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: const Duration(seconds: 0),
      ));
      await remoteConfig.fetchAndActivate();

      // 1. Purana Maintenance Mode check
      bool maintenance = remoteConfig.getBool('maintenance_mode');
      
      // 2. Naya Version Logic Check
      String fbLatestVersion = remoteConfig.getString('latest_version');
      String fbUpdateLink = remoteConfig.getString('update_link');
      String fbMsg = remoteConfig.getString('maintenance_message');
      
      // App ka current version nikalna
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      bool needsUpdate = false;
      if (fbLatestVersion.isNotEmpty && currentVersion != fbLatestVersion) {
         needsUpdate = true; // Agar Firebase ka version app ke version se alag hai toh update chahiye
      }

      setState(() {
        isMaintenance = maintenance;
        isUpdateRequired = needsUpdate;
        
        if (fbUpdateLink.isNotEmpty) {
           updateLink = fbUpdateLink;
        }

        if (fbMsg.isNotEmpty) {
          maintenanceMsg = fbMsg;
        }
      });
    } catch (e) {
      print("⚠️ Remote Config Error: $e");
    }

    // Agar maintenance ON hai YA Update chahiye, toh app block karo (isLoading false karke screen roko)
    if (isMaintenance || isUpdateRequired) {
      setState(() {
        isLoading = false; 
      });
    } else {
      // Sab theek hai, Dashboard par jao
      Timer(const Duration(milliseconds: 2500), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage()), 
        );
      });
    }
  }

  // 🚀 NAYA: URL open karne ka function
  Future<void> _launchUpdateURL() async {
    final Uri url = Uri.parse(updateLink);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print('Could not launch $url');
    }
  }


  @override
  Widget build(BuildContext context) {
    // 🔴 BLOCKED STATE
    if ((isMaintenance || isUpdateRequired) && !isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 85),
                const SizedBox(height: 25),
                const Text(
                  'MANDATORY UPDATE',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
                const SizedBox(height: 15),
                Text(
                  maintenanceMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 45),
                
                // 🚀 NAYA: Clickable Button jo seedha link par le jayega
                ElevatedButton.icon(
                  onPressed: _launchUpdateURL,
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text(
                    "UPDATE NOW",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 🟢 APP STARTING STATE
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 130,
              errorBuilder: (_, __, ___) => const Text(
                'HANNUTV',
                style: TextStyle(color: Colors.red, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 3),
            const SizedBox(height: 25),
            const Text(
              'Connecting to Secure Servers...',
              style: TextStyle(color: Colors.grey, fontSize: 14, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}