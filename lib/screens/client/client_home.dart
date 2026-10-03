import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../localization/app_localizations.dart';
import '../../localization/language_provider.dart';

import 'create_project_screen.dart';
import 'my_projects_screen.dart';
import 'client_profile_screen.dart';
import 'client_messages_screen.dart';
import 'client_notifications_screen.dart';
import 'project_details_screen.dart';
import 'hire_developer_screen.dart';

class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome>
    with SingleTickerProviderStateMixin {
  int _selectedNav = 0;

  late final AnimationController _pageController;

  List<_ClientNavItem> _navItems(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return [
      _ClientNavItem(Icons.grid_view_rounded, l10n.dashboard),
      _ClientNavItem(Icons.folder_copy_rounded, l10n.myProjects),
      _ClientNavItem(Icons.chat_bubble_rounded, l10n.messages),
      _ClientNavItem(Icons.notifications_rounded, l10n.notifications),
      _ClientNavItem(Icons.person_rounded, l10n.myProfile),
    ];
  }

  @override
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _selectNav(int index) {
    setState(() {
      _selectedNav = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context);

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FC),
        body: Center(
          child: Text(
            l10n.loginAgain,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collectionGroup('messages')
          .where('clientId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, messageSnapshot) {
        final unreadMessageCount = messageSnapshot.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('notifications')
              .where('isRead', isEqualTo: false)
              .snapshots(),
          builder: (context, notificationSnapshot) {
            final unreadNotificationCount =
                notificationSnapshot.data?.docs.length ?? 0;

            return Scaffold(
              backgroundColor: const Color(0xFFF5F7FB),
              body: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _AmbientPainter()),
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
                                compact: tablet,
                                unreadMessageCount: unreadMessageCount,
                                unreadNotificationCount:
                                    unreadNotificationCount,
                              ),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildTopBar(mobile: mobile),
                                  Expanded(
                                    child: _buildContent(
                                      mobile: mobile,
                                      tablet: tablet,
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
                ],
              ),
              bottomNavigationBar: _buildMobileNavigation(
                unreadMessageCount: unreadMessageCount,
                unreadNotificationCount: unreadNotificationCount,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSidebar({
    required bool compact,
    required int unreadMessageCount,
    required int unreadNotificationCount,
  }) {
    return Container(
      width: compact ? 82 : 250,
      margin: const EdgeInsets.fromLTRB(14, 14, 0, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EAF2)),
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
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                const _BrandMark(),
                if (!compact) ...[
                  const SizedBox(width: 11),
                  const Text(
                    'SkillBridge',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(height: 1, color: const Color(0xFFEFF2F6)),
          ),
          const SizedBox(height: 13),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _navItems(context).length,
              separatorBuilder: (_, _) => const SizedBox(height: 3),
              itemBuilder: (context, index) {
                final item = _navItems(context)[index];

                final badgeCount = index == 2
                    ? unreadMessageCount
                    : index == 3
                    ? unreadNotificationCount
                    : 0;

                return _SidebarItem(
                  item: item,
                  selected: _selectedNav == index,
                  compact: compact,
                  badgeCount: badgeCount,
                  onTap: () => _selectNav(index),
                );
              },
            ),
          ),
          if (!compact)
            _SidebarAccount(onProfile: () => _selectNav(4), onLogout: _logout)
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: IconButton(
                onPressed: () => _selectNav(4),
                tooltip: AppLocalizations.of(context).profile,
                icon: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar({required bool mobile}) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(mobile ? 14 : 20, 14, mobile ? 14 : 20, 4),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5EAF2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x070F172A),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            if (mobile) ...[const _BrandMark(), const SizedBox(width: 10)],
            if (!mobile)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _navItems(context)[_selectedNav].icon,
                  color: const Color(0xFF2563EB),
                  size: 21,
                ),
              ),
            if (!mobile) const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _navItems(context)[_selectedNav].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF101828),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.client.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.skillBridgeWorkspace,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: l10n.selectLanguage,
              onPressed: () {
                _showLanguageMenu(context);
              },
              icon: const Icon(Icons.language_rounded, size: 22),
            ),
            PopupMenuButton<String>(
              tooltip: l10n.clientAccount,
              offset: const Offset(0, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                if (value == 'profile') {
                  _selectNav(4);
                }

                if (value == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 19),
                      const SizedBox(width: 10),
                      Text(l10n.myProfile),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, size: 19),
                      const SizedBox(width: 10),
                      Text(l10n.logout),
                    ],
                  ),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: _UserAvatar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({required bool mobile, required bool tablet}) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _pageController, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.025), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _pageController,
                curve: Curves.easeOutCubic,
              ),
            ),
        child: IndexedStack(
          index: _selectedNav,
          children: const [
            _ClientDashboardSection(),
            _ClientProjectsSection(),
            _ClientMessagesSection(),
            _ClientNotificationsSection(),
            _ClientProfileSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavigation({
    required int unreadMessageCount,
    required int unreadNotificationCount,
  }) {
    final l10n = AppLocalizations.of(context);

    if (MediaQuery.of(context).size.width >= 760) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFE5EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 28,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            height: 72,
            indicatorColor: const Color(0xFFEAF2FF),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);

              return TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF667085),
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);

              return IconThemeData(
                size: selected ? 22 : 21,
                color: selected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF667085),
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _selectedNav,
            onDestinationSelected: _selectNav,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.grid_view_outlined),
                selectedIcon: const Icon(Icons.grid_view_rounded),
                label: l10n.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.folder_outlined),
                selectedIcon: const Icon(Icons.folder_rounded),
                label: l10n.projects,
              ),
              NavigationDestination(
                icon: _BottomBadgeIcon(
                  icon: Icons.chat_bubble_outline_rounded,
                  count: unreadMessageCount,
                ),
                selectedIcon: _BottomBadgeIcon(
                  icon: Icons.chat_bubble_rounded,
                  count: unreadMessageCount,
                ),
                label: l10n.messages,
              ),
              NavigationDestination(
                icon: _BottomBadgeIcon(
                  icon: Icons.notifications_none_rounded,
                  count: unreadNotificationCount,
                ),
                selectedIcon: _BottomBadgeIcon(
                  icon: Icons.notifications_rounded,
                  count: unreadNotificationCount,
                ),
                label: l10n.alerts,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: l10n.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;

  const _BottomBadgeIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Icon(icon);
    }

    final text = count > 99 ? '99+' : '$count';

    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 2, bottom: 1, child: Icon(icon)),
          Positioned(
            top: -7,
            right: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientDashboardSection extends StatelessWidget {
  const _ClientDashboardSection();

  void _openCreateProject(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
    );
  }

  void _openMyProjects(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyProjectsScreen()),
    );
  }

  void _openMessages(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientMessagesScreen()),
    );
  }

  void _openHireDeveloper(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HireDeveloperScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context);

    if (user == null) {
      return Center(
        child: Text(
          l10n.loginAgain,
          style: const TextStyle(
            color: Color(0xFF667085),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        String name = '';

        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data();

          if (userData != null && userData['name'] != null) {
            name = userData['name'].toString();
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .where('clientId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, projectSnapshot) {
            if (projectSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _ErrorCard(
                    message:
                        '${l10n.somethingWentWrong}\n'
                        '${projectSnapshot.error}',
                  ),
                ),
              );
            }

            final projects = projectSnapshot.data?.docs ?? [];

            final totalProjects = projects.length;

            final activeProjects = projects.where((doc) {
              final status = doc.data()['status']?.toString() ?? '';

              return status != 'completed' && status != 'cancelled';
            }).length;

            final completedProjects = projects.where((doc) {
              final status = doc.data()['status']?.toString() ?? '';

              return status == 'completed';
            }).length;

            final loading =
                projectSnapshot.connectionState == ConnectionState.waiting;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DashboardWelcome(
                        name: name,
                        projectCount: totalProjects,
                      ),
                      const SizedBox(height: 18),
                      _CreateProjectBanner(
                        onTap: () => _openCreateProject(context),
                      ),
                      const SizedBox(height: 14),
                      _HireDeveloperBanner(
                        onTap: () => _openHireDeveloper(context),
                      ),
                      const SizedBox(height: 27),
                      _StatsGrid(
                        totalProjects: totalProjects,
                        activeProjects: activeProjects,
                        completedProjects: completedProjects,
                      ),
                      const SizedBox(height: 29),
                      _RecentProjectsHeader(
                        hasProjects: projects.isNotEmpty,
                        onViewAll: () => _openMyProjects(context),
                      ),
                      const SizedBox(height: 13),
                      if (loading)
                        const _LoadingCard()
                      else if (projects.isEmpty)
                        const _EmptyProjectCard()
                      else
                        Column(
                          children: projects
                              .take(3)
                              .map(
                                (doc) => Padding(
                                  padding: const EdgeInsets.only(bottom: 11),
                                  child: _ProjectCard(
                                    project: doc.data(),
                                    projectId: doc.id,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      if (projects.isNotEmpty) ...[
                        const SizedBox(height: 19),
                        _SectionHeading(
                          eyebrow: l10n.quickActions,
                          title: l10n.continueWhereLeft,
                          subtitle: l10n.jumpWorkspace,
                        ),
                        const SizedBox(height: 13),
                        _QuickActions(
                          onProjects: () => _openMyProjects(context),
                          onMessages: () => _openMessages(context),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DashboardWelcome extends StatelessWidget {
  final String name;
  final int projectCount;

  const _DashboardWelcome({required this.name, required this.projectCount});

  String _initial() {
    if (name.trim().isEmpty) {
      return 'U';
    }

    return name.trim()[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E9F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 59,
            height: 59,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x252563EB),
                  blurRadius: 17,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _initial(),
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.welcomeBack,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name.isEmpty ? l10n.client : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF101828),
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  l10n.softwareProjectsDescription,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8FF),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFDCE7FA)),
            ),
            child: Column(
              children: [
                Text(
                  '$projectCount',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  projectCount == 1 ? l10n.project : l10n.projectsPlural,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF667085),
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

class _CreateProjectBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateProjectBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x202563EB),
                blurRadius: 25,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: const Icon(
                  Icons.add_business_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.createNewProject,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      l10n.shareIdea,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Color(0xFFE5EDFF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HireDeveloperBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _HireDeveloperBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE0E7FF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6FF), Color(0xFFE0E7FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  color: Color(0xFF4F46E5),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.hireDeveloper,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      l10n.findDevelopers,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF4F46E5),
                  size: 21,
                ),
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

  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.25,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: Color(0xFF101828),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Color(0xFF667085),
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int totalProjects;
  final int activeProjects;
  final int completedProjects;

  const _StatsGrid({
    required this.totalProjects,
    required this.activeProjects,
    required this.completedProjects,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _StatCard(
            icon: Icons.folder_copy_rounded,
            title: l10n.totalProjects,
            value: totalProjects.toString(),
            color: const Color(0xFF2563EB),
            background: const Color(0xFFEFF6FF),
          ),
          _StatCard(
            icon: Icons.autorenew_rounded,
            title: l10n.activeProjects,
            value: activeProjects.toString(),
            color: const Color(0xFFD97706),
            background: const Color(0xFFFFF7E8),
          ),
          _StatCard(
            icon: Icons.task_alt_rounded,
            title: l10n.completed,
            value: completedProjects.toString(),
            color: const Color(0xFF16A34A),
            background: const Color(0xFFECFDF3),
          ),
        ];

        if (constraints.maxWidth >= 850) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
              const SizedBox(width: 12),
              Expanded(child: cards[2]),
            ],
          );
        }

        if (constraints.maxWidth >= 560) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: (constraints.maxWidth - 12) / 2, child: cards[0]),
              SizedBox(width: (constraints.maxWidth - 12) / 2, child: cards[1]),
              SizedBox(width: constraints.maxWidth, child: cards[2]),
            ],
          );
        }

        return Column(
          children: [
            cards[0],
            const SizedBox(height: 12),
            cards[1],
            const SizedBox(height: 12),
            cards[2],
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final Color background;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF101828),
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

class _RecentProjectsHeader extends StatelessWidget {
  final bool hasProjects;
  final VoidCallback onViewAll;

  const _RecentProjectsHeader({
    required this.hasProjects,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _SectionHeading(
            eyebrow: l10n.projects,
            title: l10n.recentProjects,
            subtitle: l10n.latestProjectActivity,
          ),
        ),
        if (hasProjects)
          TextButton.icon(
            onPressed: onViewAll,
            icon: const Icon(Icons.arrow_forward_rounded, size: 15),
            label: Text(l10n.viewAll),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              textStyle: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final String projectId;

  const _ProjectCard({required this.project, required this.projectId});

  String _formatStatus(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context);

    switch (status) {
      case 'requirement':
        return l10n.requirement;
      case 'team_formation':
        return l10n.teamFormation;
      case 'development':
        return l10n.development;
      case 'testing':
        return l10n.testing;
      case 'client_review':
        return l10n.clientReview;
      case 'completed':
        return l10n.completed;
      case 'cancelled':
        return l10n.cancelled;
      default:
        return status;
    }
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFFECFDF3);
      case 'cancelled':
        return const Color(0xFFFEF3F2);
      case 'testing':
        return const Color(0xFFECFCFF);
      case 'client_review':
        return const Color(0xFFFDF2F8);
      case 'development':
        return const Color(0xFFFFF7E8);
      case 'team_formation':
        return const Color(0xFFF4F0FF);
      default:
        return const Color(0xFFEFF6FF);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF15803D);
      case 'cancelled':
        return const Color(0xFFB42318);
      case 'testing':
        return const Color(0xFF0E7490);
      case 'client_review':
        return const Color(0xFFBE185D);
      case 'development':
        return const Color(0xFFB45309);
      case 'team_formation':
        return const Color(0xFF6D28D9);
      default:
        return const Color(0xFF1D4ED8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final title = project['title']?.toString() ?? l10n.project;

    final category = project['category']?.toString() ?? '';

    final status = project['status']?.toString() ?? 'requirement';

    final budget = project['budget']?.toString() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectDetailsScreen(projectId: projectId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFE5EAF2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x070F172A),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6FF), Color(0xFFE4ECFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.folder_copy_rounded,
                  size: 24,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF101828),
                      ),
                    ),
                    if (category.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                    if (budget.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            size: 13,
                            color: Color(0xFF98A2B3),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              budget,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475467),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _statusBackground(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatStatus(context, status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _statusColor(status),
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: Color(0xFF98A2B3),
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

class _QuickActions extends StatelessWidget {
  final VoidCallback onProjects;
  final VoidCallback onMessages;

  const _QuickActions({required this.onProjects, required this.onMessages});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (MediaQuery.of(context).size.width < 560) {
      return Column(
        children: [
          _QuickActionCard(
            icon: Icons.folder_rounded,
            title: l10n.myProjects,
            subtitle: l10n.openProjectWorkspace,
            onTap: onProjects,
          ),
          const SizedBox(height: 10),
          _QuickActionCard(
            icon: Icons.chat_rounded,
            title: l10n.messages,
            subtitle: l10n.continueConversations,
            onTap: onMessages,
          ),
          const SizedBox(height: 10),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.folder_rounded,
            title: l10n.myProjects,
            subtitle: l10n.openProjectWorkspace,
            onTap: onProjects,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.chat_rounded,
            title: l10n.messages,
            subtitle: l10n.continueConversations,
            onTap: onMessages,
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5EAF2)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 19, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF344054),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_outward_rounded,
                size: 17,
                color: Color(0xFF98A2B3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProjectCard extends StatelessWidget {
  const _EmptyProjectCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 46),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(21),
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              size: 31,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noProjectsYet,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            l10n.createFirstProject,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 115,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Color(0xFF2563EB),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1C2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _ClientNavItem item;
  final bool selected;
  final bool compact;
  final int badgeCount;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.compact,
    required this.badgeCount,
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
              _SidebarIcon(
                icon: item.icon,
                selected: selected,
                badgeCount: badgeCount,
              ),
              if (!compact) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final int badgeCount;

  const _SidebarIcon({
    required this.icon,
    required this.selected,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? const Color(0xFF2563EB)
        : const Color(0xFF64748B);

    if (badgeCount <= 0) {
      return Icon(icon, size: 20, color: iconColor);
    }

    final text = badgeCount > 99 ? '99+' : '$badgeCount';

    return SizedBox(
      width: 25,
      height: 25,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 2,
            bottom: 2,
            child: Icon(icon, size: 20, color: iconColor),
          ),
          Positioned(
            top: -5,
            right: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1.3),
              ),
              alignment: Alignment.center,
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarAccount extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  const _SidebarAccount({required this.onProfile, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context);

    final name =
        user?.displayName ?? user?.email?.split('@').first ?? l10n.client;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          Container(height: 1, color: const Color(0xFFEFF2F6)),
          const SizedBox(height: 12),
          InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const _UserAvatar(size: 39),
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
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF101828),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.clientAccount,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF98A2B3),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: IconButton(
                  onPressed: onProfile,
                  tooltip: l10n.profile,
                  icon: const Icon(Icons.settings_outlined, size: 19),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF667085),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: IconButton(
                  onPressed: onLogout,
                  tooltip: l10n.logout,
                  icon: const Icon(Icons.logout_rounded, size: 19),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF667085),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final double size;

  const _UserAvatar({this.size = 40});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context);

    final name = user?.displayName ?? user?.email ?? l10n.client;

    final initial = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDBEAFE), Color(0xFFE0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * .34,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF3730A3),
        ),
      ),
    );
  }
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

class _ClientNavItem {
  final IconData icon;
  final String label;

  const _ClientNavItem(this.icon, this.label);
}

class _AmbientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0x0D2563EB);

    canvas.drawCircle(Offset(size.width * .88, size.height * .10), 190, paint);

    paint.color = const Color(0x087C3AED);

    canvas.drawCircle(Offset(size.width * .04, size.height * .76), 150, paint);
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) {
    return false;
  }
}

