import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'auth/role_selection_screen.dart';

// ================================================================
// DESIGN TOKENS
// ================================================================

const _kDark = Color(0xFF0B1220);
const _kInk = Color(0xFF0F172A);
const _kMuted = Color(0xFF64748B);
const _kBlue = Color(0xFF2563EB);
const _kTeal = Color(0xFF0F766E);
const _kPurple = Color(0xFF7C3AED);
const _kBorder = Color(0xFFE2E8F0);
const _kBg = Color(0xFFF8FAFC);

bool _isMobile(BuildContext c) => MediaQuery.sizeOf(c).width < 700;
double _vPad(BuildContext c) => _isMobile(c) ? 56 : 96;
double _clamp1(double v) => v.clamp(-1.0, 1.0).toDouble();

// ================================================================
// PAGE
// ================================================================

class SkillBridgeLandingPage extends StatefulWidget {
  const SkillBridgeLandingPage({super.key});

  @override
  State<SkillBridgeLandingPage> createState() => _SkillBridgeLandingPageState();
}

class _SkillBridgeLandingPageState extends State<SkillBridgeLandingPage>
    with SingleTickerProviderStateMixin {
  late final YoutubePlayerController _youtubeController;
  late final AnimationController _ambient; // drives the hero 3D scene
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();

    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _youtubeController = YoutubePlayerController.fromVideoId(
      videoId: '2fIg6FxzaxE',
      autoPlay: false,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        showControls: true,
        mute: false,
      ),
    );
  }

  @override
  void dispose() {
    _youtubeController.pauseVideo();
    _youtubeController.close();
    _ambient.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pauseLandingVideo() async {
    try {
      await _youtubeController.pauseVideo();
    } catch (e) {
      debugPrint('Could not pause landing page video: $e');
    }
  }

  Future<void> _goToRoleSelection(BuildContext context) async {
    await _pauseLandingVideo();
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            child: Column(
              children: [
                _buildHero(context),
                _buildVideoSection(context),
                _buildAbout(context),
                _buildForUsers(context),
                _buildHowItWorks(context),
                _buildAiSection(context),
                _buildWhySkillBridge(context),
                _buildFinalCta(context),
                _buildFooter(),
              ],
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _buildNavbar(context)),
        ],
      ),
    );
  }

  // ============================================================
  // NAVBAR (glass, floats over the page, switches to light on scroll)
  // ============================================================

  Widget _buildNavbar(BuildContext context) {
    final mobile = _isMobile(context);

    return AnimatedBuilder(
      animation: _scroll,
      builder: (context, _) {
        final scrolled = _scroll.hasClients && _scroll.offset > 40;

        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 16 : 24,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: scrolled
                    ? Colors.white.withValues(alpha: 0.88)
                    : _kDark.withValues(alpha: 0.35),
                border: Border(
                  bottom: BorderSide(
                    color: scrolled
                        ? _kBorder
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Row(
                    children: [
                      _Logo(lightText: !scrolled),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => _goToRoleSelection(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        child: const Text('Get started'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // HERO — rotating 3D network, perspective grid floor
  // ============================================================

  Widget _buildHero(BuildContext context) {
    final mobile = _isMobile(context);

    return Container(
      width: double.infinity,
      color: _kDark,
      child: ClipRect(
        child: Stack(
          children: [
            // Parallax glows
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scroll,
                builder: (context, _) {
                  final o = _scroll.hasClients ? _scroll.offset : 0.0;
                  return Stack(
                    children: [
                      Positioned(
                        top: -140 + o * 0.25,
                        right: -120,
                        child: const _GlowCircle(
                          size: 420,
                          color: Color(0x362563EB),
                        ),
                      ),
                      Positioned(
                        bottom: -160 - o * 0.1,
                        left: -140,
                        child: const _GlowCircle(
                          size: 380,
                          color: Color(0x2414B8A6),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Perspective floor grid
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 340,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _ambient,
                  builder: (context, _) => CustomPaint(
                    painter: _GridPainter(_ambient.value),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                mobile ? 110 : 140,
                24,
                mobile ? 60 : 100,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 950;

                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 11,
                              child: _heroText(context, center: false),
                            ),
                            const SizedBox(width: 40),
                            Expanded(
                              flex: 10,
                              child: _Reveal(
                                delay: const Duration(milliseconds: 250),
                                dy: 0,
                                child: _HeroScene(t: _ambient, height: 500),
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          _heroText(context, center: true),
                          const SizedBox(height: 40),
                          _Reveal(
                            delay: const Duration(milliseconds: 250),
                            dy: 0,
                            child: _HeroScene(
                              t: _ambient,
                              height: mobile ? 340 : 440,
                            ),
                          ),
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
    );
  }

  Widget _heroText(BuildContext context, {required bool center}) {
    final w = MediaQuery.sizeOf(context).width;
    final fs = w < 420
        ? 46.0
        : w < 700
        ? 58.0
        : w < 1000
        ? 70.0
        : 82.0;

    final cross = center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final align = center ? TextAlign.center : TextAlign.left;

    final connectShader = const LinearGradient(
      colors: [Color(0xFF60A5FA), Color(0xFF2DD4BF)],
    ).createShader(Rect.fromLTWH(0, 0, fs * 4.6, fs));

    final growShader = const LinearGradient(
      colors: [Color(0xFFA78BFA), Color(0xFFF0ABFC)],
    ).createShader(Rect.fromLTWH(0, 0, fs * 3, fs));

    return _Reveal(
      child: Column(
        crossAxisAlignment: cross,
        children: [
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.w900,
                height: 1.0,
                letterSpacing: -2.5,
                color: Colors.white,
              ),
              children: [
                const TextSpan(text: 'Connect\n'),
                TextSpan(
                  text: 'Build\n',
                  style: TextStyle(foreground: Paint()..shader = connectShader),
                ),
                TextSpan(
                  text: 'Grow',
                  style: TextStyle(foreground: Paint()..shader = growShader),
                ),
              ],
            ),
            textAlign: align,
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Where ideas meet skills and become software. '
              'Clients share what they need, developers join the team, '
              'and AI helps plan the way.',
              textAlign: align,
              style: const TextStyle(
                fontSize: 18,
                height: 1.6,
                color: Color(0xFFA9B8CF),
              ),
            ),
          ),
          const SizedBox(height: 34),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: center ? Alignment.center : Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: center
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                FilledButton.icon(
                  onPressed: () => _goToRoleSelection(context),
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text('Get started'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 18,
                    ),
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: _kBlue,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                OutlinedButton.icon(
                  onPressed: () => _goToRoleSelection(context),
                  icon: const Icon(Icons.code_rounded),
                  label: const Text('Join as developer'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 18,
                    ),
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VIDEO
  // ============================================================

  Widget _buildVideoSection(BuildContext context) {
    final mobile = _isMobile(context);

    return Container(
      width: double.infinity,
      color: _kDark,
      padding: EdgeInsets.fromLTRB(24, 0, 24, _vPad(context)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Column(
            children: [
              Text(
                'From idea to software',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: mobile ? 28 : 38,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'See how SkillBridge connects clients, developers and '
                'software projects in one place.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF94A3B8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              // Gradient frame + glow
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kBlue, _kPurple, Color(0xFF14B8A6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x552563EB),
                      blurRadius: 60,
                      offset: Offset(0, 24),
                    ),
                  ],
                ),
                child: YoutubePlayer(
                  controller: _youtubeController,
                  aspectRatio: 16 / 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ABOUT
  // ============================================================

  Widget _buildAbout(BuildContext context) {
    return _Section(
      title: 'What is SkillBridge?',
      subtitle:
          'SkillBridge brings clients, developers, projects and AI-assisted '
          'planning together in one connected platform.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final items = [
            _FeatureCard(
              icon: Icons.work_outline_rounded,
              title: 'Software projects',
              description:
                  'Clients share software requirements and connect '
                  'with developers who can build the solution.',
              accent: _kBlue,
              onTap: () => _goToRoleSelection(context),
            ),
            _FeatureCard(
              icon: Icons.groups_outlined,
              title: 'Team collaboration',
              description:
                  'Developers collaborate in roles such as frontend, '
                  'backend and database development.',
              accent: _kTeal,
              onTap: () => _goToRoleSelection(context),
            ),
            _FeatureCard(
              icon: Icons.smart_toy_outlined,
              title: 'AI assistance',
              description:
                  'AI helps understand requirements, organize project '
                  'information and support planning.',
              accent: _kPurple,
              onTap: () => _goToRoleSelection(context),
            ),
          ];

          if (constraints.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items
                  .map(
                    (item) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        child: item,
                      ),
                    ),
                  )
                  .toList(),
            );
          }

          return Column(
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: item,
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  // ============================================================
  // CLIENT / DEVELOPER
  // ============================================================

  Widget _buildForUsers(BuildContext context) {
    return _Section(
      background: Colors.white,
      title: 'Built for both sides of the project',
      subtitle: 'One platform. Two roles. One connected workflow.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final clientCard = _RoleCard(
            icon: Icons.business_center_outlined,
            title: 'For clients',
            description:
                'Turn your software idea into a structured '
                'project and connect with developers.',
            features: const [
              'Create project requirements',
              'Get AI-assisted requirement support',
              'Build a suitable development team',
              'Track project progress',
            ],
            cta: 'Continue as client',
            accent: _kBlue,
            onTap: () => _goToRoleSelection(context),
          );

          final developerCard = _RoleCard(
            icon: Icons.code_rounded,
            title: 'For developers',
            description:
                'Use your skills to work on software projects '
                'and collaborate with other developers.',
            features: const [
              'Discover software projects',
              'Show your skills and profile',
              'Join development teams',
              'Work through a structured workflow',
            ],
            cta: 'Continue as developer',
            accent: _kTeal,
            onTap: () => _goToRoleSelection(context),
          );

          if (constraints.maxWidth > 700) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: clientCard),
                const SizedBox(width: 24),
                Expanded(child: developerCard),
              ],
            );
          }

          return Column(
            children: [clientCard, const SizedBox(height: 20), developerCard],
          );
        },
      ),
    );
  }

  // ============================================================
  // HOW IT WORKS (a real sequence, so numbered)
  // ============================================================

  Widget _buildHowItWorks(BuildContext context) {
    const steps = [
      (
        '01',
        'Create a requirement',
        'The client describes the software idea and project needs.',
        Icons.edit_note_rounded,
      ),
      (
        '02',
        'Understand and plan',
        'AI helps organize the requirement and supports initial planning.',
        Icons.psychology_outlined,
      ),
      (
        '03',
        'Form the team',
        'Suitable developers join according to project roles.',
        Icons.groups_rounded,
      ),
      (
        '04',
        'Build and test',
        'The team develops, reviews and tests the software.',
        Icons.build_circle_outlined,
      ),
      (
        '05',
        'Deliver',
        'The completed software moves through review and final delivery.',
        Icons.task_alt_rounded,
      ),
    ];

    return _Section(
      title: 'How SkillBridge works',
      subtitle: 'A structured journey from the first idea to final delivery.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width > 1000
              ? 5
              : width > 700
              ? 3
              : width > 480
              ? 2
              : 1;
          const gap = 18.0;
          final cardWidth = (width - (columns - 1) * gap) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            alignment: WrapAlignment.center,
            children: steps.map((s) {
              return SizedBox(
                width: cardWidth,
                child: _Tilt3D(
                  radius: 22,
                  onTap: () => _goToRoleSelection(context),
                  child: _StepCard(
                    number: s.$1,
                    title: s.$2,
                    description: s.$3,
                    icon: s.$4,
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ============================================================
  // AI SECTION
  // ============================================================

  Widget _buildAiSection(BuildContext context) {
    final mobile = _isMobile(context);

    return Container(
      width: double.infinity,
      color: _kDark,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: _vPad(context)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI-assisted project planning',
                    style: TextStyle(
                      fontSize: mobile ? 30 : 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SkillBridge uses AI to turn a client idea into clearer '
                    'requirements, useful questions, organized information '
                    'and a first plan.',
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.65,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _DarkFeature(
                    icon: Icons.chat_outlined,
                    text: 'Understand project requirements',
                  ),
                  const _DarkFeature(
                    icon: Icons.question_answer_outlined,
                    text: 'Ask useful clarification questions',
                  ),
                  const _DarkFeature(
                    icon: Icons.description_outlined,
                    text: 'Organize project information',
                  ),
                  const _DarkFeature(
                    icon: Icons.timeline_outlined,
                    text: 'Support preliminary planning',
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => _goToRoleSelection(context),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Explore SkillBridge'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              );

              final visual = _AiAssistantCard(
                onTap: () => _goToRoleSelection(context),
              );

              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 64),
                    Expanded(child: visual),
                  ],
                );
              }

              return Column(
                children: [content, const SizedBox(height: 44), visual],
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WHY SKILLBRIDGE
  // ============================================================

  Widget _buildWhySkillBridge(BuildContext context) {
    const benefits = [
      (
        Icons.link_rounded,
        'Connected ecosystem',
        'Bring clients, developers and projects together.',
      ),
      (
        Icons.psychology_alt_outlined,
        'AI assisted',
        'Make project requirements easier to understand.',
      ),
      (
        Icons.track_changes_rounded,
        'Structured workflow',
        'Move from idea to delivery with a clear process.',
      ),
      (
        Icons.groups_2_outlined,
        'Collaboration',
        'Let developers work together effectively.',
      ),
    ];

    return _Section(
      title: 'More than a project platform',
      subtitle: 'Designed around the real journey of building software.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width > 900
              ? 4
              : width > 600
              ? 2
              : 1;
          const gap = 18.0;
          final cardWidth = (width - (columns - 1) * gap) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: benefits.map((b) {
              return SizedBox(
                width: cardWidth,
                child: _Tilt3D(
                  radius: 20,
                  child: _BenefitCard(
                    icon: b.$1,
                    title: b.$2,
                    description: b.$3,
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ============================================================
  // FINAL CTA
  // ============================================================

  Widget _buildFinalCta(BuildContext context) {
    final mobile = _isMobile(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: mobile ? 56 : 100,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: _Tilt3D(
            radius: 32,
            maxTilt: 0.05,
            hoverScale: 1.01,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2563EB),
                    Color(0xFF1D4ED8),
                    Color(0xFF4338CA),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -90,
                    right: -70,
                    child: _GlowCircle(
                      size: 260,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  Positioned(
                    bottom: -110,
                    left: -80,
                    child: _GlowCircle(
                      size: 280,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: mobile ? 24 : 40,
                      vertical: mobile ? 44 : 60,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.rocket_launch_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Have a project or a skill?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: mobile ? 30 : 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'Bring your software idea or your development '
                            'skills to SkillBridge and build something '
                            'meaningful.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              color: Color(0xFFE0E7FF),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 30),
                          FilledButton.icon(
                            onPressed: () => _goToRoleSelection(context),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Join SkillBridge'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1D4ED8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 26,
                                vertical: 18,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FOOTER
  // ============================================================

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      color: _kInk,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              const _Logo(lightText: true),
              const SizedBox(height: 15),
              const Text(
                'Connecting ideas with the skills to build them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 25),
              Container(height: 1, color: const Color(0xFF1E293B)),
              const SizedBox(height: 20),
              const Text(
                'SkillBridge  |  Connect - Build - Grow.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// 3D: HERO SCENE (rotating network sphere + floating glass chips)
// ================================================================

class _HeroScene extends StatefulWidget {
  final Animation<double> t;
  final double height;

  const _HeroScene({required this.t, required this.height});

  @override
  State<_HeroScene> createState() => _HeroSceneState();
}

class _HeroSceneState extends State<_HeroScene> {
  Offset _p = Offset.zero; // pointer position, -1..1

  void _onHover(PointerEvent e) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    setState(() {
      _p = Offset(
        _clamp1(e.localPosition.dx / box.size.width * 2 - 1),
        _clamp1(e.localPosition.dy / box.size.height * 2 - 1),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: _onHover,
      onExit: (_) => setState(() => _p = Offset.zero),
      child: SizedBox(
        height: widget.height,
        child: TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(begin: Offset.zero, end: _p),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          builder: (context, p, _) {
            return AnimatedBuilder(
              animation: widget.t,
              builder: (context, _) {
                final t = widget.t.value;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _NetworkPainter(t, p)),
                    ),
                    // Core hub
                    Center(
                      child: Transform.scale(
                        scale: 1 + math.sin(t * 2 * math.pi * 6) * 0.04,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _kBlue.withValues(alpha: 0.6),
                                blurRadius: 40,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.hub_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                    ),
                    _chip(
                      p,
                      t,
                      Icons.lightbulb_outline_rounded,
                      'Client idea',
                      const Color(0xFF60A5FA),
                      const Alignment(-1, -0.65),
                      0.0,
                      1.0,
                    ),
                    _chip(
                      p,
                      t,
                      Icons.code_rounded,
                      'Developer team',
                      const Color(0xFF2DD4BF),
                      const Alignment(1, -0.2),
                      0.3,
                      1.5,
                    ),
                    _chip(
                      p,
                      t,
                      Icons.auto_awesome_rounded,
                      'AI planning',
                      const Color(0xFFA78BFA),
                      const Alignment(-0.9, 0.7),
                      0.6,
                      1.2,
                    ),
                    _chip(
                      p,
                      t,
                      Icons.task_alt_rounded,
                      'Delivered',
                      const Color(0xFF4ADE80),
                      const Alignment(0.95, 0.85),
                      0.85,
                      0.8,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _chip(
    Offset p,
    double t,
    IconData icon,
    String label,
    Color color,
    Alignment alignment,
    double phase,
    double depth,
  ) {
    final bob = math.sin((t * 6 + phase) * 2 * math.pi) * 9;

    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(-p.dx * 22 * depth, -p.dy * 16 * depth + bob),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(p.dx * 0.35 * depth)
            ..rotateX(-p.dy * 0.25 * depth),
          child: _GlassChip(icon: icon, label: label, color: color),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _GlassChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111B33).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a rotating 3D "network" on a sphere with perspective projection.
class _NetworkPainter extends CustomPainter {
  final double t; // 0..1 loop
  final Offset p; // pointer -1..1

  _NetworkPainter(this.t, this.p);

  static const int _n = 72;
  static const _palette = [
    Color(0xFF3B82F6),
    Color(0xFF14B8A6),
    Color(0xFFA78BFA),
  ];

  // Points on a unit sphere (Fibonacci spiral)
  static final List<List<double>> _pts = () {
    final golden = math.pi * (3 - math.sqrt(5));
    return List.generate(_n, (i) {
      final y = 1 - (i / (_n - 1)) * 2;
      final r = math.sqrt(math.max(0.0, 1 - y * y));
      final th = golden * i;
      return [math.cos(th) * r, y, math.sin(th) * r];
    });
  }();

  // Connect close neighbours
  static final List<List<int>> _edges = () {
    final e = <List<int>>[];
    for (var i = 0; i < _n; i++) {
      for (var j = i + 1; j < _n; j++) {
        final dx = _pts[i][0] - _pts[j][0];
        final dy = _pts[i][1] - _pts[j][1];
        final dz = _pts[i][2] - _pts[j][2];
        if (dx * dx + dy * dy + dz * dz < 0.36) e.add([i, j]);
      }
    }
    return e;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.34;

    final angle = t * 2 * math.pi + p.dx * 0.7;
    final tilt = 0.38 + p.dy * 0.35;
    final ca = math.cos(angle), sa = math.sin(angle);
    final ct = math.cos(tilt), st = math.sin(tilt);

    // Orbit rings
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.45 + p.dx * 0.1);
    ring.color = _palette[0].withValues(alpha: 0.25);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 3.0,
        height: radius * 1.0,
      ),
      ring,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(0.55 - p.dx * 0.1);
    ring.color = _palette[1].withValues(alpha: 0.2);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.5,
        height: radius * 0.8,
      ),
      ring,
    );
    canvas.restore();

    // Core glow
    final glow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x442563EB), Color(0x00000000)],
      ).createShader(Rect.fromCircle(center: c, radius: radius * 1.35));
    canvas.drawCircle(c, radius * 1.35, glow);

    // Project points
    final pos = List<Offset>.filled(_n, Offset.zero);
    final depth = List<double>.filled(_n, 0);

    for (var i = 0; i < _n; i++) {
      final x = _pts[i][0], y = _pts[i][1], z = _pts[i][2];

      // rotate around Y
      final x1 = x * ca + z * sa;
      final z1 = -x * sa + z * ca;

      // tilt around X
      final y2 = y * ct - z1 * st;
      final z2 = y * st + z1 * ct;

      final persp = 1 + z2 * 0.25;
      pos[i] = c + Offset(x1 * radius * persp, y2 * radius * persp);
      depth[i] = z2;
    }

    // Edges
    final line = Paint()..style = PaintingStyle.stroke;
    for (final e in _edges) {
      final d = (depth[e[0]] + depth[e[1]]) / 2; // -1..1
      final a = (d + 1) / 2;
      line
        ..strokeWidth = 0.7 + 0.8 * a
        ..color = _palette[0].withValues(alpha: 0.06 + 0.42 * a);
      canvas.drawLine(pos[e[0]], pos[e[1]], line);
    }

    // Nodes
    final dot = Paint();
    for (var i = 0; i < _n; i++) {
      final a = (depth[i] + 1) / 2;
      final r = 1.8 + 3.2 * a;
      final color = _palette[i % 3];

      dot.color = color.withValues(alpha: 0.12 + 0.12 * a);
      canvas.drawCircle(pos[i], r * 2.6, dot);

      dot.color = color.withValues(alpha: 0.35 + 0.65 * a);
      canvas.drawCircle(pos[i], r, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter old) => old.t != t || old.p != p;
}

/// Moving perspective floor grid behind the hero.
class _GridPainter extends CustomPainter {
  final double t;

  _GridPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Horizontal lines rushing toward the viewer
    const rows = 14;
    final shift = (t * 12) % 1;
    for (var i = 0; i < rows; i++) {
      final f = (i + shift) / rows;
      final y = h * f * f;
      paint.color = _kBlue.withValues(alpha: 0.38 * f);
      canvas.drawLine(Offset(0, y), Offset(w, y), paint);
    }

    // Vertical lines converging at the horizon
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x002563EB), Color(0x552563EB)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    for (var k = -14; k <= 14; k++) {
      canvas.drawLine(
        Offset(cx + k * w * 0.012, 0),
        Offset(cx + k * w * 0.11, h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.t != t;
}

// ================================================================
// 3D: TILT CARD (pointer-driven perspective tilt + glare + depth shadow)
// ================================================================

class _Tilt3D extends StatefulWidget {
  final Widget child;
  final double radius;
  final double maxTilt;
  final double hoverScale;
  final VoidCallback? onTap;
  final Offset rest; // resting rotation (rotX, rotY)

  const _Tilt3D({
    required this.child,
    this.radius = 22,
    this.maxTilt = 0.14,
    this.hoverScale = 1.025,
    this.onTap,
    this.rest = Offset.zero,
  });

  @override
  State<_Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<_Tilt3D> {
  Offset _p = Offset.zero;
  bool _hover = false;

  void _update(PointerEvent e) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    setState(() {
      _hover = true;
      _p = Offset(
        _clamp1(e.localPosition.dx / box.size.width * 2 - 1),
        _clamp1(e.localPosition.dy / box.size.height * 2 - 1),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);
    final k = _hover ? 1.0 : 0.0;

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(-_p.dy * widget.maxTilt * k + widget.rest.dx)
      ..rotateY(_p.dx * widget.maxTilt * k + widget.rest.dy);

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onHover: _update,
      onExit: (_) => setState(() {
        _hover = false;
        _p = Offset.zero;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? widget.hoverScale : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transformAlignment: Alignment.center,
            transform: matrix,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: _hover
                      ? const Color(0x330F172A)
                      : const Color(0x120F172A),
                  blurRadius: _hover ? 44 : 22,
                  offset: Offset(-_p.dx * 14, (_hover ? 22 : 10) - _p.dy * 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  widget.child,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _hover ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment(_p.dx, _p.dy),
                              radius: 0.9,
                              colors: [
                                Colors.white.withValues(alpha: 0.18),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// REVEAL (used sparingly: hero entrance and chat bubbles)
// ================================================================

class _Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double dy;

  const _Reveal({
    required this.child,
    this.delay = Duration.zero,
    this.dy = 0.06,
  });

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  ScrollPosition? _pos;
  bool _triggered = false;
  bool _visible = false;
  double _viewportHeight = 800;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewportHeight = MediaQuery.sizeOf(context).height;
    _pos?.removeListener(_check);
    _pos = Scrollable.maybeOf(context)?.position;
    _pos?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_triggered || !mounted) return;
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return;

    final top = ro.localToGlobal(Offset.zero).dy;
    if (top < _viewportHeight * 0.9) {
      _triggered = true;
      _pos?.removeListener(_check);
      if (widget.delay == Duration.zero) {
        setState(() => _visible = true);
      } else {
        Future.delayed(widget.delay, () {
          if (mounted) setState(() => _visible = true);
        });
      }
    }
  }

  @override
  void dispose() {
    _pos?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : Offset(0, widget.dy),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ================================================================
// LOGO
// ================================================================

class _Logo extends StatelessWidget {
  final bool lightText;

  const _Logo({this.lightText = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x552563EB),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(Icons.hub_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: lightText ? Colors.white : _kInk,
          ),
          child: const Text('SkillBridge'),
        ),
      ],
    );
  }
}

// ================================================================
// SECTION
// ================================================================

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Color? background;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);

    return Container(
      width: double.infinity,
      color: background,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: _vPad(context)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: mobile ? 28 : 38,
                  fontWeight: FontWeight.w900,
                  color: _kInk,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: _kMuted,
                    height: 1.55,
                  ),
                ),
              ),
              SizedBox(height: mobile ? 32 : 48),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// CARDS
// ================================================================

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Tilt3D(
      radius: 22,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, accent.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(17),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 27),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14.5,
                color: _kMuted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'Explore',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(Icons.arrow_forward_rounded, size: 16, color: accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> features;
  final String cta;
  final Color accent;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.features,
    required this.cta,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Tilt3D(
      radius: 26,
      maxTilt: 0.09,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(icon, color: accent, size: 29),
                ),
                const Spacer(),
                Icon(Icons.arrow_outward_rounded, color: accent),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(fontSize: 15, color: _kMuted, height: 1.5),
            ),
            const SizedBox(height: 24),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 19, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  cta,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 17, color: accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;

  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 230),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorder),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 6,
            right: 14,
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 54,
                fontWeight: FontWeight.w900,
                color: Color(0xFFEFF3F8),
                height: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x442563EB),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 25),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _kMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 170),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kBlue, size: 30),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 14, color: _kMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// AI CARD (tilted chat mock-up with a pulsing assistant orb)
// ================================================================

class _AiAssistantCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AiAssistantCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);

    return _Tilt3D(
      radius: 28,
      maxTilt: 0.09,
      onTap: onTap,
      rest: mobile ? Offset.zero : const Offset(0.04, -0.12),
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF111827), Color(0xFF172554)],
          ),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                _PulseOrb(),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI project assistant',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'From idea to clearer requirements',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _Reveal(
              delay: Duration(milliseconds: 200),
              child: _Bubble(
                text: 'I want an app to manage my small business.',
                fromUser: true,
              ),
            ),
            const SizedBox(height: 12),
            const _Reveal(
              delay: Duration(milliseconds: 1000),
              child: _Bubble(
                text: 'Great. Who will use it, and which features matter most?',
                fromUser: false,
              ),
            ),
            const SizedBox(height: 16),
            const _Reveal(
              delay: Duration(milliseconds: 1800),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniTag(text: 'Requirements', color: Color(0xFF60A5FA)),
                  _MiniTag(text: 'Roles', color: Color(0xFF2DD4BF)),
                  _MiniTag(text: 'Timeline', color: Color(0xFFA78BFA)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool fromUser;

  const _Bubble({required this.text, required this.fromUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: fromUser ? _kBlue : _kInk,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(fromUser ? 16 : 4),
              bottomRight: Radius.circular(fromUser ? 4 : 16),
            ),
            border: Border.all(
              color: fromUser ? Colors.transparent : const Color(0xFF334155),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseOrb extends StatefulWidget {
  const _PulseOrb();

  @override
  State<_PulseOrb> createState() => _PulseOrbState();
}

class _PulseOrbState extends State<_PulseOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = Curves.easeInOut.transform(_c.value);
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kBlue.withValues(alpha: 0.18),
            border: Border.all(color: const Color(0xFF60A5FA)),
            boxShadow: [
              BoxShadow(
                color: _kBlue.withValues(alpha: 0.2 + 0.3 * v),
                blurRadius: 10 + 16 * v,
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF93C5FD),
            size: 24,
          ),
        );
      },
    );
  }
}

// ================================================================
// SMALL PIECES
// ================================================================

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _DarkFeature extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DarkFeature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF93C5FD), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
