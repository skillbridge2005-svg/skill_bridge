import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class ClientGuideScreen extends StatefulWidget {
  const ClientGuideScreen({super.key});

  @override
  State<ClientGuideScreen> createState() => _ClientGuideScreenState();
}

class _ClientGuideScreenState extends State<ClientGuideScreen>
    with SingleTickerProviderStateMixin {
  static const Color _ink = Color(0xFF111827);
  static const Color _indigo = Color(0xFF4F46E5);
  static const Color _violet = Color(0xFF7C3AED);
  static const Color _pink = Color(0xFFEC4899);
  static const Color _muted = Color(0xFF6B7280);

  // All Client Guide videos
  static const List<_GuidePart> _guideParts = [
    _GuidePart(
      number: 1,
      title: 'Client Guide Part 1',
      description: 'Watch the first part of the Client Guide.',
      videoId: 'ojx3QZP9loQ',
      icon: Icons.play_circle_outline_rounded,
    ),
    _GuidePart(
      number: 2,
      title: 'Client Guide Part 2',
      description: 'Continue learning about SkillBridge.',
      videoId: 'Ofz4YsyrJQM',
      icon: Icons.video_library_outlined,
    ),
    _GuidePart(
      number: 3,
      title: 'Client Guide Part 3',
      description: 'Explore the next part of the client tutorial.',
      videoId: 'xFH-QGdV1pc',
      icon: Icons.explore_outlined,
    ),
    _GuidePart(
      number: 4,
      title: 'Client Guide Part 4',
      description: 'Learn more about using the platform.',
      videoId: 'SxEcpd0JqRQ',
      icon: Icons.dashboard_customize_outlined,
    ),
    _GuidePart(
      number: 5,
      title: 'Client Guide Part 5',
      description: 'Continue with the client walkthrough.',
      videoId: 'pfDus7GT0LU',
      icon: Icons.groups_outlined,
    ),
    _GuidePart(
      number: 6,
      title: 'Client Guide Part 6',
      description: 'Watch the sixth tutorial video.',
      videoId: 'ltGBdTxVGi8',
      icon: Icons.payments_outlined,
    ),
    _GuidePart(
      number: 7,
      title: 'Client Guide Part 7',
      description: 'Complete the final part of the Client Guide.',
      videoId: '1tVEfi-xCXg',
      icon: Icons.verified_outlined,
    ),
  ];

  late final YoutubePlayerController _controller;
  late final AnimationController _glow;

  int _selectedIndex = 0;

  _GuidePart get _selectedPart => _guideParts[_selectedIndex];

  @override
  void initState() {
    super.initState();

    _controller = YoutubePlayerController.fromVideoId(
      videoId: _guideParts.first.videoId,
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

  // Load selected video
  void _selectPart(int index) {
    if (index < 0 || index >= _guideParts.length) return;

    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    _controller.loadVideoById(videoId: _guideParts[index].videoId);
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
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Client Guide',
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
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 30),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth > 720;

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 300,
                                child: Column(
                                  children: [
                                    _buildPlayer(),
                                    const SizedBox(height: 20),
                                    _buildSelectedInfo(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 28),
                              Expanded(child: _buildGuideParts()),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPlayer(),
                            const SizedBox(height: 22),
                            _buildSelectedInfo(),
                            const SizedBox(height: 28),
                            _buildGuideParts(),
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

  // ------------------------------------------------ HERO

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
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
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
                            Icons.school_rounded,
                            size: 16,
                            color: Color(0xFFFDE68A),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'CLIENT LEARNING CENTER',
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
                      'Welcome, Client! 👋',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Learn how to use SkillBridge with our step-by-step '
                      'video tutorials. Select any guide part below and '
                      'start watching.',
                      style: TextStyle(
                        color: Color(0xFFD1D5DB),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(
                          Icons.video_collection_rounded,
                          color: Colors.white70,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_guideParts.length} Video Tutorials Available',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // ------------------------------------------------ VIDEO PLAYER

  Widget _buildPlayer() {
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
          width: 284,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: ColoredBox(
                  color: Colors.black,
                  child: YoutubePlayer(
                    controller: _controller,
                    aspectRatio: 9 / 16,
                  ),
                ),
              ),
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

  // ------------------------------------------------ SELECTED VIDEO INFO

  Widget _buildSelectedInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _indigo.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: _indigo,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NOW PLAYING',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _selectedPart.title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            _selectedPart.description,
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _navigationButton(
                  label: 'Previous',
                  icon: Icons.arrow_back_rounded,
                  enabled: _selectedIndex > 0,
                  onTap: () => _selectPart(_selectedIndex - 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _navigationButton(
                  label: 'Next Part',
                  icon: Icons.arrow_forward_rounded,
                  enabled: _selectedIndex < _guideParts.length - 1,
                  onTap: () => _selectPart(_selectedIndex + 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navigationButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? _indigo : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: enabled ? Colors.white : Colors.grey),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------ GUIDE PARTS

  Widget _buildGuideParts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Client Video Tutorials',
          style: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Choose a part to watch its video tutorial.',
          style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 18),

        ...List.generate(_guideParts.length, (index) => _buildPartCard(index)),

        const SizedBox(height: 12),
        _buildHelpCard(),
      ],
    );
  }

  Widget _buildPartCard(int index) {
    final part = _guideParts[index];
    final isSelected = _selectedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? _indigo : const Color(0xFFE5E7EB),
          width: isSelected ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? _indigo.withOpacity(0.08)
                : const Color(0x0A0F172A),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _selectPart(index),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [_indigo, _violet]
                          : [const Color(0xFFF3F4F6), const Color(0xFFE5E7EB)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    part.icon,
                    color: isSelected ? Colors.white : _muted,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        part.title,
                        style: TextStyle(
                          color: isSelected ? _indigo : _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isSelected ? 'Currently selected' : 'Tap to watch',
                        style: TextStyle(
                          color: isSelected ? _indigo : _muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.play_circle_outline_rounded,
                  color: isSelected ? _indigo : _muted,
                  size: 25,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------ HELP CARD

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

// ------------------------------------------------ GUIDE PART MODEL

class _GuidePart {
  final int number;
  final String title;
  final String description;
  final String videoId;
  final IconData icon;

  const _GuidePart({
    required this.number,
    required this.title,
    required this.description,
    required this.videoId,
    required this.icon,
  });
}
