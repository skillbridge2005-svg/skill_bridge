import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/leaderboard_entry.dart';
import '../../services/leaderboard_service.dart';
import '../../services/podium_message_sevice.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final LeaderboardService _leaderboardService = LeaderboardService();

  String _selectedRole = 'developer';

  late Future<List<LeaderboardEntry>> _leaderboardFuture;

  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _backgroundColor = Color(0xFFF8FAFC);
  static const Color _textColor = Color(0xFF0F172A);
  static const Color _secondaryTextColor = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  void _loadLeaderboard() {
    _leaderboardFuture = _leaderboardService.getLeaderboard(
      role: _selectedRole,
    );
  }

  Future<void> _refreshLeaderboard() async {
    setState(_loadLeaderboard);

    try {
      await _leaderboardFuture;
    } catch (_) {
      // The FutureBuilder displays the error state.
    }
  }

  void _changeRole(String role) {
    if (_selectedRole == role) return;

    setState(() {
      _selectedRole = role;
      _loadLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _textColor,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<LeaderboardEntry>>(
          future: _leaderboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _primaryColor),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorState();
            }

            final entries = snapshot.data ?? <LeaderboardEntry>[];

            if (entries.isEmpty) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              onRefresh: _refreshLeaderboard,
              color: _primaryColor,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 800;

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 32 : 16,
                      vertical: 20,
                    ),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildRoleSelector(),
                      const SizedBox(height: 28),
                      // NEW: animated 3D-style podium (Top Performers card).
                      TopPerformersPodium(
                        entries: entries,
                        role: _selectedRole,
                        currentUserId: FirebaseAuth.instance.currentUser?.uid,
                        idOf: (entry) => entry.uid,
                      ),
                      const SizedBox(height: 32),
                      _buildRankingHeader(entries.length),
                      const SizedBox(height: 14),
                      ...entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildRankingTile(entry),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Excellence deserves recognition!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _selectedRole == 'developer'
                      ? 'Discover top-performing developers on SkillBridge.'
                      : 'Discover clients who have successfully completed projects.',
                  style: const TextStyle(
                    color: Color(0xFFE0E7FF),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFFD166),
            size: 58,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // DEVELOPER / CLIENT SELECTOR
  // ------------------------------------------------------------

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildRoleButton(
              title: 'Developers',
              icon: Icons.code_rounded,
              role: 'developer',
            ),
          ),
          Expanded(
            child: _buildRoleButton(
              title: 'Clients',
              icon: Icons.business_center_rounded,
              role: 'client',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton({
    required String title,
    required IconData icon,
    required String role,
  }) {
    final isSelected = _selectedRole == role;

    return InkWell(
      onTap: () => _changeRole(role),
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: isSelected ? Colors.white : _secondaryTextColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : _secondaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TOP 10 RANKING HEADER
  // ------------------------------------------------------------

  Widget _buildRankingHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Text(
            'Leaderboard Rankings',
            style: TextStyle(
              color: _textColor,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count users',
            style: const TextStyle(
              color: _primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // RANKING TILE
  // ------------------------------------------------------------

  Widget _buildRankingTile(LeaderboardEntry entry) {
    final bool isTopThree = entry.rank <= 3;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTopThree ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 35,
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: TextStyle(
                  color: isTopThree ? _primaryColor : _secondaryTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildAvatar(
            name: entry.name,
            imageUrl: entry.profileImageUrl,
            radius: 25,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${entry.completedProjects} completed projects',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
                if (_selectedRole == 'developer' &&
                    entry.averageRating != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF59E0B),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        entry.averageRating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: _secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.score}',
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'POINTS',
                style: TextStyle(
                  color: _secondaryTextColor,
                  fontSize: 9,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // AVATAR
  // ------------------------------------------------------------

  Widget _buildAvatar({
    required String name,
    required String? imageUrl,
    required double radius,
  }) {
    final initial = name.trim().isNotEmpty
        ? name.trim().substring(0, 1).toUpperCase()
        : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFDBEAFE),
      backgroundImage: imageUrl != null && imageUrl.trim().isNotEmpty
          ? NetworkImage(imageUrl)
          : null,
      child: imageUrl == null || imageUrl.trim().isEmpty
          ? Text(
              initial,
              style: TextStyle(
                color: _primaryColor,
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  // ------------------------------------------------------------
  // EMPTY STATE
  // ------------------------------------------------------------

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _refreshLeaderboard,
      color: _primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: const [
          SizedBox(height: 100),
          Icon(Icons.emoji_events_outlined, size: 80, color: Color(0xFF94A3B8)),
          SizedBox(height: 20),
          Text(
            'No rankings yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Complete projects to appear on the leaderboard!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _secondaryTextColor,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ERROR STATE
  // ------------------------------------------------------------

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Colors.redAccent,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load leaderboard',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textColor,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _secondaryTextColor),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(_loadLeaderboard);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TOP PERFORMERS — ANIMATED 3D-STYLE PODIUM
//
// Everything below is dedicated to the Top Performers card. The characters,
// podiums, crown, sparkles and confetti are drawn with CustomPainter, so there
// are NO external assets, NO new dependencies and NO pubspec changes.
// ============================================================================

const Color _kInk = Color(0xFF0F172A);
const Color _kNavy = Color(0xFF0F172A);
const Color _kBlue = Color(0xFF2563EB);

enum _CelebrationPose { victory, wave, fistPump }

enum _Accessory { cape, headphones, sunglasses }

class _MetalTheme {
  const _MetalTheme({
    required this.top,
    required this.light,
    required this.mid,
    required this.dark,
    required this.glow,
  });

  final Color top;
  final Color light;
  final Color mid;
  final Color dark;
  final Color glow;
}

class _CharacterLook {
  const _CharacterLook({
    required this.skin,
    required this.hair,
    required this.shirt,
    required this.pants,
    required this.accent,
    required this.hairStyle,
    required this.accessory,
  });

  final Color skin;
  final Color hair;
  final Color shirt;
  final Color pants;
  final Color accent;
  final _Accessory accessory;

  /// 0 = short side-swept, 1 = long hair with clip, 2 = curly tufts.
  final int hairStyle;
}

class _PlaceStyle {
  const _PlaceStyle({
    required this.metal,
    required this.look,
    required this.pose,
    required this.podiumHeight,
    required this.charScale,
    required this.bounce,
    required this.phase,
  });

  final _MetalTheme metal;
  final _CharacterLook look;
  final _CelebrationPose pose;
  final double podiumHeight;
  final double charScale;
  final double bounce;
  final double phase;
}

Color _shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

Paint _spherePaint(Offset c, double r, Color light, Color dark) {
  return Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.45, -0.55),
      radius: 1.05,
      colors: [light, dark],
    ).createShader(Rect.fromCircle(center: c, radius: r));
}

void _star4(Canvas canvas, Offset c, double r, Paint paint) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final radius = i.isEven ? r : r * 0.35;
    final angle = i * math.pi / 4 - math.pi / 2;
    final p = Offset(
      c.dx + radius * math.cos(angle),
      c.dy + radius * math.sin(angle),
    );
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  canvas.drawPath(path, paint);
}

String _displayName(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? 'SkillBridge User' : trimmed;
}

class TopPerformersPodium extends StatefulWidget {
  const TopPerformersPodium({
    super.key,
    required this.entries,
    required this.role,
    required this.idOf,
    this.currentUserId,
    this.messageService,
    this.onEntryTap,
  });

  /// Full leaderboard list (already sorted). Only the first three are used.
  final List<LeaderboardEntry> entries;

  /// 'developer' or 'client' — only used for the subtitle text.
  final String role;

  /// Returns the user id (same id used as the Firebase Auth uid) of an entry.
  final String Function(LeaderboardEntry entry) idOf;

  /// The signed-in user's id. If it matches one of the top three, that
  /// performer can post or edit their cloud message.
  final String? currentUserId;

  /// Optional override (defaults to [PodiumMessageService]).
  final PodiumMessageService? messageService;

  /// Optional: hook this up to your existing profile navigation.
  final ValueChanged<LeaderboardEntry>? onEntryTap;

  @override
  State<TopPerformersPodium> createState() => _TopPerformersPodiumState();
}

class _TopPerformersPodiumState extends State<TopPerformersPodium>
    with TickerProviderStateMixin {
  // Index 0 = 1st place, 1 = 2nd place, 2 = 3rd place.
  static const List<_PlaceStyle> _styles = [
    _PlaceStyle(
      metal: _MetalTheme(
        top: Color(0xFFFFF3C4),
        light: Color(0xFFFFE08A),
        mid: Color(0xFFF5B82E),
        dark: Color(0xFFB97709),
        glow: Color(0xFFFFD166),
      ),
      look: _CharacterLook(
        skin: Color(0xFFF6CDA4),
        hair: Color(0xFF2B1B14),
        shirt: Color(0xFF2563EB),
        pants: Color(0xFF0F172A),
        accent: Color(0xFFFFC53D),
        hairStyle: 0,
        accessory: _Accessory.cape,
      ),
      pose: _CelebrationPose.victory,
      podiumHeight: 158,
      charScale: 1.5,
      bounce: 15,
      phase: 0.0,
    ),
    _PlaceStyle(
      metal: _MetalTheme(
        top: Color(0xFFFFFFFF),
        light: Color(0xFFF1F5F9),
        mid: Color(0xFFB6C2D1),
        dark: Color(0xFF7B8798),
        glow: Color(0xFFCBD5E1),
      ),
      look: _CharacterLook(
        skin: Color(0xFFC98C63),
        hair: Color(0xFF111827),
        shirt: Color(0xFF7C3AED),
        pants: Color(0xFF1E293B),
        accent: Color(0xFFF472B6),
        hairStyle: 1,
        accessory: _Accessory.headphones,
      ),
      pose: _CelebrationPose.wave,
      podiumHeight: 130,
      charScale: 1.3,
      bounce: 3,
      phase: 0.18,
    ),
    _PlaceStyle(
      metal: _MetalTheme(
        top: Color(0xFFF8CFA0),
        light: Color(0xFFF0B27A),
        mid: Color(0xFFCD7F32),
        dark: Color(0xFF8A4B1B),
        glow: Color(0xFFE59A55),
      ),
      look: _CharacterLook(
        skin: Color(0xFF8D5A3C),
        hair: Color(0xFF1F2937),
        shirt: Color(0xFF0EA5E9),
        pants: Color(0xFF0F172A),
        accent: Color(0xFFFFA45C),
        hairStyle: 2,
        accessory: _Accessory.sunglasses,
      ),
      pose: _CelebrationPose.fistPump,
      podiumHeight: 110,
      charScale: 1.3,
      bounce: 6,
      phase: 0.36,
    ),
  ];

  static const List<double> _podiumBegin = [0.25, 0.12, 0.0];
  static const List<double> _podiumEnd = [0.80, 0.67, 0.55];

  late final AnimationController _entrance;
  late final AnimationController _loop;
  late final AnimationController _confetti;

  late final List<Animation<double>> _podiumSlide;
  late final List<Animation<double>> _podiumFade;
  late final List<Animation<double>> _charScale;
  late final List<Animation<double>> _charFade;

  bool _started = false;
  bool _reduceMotion = false;

  late final PodiumMessageService _service =
      widget.messageService ?? PodiumMessageService();
  StreamSubscription<Map<String, PodiumMessage>>? _messageSub;
  Map<String, PodiumMessage> _messages = const {};
  String _idsKey = '';

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    Animation<double> interval(double a, double b, Curve curve) {
      return CurvedAnimation(
        parent: _entrance,
        curve: Interval(a, b, curve: curve),
      );
    }

    _podiumSlide = List.generate(
      3,
      (i) => interval(_podiumBegin[i], _podiumEnd[i], Curves.easeOutCubic),
    );
    _podiumFade = List.generate(
      3,
      (i) => interval(_podiumBegin[i], _podiumBegin[i] + 0.25, Curves.easeOut),
    );
    _charScale = List.generate(3, (i) {
      final begin = _podiumEnd[i] - 0.2;
      return interval(begin, math.min(begin + 0.4, 1.0), Curves.easeOutBack);
    });
    _charFade = List.generate(3, (i) {
      final begin = _podiumEnd[i] - 0.2;
      return interval(begin, begin + 0.2, Curves.easeOut);
    });

    _subscribeMessages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (_reduceMotion) {
      _loop.stop();
      _entrance.value = 1;
      _confetti.value = 0;
      _started = true;
      return;
    }

    if (!_started) {
      _started = true;
      _entrance.forward();
      _confetti.forward();
    }
    if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  String _signature(List<LeaderboardEntry> entries) {
    return entries
        .take(3)
        .map((e) => '${e.rank}|${e.name}|${e.score}')
        .join(';');
  }

  @override
  void didUpdateWidget(covariant TopPerformersPodium oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Replay the celebration only when the top three actually change.
    if (!_reduceMotion &&
        _signature(oldWidget.entries) != _signature(widget.entries)) {
      _entrance.forward(from: 0);
      _confetti.forward(from: 0);
    }

    _subscribeMessages();
  }

  /// Listens to the cloud messages of the current top three users only.
  void _subscribeMessages() {
    final ids = widget.entries
        .take(3)
        .map(widget.idOf)
        .where((id) => id.isNotEmpty)
        .toList();
    final key = ids.join(',');
    if (key == _idsKey) return;

    _idsKey = key;
    _messageSub?.cancel();
    _messageSub = null;
    _messages = const {};

    if (ids.isEmpty) return;

    _messageSub = _service.watchMessages(ids).listen(
      (messages) {
        if (!mounted) return;
        setState(() => _messages = messages);
      },
      // If reading fails the podium simply shows no clouds.
      onError: (Object _) {},
    );
  }

  bool _isOwner(String id) {
    return id.isNotEmpty &&
        widget.currentUserId != null &&
        widget.currentUserId == id;
  }

  Future<void> _openComposer(LeaderboardEntry entry) async {
    final id = widget.idOf(entry);
    if (!_isOwner(id)) return;

    final result = await showDialog<_ComposeResult>(
      context: context,
      builder: (_) => _PodiumMessageDialog(
        initialText: _messages[id]?.text ?? '',
        maxLength: PodiumMessageService.maxLength,
      ),
    );
    if (result == null || !mounted) return;

    try {
      if (result.delete) {
        await _service.deleteMessage(id);
      } else {
        await _service.setMessage(
          userId: id,
          name: _displayName(entry.name),
          text: result.text,
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update your message. Please try again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _entrance.dispose();
    _loop.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = widget.entries.take(3).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    final isDeveloper = widget.role == 'developer';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A8A), Color(0xFF172554), _kNavy],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stageW = constraints.maxWidth;
                    final s = (stageW / 360).clamp(0.7, 1.45).toDouble();
                    final bs = s.clamp(0.95, 1.2).toDouble();
                    final firstId = widget.idOf(top.first);
                    final firstHasCloud =
                        _messages[firstId] != null || _isOwner(firstId);
                    // Extra headroom above the winner only when a cloud shows.
                    final stageH = firstHasCloud ? 355 * s + 118 * bs : 360 * s;
                    final slotW = stageW / 3;

                    // Visual order: 2nd | 1st | 3rd (only for qualified users).
                    final slots = <Widget>[];
                    for (final place in const [1, 0, 2]) {
                      if (place >= top.length) continue;
                      slots.add(
                        _buildSlot(
                          place: place,
                          entry: top[place],
                          slotW: slotW,
                          stageH: stageH,
                          s: s,
                        ),
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTitle(isDeveloper),
                        const SizedBox(height: 14),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                          width: stageW,
                          height: stageH,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Rotating light rays + glow behind the winner.
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: RepaintBoundary(
                                    child: CustomPaint(
                                      painter: _RaysPainter(
                                        loop: _loop,
                                        radius: 230 * s,
                                        glow: _styles[0].metal.glow,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Floating sparkles.
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: RepaintBoundary(
                                    child: CustomPaint(
                                      painter: _SparklePainter(
                                        loop: _loop,
                                        scale: s,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: slots,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Floor line the podiums stand on.
                        Container(
                          width: stageW,
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.28),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // Confetti burst when the card appears.
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _ConfettiPainter(_confetti)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // TITLE
  // ------------------------------------------------------------

  Widget _buildTitle(bool isDeveloper) {
    Widget line({required bool fadeOut}) {
      return Expanded(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: fadeOut
                  ? [Colors.white.withValues(alpha: 0.4), Colors.transparent]
                  : [Colors.transparent, Colors.white.withValues(alpha: 0.4)],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            line(fadeOut: false),
            const SizedBox(width: 10),
            const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFFFD166),
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              'TOP PERFORMERS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            line(fadeOut: true),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isDeveloper
              ? 'Celebrating the best developers'
              : 'Celebrating the best clients',
          style: const TextStyle(
            color: Color(0xFFBFDBFE),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // ONE PODIUM SLOT (podium + character + crown)
  // ------------------------------------------------------------

  Widget _buildSlot({
    required int place,
    required LeaderboardEntry entry,
    required double slotW,
    required double stageH,
    required double s,
  }) {
    final style = _styles[place];
    final podiumH = style.podiumHeight * s;
    final depth = 14 * s;
    final podiumW = math.max(48.0, math.min(slotW - 6, 118 * s));
    final charW = 76 * s * style.charScale;
    final charH = 95 * s * style.charScale;
    final charBottom = podiumH - depth * 0.5;
    final isFirst = place == 0;
    final crownW = 42 * s;
    final crownH = 32 * s;

    // Cloud message (opinion) shown above the character's head.
    final id = widget.idOf(entry);
    final message = _messages[id];
    final isOwner = _isOwner(id);
    final bs = s.clamp(0.95, 1.2).toDouble();
    final cloudW = slotW * (isFirst ? 1.7 : 1.2);
    final headTop = charBottom + charH * 0.96;
    final cloudBottom = isFirst
        ? headTop + 3 * s + crownH + style.bounce * s + 13 * s
        : headTop + style.bounce * s + 10 * s;

    return _HoverLift(
      onTap: widget.onEntryTap == null ? null : () => widget.onEntryTap!(entry),
      child: SizedBox(
        width: slotW,
        height: stageH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Podium
            Positioned(
              bottom: 0,
              left: (slotW - podiumW) / 2,
              width: podiumW,
              height: podiumH,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.45),
                  end: Offset.zero,
                ).animate(_podiumSlide[place]),
                child: FadeTransition(
                  opacity: _podiumFade[place],
                  child: _PodiumBlock(
                    entry: entry,
                    style: style,
                    scale: s,
                    depth: depth,
                    loop: _loop,
                  ),
                ),
              ),
            ),
            // Celebrating character
            Positioned(
              bottom: charBottom,
              left: (slotW - charW) / 2,
              width: charW,
              height: charH,
              child: FadeTransition(
                opacity: _charFade[place],
                child: ScaleTransition(
                  scale: _charScale[place],
                  alignment: Alignment.bottomCenter,
                  child: AnimatedBuilder(
                    animation: _loop,
                    builder: (context, child) {
                      final t = (_loop.value + style.phase) % 1.0;
                      final jump = math.max(0.0, math.sin(2 * math.pi * t));
                      final breathe = math.sin(4 * math.pi * t);
                      final k = (style.bounce / 15).clamp(0.2, 1.0).toDouble();
                      final sy =
                          1 +
                          0.06 * k * jump -
                          0.025 * k * (1 - jump) +
                          0.01 * breathe;
                      final sx = 1 / sy;
                      return Transform.translate(
                        offset: Offset(0, -style.bounce * s * jump),
                        child: Transform.scale(
                          scaleX: sx,
                          scaleY: sy,
                          alignment: Alignment.bottomCenter,
                          child: child,
                        ),
                      );
                    },
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _CharacterPainter(
                          look: style.look,
                          pose: style.pose,
                          loop: _loop,
                          phase: style.phase,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Floating golden crown for the winner
            if (isFirst)
              Positioned(
                bottom: charBottom + charH * 0.96 + 3 * s,
                left: (slotW - crownW) / 2,
                width: crownW,
                height: crownH,
                child: FadeTransition(
                  opacity: _charFade[place],
                  child: ScaleTransition(
                    scale: _charScale[place],
                    alignment: Alignment.bottomCenter,
                    child: AnimatedBuilder(
                      animation: _loop,
                      builder: (context, child) {
                        final t = (_loop.value + style.phase) % 1.0;
                        final jump = math.max(0.0, math.sin(2 * math.pi * t));
                        final dy =
                            -style.bounce * s * jump -
                            3 * s * math.sin(2 * math.pi * _loop.value);
                        return Transform.translate(
                          offset: Offset(0, dy),
                          child: Transform.rotate(
                            angle: 0.1 * math.sin(2 * math.pi * _loop.value),
                            child: child,
                          ),
                        );
                      },
                      child: const RepaintBoundary(
                        child: CustomPaint(painter: _CrownPainter()),
                      ),
                    ),
                  ),
                ),
              ),
            // Opinion cloud (visible to everyone; editable by its owner).
            if (message != null || isOwner)
              Positioned(
                bottom: cloudBottom,
                left: (slotW - cloudW) / 2,
                width: cloudW,
                child: FadeTransition(
                  opacity: _charFade[place],
                  child: ScaleTransition(
                    scale: _charScale[place],
                    alignment: Alignment.bottomCenter,
                    child: AnimatedBuilder(
                      animation: _loop,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            0,
                            2 *
                                bs *
                                math.sin(2 * math.pi * _loop.value + place),
                          ),
                          child: child,
                        );
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: animation,
                              alignment: Alignment.bottomCenter,
                              child: child,
                            ),
                          );
                        },
                        child: _SpeechCloud(
                          key: ValueKey(message?.text ?? '__placeholder'),
                          text: message?.text,
                          scale: bs,
                          isOwner: isOwner,
                          accent: style.metal.mid,
                          onTap: isOwner ? () => _openComposer(entry) : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HOVER LIFT (desktop / web)
// ============================================================================

class _HoverLift extends StatefulWidget {
  const _HoverLift({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: AnimatedSlide(
            offset: _hovered ? const Offset(0, -0.012) : Offset.zero,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PODIUM BLOCK (3D metallic step + user plate)
// ============================================================================

class _PodiumBlock extends StatelessWidget {
  const _PodiumBlock({
    required this.entry,
    required this.style,
    required this.scale,
    required this.depth,
    required this.loop,
  });

  final LeaderboardEntry entry;
  final _PlaceStyle style;
  final double scale;
  final double depth;
  final Animation<double> loop;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final isFirst = style.podiumHeight >= 150;
    final name = _displayName(entry.name);
    final projects = entry.completedProjects;

    return LayoutBuilder(
      builder: (context, constraints) {
        final nameWidth = math.max(36.0, constraints.maxWidth - 14 * s);

        return CustomPaint(
          painter: _PodiumPainter(
            metal: style.metal,
            depth: depth,
            shimmer: loop,
            phase: style.phase,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(5 * s, depth + 7 * s, 5 * s, 5 * s),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PodiumAvatar(
                    name: name,
                    imageUrl: entry.profileImageUrl,
                    radius: (isFirst ? 22 : 18) * s,
                    medalSize: (isFirst ? 22 : 18) * s,
                    rank: entry.rank,
                    metal: style.metal,
                  ),
                  SizedBox(height: 8 * s),
                  SizedBox(
                    width: nameWidth,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _kInk,
                        fontSize: (isFirst ? 13.5 : 12) * s,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(height: 3 * s),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 9 * s,
                      vertical: 2.5 * s,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Text(
                      '${entry.score} pts',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: 11 * s,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(height: 3 * s),
                  Text(
                    '$projects ${projects == 1 ? 'project' : 'projects'}',
                    maxLines: 1,
                    style: TextStyle(
                      color: _kInk.withValues(alpha: 0.72),
                      fontSize: 10 * s,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PodiumAvatar extends StatelessWidget {
  const _PodiumAvatar({
    required this.name,
    required this.imageUrl,
    required this.radius,
    required this.medalSize,
    required this.rank,
    required this.metal,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final double medalSize;
  final int rank;
  final _MetalTheme metal;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    final size = radius * 2;

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: const Color(0xFFDBEAFE),
      child: Text(
        initial,
        style: TextStyle(
          color: _kBlue,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.all(radius * 0.12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, metal.dark],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: url.isEmpty
                  ? fallback
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => fallback,
                    ),
            ),
          ),
        ),
        Positioned(
          right: -medalSize * 0.32,
          bottom: -medalSize * 0.22,
          child: _Medal(rank: rank, metal: metal, size: medalSize),
        ),
      ],
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.rank, required this.metal, required this.size});

  final int rank;
  final _MetalTheme metal;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [metal.top, metal.mid, metal.dark],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: Colors.white, width: size * 0.07),
        boxShadow: [
          BoxShadow(
            color: metal.glow.withValues(alpha: 0.6),
            blurRadius: size * 0.5,
          ),
        ],
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: _kInk,
          fontSize: size * 0.54,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

// ============================================================================
// PAINTERS
// ============================================================================

/// Metallic 3D podium step: glossy front face, perspective top face,
/// animated shimmer sweep.
class _PodiumPainter extends CustomPainter {
  _PodiumPainter({
    required this.metal,
    required this.depth,
    required Animation<double> shimmer,
    required this.phase,
  }) : _shimmer = shimmer,
       super(repaint: shimmer);

  final _MetalTheme metal;
  final double depth;
  final double phase;
  final Animation<double> _shimmer;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final d = depth;
    final inset = d * 0.8;

    // Soft ground shadow.
    canvas.drawOval(
      Rect.fromLTWH(-6, h - 6, w + 12, 12),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Front face.
    final front = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, d, w, h - d),
      bottomLeft: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );
    canvas.drawRRect(
      front,
      Paint()
        ..shader = LinearGradient(
          colors: [metal.mid, metal.light, metal.mid, metal.dark],
          stops: const [0.0, 0.28, 0.62, 1.0],
        ).createShader(front.outerRect),
    );
    canvas.drawRRect(
      front,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)],
        ).createShader(front.outerRect),
    );

    // Moving gloss band.
    canvas.save();
    canvas.clipRRect(front);
    final p = (_shimmer.value + phase) % 1.0;
    final x = -w * 0.5 + p * w * 2.0;
    final band = Path()
      ..moveTo(x, d)
      ..lineTo(x + w * 0.16, d)
      ..lineTo(x + w * 0.16 - h * 0.35, h)
      ..lineTo(x - h * 0.35, h)
      ..close();
    canvas.drawPath(band, Paint()..color = Colors.white.withValues(alpha: 0.2));
    canvas.restore();

    // Front outline.
    canvas.drawRRect(
      front,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    // Top face (perspective trapezoid).
    final topFace = Path()
      ..moveTo(inset, 0)
      ..lineTo(w - inset, 0)
      ..lineTo(w, d)
      ..lineTo(0, d)
      ..close();
    canvas.drawPath(
      topFace,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [metal.top, metal.light],
        ).createShader(Rect.fromLTWH(0, 0, w, d)),
    );
    canvas.drawPath(
      topFace,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    // Bright bevel edge between top and front.
    canvas.drawLine(
      Offset(0, d),
      Offset(w, d),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _PodiumPainter old) =>
      old.metal != metal || old.depth != depth || old.phase != phase;
}

/// Cute 3D-shaded chibi character, fully animated (arms, blink, head tilt).
/// Drawn in an 80x100 coordinate space and scaled to fit.
class _CharacterPainter extends CustomPainter {
  _CharacterPainter({
    required this.look,
    required this.pose,
    required Animation<double> loop,
    required this.phase,
  }) : _loop = loop,
       super(repaint: loop);

  final _CharacterLook look;
  final _CelebrationPose pose;
  final double phase;
  final Animation<double> _loop;

  @override
  void paint(Canvas canvas, Size size) {
    final t = (_loop.value + phase) % 1.0;
    final s1 = math.sin(2 * math.pi * t);
    final s2 = math.sin(4 * math.pi * t);

    canvas.save();
    canvas.scale(size.width / 80, size.height / 100);

    // Contact shadow on the podium top.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(40, 96.5), width: 46, height: 7),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    if (look.accessory == _Accessory.cape) {
      _drawCape(canvas, s1, s2);
    }
    _drawLegs(canvas);
    _drawTorso(canvas);
    _drawArms(canvas, s2);
    _drawHead(canvas, t, s1);

    canvas.restore();
  }

  void _drawLegs(Canvas canvas) {
    for (final cx in const [32.0, 48.0]) {
      final leg = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 6, 74, 12, 19),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        leg,
        Paint()
          ..shader = LinearGradient(
            colors: [_shade(look.pants, 0.08), _shade(look.pants, -0.06)],
          ).createShader(leg.outerRect),
      );

      final shoe = Rect.fromCenter(
        center: Offset(cx + (cx < 40 ? -1.5 : 1.5), 94.5),
        width: 17,
        height: 8.5,
      );
      canvas.drawOval(
        shoe,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFCBD5E1)],
          ).createShader(shoe),
      );
      canvas.drawArc(
        shoe.deflate(0.6),
        0.15,
        math.pi - 0.3,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = look.accent,
      );
    }
  }

  void _drawTorso(Canvas canvas) {
    final torso = RRect.fromRectAndRadius(
      const Rect.fromLTRB(23, 47, 57, 80),
      const Radius.circular(13),
    );
    canvas.drawRRect(
      torso,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _shade(look.shirt, 0.12),
            look.shirt,
            _shade(look.shirt, -0.12),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(torso.outerRect),
    );
    // Soft highlight on the left side for volume.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 50, 9, 22),
        const Radius.circular(5),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
    // Chest emblem.
    canvas.drawCircle(
      const Offset(40, 63),
      5.2,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.drawCircle(const Offset(40, 63), 3.2, Paint()..color = look.accent);
  }

  void _drawArms(Canvas canvas, double s2) {
    const double pi = math.pi;
    const ls = Offset(27, 55);
    const rs = Offset(53, 55);

    final twinkle = 0.5 + 0.5 * s2;

    switch (pose) {
      case _CelebrationPose.victory:
        // Both arms up, cheering, with golden sparkles at the hands.
        final leftHand = _arm(
          canvas,
          ls,
          -pi / 2 - 1.0 + 0.22 * s2,
          -pi / 2 - 0.35 + 0.35 * s2,
        );
        final rightHand = _arm(
          canvas,
          rs,
          -pi / 2 + 1.0 - 0.22 * s2,
          -pi / 2 + 0.35 - 0.35 * s2,
        );
        final starPaint = Paint()
          ..color = const Color(0xFFFFE08A)
              .withValues(alpha: 0.4 + 0.6 * twinkle);
        _star4(
          canvas,
          leftHand.translate(-6, -8),
          3.2 + 1.5 * twinkle,
          starPaint,
        );
        _star4(
          canvas,
          rightHand.translate(6, -8),
          3.2 + 1.5 * (1 - twinkle),
          starPaint,
        );
      case _CelebrationPose.wave:
        // Left arm relaxed, right hand waving with motion arcs.
        _arm(canvas, ls, pi / 2 + 0.35, pi / 2 + 0.1);
        final waveHand = _arm(canvas, rs, -0.55, -pi / 2 + 0.55 * s2);
        final wavePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.25 + 0.55 * twinkle);
        for (var i = 0; i < 2; i++) {
          canvas.drawArc(
            Rect.fromCenter(
              center: waveHand.translate(5 + i * 4.0, -1),
              width: 8 + i * 4.0,
              height: 12 + i * 5.0,
            ),
            -0.9,
            1.8,
            false,
            wavePaint,
          );
        }
      case _CelebrationPose.fistPump:
        // Left hand on hip, right fist pumping with power lines.
        _arm(canvas, ls, pi / 2 + 0.55, pi / 2 - 0.45);
        final fistHand = _arm(
          canvas,
          rs,
          -0.5 - 0.22 * s2,
          -pi / 2 + 0.15 - 0.45 * s2,
          handRadius: 6.0,
        );
        final powerPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFFE08A)
              .withValues(alpha: 0.35 + 0.65 * twinkle);
        for (final a in const [-2.2, -1.57, -0.95]) {
          canvas.drawLine(
            fistHand + Offset(math.cos(a) * 9, math.sin(a) * 9),
            fistHand + Offset(math.cos(a) * 14, math.sin(a) * 14),
            powerPaint,
          );
        }
    }
  }

  Offset _arm(
    Canvas canvas,
    Offset shoulder,
    double upperAngle,
    double foreAngle, {
    double handRadius = 5.4,
  }) {
    final elbow =
        shoulder + Offset(math.cos(upperAngle) * 12, math.sin(upperAngle) * 12);
    final hand =
        elbow + Offset(math.cos(foreAngle) * 12, math.sin(foreAngle) * 12);

    final path = Path()
      ..moveTo(shoulder.dx, shoulder.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(hand.dx, hand.dy);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _shade(look.shirt, -0.14),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = look.shirt,
    );
    canvas.drawCircle(
      hand,
      handRadius,
      _spherePaint(
        hand,
        handRadius,
        _shade(look.skin, 0.1),
        _shade(look.skin, -0.1),
      ),
    );
    return hand;
  }

  void _drawHead(Canvas canvas, double t, double s1) {
    canvas.save();
    // Gentle head tilt.
    canvas.translate(40, 50);
    canvas.rotate(0.05 * s1);
    canvas.translate(-40, -50);

    const center = Offset(40, 29);

    // Back hair (long style).
    if (look.hairStyle == 1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(15, 13, 65, 55),
          const Radius.circular(21),
        ),
        Paint()..color = _shade(look.hair, -0.08),
      );
    }

    // Ears.
    for (final x in const [19.0, 61.0]) {
      canvas.drawCircle(
        Offset(x, 31),
        4.2,
        Paint()..color = _shade(look.skin, -0.06),
      );
    }

    // Face.
    canvas.drawCircle(
      center,
      21,
      _spherePaint(center, 21, _shade(look.skin, 0.1), _shade(look.skin, -0.1)),
    );

    _drawFace(canvas, t);
    _drawFrontHair(canvas);

    if (look.accessory == _Accessory.sunglasses) {
      _drawSunglasses(canvas);
    } else if (look.accessory == _Accessory.headphones) {
      _drawHeadphones(canvas);
    }

    canvas.restore();
  }

  void _drawFace(Canvas canvas, double t) {
    // Blush.
    final blush = Paint()
      ..color = const Color(0xFFFB7185).withValues(alpha: 0.32);
    canvas.drawCircle(const Offset(28.5, 36), 4, blush);
    canvas.drawCircle(const Offset(51.5, 36), 4, blush);

    const eyeL = Offset(32.5, 31);
    const eyeR = Offset(47.5, 31);
    const inkColor = Color(0xFF1E293B);
    final happy = pose == _CelebrationPose.victory;

    if (happy) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = inkColor;
      for (final e in const [eyeL, eyeR]) {
        canvas.drawArc(
          Rect.fromCenter(center: e.translate(0, 1.5), width: 7.5, height: 7),
          math.pi,
          math.pi,
          false,
          stroke,
        );
      }
    } else {
      final blink = t > 0.82 && t < 0.87;
      final eyeH = blink ? 1.2 : 8.4;
      for (final e in const [eyeL, eyeR]) {
        canvas.drawOval(
          Rect.fromCenter(center: e, width: 6.6, height: eyeH),
          Paint()..color = inkColor,
        );
        if (!blink) {
          canvas.drawCircle(
            e.translate(-1.3, -2.3),
            1.8,
            Paint()..color = Colors.white,
          );
          canvas.drawCircle(
            e.translate(1.3, 1.9),
            0.8,
            Paint()..color = Colors.white.withValues(alpha: 0.85),
          );
        }
      }
    }

    // Eyebrows.
    final brow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..color = _shade(look.hair, -0.02);
    final lift = happy ? 1.5 : 0.0;
    canvas.drawLine(Offset(29.5, 24.5 - lift), Offset(35.5, 23.5 - lift), brow);
    canvas.drawLine(Offset(44.5, 23.5 - lift), Offset(50.5, 24.5 - lift), brow);

    // Mouth.
    if (pose == _CelebrationPose.wave) {
      canvas.drawPath(
        Path()
          ..moveTo(35, 37.5)
          ..quadraticBezierTo(40, 42.5, 45, 37.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF7C2D12),
      );
    } else {
      final mouth = Path()
        ..moveTo(34.5, 37)
        ..quadraticBezierTo(40, 39, 45.5, 37)
        ..quadraticBezierTo(40, 47.5, 34.5, 37)
        ..close();
      canvas.drawPath(mouth, Paint()..color = const Color(0xFF7F1D1D));
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(40, 42.6), width: 6, height: 3.4),
        Paint()..color = const Color(0xFFFB7185),
      );
    }
  }

  /// Flowing hero cape with gold trim (first place).
  void _drawCape(Canvas canvas, double s1, double s2) {
    const capeColor = Color(0xFFE11D48);
    final sway = s1 * 4;
    final ripple = s2 * 2.5;

    final cape = Path()
      ..moveTo(28, 52)
      ..lineTo(52, 52)
      ..quadraticBezierTo(70 + sway, 68, 69 + sway * 1.4, 90)
      ..quadraticBezierTo(55, 86 + ripple, 40, 92)
      ..quadraticBezierTo(25, 86 - ripple, 11 - sway * 1.4, 90)
      ..quadraticBezierTo(10 - sway, 68, 28, 52)
      ..close();

    canvas.drawPath(
      cape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_shade(capeColor, 0.08), _shade(capeColor, -0.14)],
        ).createShader(const Rect.fromLTWH(8, 50, 64, 44)),
    );
    canvas.drawPath(
      cape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFFFD166),
    );
    canvas.drawLine(
      const Offset(40, 56),
      Offset(40 + sway * 0.3, 90),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..strokeWidth = 1.2,
    );
  }

  /// Cool glossy shades (third place).
  void _drawSunglasses(Canvas canvas) {
    const frame = Color(0xFF0B1220);

    for (final cx in const [32.5, 47.5]) {
      final lens = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, 31.5), width: 13, height: 9),
        const Radius.circular(3.6),
      );
      canvas.drawRRect(
        lens,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A8A), frame],
          ).createShader(lens.outerRect),
      );
      canvas.drawRRect(
        lens,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = frame,
      );
      canvas.drawLine(
        Offset(cx - 3.5, 33.6),
        Offset(cx + 0.5, 28.8),
        Paint()
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    final framePaint = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = frame;
    canvas.drawLine(const Offset(39, 30.5), const Offset(41, 30.5), framePaint);
    canvas.drawLine(const Offset(26, 30.5), const Offset(21, 30), framePaint);
    canvas.drawLine(const Offset(54, 30.5), const Offset(59, 30), framePaint);
  }

  /// Studio headphones (second place).
  void _drawHeadphones(Canvas canvas) {
    final band = Rect.fromCircle(center: const Offset(40, 29), radius: 24.5);

    canvas.drawArc(
      band,
      math.pi + 0.12,
      math.pi - 0.24,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF1E293B),
    );
    canvas.drawArc(
      band,
      math.pi + 0.3,
      math.pi - 0.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = look.accent.withValues(alpha: 0.9),
    );

    for (final cx in const [15.5, 64.5]) {
      final cup = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, 32), width: 8, height: 14),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        cup,
        Paint()
          ..shader = LinearGradient(
            colors: [_shade(look.accent, 0.1), _shade(look.accent, -0.12)],
          ).createShader(cup.outerRect),
      );
      canvas.drawRRect(
        cup,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = const Color(0xFF1E293B),
      );
      canvas.drawLine(
        Offset(cx - 1.2, 28),
        Offset(cx - 1.2, 33),
        Paint()
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.45),
      );
    }
  }

  Paint _hairPaint() {
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_shade(look.hair, 0.12), _shade(look.hair, -0.06)],
      ).createShader(const Rect.fromLTWH(14, 4, 52, 30));
  }

  void _drawFrontHair(Canvas canvas) {
    final paint = _hairPaint();

    // Curly tufts behind the cap.
    if (look.hairStyle == 2) {
      canvas.drawCircle(const Offset(31, 11), 7.4, paint);
      canvas.drawCircle(const Offset(40, 8.5), 8.2, paint);
      canvas.drawCircle(const Offset(49, 11), 7.4, paint);
    }

    final cap = Path()
      ..moveTo(17.5, 29)
      ..arcTo(
        Rect.fromCircle(center: const Offset(40, 29), radius: 22.5),
        math.pi,
        math.pi,
        false,
      )
      ..quadraticBezierTo(60.5, 20, 48, 17.5)
      ..quadraticBezierTo(36, 21, 17.5, 27)
      ..close();
    canvas.drawPath(cap, paint);

    // Hair gloss.
    canvas.drawOval(
      const Rect.fromLTWH(28, 9.5, 11, 4.5),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    // Hair clip.
    if (look.hairStyle == 1) {
      canvas.drawCircle(
        const Offset(55, 15),
        3.1,
        Paint()..color = look.accent,
      );
      canvas.drawCircle(
        const Offset(55, 15),
        1.2,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CharacterPainter old) =>
      old.look != look || old.pose != pose || old.phase != phase;
}

/// Golden crown with a soft glow, drawn in a 40x30 space.
class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 30);

    final body = Path()
      ..moveTo(5, 26)
      ..lineTo(2.5, 9)
      ..lineTo(12.5, 17)
      ..lineTo(20, 3.5)
      ..lineTo(27.5, 17)
      ..lineTo(37.5, 9)
      ..lineTo(35, 26)
      ..close();

    // Glow.
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFFFFD166).withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Gold body.
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF1B8), Color(0xFFF5B82E), Color(0xFFB97709)],
        ).createShader(const Rect.fromLTWH(0, 0, 40, 30)),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF9A5B06),
    );

    // Band.
    final band = RRect.fromRectAndRadius(
      const Rect.fromLTRB(4.6, 22, 35.4, 28),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(
      band,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5B82E), Color(0xFF9A5B06)],
        ).createShader(band.outerRect),
    );

    // Tip pearls.
    for (final p in const [
      Offset(2.5, 8.5),
      Offset(20, 3),
      Offset(37.5, 8.5),
    ]) {
      canvas.drawCircle(
        p,
        2.6,
        _spherePaint(p, 2.6, Colors.white, const Color(0xFFFFD166)),
      );
    }

    // Band gems.
    const gems = [Offset(12, 25), Offset(20, 25), Offset(28, 25)];
    const gemColors = [Color(0xFF60A5FA), Color(0xFFF43F5E), Color(0xFF60A5FA)];
    for (var i = 0; i < gems.length; i++) {
      canvas.drawCircle(gems[i], 1.8, Paint()..color = gemColors[i]);
      canvas.drawCircle(
        gems[i].translate(-0.5, -0.5),
        0.6,
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Slowly rotating light rays and a pulsing golden glow behind the winner.
class _RaysPainter extends CustomPainter {
  _RaysPainter({
    required Animation<double> loop,
    required this.radius,
    required this.glow,
  }) : _loop = loop,
       super(repaint: loop);

  final Animation<double> _loop;
  final double radius;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - radius * 0.95);
    final pulse = 1 + 0.05 * math.sin(2 * math.pi * _loop.value);

    // Glow.
    final glowRadius = radius * 0.62 * pulse;
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: 0.42),
            glow.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );

    // Rays. The pattern repeats every 30°, so the loop is seamless.
    const rayCount = 12;
    const step = 2 * math.pi / rayCount;
    final rotation = _loop.value * step;
    final rayPaint = Paint()
      ..shader = RadialGradient(
        colors: [glow.withValues(alpha: 0.22), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    for (var k = 0; k < rayCount; k++) {
      final a = k * step + rotation;
      const half = 0.1;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + radius * math.cos(a - half),
          center.dy + radius * math.sin(a - half),
        )
        ..lineTo(
          center.dx + radius * math.cos(a + half),
          center.dy + radius * math.sin(a + half),
        )
        ..close();
      canvas.drawPath(path, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) =>
      old.radius != radius || old.glow != glow;
}

class _Spark {
  const _Spark(this.fx, this.fy, this.size, this.phase, this.speed, this.color);

  final double fx;
  final double fy;
  final double size;
  final double phase;
  final int speed;
  final Color color;
}

final List<_Spark> _sparks = _buildSparks();

List<_Spark> _buildSparks() {
  final r = math.Random(11);
  const colors = [Color(0xFFFFE08A), Colors.white, Color(0xFF93C5FD)];
  return List.generate(
    18,
    (i) => _Spark(
      0.03 + r.nextDouble() * 0.94,
      0.02 + r.nextDouble() * 0.78,
      3 + r.nextDouble() * 4.5,
      r.nextDouble(),
      1 + r.nextInt(2),
      colors[i % colors.length],
    ),
  );
}

/// Twinkling, gently floating four-point stars.
class _SparklePainter extends CustomPainter {
  _SparklePainter({required Animation<double> loop, required this.scale})
    : _loop = loop,
      super(repaint: loop);

  final Animation<double> _loop;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    for (final sp in _sparks) {
      final t = (_loop.value * sp.speed + sp.phase) % 1.0;
      final twinkle = 0.5 + 0.5 * math.sin(2 * math.pi * t);
      final pos = Offset(
        sp.fx * size.width,
        sp.fy * size.height + math.sin(2 * math.pi * t) * 5 * scale,
      );
      final r = sp.size * scale * (0.45 + 0.55 * twinkle);
      _drawStar(
        canvas,
        pos,
        r,
        Paint()..color = sp.color.withValues(alpha: 0.25 + 0.75 * twinkle),
      );
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final radius = i.isEven ? r : r * 0.35;
      final angle = i * math.pi / 4 - math.pi / 2;
      final p = Offset(
        c.dx + radius * math.cos(angle),
        c.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.scale != scale;
}

class _ConfettiBit {
  const _ConfettiBit({
    required this.fx,
    required this.delay,
    required this.speed,
    required this.swing,
    required this.swingFreq,
    required this.spin,
    required this.w,
    required this.h,
    required this.color,
  });

  final double fx;
  final double delay;
  final double speed;
  final double swing;
  final double swingFreq;
  final double spin;
  final double w;
  final double h;
  final Color color;
}

final List<_ConfettiBit> _confettiBits = _buildConfetti();

List<_ConfettiBit> _buildConfetti() {
  final r = math.Random(42);
  const colors = [
    Color(0xFFFFD166),
    Colors.white,
    Color(0xFF93C5FD),
    Color(0xFFF472B6),
    Color(0xFFA5B4FC),
    Color(0xFF6EE7B7),
    Color(0xFFFDE68A),
  ];
  return List.generate(
    42,
    (i) => _ConfettiBit(
      fx: r.nextDouble(),
      delay: r.nextDouble() * 0.25,
      speed: 0.8 + r.nextDouble() * 0.4,
      swing: 6 + r.nextDouble() * 14,
      swingFreq: 1 + r.nextDouble() * 2,
      spin: 1 + r.nextDouble() * 3,
      w: 4 + r.nextDouble() * 4,
      h: 2.5 + r.nextDouble() * 2,
      color: colors[i % colors.length],
    ),
  );
}

/// One-shot confetti shower that plays when the card appears.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(Animation<double> progress)
    : _progress = progress,
      super(repaint: progress);

  final Animation<double> _progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _progress.value;
    if (p <= 0 || p >= 1) return;

    for (final bit in _confettiBits) {
      final local = ((p - bit.delay) / (1 - bit.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      final y = -12 + (size.height + 24) * math.pow(local, 0.85) * bit.speed;
      final x =
          bit.fx * size.width +
          math.sin(local * 2 * math.pi * bit.swingFreq + bit.fx * 10) *
              bit.swing;
      final opacity = local > 0.85 ? (1 - local) / 0.15 : 1.0;
      final flip = (0.35 + 0.65 * math.cos(local * bit.spin * 5).abs());

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * bit.spin * 2 * math.pi);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: bit.w,
          height: bit.h * flip,
        ),
        Paint()..color = bit.color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => false;
}

// ============================================================================
// CLOUD MESSAGE (speech / thought cloud shown above a top performer)
// ============================================================================

class _SpeechCloud extends StatelessWidget {
  const _SpeechCloud({
    super.key,
    required this.text,
    required this.scale,
    required this.isOwner,
    required this.accent,
    this.onTap,
  });

  /// `null` means "placeholder" (owner has not written a message yet).
  final String? text;
  final double scale;
  final bool isOwner;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bs = scale;
    final bump = 6.5 * bs;
    final isPlaceholder = text == null;
    final label = text ?? 'Tap to share your thoughts';

    Widget dot(double d) => Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            painter: _CloudPainter(
              bump: bump,
              opacity: isPlaceholder ? 0.82 : 1.0,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                bump + 5 * bs,
                bump + 3 * bs,
                bump + 5 * bs,
                bump + 3 * bs,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaceholder ? const Color(0xFF64748B) : _kInk,
                      fontSize: 10.5 * bs,
                      height: 1.25,
                      fontWeight: isPlaceholder
                          ? FontWeight.w600
                          : FontWeight.w700,
                      fontStyle: isPlaceholder
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  if (isOwner)
                    Positioned(
                      right: -bump * 1.3,
                      top: -bump * 1.2,
                      child: Container(
                        width: 15 * bs,
                        height: 15 * bs,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 9 * bs,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 1.5 * bs),
          // Thought-bubble tail drifting down towards the character.
          dot(8 * bs),
          SizedBox(height: 2 * bs),
          dot(5.5 * bs),
          SizedBox(height: 2 * bs),
          dot(3.5 * bs),
        ],
      ),
    );
  }
}

/// Scalloped cloud outline: a rounded rectangle with bumps all around.
class _CloudPainter extends CustomPainter {
  const _CloudPainter({required this.bump, required this.opacity});

  final double bump;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final r = bump;
    final inner = Rect.fromLTRB(r, r, size.width - r, size.height - r);
    if (inner.width <= 0 || inner.height <= 0) return;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(inner, Radius.circular(r * 0.6)));

    final nx = math.max(2, (inner.width / (r * 1.5)).round());
    for (var i = 0; i <= nx; i++) {
      final x = inner.left + inner.width * i / nx;
      path.addOval(Rect.fromCircle(center: Offset(x, inner.top), radius: r));
      path.addOval(Rect.fromCircle(center: Offset(x, inner.bottom), radius: r));
    }
    final ny = math.max(1, (inner.height / (r * 1.5)).round());
    for (var j = 0; j <= ny; j++) {
      final y = inner.top + inner.height * j / ny;
      path.addOval(Rect.fromCircle(center: Offset(inner.left, y), radius: r));
      path.addOval(Rect.fromCircle(center: Offset(inner.right, y), radius: r));
    }

    // Soft shadow.
    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Cloud body.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: opacity),
            const Color(0xFFE0ECFF).withValues(alpha: opacity),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _CloudPainter old) =>
      old.bump != bump || old.opacity != opacity;
}

class _ComposeResult {
  const _ComposeResult.post(this.text) : delete = false;
  const _ComposeResult.remove() : text = '', delete = true;

  final String text;
  final bool delete;
}

class _PodiumMessageDialog extends StatefulWidget {
  const _PodiumMessageDialog({
    required this.initialText,
    required this.maxLength,
  });

  final String initialText;
  final int maxLength;

  @override
  State<_PodiumMessageDialog> createState() => _PodiumMessageDialogState();
}

class _PodiumMessageDialogState extends State<_PodiumMessageDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'Your message to everyone',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'As a top performer, you can share a short opinion. '
            'Everyone will see it in the cloud above you.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxLength,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Write your opinion…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.initialText.isNotEmpty)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const _ComposeResult.remove()),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;
            Navigator.pop(context, _ComposeResult.post(text));
          },
          child: const Text('Post'),
        ),
      ],
    );
  }
}
