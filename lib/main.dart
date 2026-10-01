import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:uni_links/uni_links.dart'; // 🚀 DEEP LINKING ADDED
import 'dashboard.dart';
import 'video_player_page.dart'; // 🚀 ADDED FOR DEEP LINK ROUTING

// 🚀 DEEP LINKING NAVIGATOR KEY
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 🚀 1. DEEP BACKGROUND HANDLER (Hardcoded System-Level Listener)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔥 Background Notification Hit: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🚀 2. INITIALIZE FIREBASE CORE
  await Firebase.initializeApp();

  // 🚀 3. REGISTER BACKGROUND LISTENER
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🚀 4. AGGRESSIVE PERMISSION REQUEST (Badge, Sound, Alert)
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

  // 🚀 5. FORCE FOREGROUND HEADS-UP POPUP
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, 
    badge: true, 
    sound: true, 
  );

  // 🚀 6. FOREGROUND MESSAGE LISTENER (App open hone par notification)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('🔥 Foreground Notification Hit!');
    if (message.notification != null) {
      print('Title: ${message.notification?.title}');
    }
  });

  // 🚀 7. FETCH DEVICE TOKEN (Connection Test)
  messaging.getToken().then((token) {
    print("📲 FIREBASE DEVICE TOKEN: $token");
  });

  runApp(const HannuTvApp());
}

class HannuTvApp extends StatefulWidget {
  const HannuTvApp({Key? key}) : super(key: key);

  @override
  State<HannuTvApp> createState() => _HannuTvAppState();
}

class _HannuTvAppState extends State<HannuTvApp> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _initDeepLinkListener(); // 🚀 DEEP LINK INITIALIZER ADDED
  }

  // 🚀 CATCH DEEP LINKS (Share kiye hue links yahan aayenge)
  void _initDeepLinkListener() async {
    try {
      final initialUri = await getInitialUri();
      if (initialUri != null) _handleDeepLink(initialUri);
    } catch (e) { print(e); }

    _sub = uriLinkStream.listen((Uri? uri) {
      if (uri != null) _handleDeepLink(uri);
    }, onError: (err) {});
  }

  void _handleDeepLink(Uri uri) {
    // Format: https://hannutv.blogspot.com/watch?id=12345&type=movie
    if (uri.path.contains('/watch')) {
      String? idStr = uri.queryParameters['id'];
      String? type = uri.queryParameters['type'] ?? 'movie';
      
      if (idStr != null) {
        int id = int.tryParse(idStr) ?? 0;
        if (id != 0) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => VideoPlayerPage(
                tmdbId: id,
                mediaType: type,
                movieTitle: "Shared Movie", // TMDB se andar fetch hoga
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
      navigatorKey: navigatorKey, // 🚀 KEY ADDED FOR DEEP ROUTING
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

// ── SPLASH SCREEN (Deep Kill Switch Logic) ──────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool isMaintenance = false;
  String maintenanceMsg = "System Upgrade in Progress. Please update HANNUTV.";
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

      setState(() {
        isMaintenance = remoteConfig.getBool('maintenance_mode');
        String msg = remoteConfig.getString('maintenance_message');
        if (msg.isNotEmpty) {
          maintenanceMsg = msg;
        }
      });
    } catch (e) {
      print("⚠️ Remote Config Error: $e");
    }

    if (!isMaintenance) {
      Timer(const Duration(milliseconds: 2500), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()), 
        );
      });
    } else {
      setState(() {
        isLoading = false; 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔴 BLOCKED STATE
    if (isMaintenance && !isLoading) {
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
                const Text(
                  'Get the latest version here:',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.redAccent, width: 2),
                    borderRadius: BorderRadius.circular(10)
                  ),
                  child: const Text(
                    'hannutv.blogspot.com', 
                    style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
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