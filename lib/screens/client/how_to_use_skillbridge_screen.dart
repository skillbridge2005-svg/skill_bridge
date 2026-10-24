import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class HowToUseSkillBridgeScreen extends StatefulWidget {
  const HowToUseSkillBridgeScreen({super.key});

  @override
  State<HowToUseSkillBridgeScreen> createState() =>
      _HowToUseSkillBridgeScreenState();
}

class _HowToUseSkillBridgeScreenState extends State<HowToUseSkillBridgeScreen>
    with SingleTickerProviderStateMixin {
  static const String videoId = 'Evomgc4GHgc';

  static const Color _ink = Color(0xFF111827);
  static const Color _indigo = Color(0xFF4F46E5);
  static const Color _violet = Color(0xFF7C3AED);
  static const Color _pink = Color(0xFFEC4899);
  static const Color _muted = Color(0xFF6B7280);

  late final YoutubePlayerController _controller;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();

    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        showVideoAnnotations: false,
        enableCaption: true,
        strictRelatedVideos: true,
        playsInline: true,
      ),
    );

    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      // Solid app bar (no overlap with the hero content on mobile)
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'How to Use SkillBridge',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildHero(),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth > 700;
                        final details = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle(),
                            const SizedBox(height: 16),
                            _buildSteps(),
                            const SizedBox(height: 6),
                            _buildHelpCard(),
                          ],
                        );

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPhonePlayer(300),
                              const SizedBox(width: 32),
                              Expanded(child: details),
                            ],
                          );
                        }

                        // Mobile: player fits the screen width (max 300)
                        final playerWidth = (constraints.maxWidth - 20).clamp(
                          200.0,
                          300.0,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPhonePlayer(playerWidth),
                            const SizedBox(height: 28),
                            details,
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- HERO
  Widget _buildHero() {
    final width = MediaQuery.of(context).size.width;
    final titleSize = width < 380 ? 26.0 : 30.0;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF312E81), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -30,
            child: _bubble(130, Colors.white.withOpacity(0.06)),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: _bubble(70, _pink.withOpacity(0.25)),
          ),
          Positioned(
            left: -40,
            bottom: -60,
            child: _bubble(110, Colors.white.withOpacity(0.05)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 16,
                              color: Color(0xFFFDE68A),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'QUICK TOUR  •  UNDER 1 MIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome to\nSkillBridge! 👋',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Watch this short tutorial to learn how SkillBridge '
                        'works, explore its features, and get the most out '
                        'of the platform.',
                        style: TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  // ------------------------------------------------------- PORTRAIT PLAYER
  Widget _buildPhonePlayer(double width) {
    return Center(
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_glow.value);
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(_indigo, _pink, t)!.withOpacity(0.35),
                  blurRadius: 22 + 14 * t,
                  spreadRadius: 1 + 2 * t,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          );
        },
        child: SizedBox(
          width: width,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: ColoredBox(
                  color: Colors.black,
                  // Portrait 9:16 for YouTube Shorts
                  child: YoutubePlayer(
                    controller: _controller,
                    aspectRatio: 9 / 16,
                  ),
                ),
              ),
              // Phone notch (ignores touches so the player stays tappable)
              IgnorePointer(
                child: Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 60,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
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

  // --------------------------------------------------------------- DETAILS
  Widget _buildSectionTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What you\'ll learn',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Tap play on the short and follow along with these highlights.',
          style: TextStyle(fontSize: 13, height: 1.5, color: _muted),
        ),
      ],
    );
  }

  Widget _buildSteps() {
    const steps = [
      (
        Icons.person_add_alt_1_rounded,
        'Set up your profile',
        'Add your skills and goals so we can match you better.',
        _indigo,
      ),
      (
        Icons.explore_rounded,
        'Explore opportunities',
        'Browse and discover options that fit your skills.',
        _violet,
      ),
      (
        Icons.handshake_rounded,
        'Connect & collaborate',
        'Reach out, apply, and build meaningful connections.',
        _pink,
      ),
      (
        Icons.trending_up_rounded,
        'Track your growth',
        'Follow your progress and level up over time.',
        Color(0xFF059669),
      ),
    ];

    return Column(
      children: List.generate(steps.length, (i) {
        final s = steps[i];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 450 + i * 150),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - v)),
              child: child,
            ),
          ),
          child: _stepCard(i + 1, s.$1, s.$2, s.$3, s.$4),
        );
      }),
    );
  }

  Widget _stepCard(
    int number,
    IconData icon,
    String title,
    String body,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '0$number',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color.withOpacity(0.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFFDF2F8)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.support_agent_rounded, color: _indigo, size: 28),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need more help?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'If you have any questions, visit the Help & Support '
                  'section on your profile to contact the SkillBridge team.',
                  style: TextStyle(fontSize: 13, height: 1.6, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
