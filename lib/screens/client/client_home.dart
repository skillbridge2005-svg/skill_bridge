import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_project_screen.dart';
import 'my_projects_screen.dart';
import 'client_profile_screen.dart';
import 'client_messages_screen.dart';
import 'client_notifications_screen.dart';
import 'project_details_screen.dart';

class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  int _currentIndex = 0;

  final List<String> _titles = const [
    'Dashboard',
    'My Projects',
    'Messages',
    'Notifications',
    'Profile',
  ];

  void _changeSection(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const _ClientDashboardSection(),
          const _ClientProjectsSection(),
          const _ClientMessagesSection(),
          const _ClientNotificationsSection(),
          const _ClientProfileSection(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _changeSection,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Please login again.'));
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
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Unable to load dashboard data.\n'
                    '${projectSnapshot.error}',
                    textAlign: TextAlign.center,
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

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Welcome back' : 'Welcome back, $name',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Manage your software projects from one place.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 28),

                      _CreateProjectCard(
                        onTap: () => _openCreateProject(context),
                      ),

                      const SizedBox(height: 28),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cards = [
                            _DashboardStatCard(
                              icon: Icons.folder_outlined,
                              title: 'Total Projects',
                              value: totalProjects.toString(),
                            ),
                            _DashboardStatCard(
                              icon: Icons.timelapse_rounded,
                              title: 'Active Projects',
                              value: activeProjects.toString(),
                            ),
                            _DashboardStatCard(
                              icon: Icons.check_circle_outline_rounded,
                              title: 'Completed',
                              value: completedProjects.toString(),
                            ),
                          ];

                          if (constraints.maxWidth > 700) {
                            return Row(
                              children: cards
                                  .map(
                                    (card) => Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 10,
                                        ),
                                        child: card,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          }

                          return Column(
                            children: cards
                                .map(
                                  (card) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: card,
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 30),

                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Recent Projects',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (projects.isNotEmpty)
                            TextButton(
                              onPressed: () => _openMyProjects(context),
                              child: const Text('View All'),
                            ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      if (projects.isEmpty)
                        const _EmptyProjectCard()
                      else
                        Column(
                          children: projects
                              .take(3)
                              .map(
                                (doc) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _DashboardProjectCard(
                                    project: doc.data(),
                                    projectId: doc.id,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
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

class _CreateProjectCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateProjectCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: const Color(0xFF2563EB),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.add_business_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a New Project',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Start with your software idea and requirements.',
                    style: TextStyle(fontSize: 14, color: Color(0xFFE0EAFF)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DashboardStatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
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

class _DashboardProjectCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final String projectId;

  const _DashboardProjectCard({required this.project, required this.projectId});

  String _formatStatus(String status) {
    switch (status) {
      case 'requirement':
        return 'Requirement';
      case 'team_formation':
        return 'Team Formation';
      case 'development':
        return 'Development';
      case 'testing':
        return 'Testing';
      case 'client_review':
        return 'Client Review';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = project['title']?.toString() ?? 'Untitled Project';

    final category = project['category']?.toString() ?? '';

    final status = project['status']?.toString() ?? 'requirement';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailsScreen(projectId: projectId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.folder_outlined,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatStatus(status),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProjectCard extends StatelessWidget {
  const _EmptyProjectCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.folder_open_outlined, size: 52, color: Color(0xFF94A3B8)),
          SizedBox(height: 14),
          Text(
            'No projects yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Your real projects will appear here after you create one.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
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
