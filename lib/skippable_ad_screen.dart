import 'package:flutter/material.dart';
import 'dart:async';

class SkippableAdScreen extends StatefulWidget {
  final int adDuration;
  final Widget nextScreen;

  const SkippableAdScreen({
    super.key,
    required this.adDuration,
    required this.nextScreen,
  });

  @override
  State<SkippableAdScreen> createState() => _SkippableAdScreenState();
}

class _SkippableAdScreenState extends State<SkippableAdScreen> {
  late int timeLeft;
  Timer? timer;
  bool canSkip = false;

  @override
  void initState() {
    super.initState();
    timeLeft = widget.adDuration;
    startTimer();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft > 0) {
        setState(() {
          timeLeft--;
          if (timeLeft <= widget.adDuration - 5) {
            canSkip = true;
          }
        });
      } else {
        t.cancel();
        goToNext();
      }
    });
  }

  void goToNext() {
    timer?.cancel();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => widget.nextScreen));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 PopScope completely blocks the mobile Back Button 🔥
    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please watch or skip the ad to continue!'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Yaha tumhara actual Ad Network ka widget aayega
              const Center(
                child: Text(
                  "Sponsor Ad Playing...\n\nPlease wait.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 18),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSkip ? Colors.redAccent : Colors.grey[800],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: canSkip ? goToNext : null,
                  child: Text(
                    canSkip ? "Skip Ad >>" : "Skip in $timeLeft s",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "Ad",
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}