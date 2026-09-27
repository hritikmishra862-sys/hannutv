import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart'; // Naya package
import 'dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Notification Permission
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  runApp(const HannuTvApp());
}

class HannuTvApp extends StatelessWidget {
  const HannuTvApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

// ── SPLASH SCREEN (With Kill Switch Logic) ──────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool isMaintenance = false;
  String maintenanceMsg = "Server is updating. Please install the new app.";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    checkMaintenance();
  }

  Future<void> checkMaintenance() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(seconds: 0), // Fast Sync
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
      print("Remote config error: $e");
    }

    // Agar maintenance ON nahi hai, toh Dashboard par bhej do
    if (!isMaintenance) {
      Timer(const Duration(milliseconds: 2000), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage()), 
        );
      });
    } else {
      // Agar ON hai, toh Loading rok do aur Block Screen dikhao
      setState(() {
        isLoading = false; 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔴 MAINTENANCE SCREEN (App Blocked)
    if (isMaintenance && !isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update, color: Colors.red, size: 80),
                const SizedBox(height: 20),
                const Text(
                  'UPDATE REQUIRED',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 15),
                Text(
                  maintenanceMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Please download new version from:',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 5),
                const Text(
                  'hannutv.blogspot.com', // Aapki website ka link
                  style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 🟢 NORMAL SPLASH SCREEN (App Open)
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',
                height: 120,
                errorBuilder: (_, __, ___) => const Text(
                  'HANNUTV',
                  style: TextStyle(color: Colors.red, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                'Starting HANNUTV...',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}