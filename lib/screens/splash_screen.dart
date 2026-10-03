import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'auth/auth_wrapper.dart';

class SkillBridgeSplashScreen extends StatefulWidget {
  const SkillBridgeSplashScreen({super.key});

  @override
  State<SkillBridgeSplashScreen> createState() =>
      _SkillBridgeSplashScreenState();
}

class _SkillBridgeSplashScreenState extends State<SkillBridgeSplashScreen> {
  VideoPlayerController? _videoController;

  bool _isLoading = true;
  bool _hasError = false;

  Timer? _fallbackTimer;

  // ----------------------------------------------------------
  // SUPABASE VIDEO URL
  // ----------------------------------------------------------

  static const String splashVideoUrl =
      'https://qfrzqhyqfrhwkfkgskrn.supabase.co/storage/v1/object/public/skillbridge/splash.mp4';

  @override
  void initState() {
    super.initState();

    _initializeVideo();
  }

  // ----------------------------------------------------------
  // INITIALIZE VIDEO
  // ----------------------------------------------------------

  Future<void> _initializeVideo() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(splashVideoUrl),
      );

      _videoController = controller;

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Keep splash video silent
      await controller.setVolume(0.0);

      // Start video
      await controller.play();

      // Detect when video finishes
      controller.addListener(_videoListener);

      // Safety fallback
      _fallbackTimer = Timer(const Duration(seconds: 10), _goToAuthWrapper);
    } catch (e) {
      debugPrint('Splash video error: $e');

      _showFallback();
    }
  }

  // ----------------------------------------------------------
  // VIDEO FINISHED
  // ----------------------------------------------------------

  void _videoListener() {
    final controller = _videoController;

    if (controller == null) return;

    if (controller.value.isInitialized &&
        controller.value.position >= controller.value.duration) {
      _goToAuthWrapper();
    }
  }

  // ----------------------------------------------------------
  // FALLBACK
  // ----------------------------------------------------------

  void _showFallback() {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _hasError = true;
    });

    _fallbackTimer = Timer(const Duration(seconds: 2), _goToAuthWrapper);
  }

  // ----------------------------------------------------------
  // GO TO AUTH WRAPPER
  // ----------------------------------------------------------

  void _goToAuthWrapper() {
    if (!mounted) return;

    _fallbackTimer?.cancel();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
    );
  }

  // ----------------------------------------------------------
  // DISPOSE
  // ----------------------------------------------------------

  @override
  void dispose() {
    _fallbackTimer?.cancel();

    _videoController?.removeListener(_videoListener);

    _videoController?.dispose();

    super.dispose();
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ------------------------------------------------
            // SPLASH VIDEO
            // ------------------------------------------------

            if (!_isLoading &&
                !_hasError &&
                _videoController != null &&
                _videoController!.value.isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),

            // ------------------------------------------------
            // SUBTLE DARK OVERLAY
            // ------------------------------------------------
            if (!_isLoading && !_hasError)
              Container(color: Colors.black.withValues(alpha: 0.08)),

            // ------------------------------------------------
            // LOADING
            // ------------------------------------------------
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),

            // ------------------------------------------------
            // FALLBACK
            // ------------------------------------------------
            if (_hasError)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/skillbridge_logo.png', width: 230),

                  const SizedBox(height: 25),

                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
