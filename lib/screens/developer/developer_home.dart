import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'developer_profile.dart';
import '../settings/settings_screen.dart';

/// SkillBridge Developer Dashboard
///
/// This screen is intentionally self-contained and uses only Flutter + the
/// Firebase packages already used by the SkillBridge auth flow.
///
/// It is designed as the developer's command center:
/// - profile completion + onboarding reminder
/// - project recommendations + match explanation
/// - application pipeline
/// - active work
/// - AI career insight
/// - teams, messages, notifications and quick actions
/// - responsive desktop/tablet/mobile layouts
///
/// The project/application data below is demo UI data for now. Replace the
/// demo lists with Firestore queries when those collections are implemented.
class DeveloperHome extends StatefulWidget {
  const DeveloperHome({super.key});

  @override
  State<DeveloperHome> createState() => _DeveloperHomeState();
}

class _DeveloperHomeState extends State<DeveloperHome>
    with TickerProviderStateMixin {
  int _selectedNav = 0;
  bool _sidebarExpanded = true;
  bool _showProfileReminder = true;
  bool _notificationsOpen = false;
  bool _messagesOpen = false;

  late final AnimationController _pageController;
  late final AnimationController _ambientController;

  final List<_NavItem> _navItems = const [
    _NavItem(Icons.grid_view_rounded, 'Dashboard'),
    _NavItem(Icons.travel_explore_rounded, 'Discover Projects'),
    _NavItem(Icons.assignment_rounded, 'My Applications'),
    _NavItem(Icons.work_history_rounded, 'Active Projects'),
    _NavItem(Icons.groups_2_rounded, 'Teams'),
    _NavItem(Icons.auto_awesome_rounded, 'AI Career Assistant'),
    _NavItem(Icons.person_rounded, 'My Profile'),
    _NavItem(Icons.folder_copy_rounded, 'Portfolio'),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _selectNav(int index) {
    // My Profile is a separate screen.
    if (index == 6) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DeveloperProfile()),
      );
      return;
    }

    setState(() {
      _selectedNav = index;
      _notificationsOpen = false;
      _messagesOpen = false;
    });
  }

  void _showFeatureSnack(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text('$feature is ready for the next module.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userStream(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final name =
            (data['name'] ??
                    FirebaseAuth.instance.currentUser?.displayName ??
                    'Developer')
                .toString();
        final email =
            (data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '')
                .toString();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _developerProfileStream(),
          builder: (context, profileSnapshot) {
            final profileData =
                profileSnapshot.data?.data() ?? const <String, dynamic>{};

            // developerProfiles is the source of truth for the profile
            // completion shown on the developer dashboard.
            final completion = profileData.isNotEmpty
                ? _profileCompletion(profileData)
                : _profileCompletion(data);

            return Scaffold(
              backgroundColor: _AppColors.background,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _AmbientPainter(_ambientController.value),
                          );
                        },
                      ),
                    ),
                  ),
                  SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final mobile = constraints.maxWidth < 760;
                        final tablet =
                            constraints.maxWidth >= 760 &&
                            constraints.maxWidth < 1120;

                        return Row(
                          children: [
                            if (!mobile)
                              _buildSidebar(
                                compact: tablet || !_sidebarExpanded,
                                name: name,
                                email: email,
                                completion: completion,
                              ),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildTopBar(
                                    mobile: mobile,
                                    name: name,
                                    email: email,
                                  ),
                                  Expanded(
                                    child: _buildContent(
                                      mobile: mobile,
                                      tablet: tablet,
                                      name: name,
                                      completion: completion,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (_notificationsOpen)
                    _buildOverlayPanel(
                      right: 78,
                      width: 360,
                      child: _notificationPanel(),
                    ),
                  if (_messagesOpen)
                    _buildOverlayPanel(
                      right: 132,
                      width: 360,
                      child: _messagePanel(),
                    ),
                ],
              ),
              bottomNavigationBar: _buildMobileNavigation(),
            );
          },
        );
      },
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _developerProfileStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('developerProfiles')
        .doc(uid)
        .snapshots();
  }

  int _profileCompletion(Map<String, dynamic> data) {
    final raw = data['profileCompletion'];

    if (raw is num) {
      return raw.toInt().clamp(0, 100);
    }

    return _calculateProfileCompletion(data);
  }

  int _calculateProfileCompletion(Map<String, dynamic> data) {
    int completed = 0;
    const total = 12;

    if (_has(data, 'name')) completed++;
    if (_has(data, 'headline')) completed++;
    if (_has(data, 'bio')) completed++;
    if (_has(data, 'location')) completed++;
    if (_hasList(data, 'skills')) completed++;
    if (_hasList(data, 'technologies')) completed++;
    if (_has(data, 'experience')) completed++;
    if (_has(data, 'education')) completed++;
    if (_has(data, 'githubUrl')) completed++;
    if (_has(data, 'resumeUrl')) completed++;
    if (_has(data, 'availability')) completed++;
    if (_has(data, 'projectType')) completed++;

    return ((completed / total) * 100).round().clamp(0, 100);
  }

  bool _has(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value != null && value.toString().trim().isNotEmpty;
  }

  bool _hasList(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is List && value.isNotEmpty;
  }

  Widget _buildSidebar({
    required bool compact,
    required String name,
    required String email,
    required int completion,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: compact ? 82 : 254,
      margin: const EdgeInsets.fromLTRB(14, 14, 0, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 13 : 18, 18, 13, 20),
            child: Row(
              children: [
                const _BrandMark(),
                if (!compact) ...[
                  const SizedBox(width: 11),
                  const Text(
                    'SkillBridge',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
                      color: _AppColors.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _navItems.length,
              separatorBuilder: (_, index) => index == 0
                  ? const SizedBox(height: 10)
                  : const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final item = _navItems[index];
                return _SidebarItem(
                  item: item,
                  selected: _selectedNav == index,
                  compact: compact,
                  onTap: () => _selectNav(index),
                );
              },
            ),
          ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _buildMiniProfile(completion, name),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: _SidebarAction(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    compact: compact,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ),
                if (!compact)
                  Expanded(
                    child: _SidebarAction(
                      icon: Icons.logout_rounded,
                      label: 'Logout',
                      compact: compact,
                      onTap: _logout,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProfile(int completion, String name) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DeveloperProfile()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const _Avatar(size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _AppColors.ink,
                        ),
                      ),
                      const Text(
                        'Developer',
                        style: TextStyle(fontSize: 12, color: _AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: completion / 100,
                      minHeight: 5,
                      backgroundColor: Colors.white,
                      valueColor: const AlwaysStoppedAnimation(
                        _AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  '$completion%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar({
    required bool mobile,
    required String name,
    required String email,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(mobile ? 14 : 20, 14, mobile ? 14 : 20, 4),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _AppColors.border),
        ),
        child: Row(
          children: [
            if (mobile)
              IconButton(
                onPressed: () => _showMobileMenu(),
                icon: const Icon(Icons.menu_rounded),
                tooltip: 'Menu',
              ),
            if (!mobile)
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search projects, skills, technologies...',
                      hintStyle: TextStyle(color: _AppColors.muted),
                    ),
                  ),
                ),
              )
            else
              const Expanded(
                child: Text(
                  'SkillBridge',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: _AppColors.ink,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            _HeaderIcon(
              icon: Icons.notifications_none_rounded,
              badge: 3,
              selected: _notificationsOpen,
              onTap: () => setState(() {
                _notificationsOpen = !_notificationsOpen;
                _messagesOpen = false;
              }),
            ),
            _HeaderIcon(
              icon: Icons.chat_bubble_outline_rounded,
              badge: 2,
              selected: _messagesOpen,
              onTap: () => setState(() {
                _messagesOpen = !_messagesOpen;
                _notificationsOpen = false;
              }),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Account',
              offset: const Offset(0, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                if (value == 'logout') _logout();
                if (value == 'profile') _selectNav(6);
                if (value == 'settings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const _Avatar(size: 36),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(email, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'profile',
                  child: Text('My Profile'),
                ),
                const PopupMenuItem(value: 'settings', child: Text('Settings')),
                const PopupMenuItem(value: 'logout', child: Text('Logout')),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    _Avatar(size: 38),
                    Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required bool mobile,
    required bool tablet,
    required String name,
    required int completion,
  }) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _pageController, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .03), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _pageController,
                curve: Curves.easeOutCubic,
              ),
            ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            mobile ? 14 : 20,
            16,
            mobile ? 14 : 20,
            30,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreeting(mobile, name),
                const SizedBox(height: 16),
                if (_showProfileReminder && completion < 100) ...[
                  _buildProfileReminder(completion, mobile),
                  const SizedBox(height: 18),
                ],
                _buildStatsGrid(mobile),
                const SizedBox(height: 22),
                _buildRecommendedSection(mobile, tablet),
                const SizedBox(height: 22),
                if (mobile || tablet)
                  Column(
                    children: [
                      _buildApplicationPipeline(),
                      const SizedBox(height: 18),
                      _buildAiInsight(),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: _buildApplicationPipeline()),
                      const SizedBox(width: 18),
                      Expanded(flex: 4, child: _buildAiInsight()),
                    ],
                  ),
                const SizedBox(height: 22),
                _buildActiveProjects(mobile),
                const SizedBox(height: 22),
                if (mobile || tablet)
                  Column(
                    children: [
                      _buildTeamSpotlight(),
                      const SizedBox(height: 18),
                      _buildUpcoming(),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTeamSpotlight()),
                      const SizedBox(width: 18),
                      Expanded(child: _buildUpcoming()),
                    ],
                  ),
                const SizedBox(height: 22),
                _buildQuickActions(mobile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(bool mobile, String name) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning, ${name.split(' ').first} 👋',
                style: TextStyle(
                  fontSize: mobile ? 26 : 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  color: _AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your workspace for finding meaningful work, building credibility and growing your career.',
                style: TextStyle(
                  color: _AppColors.muted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        if (!mobile)
          FilledButton.icon(
            onPressed: () => _selectNav(1),
            icon: const Icon(Icons.search_rounded, size: 19),
            label: const Text('Find Projects'),
            style: FilledButton.styleFrom(
              backgroundColor: _AppColors.ink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileReminder(int completion, bool mobile) {
    return _AnimatedCard(
      delay: 80,
      child: Container(
        padding: EdgeInsets.all(mobile ? 16 : 19),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEEF4FF), Color(0xFFF8FAFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD9E5FF)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 16,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: _AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Complete your developer profile',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _AppColors.ink,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completion% complete • Add skills, portfolio and availability to improve project matching.',
                    style: const TextStyle(
                      color: _AppColors.muted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: completion / 100,
                      minHeight: 6,
                      backgroundColor: Colors.white,
                      valueColor: const AlwaysStoppedAnimation(
                        _AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            if (!mobile)
              OutlinedButton(
                onPressed: () => _selectNav(6),
                child: const Text('Complete Profile'),
              ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: () => setState(() => _showProfileReminder = false),
              icon: const Icon(Icons.close_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(bool mobile) {
    final cards = [
      _StatData(
        'Applications',
        '12',
        '+3 this week',
        Icons.assignment_turned_in_rounded,
        const Color(0xFFEFF6FF),
      ),
      _StatData(
        'Shortlisted',
        '4',
        '2 awaiting interview',
        Icons.stars_rounded,
        const Color(0xFFFFF7ED),
      ),
      _StatData(
        'Active Projects',
        '2',
        '1 due this week',
        Icons.rocket_launch_rounded,
        const Color(0xFFF0FDFA),
      ),
      _StatData(
        'Profile Views',
        '48',
        '+18% this month',
        Icons.visibility_rounded,
        const Color(0xFFF5F3FF),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = mobile
            ? 2
            : constraints.maxWidth < 1000
            ? 2
            : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: mobile ? 128 : 138,
          ),
          itemBuilder: (_, index) => _AnimatedCard(
            delay: 100 + index * 55,
            child: _StatCard(data: cards[index]),
          ),
        );
      },
    );
  }

  Widget _buildRecommendedSection(bool mobile, bool tablet) {
    final projects = [
      _ProjectData(
        title: 'Fintech Mobile Experience',
        client: 'NovaPay',
        description: 'Build a secure Flutter experience for personal finance and payments.',
        match: 94,
        skills: ['Flutter', 'Firebase', 'REST API'],
        budget: '₹45k–₹70k',
        mode: 'Remote',
        icon: Icons.account_balance_wallet_rounded,
      ),
      _ProjectData(
        title: 'AI Resume Platform',
        client: 'CareerLoop',
        description: 'Create an AI-assisted resume and job matching product for students.',
        match: 89,
        skills: ['Java', 'Python', 'AI'],
        budget: '₹35k–₹55k',
        mode: 'Hybrid',
        icon: Icons.psychology_alt_rounded,
      ),
      _ProjectData(
        title: 'Campus Collaboration App',
        client: 'EduNext',
        description: 'Develop a collaborative app connecting students, mentors and teams.',
        match: 84,
        skills: ['Flutter', 'Firestore', 'UI/UX'],
        budget: '₹25k–₹40k',
        mode: 'Remote',
        icon: Icons.school_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          eyebrow: 'AI MATCHING',
          title: 'Recommended for you',
          subtitle: 'Projects ranked by your skills, preferences and profile.',
          action: 'View all',
          onAction: () => _selectNav(1),
        ),
        const SizedBox(height: 13),
        SizedBox(
          height: mobile ? 292 : 282,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: projects.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, index) => SizedBox(
              width: mobile
                  ? 315
                  : tablet
                  ? 350
                  : 390,
              child: _AnimatedCard(
                delay: 180 + index * 80,
                child: _ProjectCard(
                  project: projects[index],
                  onApply: () => _showApplyDialog(projects[index]),
                  onView: () => _showProjectDialog(projects[index]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationPipeline() {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            eyebrow: 'APPLICATIONS',
            title: 'Your application pipeline',
            subtitle: 'Track every opportunity from application to interview.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 112,
            child: Row(
              children: [
                _PipelineStep('Applied', '12', _AppColors.primary),
                _PipelineConnector(),
                _PipelineStep('Review', '5', const Color(0xFF7C3AED)),
                _PipelineConnector(),
                _PipelineStep('Shortlisted', '4', const Color(0xFFF59E0B)),
                _PipelineConnector(),
                _PipelineStep('Interview', '2', const Color(0xFF0F766E)),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 15),
          _ApplicationRow(
            title: 'Fintech Mobile Experience',
            company: 'NovaPay',
            status: 'Shortlisted',
            color: const Color(0xFFF59E0B),
            time: 'Updated 2h ago',
          ),
          _ApplicationRow(
            title: 'AI Resume Platform',
            company: 'CareerLoop',
            status: 'Under review',
            color: const Color(0xFF7C3AED),
            time: 'Updated yesterday',
          ),
          _ApplicationRow(
            title: 'Campus Collaboration App',
            company: 'EduNext',
            status: 'Applied',
            color: _AppColors.primary,
            time: 'Updated 2d ago',
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsight() {
    return _DashboardCard(
      gradient: const LinearGradient(
        colors: [Color(0xFF111827), Color(0xFF1E293B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: const Color(0xFF273449),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF93C5FD),
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'SkillBridge AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              _SmallPill(
                text: 'INSIGHT',
                foreground: const Color(0xFFBFDBFE),
                background: Colors.white.withOpacity(.08),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Your profile is close to being opportunity-ready.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.18,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Add a portfolio project and your GitHub profile to improve the quality of your recommendations.',
            style: TextStyle(
              color: Colors.white.withOpacity(.66),
              height: 1.5,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _AiAction(
                  label: 'Improve profile',
                  icon: Icons.person_add_alt_1_rounded,
                  onTap: () => _selectNav(6),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _AiAction(
                  label: 'Ask AI',
                  icon: Icons.chat_rounded,
                  onTap: () => _selectNav(5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveProjects(bool mobile) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            eyebrow: 'ACTIVE WORK',
            title: 'Keep your projects moving',
            subtitle: 'Your current commitments and upcoming milestones.',
            action: 'Open workspace',
            onAction: () => _selectNav(3),
          ),
          const SizedBox(height: 17),
          _ActiveProjectRow(
            title: 'E-Commerce Mobile Application',
            client: 'Client: MarketHub',
            progress: .68,
            next: 'UI review • Today',
            color: _AppColors.primary,
            icon: Icons.shopping_bag_rounded,
          ),
          const SizedBox(height: 12),
          _ActiveProjectRow(
            title: 'College Event Management',
            client: 'Team: CampusLabs',
            progress: .42,
            next: 'API integration • 2 days',
            color: const Color(0xFF7C3AED),
            icon: Icons.event_available_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSpotlight() {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            eyebrow: 'TEAM MATCHING',
            title: 'Find your next teammate',
            subtitle:
                'SkillBridge can help you fill gaps in your project team.',
            action: 'Find teammates',
            onAction: () => _selectNav(4),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              const _Avatar(size: 48, initials: 'RK'),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riya Kulkarni',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'UI/UX Designer • 93% compatibility',
                      style: TextStyle(fontSize: 12, color: _AppColors.muted),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _showFeatureSnack('Team invitation'),
                child: const Text('Invite'),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              const _Avatar(size: 48, initials: 'AS'),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aditya Shah',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Backend Developer • 88% compatibility',
                      style: TextStyle(fontSize: 12, color: _AppColors.muted),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _showFeatureSnack('Team invitation'),
                child: const Text('Invite'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcoming() {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            eyebrow: 'UP NEXT',
            title: 'Upcoming deadlines',
            subtitle: 'Stay ahead of your active project commitments.',
          ),
          const SizedBox(height: 15),
          _DeadlineRow(
            date: 'TODAY',
            title: 'Submit UI prototype',
            project: 'E-Commerce Mobile App',
            urgent: true,
          ),
          _DeadlineRow(
            date: '03 OCT',
            title: 'API integration',
            project: 'College Event Management',
          ),
          _DeadlineRow(
            date: '07 OCT',
            title: 'Client review',
            project: 'E-Commerce Mobile App',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool mobile) {
    final actions = [
      _QuickAction(
        Icons.search_rounded,
        'Find Projects',
        'Explore matching work',
        () => _selectNav(1),
      ),
      _QuickAction(
        Icons.person_add_alt_1_rounded,
        'Improve Profile',
        'Build credibility',
        () => _selectNav(6),
      ),
      _QuickAction(
        Icons.groups_2_rounded,
        'Find Teammates',
        'Build a stronger team',
        () => _selectNav(4),
      ),
      _QuickAction(
        Icons.auto_awesome_rounded,
        'Ask SkillBridge AI',
        'Get career guidance',
        () => _selectNav(5),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          eyebrow: 'QUICK ACTIONS',
          title: 'What do you want to do?',
          subtitle: 'Jump directly to the task you need right now.',
        ),
        const SizedBox(height: 13),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: mobile ? 1 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 84,
          ),
          itemBuilder: (_, index) => _QuickActionCard(action: actions[index]),
        ),
      ],
    );
  }

  Widget _buildMobileNavigation() {
    return MediaQuery.of(context).size.width >= 760
        ? const SizedBox.shrink()
        : NavigationBar(
            selectedIndex: math.min(_selectedNav, 4),
            onDestinationSelected: (index) {
              if (index < 5) {
                _selectNav(index);
              } else {
                _showMobileMenu();
              }
            },
            height: 72,
            backgroundColor: Colors.white,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.travel_explore_outlined),
                selectedIcon: Icon(Icons.travel_explore_rounded),
                label: 'Explore',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment_rounded),
                label: 'Applied',
              ),
              NavigationDestination(
                icon: Icon(Icons.work_history_outlined),
                selectedIcon: Icon(Icons.work_history_rounded),
                label: 'Work',
              ),
              NavigationDestination(
                icon: Icon(Icons.more_horiz_rounded),
                label: 'More',
              ),
            ],
          );
  }

  void _showMobileMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SkillBridge',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              for (final entry in <MapEntry<int, _NavItem>>[
                MapEntry(4, _navItems[4]),
                MapEntry(5, _navItems[5]),
                MapEntry(6, _navItems[6]),
                MapEntry(7, _navItems[7]),
              ])
                ListTile(
                  leading: Icon(entry.value.icon),
                  title: Text(entry.value.label),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _selectNav(entry.key);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayPanel({
    required double right,
    required double width,
    required Widget child,
  }) {
    return Positioned(
      top: 86,
      right: right,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(width: width, child: child),
      ),
    );
  }

  Widget _notificationPanel() {
    return _FloatingPanel(
      title: 'Notifications',
      action: 'Mark all read',
      children: const [
        _NotificationItem(
          icon: Icons.auto_awesome_rounded,
          title: 'New project match',
          body: 'Fintech Mobile Experience matches 94% of your profile.',
          time: '5 min',
        ),
        _NotificationItem(
          icon: Icons.star_rounded,
          title: 'You were shortlisted',
          body: 'NovaPay moved your application to Shortlisted.',
          time: '2 h',
        ),
        _NotificationItem(
          icon: Icons.schedule_rounded,
          title: 'Deadline approaching',
          body: 'UI prototype is due today.',
          time: '4 h',
        ),
      ],
    );
  }

  Widget _messagePanel() {
    return _FloatingPanel(
      title: 'Messages',
      action: 'View all',
      children: const [
        _MessageItem(
          initials: 'NP',
          name: 'NovaPay',
          body: 'Can you share the latest build?',
          time: '8 min',
        ),
        _MessageItem(
          initials: 'CH',
          name: 'CampusLabs',
          body: 'API credentials are ready.',
          time: '1 h',
        ),
        _MessageItem(
          initials: 'CL',
          name: 'CareerLoop',
          body: 'Your proposal has been reviewed.',
          time: 'Yesterday',
        ),
      ],
    );
  }

  void _showProjectDialog(_ProjectData project) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ProjectIcon(icon: project.icon),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.title,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            project.client,
                            style: const TextStyle(color: _AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    _MatchBadge(score: project.match),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  project.description,
                  style: const TextStyle(color: _AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Why you match',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: project.skills
                      .map((skill) => _SkillChip(skill, checked: true))
                      .toList(),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 18,
                      color: _AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(project.budget),
                    const SizedBox(width: 18),
                    const Icon(
                      Icons.public_rounded,
                      size: 18,
                      color: _AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(project.mode),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showApplyDialog(project);
                      },
                      icon: const Icon(Icons.send_rounded, size: 17),
                      label: const Text('Apply now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showApplyDialog(_ProjectData project) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: _AppColors.primary,
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'AI Application Assistant',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  'Applying to ${project.title}',
                  style: const TextStyle(color: _AppColors.muted),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: _AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _MatchBadge(score: project.match),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Strong match based on your current profile. AI can generate a personalized proposal for you to review before submitting.',
                          style: TextStyle(fontSize: 12.5, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Application message',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText:
                        'Write a short introduction or generate one with AI...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: _AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: _AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showFeatureSnack('AI proposal generation'),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                      label: const Text('Generate with AI'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 7),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showFeatureSnack('Application submitted');
                      },
                      icon: const Icon(Icons.send_rounded, size: 17),
                      label: const Text('Submit application'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppColors {
  static const background = Color(0xFFF6F8FC);
  static const surfaceSoft = Color(0xFFF1F5F9);
  static const border = Color(0xFFE5EAF2);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const primary = Color(0xFF2563EB);
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _StatData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color background;
  const _StatData(
    this.title,
    this.value,
    this.subtitle,
    this.icon,
    this.background,
  );
}

class _ProjectData {
  final String title;
  final String client;
  final String description;
  final int match;
  final List<String> skills;
  final String budget;
  final String mode;
  final IconData icon;
  const _ProjectData({
    required this.title,
    required this.client,
    required this.description,
    required this.match,
    required this.skills,
    required this.budget,
    required this.mode,
    required this.icon,
  });
}

class _QuickAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.title, this.subtitle, this.onTap);
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(
            color: Color(0x302563EB),
            blurRadius: 15,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: const Icon(Icons.hub_rounded, color: Colors.white, size: 21),
    );
  }
}

class _Avatar extends StatelessWidget {
  final double size;
  final String? initials;
  const _Avatar({required this.size, this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDBEAFE), Color(0xFFE0E7FF)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initials ?? 'A',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: const Color(0xFF3730A3),
          fontSize: size * .34,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: compact ? item.label : '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF4FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                item.icon,
                size: 20,
                color: selected ? _AppColors.primary : _AppColors.muted,
              ),
              if (!compact) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? _AppColors.primary : _AppColors.muted,
                    ),
                  ),
                ),
                if (item.label == 'AI Career Assistant') const _TinySpark(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TinySpark extends StatelessWidget {
  const _TinySpark();
  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.auto_awesome_rounded,
      size: 14,
      color: Color(0xFF7C3AED),
    );
  }
}

class _SidebarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;
  final VoidCallback onTap;
  const _SidebarAction({
    required this.icon,
    required this.label,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          foregroundColor: _AppColors.muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final int badge;
  final bool selected;
  final VoidCallback onTap;
  const _HeaderIcon({
    required this.icon,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 21),
          style: IconButton.styleFrom(
            backgroundColor: selected
                ? const Color(0xFFEFF4FF)
                : Colors.transparent,
            foregroundColor: selected ? _AppColors.primary : _AppColors.muted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
        Positioned(
          top: 7,
          right: 7,
          child: Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text(
              '$badge',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final Color borderColor;
  const _DashboardCard({
    required this.child,
    this.gradient,
    this.borderColor = _AppColors.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: gradient == null ? Colors.white.withOpacity(.96) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 24,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AnimatedCard extends StatefulWidget {
  final Widget child;
  final int delay;
  const _AnimatedCard({required this.child, required this.delay});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, .035),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 37,
                    height: 37,
                    decoration: BoxDecoration(
                      color: data.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(data.icon, size: 18, color: _AppColors.ink),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.more_horiz_rounded,
                    color: _AppColors.muted,
                    size: 19,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: _AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    data.value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.7,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      data.subtitle,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: _AppColors.muted,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: _AppColors.primary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: _AppColors.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.45,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _AppColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (action != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.arrow_forward_rounded, size: 15),
            label: Text(action!),
            style: TextButton.styleFrom(
              foregroundColor: _AppColors.primary,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProjectCard extends StatefulWidget {
  final _ProjectData project;
  final VoidCallback onApply;
  final VoidCallback onView;
  const _ProjectCard({
    required this.project,
    required this.onApply,
    required this.onView,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hovered = false;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: _hovered ? const Color(0xFFC9D9FF) : _AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0C0F172A),
              blurRadius: _hovered ? 28 : 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProjectIcon(icon: widget.project.icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.project.client,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: _AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.project.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _saved = !_saved),
                  tooltip: 'Save project',
                  icon: Icon(
                    _saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 19,
                    color: _saved ? _AppColors.primary : _AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              widget.project.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _AppColors.muted,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: widget.project.skills
                  .map((skill) => _SkillChip(skill))
                  .toList(),
            ),
            const Spacer(),
            Row(
              children: [
                _MatchBadge(score: widget.project.match),
                const Spacer(),
                Text(
                  widget.project.budget,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onView,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('View'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.onApply,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      backgroundColor: _AppColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Apply'),
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

class _ProjectIcon extends StatelessWidget {
  final IconData icon;
  const _ProjectIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFE0E7FF)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: _AppColors.primary, size: 20),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  final int score;
  const _MatchBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC7F0D6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 12,
            color: Color(0xFF15803D),
          ),
          const SizedBox(width: 4),
          Text(
            '$score% match',
            style: const TextStyle(
              color: Color(0xFF15803D),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String text;
  final bool checked;
  const _SkillChip(this.text, {this.checked = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (checked) ...[
            const Icon(
              Icons.check_circle_rounded,
              size: 12,
              color: Color(0xFF16A34A),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: _AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineStep extends StatelessWidget {
  final String title;
  final String count;
  final Color color;
  const _PipelineStep(this.title, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                count,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: _AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 18, height: 1, color: _AppColors.border);
  }
}

class _ApplicationRow extends StatelessWidget {
  final String title;
  final String company;
  final String status;
  final Color color;
  final String time;
  const _ApplicationRow({
    required this.title,
    required this.company,
    required this.status,
    required this.color,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$company • $time',
                  style: const TextStyle(
                    color: _AppColors.muted,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          _SmallPill(
            text: status,
            foreground: color,
            background: color.withOpacity(.09),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String text;
  final Color foreground;
  final Color background;
  const _SmallPill({
    required this.text,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AiAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _AiAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withOpacity(.15)),
        backgroundColor: Colors.white.withOpacity(.06),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ActiveProjectRow extends StatelessWidget {
  final String title;
  final String client;
  final double progress;
  final String next;
  final Color color;
  final IconData icon;
  const _ActiveProjectRow({
    required this.title,
    required this.client,
    required this.progress,
    required this.next,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  client,
                  style: const TextStyle(color: _AppColors.muted, fontSize: 10),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (MediaQuery.of(context).size.width > 560)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'NEXT',
                  style: TextStyle(
                    fontSize: 8,
                    color: _AppColors.muted,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  next,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  final String date;
  final String title;
  final String project;
  final bool urgent;
  const _DeadlineRow({
    required this.date,
    required this.title,
    required this.project,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 53,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: urgent ? const Color(0xFFFFF1F2) : _AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              date,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: urgent ? const Color(0xFFE11D48) : _AppColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  project,
                  style: const TextStyle(
                    color: _AppColors.muted,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: _AppColors.muted,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(action.icon, color: _AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.subtitle,
                      style: const TextStyle(
                        color: _AppColors.muted,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_outward_rounded,
                size: 17,
                color: _AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingPanel extends StatelessWidget {
  final String title;
  final String action;
  final List<Widget> children;
  const _FloatingPanel({
    required this.title,
    required this.action,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 35,
            offset: Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: Text(action, style: const TextStyle(fontSize: 10)),
              ),
            ],
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String time;
  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF4FF),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 18, color: _AppColors.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
      subtitle: Text(body, style: const TextStyle(fontSize: 10, height: 1.35)),
      trailing: Text(
        time,
        style: const TextStyle(fontSize: 8.5, color: _AppColors.muted),
      ),
    );
  }
}

class _MessageItem extends StatelessWidget {
  final String initials;
  final String name;
  final String body;
  final String time;
  const _MessageItem({
    required this.initials,
    required this.name,
    required this.body,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: _Avatar(size: 38, initials: initials),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
      subtitle: Text(
        body,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10),
      ),
      trailing: Text(
        time,
        style: const TextStyle(fontSize: 8.5, color: _AppColors.muted),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  final double t;
  _AmbientPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final x1 = size.width * (.82 + math.sin(t * math.pi * 2) * .04);
    final y1 = size.height * (.08 + math.cos(t * math.pi * 2) * .03);
    paint.color = const Color(0x142563EB);
    canvas.drawCircle(Offset(x1, y1), 180, paint);

    final x2 = size.width * (.08 + math.cos(t * math.pi * 2) * .025);
    final y2 = size.height * (.72 + math.sin(t * math.pi * 2) * .03);
    paint.color = const Color(0x107C3AED);
    canvas.drawCircle(Offset(x2, y2), 140, paint);
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.t != t;
}
