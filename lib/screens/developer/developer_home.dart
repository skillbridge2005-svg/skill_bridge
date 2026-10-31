import 'dart:math' as math;
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'developer_profile.dart';
import 'my_applications.dart';
import 'discover_projects.dart';
import 'active_projects.dart';
import 'teams.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../widgets/skillbridge_avatar.dart';
import '../settings/settings_screen.dart';
import 'notifications_screen.dart';
import 'team_invitations_screen.dart';
import 'developer_messages_hub_screen.dart';
import '../../models/project_model.dart';
import '../../services/project_service.dart';
import '../../services/application_service.dart';
import '../../services/team_invitation_service.dart';
import '../../services/team_chat_service.dart';
import '../../screens/client/hire_developer_screen.dart';

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
  final NotificationService _notificationService = NotificationService();
  final ProjectService _projectService = ProjectService();
  final ApplicationService _applicationService = ApplicationService();
  final TeamInvitationService _teamInvitationService = TeamInvitationService();
  final TeamChatService _teamChatService = TeamChatService();

  final Map<String, Stream<int>> _teamUnreadStreams = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _individualChatsSubscriptions = {};

  final Map<
    String,
    Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  >
  _individualMessageSubscriptions = {};

  final Map<String, StreamController<int>> _individualUnreadControllers = {};
  final Map<String, Stream<int>> _individualUnreadStreams = {};
  late final AnimationController _pageController;
  late final AnimationController _ambientController;

  final List<_NavItem> _navItems = const [
    _NavItem(Icons.grid_view_rounded, 'Dashboard'),
    _NavItem(Icons.travel_explore_rounded, 'Discover Projects'),
    _NavItem(Icons.assignment_rounded, 'My Applications'),
    _NavItem(Icons.work_history_rounded, 'Active Projects'),
    _NavItem(Icons.groups_2_rounded, 'Teams'),
    _NavItem(Icons.person_rounded, 'My Profile'),
  ];

  void _openTeamInvitations() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const TeamInvitationsScreen()),
    );
  }

  void _openFindDevelopersForInvitation() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            FindDevelopersScreen(onInviteDeveloper: _inviteDeveloper),
      ),
    );
  }

  void _openMessagesHub() {
    setState(() {
      _messagesOpen = false;
      _notificationsOpen = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const DeveloperMessagesHubScreen(),
      ),
    );
  }

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

    unawaited(_cleanupUnreadStreams());

    super.dispose();
  }

  Future<void> _cleanupUnreadStreams() async {
    // First cancel the individual chat listeners.
    await Future.wait(
      _individualChatsSubscriptions.values.map(
        (subscription) => subscription.cancel(),
      ),
    );

    // Then cancel all message listeners.
    final messageSubscriptions = _individualMessageSubscriptions.values
        .expand((subscriptions) => subscriptions.values)
        .toList();

    await Future.wait(
      messageSubscriptions.map((subscription) => subscription.cancel()),
    );

    // Finally close the unread-count stream controllers.
    await Future.wait(
      _individualUnreadControllers.values.map(
        (controller) => controller.close(),
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _selectNav(int index) {
    // Discover Projects
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DiscoverProjects()),
      );
      return;
    }

    // My Applications
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyApplications()),
      );
      return;
    }

    // Active Projects
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActiveProjects()),
      );
      return;
    }

    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const Teams()),
      );
      return;
    }
    // My Profile
    if (index == 5) {
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

  Future<void> _inviteDeveloper(String developerId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return;

    try {
      final teamsSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .where('ownerId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get();

      if (!mounted) return;

      if (teamsSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Create an active team before inviting developers.'),
          ),
        );
        return;
      }

      final selectedTeam =
          await showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Choose a team'),
                content: SizedBox(
                  width: 420,
                  child: ListView(
                    shrinkWrap: true,
                    children: teamsSnapshot.docs.map((teamDoc) {
                      final teamData = teamDoc.data();

                      return ListTile(
                        leading: const Icon(Icons.groups_outlined),
                        title: Text(
                          (teamData['name'] ?? 'Unnamed team').toString(),
                        ),
                        subtitle: Text(
                          (teamData['projectTitle'] ?? 'No project linked')
                              .toString(),
                        ),
                        onTap: () => Navigator.pop(dialogContext, teamDoc),
                      );
                    }).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );

      if (!mounted || selectedTeam == null) return;

      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) {
          final roleController = TextEditingController();
          final responsibilitiesController = TextEditingController();

          return AlertDialog(
            title: const Text('Invitation details'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: roleController,
                      decoration: const InputDecoration(
                        labelText: 'Team role',
                        hintText: 'e.g. Flutter Developer',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: responsibilitiesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Responsibilities',
                        hintText: 'Describe the work this developer will do',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, {
                  'role': roleController.text.trim(),
                  'responsibilities': responsibilitiesController.text.trim(),
                }),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (!mounted || result == null) return;

      await _teamInvitationService.sendInvitation(
        teamId: selectedTeam.id,
        developerId: developerId,
        role: result['role'] ?? '',
        responsibilities: result['responsibilities'] ?? '',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team invitation sent successfully.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not send invitation: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
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
        final profileImageUrl =
            data['profileImageUrl']?.toString().trim() ?? '';

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
                                profileImageUrl: profileImageUrl,
                              ),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildTopBar(
                                    mobile: mobile,
                                    name: name,
                                    email: email,
                                    profileImageUrl: profileImageUrl,
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
    required String profileImageUrl,
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
              // Add Team Invitations immediately after Teams without changing
              // the existing navigation indexes for the other destinations.
              itemCount: _navItems.length + 1,
              separatorBuilder: (_, index) => index == 0
                  ? const SizedBox(height: 10)
                  : const SizedBox(height: 2),
              itemBuilder: (context, index) {
                if (index == 5) {
                  return _SidebarItem(
                    item: const _NavItem(
                      Icons.mark_email_unread_outlined,
                      'Team Invitations',
                    ),
                    selected: false,
                    compact: compact,
                    onTap: _openTeamInvitations,
                  );
                }

                final navIndex = index < 5 ? index : index - 1;
                final item = _navItems[navIndex];
                return _SidebarItem(
                  item: item,
                  selected: _selectedNav == navIndex,
                  compact: compact,
                  onTap: () => _selectNav(navIndex),
                );
              },
            ),
          ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _buildMiniProfile(completion, name, profileImageUrl),
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

  Widget _buildMiniProfile(
    int completion,
    String name,
    String profileImageUrl,
  ) {
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
                _Avatar(size: 38, name: name, profileImageUrl: profileImageUrl),
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

  Stream<int> _individualUnreadCountStream(String uid) {
    return _individualUnreadStreams.putIfAbsent(
      uid,
      () => _createIndividualUnreadCountStream(uid),
    );
  }

  Stream<int> _teamUnreadCountStream(String uid) {
    return _teamUnreadStreams.putIfAbsent(
      uid,
      () => _teamChatService.watchUnreadCount(uid),
    );
  }

  Stream<int> _createIndividualUnreadCountStream(String uid) {
    final firestore = FirebaseFirestore.instance;
    final controller = StreamController<int>();

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? chatsSubscription;

    final messageSubscriptions =
        <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};

    final unreadCountByChat = <String, int>{};

    void emitTotal() {
      if (controller.isClosed) return;

      final total = unreadCountByChat.values.fold<int>(
        0,
        (runningTotal, unreadForChat) => runningTotal + unreadForChat,
      );

      controller.add(total);
    }

    chatsSubscription = firestore
        .collection('individualChats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen(
          (chatsSnapshot) {
            final activeChatIds = chatsSnapshot.docs
                .map((doc) => doc.id)
                .toSet();

            for (final chatId in messageSubscriptions.keys.toList()) {
              if (!activeChatIds.contains(chatId)) {
                unreadCountByChat.remove(chatId);

                final subscription = messageSubscriptions.remove(chatId);

                if (subscription != null) {
                  unawaited(subscription.cancel());
                }
              }
            }

            for (final chat in chatsSnapshot.docs) {
              if (messageSubscriptions.containsKey(chat.id)) {
                continue;
              }

              final messageStream = firestore
                  .collection('individualChats')
                  .doc(chat.id)
                  .collection('messages')
                  .where('isRead', isEqualTo: false)
                  .snapshots();

              messageSubscriptions[chat.id] = messageStream.listen(
                (messagesSnapshot) {
                  final count = messagesSnapshot.docs.where((message) {
                    final senderId = message.data()['senderId']?.toString();

                    return senderId != uid;
                  }).length;

                  unreadCountByChat[chat.id] = count;
                  emitTotal();
                },
                onError: (Object error, StackTrace stackTrace) {
                  if (!controller.isClosed) {
                    controller.addError(error, stackTrace);
                  }
                },
              );
            }

            emitTotal();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );

    controller.onCancel = () async {
      await chatsSubscription?.cancel();

      final subscriptions = messageSubscriptions.values.toList();
      messageSubscriptions.clear();

      await Future.wait(
        subscriptions.map((subscription) => subscription.cancel()),
      );
    };

    return controller.stream;
  }

  Widget _buildTopBar({
    required bool mobile,
    required String name,
    required String email,
    required String profileImageUrl,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
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
            StreamBuilder<int>(
              stream: _notificationService.watchUnreadCount(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;

                return _HeaderIcon(
                  icon: Icons.notifications_none_rounded,
                  badge: unreadCount,
                  selected: _notificationsOpen,
                  onTap: () {
                    setState(() {
                      _notificationsOpen = false;
                      _messagesOpen = false;
                    });

                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                );
              },
            ),
            if (uid == null)
              _HeaderIcon(
                icon: Icons.chat_bubble_outline_rounded,
                badge: 0,
                selected: _messagesOpen,
                onTap: _openMessagesHub,
              )
            else
              StreamBuilder<int>(
                stream: _individualUnreadCountStream(uid),
                builder: (context, individualSnapshot) {
                  final individualUnread = individualSnapshot.data ?? 0;

                  return StreamBuilder<int>(
                    stream: _teamUnreadCountStream(uid),
                    builder: (context, teamSnapshot) {
                      if (teamSnapshot.hasError) {
                        debugPrint(
                          'Team unread count error: ${teamSnapshot.error}',
                        );
                      }

                      final teamUnread = teamSnapshot.data ?? 0;
                      final totalUnread = individualUnread + teamUnread;

                      return _HeaderIcon(
                        icon: Icons.chat_bubble_outline_rounded,
                        badge: totalUnread,
                        selected: _messagesOpen,
                        onTap: _openMessagesHub,
                      );
                    },
                  );
                },
              ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Account',
              offset: const Offset(0, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                } else if (value == 'profile') {
                  _selectNav(6);
                } else if (value == 'settings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'account',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _Avatar(
                      size: 36,
                      name: name,
                      profileImageUrl: profileImageUrl,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(email, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF2563EB),
                        size: 21,
                      ),
                      SizedBox(width: 12),
                      Text('My Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        color: Color(0xFF2563EB),
                        size: 21,
                      ),
                      SizedBox(width: 12),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFDC2626),
                        size: 21,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    _Avatar(
                      size: 38,
                      name: name,
                      profileImageUrl: profileImageUrl,
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded),
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

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good evening';
    } else {
      return 'Good night';
    }
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
                '${_getGreeting()}, ${name.split(' ').first} 👋',
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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text('Please log in to view statistics.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('applications')
          .where('developerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, applicationSnapshot) {
        final applications = applicationSnapshot.data?.docs ?? [];

        final applicationCount = applications.length;

        final shortlistedCount = applications.where((doc) {
          final status = (doc.data()['status'] ?? 'pending')
              .toString()
              .trim()
              .toLowerCase();
          return status == 'shortlisted';
        }).length;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('projects')
              .where('developerId', isEqualTo: uid)
              .snapshots(),
          builder: (context, projectSnapshot) {
            final projects = projectSnapshot.data?.docs ?? [];

            final activeProjectCount = projects.where((doc) {
              final status = (doc.data()['status'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
              return status == 'active';
            }).length;

            final cards = [
              _StatData(
                'Applications',
                applicationSnapshot.hasError
                    ? '—'
                    : applicationSnapshot.connectionState ==
                          ConnectionState.waiting
                    ? '...'
                    : '$applicationCount',
                'All submitted applications',
                Icons.assignment_turned_in_rounded,
                const Color(0xFFEFF6FF),
              ),
              _StatData(
                'Shortlisted',
                applicationSnapshot.hasError
                    ? '—'
                    : applicationSnapshot.connectionState ==
                          ConnectionState.waiting
                    ? '...'
                    : '$shortlistedCount',
                'Applications shortlisted',
                Icons.stars_rounded,
                const Color(0xFFFFF7ED),
              ),
              _StatData(
                'Active Projects',
                projectSnapshot.hasError
                    ? '—'
                    : projectSnapshot.connectionState == ConnectionState.waiting
                    ? '...'
                    : '$activeProjectCount',
                'Currently assigned projects',
                Icons.rocket_launch_rounded,
                const Color(0xFFF0FDFA),
              ),
              _StatData(
                'Profile Views',
                '—',
                'Tracking not enabled',
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
          },
        );
      },
    );
  }

  Widget _buildRecommendedSection(bool mobile, bool tablet) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

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
          // Keep enough vertical room for the project card on narrow screens.
          height: mobile
              ? 330
              : tablet
              ? 330
              : 310,
          child: uid == null
              ? const Center(child: Text('Please log in to view projects.'))
              : StreamBuilder<List<ProjectModel>>(
                  stream: _projectService.watchOpenProjects(),
                  builder: (context, projectSnapshot) {
                    if (projectSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !projectSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (projectSnapshot.hasError) {
                      return const Center(
                        child: Text('Unable to load recommended projects.'),
                      );
                    }

                    return FutureBuilder<
                      List<DocumentSnapshot<Map<String, dynamic>>>
                    >(
                      future: Future.wait([
                        FirebaseFirestore.instance
                            .collection('developerProfiles')
                            .doc(uid)
                            .get(),
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .get(),
                      ]),
                      builder: (context, profileSnapshot) {
                        if (profileSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (profileSnapshot.hasError ||
                            !profileSnapshot.hasData) {
                          return const Center(
                            child: Text('Unable to load your recommendations.'),
                          );
                        }

                        final profile =
                            profileSnapshot.data![0].data() ??
                            <String, dynamic>{};
                        final user =
                            profileSnapshot.data![1].data() ??
                            <String, dynamic>{};

                        List<String> readList(dynamic value) {
                          if (value is Iterable) {
                            return value
                                .map((item) => item.toString().trim())
                                .where((item) => item.isNotEmpty)
                                .toSet()
                                .toList();
                          }

                          if (value is String && value.trim().isNotEmpty) {
                            return value
                                .split(',')
                                .map((item) => item.trim())
                                .where((item) => item.isNotEmpty)
                                .toList();
                          }

                          return [];
                        }

                        String? readString(
                          dynamic profileValue,
                          dynamic userValue,
                        ) {
                          final value = profileValue ?? userValue;
                          if (value == null ||
                              value.toString().trim().isEmpty) {
                            return null;
                          }
                          return value.toString().trim();
                        }

                        final skills = readList(profile['skills']);
                        final technologies = readList(profile['technologies']);

                        final projectType = readString(
                          profile['projectType'],
                          user['projectType'],
                        );
                        final workMode = readString(
                          profile['workMode'],
                          user['workMode'],
                        );
                        final duration = readString(
                          profile['projectDuration'] ?? profile['duration'],
                          user['projectDuration'] ?? user['duration'],
                        );

                        final recommendations = _projectService
                            .getRecommendedProjects(
                              projectSnapshot.data ?? [],
                              developerSkills: skills,
                              developerTechnologies: technologies,
                              developerProjectType: projectType,
                              developerWorkMode: workMode,
                              developerDuration: duration,
                              minimumScore: 0,
                              limit: 10,
                            );

                        if (recommendations.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'No open projects are available yet. '
                                'Check Discover Projects for new opportunities.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        final projects = recommendations.map((recommendation) {
                          final project = recommendation.project;

                          final minBudget = project.effectiveBudgetMin;
                          final maxBudget = project.effectiveBudgetMax;

                          String formatBudget(double amount) {
                            return '₹${amount.toStringAsFixed(0)}';
                          }

                          final budget = minBudget <= 0 && maxBudget <= 0
                              ? 'Budget not specified'
                              : minBudget > 0 &&
                                    maxBudget > 0 &&
                                    minBudget != maxBudget
                              ? '${formatBudget(minBudget)}–${formatBudget(maxBudget)}'
                              : formatBudget(
                                  maxBudget > 0 ? maxBudget : minBudget,
                                );

                          final allSkills = <String>{
                            ...project.skills,
                            ...project.technologies,
                          }.toList();

                          return _ProjectData(
                            id: project.id,
                            clientId: project.clientId,
                            duration: project.duration.isNotEmpty
                                ? project.duration
                                : 'To be discussed',
                            title: project.title,
                            client: project.clientName.isNotEmpty
                                ? project.clientName
                                : 'Client',
                            description: project.description,
                            match: recommendation.matchPercentage,
                            skills: allSkills,
                            budget: budget,
                            mode: project.workMode.isNotEmpty
                                ? project.workMode
                                : 'Not specified',
                            icon: Icons.work_outline_rounded,
                          );
                        }).toList();

                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: projects.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
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
                                onApply: () =>
                                    _showApplyDialog(projects[index]),
                                onView: () =>
                                    _showProjectDialog(projects[index]),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildApplicationPipeline() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const _DashboardCard(
        child: Text('Please log in to view your applications.'),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('applications')
          .where('developerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _DashboardCard(
            child: Text('Unable to load your applications.'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _DashboardCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final applications =
            snapshot.data?.docs.toList() ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        String getStatus(Map<String, dynamic> data) {
          return (data['status'] ?? 'pending')
              .toString()
              .trim()
              .toLowerCase()
              .replaceAll('_', ' ')
              .replaceAll('-', ' ');
        }

        bool matchesStatus(Map<String, dynamic> data, List<String> values) {
          final status = getStatus(data);
          return values.contains(status);
        }

        final appliedCount = applications.length;
        final reviewCount = applications.where((doc) {
          return matchesStatus(doc.data(), [
            'review',
            'under review',
            'in review',
            'reviewing',
          ]);
        }).length;

        final shortlistedCount = applications.where((doc) {
          return matchesStatus(doc.data(), [
            'shortlisted',
            'shortlisted for interview',
          ]);
        }).length;

        final interviewCount = applications.where((doc) {
          return matchesStatus(doc.data(), [
            'interview',
            'interview scheduled',
            'interviewing',
            'interview invited',
          ]);
        }).length;

        DateTime dateFrom(dynamic value) {
          if (value is Timestamp) return value.toDate();
          if (value is DateTime) return value;
          return DateTime.fromMillisecondsSinceEpoch(0);
        }

        applications.sort((a, b) {
          final aData = a.data();
          final bData = b.data();

          final aDate = dateFrom(aData['updatedAt'] ?? aData['createdAt']);
          final bDate = dateFrom(bData['updatedAt'] ?? bData['createdAt']);

          return bDate.compareTo(aDate);
        });

        String relativeTime(Map<String, dynamic> data) {
          final date = dateFrom(data['updatedAt'] ?? data['createdAt']);

          if (date.millisecondsSinceEpoch == 0) {
            return 'Date unavailable';
          }

          final difference = DateTime.now().difference(date);

          if (difference.isNegative || difference.inMinutes < 1) {
            return 'Updated just now';
          }
          if (difference.inMinutes < 60) {
            return 'Updated ${difference.inMinutes}m ago';
          }
          if (difference.inHours < 24) {
            return 'Updated ${difference.inHours}h ago';
          }
          if (difference.inDays == 1) {
            return 'Updated yesterday';
          }
          if (difference.inDays < 30) {
            return 'Updated ${difference.inDays}d ago';
          }

          return 'Updated ${date.day}/${date.month}/${date.year}';
        }

        String displayStatus(Map<String, dynamic> data) {
          final status = getStatus(data);

          if (status.isEmpty || status == 'pending') return 'Applied';
          if (status == 'applied') return 'Applied';
          if (status == 'review' ||
              status == 'reviewing' ||
              status == 'in review') {
            return 'Under review';
          }
          if (status == 'shortlisted for interview') {
            return 'Shortlisted';
          }
          if (status == 'interview scheduled' ||
              status == 'interview invited') {
            return 'Interview';
          }

          return status
              .split(' ')
              .map(
                (word) => word.isEmpty
                    ? word
                    : '${word[0].toUpperCase()}${word.substring(1)}',
              )
              .join(' ');
        }

        Color statusColor(Map<String, dynamic> data) {
          final status = getStatus(data);

          if (status.contains('shortlist')) {
            return const Color(0xFFF59E0B);
          }
          if (status.contains('interview')) {
            return const Color(0xFF0F766E);
          }
          if (status.contains('review')) {
            return const Color(0xFF7C3AED);
          }
          if (status == 'rejected' || status == 'withdrawn') {
            return const Color(0xFFDC2626);
          }

          return _AppColors.primary;
        }

        return _DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading(
                eyebrow: 'APPLICATIONS',
                title: 'Your application pipeline',
                subtitle:
                    'Track every opportunity from application to interview.',
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;

                  return SizedBox(
                    height: compact ? 100 : 112,
                    child: Row(
                      children: [
                        _PipelineStep(
                          'Applied',
                          '$appliedCount',
                          _AppColors.primary,
                        ),
                        _PipelineConnector(),
                        _PipelineStep(
                          'Review',
                          '$reviewCount',
                          const Color(0xFF7C3AED),
                        ),
                        _PipelineConnector(),
                        _PipelineStep(
                          'Shortlisted',
                          '$shortlistedCount',
                          const Color(0xFFF59E0B),
                        ),
                        _PipelineConnector(),
                        _PipelineStep(
                          'Interview',
                          '$interviewCount',
                          const Color(0xFF0F766E),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              const SizedBox(height: 15),
              if (applications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 34,
                          color: _AppColors.muted,
                        ),
                        SizedBox(height: 9),
                        Text(
                          'No applications yet',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Explore recommended projects and apply to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...applications.take(3).map((application) {
                  final data = application.data();
                  final projectId = (data['projectId'] ?? '').toString();

                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: projectId.isEmpty
                        ? null
                        : FirebaseFirestore.instance
                              .collection('projects')
                              .doc(projectId)
                              .get(),
                    builder: (context, projectSnapshot) {
                      final projectData =
                          projectSnapshot.data?.data() ?? <String, dynamic>{};

                      final title =
                          (projectData['title'] ??
                                  projectData['projectTitle'] ??
                                  data['projectTitle'] ??
                                  'Project application')
                              .toString();

                      final company =
                          (projectData['clientName'] ??
                                  data['clientName'] ??
                                  data['clientId'] ??
                                  'Client')
                              .toString();

                      return _ApplicationRow(
                        title: title,
                        company: company,
                        status: displayStatus(data),
                        color: statusColor(data),
                        time: relativeTime(data),
                      );
                    },
                  );
                }),
            ],
          ),
        );
      },
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveProjects(bool mobile) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return _DashboardCard(
        child: const Text('Please log in to view your active projects.'),
      );
    }

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

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .where('assignedDeveloperId', isEqualTo: uid)
                .snapshots(),
            builder: (context, assignedSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('projects')
                    .where('developerId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, developerSnapshot) {
                  if (assignedSnapshot.hasError || developerSnapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Unable to load active projects. Check Firestore permissions.',
                        style: TextStyle(color: _AppColors.muted),
                      ),
                    );
                  }

                  if (assignedSnapshot.connectionState ==
                          ConnectionState.waiting ||
                      developerSnapshot.connectionState ==
                          ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final documents =
                      <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

                  for (final doc in assignedSnapshot.data?.docs ?? []) {
                    documents[doc.id] = doc;
                  }

                  for (final doc in developerSnapshot.data?.docs ?? []) {
                    documents[doc.id] = doc;
                  }

                  final activeProjects = documents.values.where((doc) {
                    final data = doc.data();
                    final status = (data['status'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();

                    return ![
                      'completed',
                      'cancelled',
                      'canceled',
                      'closed',
                      'rejected',
                    ].contains(status);
                  }).toList();

                  activeProjects.sort((a, b) {
                    final aDate = a.data()['updatedAt'];
                    final bDate = b.data()['updatedAt'];

                    DateTime dateOf(dynamic value) {
                      if (value is Timestamp) return value.toDate();
                      if (value is DateTime) return value;
                      return DateTime.fromMillisecondsSinceEpoch(0);
                    }

                    return dateOf(bDate).compareTo(dateOf(aDate));
                  });

                  if (activeProjects.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.work_outline_rounded,
                              size: 34,
                              color: _AppColors.muted,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No active projects yet',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _AppColors.ink,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Projects assigned to you will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: activeProjects.take(5).map((doc) {
                      final data = doc.data();

                      final title =
                          (data['title'] ??
                                  data['projectTitle'] ??
                                  'Untitled project')
                              .toString();

                      final client =
                          (data['clientName'] ?? data['clientId'] ?? 'Client')
                              .toString();

                      final status = (data['status'] ?? 'In progress')
                          .toString()
                          .trim();

                      // Supports progress stored as either 0–1 or 0–100.
                      final rawProgress = data['progress'];
                      double progress = 0;

                      if (rawProgress is num) {
                        progress = rawProgress.toDouble();
                        if (progress > 1) progress /= 100;
                      }

                      progress = progress.clamp(0.0, 1.0);

                      // If no progress field exists, derive it from milestones
                      // only when the milestone structure is understood.
                      final next = status.isEmpty
                          ? 'Status not set'
                          : status[0].toUpperCase() + status.substring(1);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ActiveProjectRow(
                          title: title,
                          client: 'Client: $client',
                          progress: progress,
                          next: next,
                          color: _AppColors.primary,
                          icon: Icons.work_outline_rounded,
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSpotlight() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      return _DashboardCard(
        child: const Text('Please log in to find teammates.'),
      );
    }

    List<String> readSkills(dynamic value) {
      if (value is Iterable) {
        return value
            .map((item) => item.toString().trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList();
      }

      if (value is String && value.trim().isNotEmpty) {
        return value
            .split(',')
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList();
      }

      return [];
    }

    String initials(String name) {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty || parts.first.isEmpty) return 'D';
      if (parts.length == 1) {
        return parts.first.substring(0, 1).toUpperCase();
      }
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            eyebrow: 'TEAM MATCHING',
            title: 'Find your next teammate',
            subtitle: 'Discover developers with skills that complement yours.',
            action: 'Find teammates',
            onAction: _openFindDevelopersForInvitation,
          ),
          const SizedBox(height: 17),

          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('developerProfiles')
                .doc(currentUid)
                .snapshots(),
            builder: (context, ownProfileSnapshot) {
              if (ownProfileSnapshot.hasError) {
                return const Text(
                  'Unable to load your skills.',
                  style: TextStyle(color: _AppColors.muted),
                );
              }

              if (ownProfileSnapshot.connectionState ==
                      ConnectionState.waiting &&
                  !ownProfileSnapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final ownProfile =
                  ownProfileSnapshot.data?.data() ?? <String, dynamic>{};

              final mySkills = <String>{
                ...readSkills(ownProfile['skills']),
                ...readSkills(ownProfile['technologies']),
              };

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('developerProfiles')
                    .limit(30)
                    .snapshots(),
                builder: (context, profilesSnapshot) {
                  if (profilesSnapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Unable to load developer profiles. Check Firestore permissions.',
                        style: TextStyle(color: _AppColors.muted),
                      ),
                    );
                  }

                  if (profilesSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !profilesSnapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final candidates = (profilesSnapshot.data?.docs ?? [])
                      .where((doc) => doc.id != currentUid)
                      .where((doc) {
                        final data = doc.data();
                        return data['isDeveloper'] != false &&
                            data['role']?.toString().toLowerCase() != 'client';
                      })
                      .toList();

                  if (candidates.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 22),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.groups_outlined,
                              size: 34,
                              color: _AppColors.muted,
                            ),
                            SizedBox(height: 9),
                            Text(
                              'No other developer profiles found',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _AppColors.ink,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Other developers will appear here when they create profiles.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: _AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  int compatibility(Map<String, dynamic> data) {
                    final candidateSkills = <String>{
                      ...readSkills(data['skills']),
                      ...readSkills(data['technologies']),
                    };

                    if (mySkills.isEmpty || candidateSkills.isEmpty) {
                      return 0;
                    }

                    final common = mySkills
                        .intersection(candidateSkills)
                        .length;
                    final total = mySkills.union(candidateSkills).length;

                    if (total == 0) return 0;
                    return ((common / total) * 100).round();
                  }

                  candidates.sort((a, b) {
                    return compatibility(b.data())
                        .compareTo(compatibility(a.data()));
                  });

                  return Column(
                    children: candidates.take(3).map((doc) {
                      final data = doc.data();

                      final name =
                          (data['name'] ??
                                  data['displayName'] ??
                                  data['fullName'] ??
                                  'Developer')
                              .toString();

                      final role =
                          (data['professionalTitle'] ??
                                  data['jobTitle'] ??
                                  data['role'] ??
                                  'Developer')
                              .toString();

                      final skills = <String>{
                        ...readSkills(data['skills']),
                        ...readSkills(data['technologies']),
                      }.toList();

                      final match = compatibility(data);

                      final subtitle = skills.isNotEmpty
                          ? '${skills.take(2).join(' • ')} • $match% match'
                          : '$role • Skills not added';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 13),
                        child: Row(
                          children: [
                            _Avatar(size: 48, initials: initials(name)),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _inviteDeveloper(doc.id),
                              child: const Text('Invite'),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUpcoming() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return _DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _SectionHeading(
              eyebrow: 'UP NEXT',
              title: 'Upcoming deadlines',
              subtitle: 'Stay ahead of your active project commitments.',
            ),
            SizedBox(height: 15),
            Text('Please log in to view your deadlines.'),
          ],
        ),
      );
    }

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

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .where('assignedDeveloperId', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Unable to load deadlines.'),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final tomorrow = today.add(const Duration(days: 1));

              final projects = snapshot.data?.docs ?? [];

              final deadlineProjects = projects.where((doc) {
                final data = doc.data();
                final status = (data['status'] ?? '').toString().toLowerCase();

                final deadlineValue = data['deadline'];

                if (deadlineValue == null) return false;

                if (status == 'completed' ||
                    status == 'cancelled' ||
                    status == 'closed' ||
                    status == 'rejected') {
                  return false;
                }

                return deadlineValue is Timestamp || deadlineValue is DateTime;
              }).toList();

              deadlineProjects.sort((a, b) {
                DateTime getDeadline(
                  QueryDocumentSnapshot<Map<String, dynamic>> doc,
                ) {
                  final value = doc.data()['deadline'];
                  if (value is Timestamp) return value.toDate();
                  return value as DateTime;
                }

                return getDeadline(a).compareTo(getDeadline(b));
              });

              final upcoming = deadlineProjects
                  .where((doc) {
                    final value = doc.data()['deadline'];
                    final deadline = value is Timestamp
                        ? value.toDate()
                        : value as DateTime;

                    return !deadline.isBefore(today);
                  })
                  .take(5)
                  .toList();

              if (upcoming.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No upcoming deadlines. Your projects are on track!',
                  ),
                );
              }

              return Column(
                children: upcoming.map((doc) {
                  final data = doc.data();
                  final deadlineValue = data['deadline'];

                  final deadline = deadlineValue is Timestamp
                      ? deadlineValue.toDate()
                      : deadlineValue as DateTime;

                  final deadlineDay = DateTime(
                    deadline.year,
                    deadline.month,
                    deadline.day,
                  );

                  final String dateLabel;

                  if (deadlineDay == today) {
                    dateLabel = 'TODAY';
                  } else if (deadlineDay == tomorrow) {
                    dateLabel = 'TOMORROW';
                  } else {
                    const months = [
                      'JAN',
                      'FEB',
                      'MAR',
                      'APR',
                      'MAY',
                      'JUN',
                      'JUL',
                      'AUG',
                      'SEP',
                      'OCT',
                      'NOV',
                      'DEC',
                    ];

                    dateLabel =
                        '${deadline.day.toString().padLeft(2, '0')} '
                        '${months[deadline.month - 1]}';
                  }

                  final title =
                      (data['deadlineTitle'] ??
                              data['nextMilestone'] ??
                              data['nextAction'] ??
                              data['title'] ??
                              data['projectTitle'] ??
                              'Project deadline')
                          .toString();

                  final project =
                      (data['title'] ??
                              data['projectTitle'] ??
                              'Untitled project')
                          .toString();

                  return _DeadlineRow(
                    date: dateLabel,
                    title: title,
                    project: project,
                    urgent: deadlineDay == today,
                  );
                }).toList(),
              );
            },
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
        _openFindDevelopersForInvitation,
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
              if (index == 4) {
                _selectNav(4); // Open Teams screen
              } else {
                _selectNav(index);
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
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups_rounded),
                label: 'Teams',
              ),
            ],
          );
  }

  void _showMobileMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
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

                // Teams
                ListTile(
                  leading: const Icon(Icons.groups_rounded),
                  title: const Text('Teams'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _selectNav(4);
                  },
                ),

                // Team Invitations
                ListTile(
                  leading: const Icon(Icons.mark_email_unread_outlined),
                  title: const Text('Team Invitations'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openTeamInvitations();
                  },
                ),

                // My Profile
                ListTile(
                  leading: const Icon(Icons.person_rounded),
                  title: const Text('My Profile'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _selectNav(6);
                  },
                ),

                // Logout
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Logout'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _logout();
                  },
                ),
              ],
            ),
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
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationService.watchMyNotifications(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FloatingPanel(
            title: 'Notifications',
            action: 'Mark all read',
            onAction: null,
            children: const [
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Unable to load notifications.',
                  style: TextStyle(fontSize: 12, color: _AppColors.muted),
                ),
              ),
            ],
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _FloatingPanel(
            title: 'Notifications',
            action: 'Mark all read',
            onAction: null,
            children: const [
              Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ],
          );
        }

        final notifications = snapshot.data ?? <NotificationModel>[];

        return _FloatingPanel(
          title: 'Notifications',
          action: 'Mark all read',
          onAction: notifications.any((notification) => notification.isUnread)
              ? _markAllNotificationsRead
              : null,
          children: [
            if (notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.all(22),
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 32,
                      color: _AppColors.muted,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'New updates will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: _AppColors.muted),
                    ),
                  ],
                ),
              )
            else
              ...notifications.take(8).map(_buildNotificationItem),
            const Divider(height: 12),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: _openAllNotifications,
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('View all notifications'),
                style: TextButton.styleFrom(
                  foregroundColor: _AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openAllNotifications() {
    setState(() {
      _notificationsOpen = false;
      _messagesOpen = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }

  Future<void> _markNotificationRead(NotificationModel notification) async {
    if (notification.isRead) {
      return;
    }

    try {
      await _notificationService.markAsRead(notification.id);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update notification: $error')),
      );
    }
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    return _NotificationItem(
      notification: notification,
      onTap: () => _markNotificationRead(notification),
    );
  }

  Future<void> _markAllNotificationsRead() async {
    try {
      await _notificationService.markAllAsRead();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark notifications as read: $error')),
      );
    }
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

  Future<void> _showApplyDialog(_ProjectData project) async {
    final formKey = GlobalKey<FormState>();
    final messageController = TextEditingController();
    final budgetController = TextEditingController();
    final durationController = TextEditingController(text: project.duration);

    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submitApplication() async {
              if (isSubmitting) return;

              if (!formKey.currentState!.validate()) return;

              final user = FirebaseAuth.instance.currentUser;

              if (user == null) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Please log in to apply for projects.'),
                  ),
                );
                return;
              }

              final proposedBudget = double.tryParse(
                budgetController.text.trim().replaceAll(',', ''),
              );

              if (proposedBudget == null || proposedBudget <= 0) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid proposed budget.'),
                  ),
                );
                return;
              }

              setDialogState(() => isSubmitting = true);

              try {
                await _applicationService.createApplication(
                  projectId: project.id,
                  clientId: project.clientId,
                  coverLetter: messageController.text.trim(),
                  proposedBudget: proposedBudget,
                  estimatedDuration: durationController.text.trim(),
                );

                if (!mounted) return;

                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Application submitted successfully!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (error) {
                setDialogState(() => isSubmitting = false);

                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Could not submit application: ${error.toString()}',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(26),
                    child: Form(
                      key: formKey,
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
                              const Expanded(
                                child: Text(
                                  'AI Application Assistant',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
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
                                    'Strong match based on your current profile. '
                                    'Review your proposal before submitting.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.45,
                                    ),
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
                          TextFormField(
                            controller: messageController,
                            maxLines: 5,
                            enabled: !isSubmitting,
                            decoration: InputDecoration(
                              hintText:
                                  'Introduce yourself and explain why '
                                  'you are suitable for this project...',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: _AppColors.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: _AppColors.border,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an application message.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your proposed budget (₹)',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: budgetController,
                            enabled: !isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your proposed amount',
                              prefixText: '₹ ',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: _AppColors.border,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final amount = double.tryParse(
                                (value ?? '').trim().replaceAll(',', ''),
                              );

                              if (amount == null || amount <= 0) {
                                return 'Enter a valid budget greater than zero.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Estimated duration',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: durationController,
                            enabled: !isSubmitting,
                            decoration: InputDecoration(
                              hintText: 'e.g. 3 weeks',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: _AppColors.border,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your estimated duration.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                child: const Text('Cancel'),
                              ),
                              FilledButton.icon(
                                onPressed: isSubmitting
                                    ? null
                                    : submitApplication,
                                icon: isSubmitting
                                    ? const SizedBox(
                                        width: 17,
                                        height: 17,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded, size: 17),
                                label: Text(
                                  isSubmitting
                                      ? 'Submitting...'
                                      : 'Submit application',
                                ),
                              ),
                            ],
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
      },
    );

    messageController.dispose();
    budgetController.dispose();
    durationController.dispose();
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
  final String id;
  final String clientId;
  final String duration;
  final String title;
  final String client;
  final String description;
  final int match;
  final List<String> skills;
  final String budget;
  final String mode;
  final IconData icon;

  const _ProjectData({
    required this.id,
    required this.clientId,
    required this.duration,
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
  final String? name;
  final String? profileImageUrl;

  const _Avatar({
    required this.size,
    this.initials,
    this.name,
    this.profileImageUrl,
  });

  String _getInitials(String? name) {
    final value = name?.trim() ?? '';

    if (value.isEmpty) return '';

    final parts = value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }

    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (profileImageUrl?.trim().isNotEmpty == true) {
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDBEAFE), Color(0xFFE0E7FF)],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: SkillBridgeAvatar(
          profileImageUrl: profileImageUrl,
          name: name ?? initials,
          size: size - 4,
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF3730A3),
        ),
      );
    }

    final displayInitials =
        initials ??
        (name?.trim().isNotEmpty == true ? name!.trim()[0].toUpperCase() : 'A');

    final avatarText = _getInitials(initials);

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
      child: avatarText.isEmpty
          ? Icon(
              Icons.person_rounded,
              color: const Color(0xFF3730A3),
              size: size * 0.58,
            )
          : Text(
              avatarText,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF3730A3),
                fontSize: size * (avatarText.length > 1 ? 0.29 : 0.34),
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
        if (badge > 0)
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                badge > 9 ? '9+' : '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
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
    final skills = widget.project.skills
        .map((skill) => skill.trim())
        .where((skill) => skill.isNotEmpty)
        .toList();

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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
              softWrap: true,
              style: const TextStyle(
                color: _AppColors.muted,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            // Keep skill chips on one horizontally scrollable row. A Wrap can
            // create several rows for long project skill lists and push the
            // View/Apply buttons outside the fixed-height recommendation card.
            SizedBox(
              height: 34,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    ...skills
                        .take(3)
                        .map(
                          (skill) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _SkillChip(skill),
                          ),
                        ),
                    if (skills.length > 3)
                      _SkillChip('+${skills.length - 3} more'),
                  ],
                ),
              ),
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 145),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: _AppColors.muted,
              ),
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
  final VoidCallback? onAction;

  const _FloatingPanel({
    required this.title,
    required this.action,
    required this.children,
    this.onAction,
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
                onPressed: onAction,
                child: Text(
                  action,
                  style: TextStyle(
                    fontSize: 10,
                    color: onAction == null
                        ? _AppColors.muted
                        : _AppColors.primary,
                  ),
                ),
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
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationItem({required this.notification, required this.onTap});

  IconData _iconForType(String type) {
    switch (type.trim().toLowerCase()) {
      case 'project_match':
        return Icons.auto_awesome_rounded;

      case 'shortlisted':
        return Icons.star_rounded;

      case 'accepted':
        return Icons.check_circle_rounded;

      case 'rejected':
        return Icons.cancel_rounded;

      case 'application':
        return Icons.assignment_rounded;

      case 'team':
        return Icons.groups_2_rounded;

      case 'deadline':
        return Icons.schedule_rounded;

      case 'message':
        return Icons.chat_bubble_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

  String _timeAgo(DateTime? dateTime) {
    if (dateTime == null) {
      return '';
    }

    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} h';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} d';
    }

    return '${dateTime.day}/${dateTime.month}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: unread ? const Color(0xFFF8FAFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                _iconForType(notification.type),
                size: 18,
                color: _AppColors.primary,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.w900
                                : FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 5),
                          decoration: const BoxDecoration(
                            color: _AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.35,
                      color: _AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _timeAgo(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 8.5,
                      color: _AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _QuickAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction(this.icon, this.title, this.subtitle, this.onTap);
}