class _ClientProjectsSection extends StatelessWidget {
  const _ClientProjectsSection();

  @override
  Widget build(BuildContext context) {
    return const MyProjectsScreen();
  }
}

class _ClientMessagesSection extends StatelessWidget {
  const _ClientMessagesSection();

  @override
  Widget build(BuildContext context) {
    return const ClientMessagesScreen();
  }
}

class _ClientNotificationsSection extends StatelessWidget {
  const _ClientNotificationsSection();

  @override
  Widget build(BuildContext context) {
    return const ClientNotificationsScreen();
  }
}

class _ClientProfileSection extends StatelessWidget {
  const _ClientProfileSection();

  @override
  Widget build(BuildContext context) {
    return const ClientProfileScreen();
  }
}

void _showLanguageMenu(BuildContext context) {
  final provider = context.read<LanguageProvider>();
  final l10n = AppLocalizations.of(context);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final currentLanguage = provider.locale.languageCode;

      return Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.selectLanguage,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF101828),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _languageOption(
              context: sheetContext,
              provider: provider,
              title: l10n.english,
              subtitle: l10n.english,
              locale: const Locale('en'),
              selected: currentLanguage == 'en',
            ),
            _languageOption(
              context: sheetContext,
              provider: provider,
              title: l10n.marathi,
              subtitle: l10n.marathi,
              locale: const Locale('mr'),
              selected: currentLanguage == 'mr',
            ),
            _languageOption(
              context: sheetContext,
              provider: provider,
              title: l10n.hindi,
              subtitle: l10n.hindi,
              locale: const Locale('hi'),
              selected: currentLanguage == 'hi',
            ),
          ],
        ),
      );
    },
  );
}

Widget _languageOption({
  required BuildContext context,
  required LanguageProvider provider,
  required String title,
  required String subtitle,
  required Locale locale,
  required bool selected,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(
      color: selected ? const Color(0xFFEFF4FF) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: selected ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB),
      ),
    ),
    child: ListTile(
      onTap: () {
        provider.changeLanguage(locale);
        Navigator.pop(context);
      },
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDBEAFE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.language_rounded,
          color: selected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: selected ? const Color(0xFF2563EB) : const Color(0xFF101828),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB))
          : const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
    ),
  );
}
