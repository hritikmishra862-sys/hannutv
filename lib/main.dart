import 'package:flutter/material.dart';
import 'dart:async';
import 'dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HannuTVApp());
}

class HannuTVApp extends StatelessWidget {
  const HannuTVApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HANNUTV',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        primaryColor: Colors.red,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', width: 220),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.red),
            const SizedBox(height: 15),
            const Text("Loading Server Data...", style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}