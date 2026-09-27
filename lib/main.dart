import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Messaging import kiya
import 'dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase Initialize kiya
  await Firebase.initializeApp();

  // Android 13+ ke liye Notification Permission maangna zaroori hai
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ── SPLASH SCREEN ──────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 2.5 Second ka wait aur seedha Dashboard
    Timer(const Duration(milliseconds: 2500), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardPage()), 
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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