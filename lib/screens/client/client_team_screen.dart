import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClientTeamScreen extends StatelessWidget {
  final String projectId;

  const ClientTeamScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Project Team',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .collection('team')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load team.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final members = snapshot.data?.docs ?? [];

          if (members.isEmpty) {
            return const _EmptyTeam();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: members.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final document = members[index];
              final data = document.data();

              return _TeamMemberCard(data: data);
            },
          );
        },
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _TeamMemberCard({required this.data});

  IconData _roleIcon(String role) {
    switch (role) {
      case 'frontend':
        return Icons.web_rounded;

      case 'backend':
        return Icons.dns_rounded;

      case 'database':
        return Icons.storage_rounded;

      case 'tester':
        return Icons.bug_report_outlined;

      case 'project_manager':
      case 'team_leader':
        return Icons.manage_accounts_outlined;

      default:
        return Icons.person_outline_rounded;
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'frontend':
        return 'Frontend Developer';

      case 'backend':
        return 'Backend Developer';

      case 'database':
        return 'Database Developer';

      case 'tester':
        return 'Tester / QA';

      case 'project_manager':
      case 'team_leader':
        return 'Project Manager / Team Leader';

      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = data['name']?.toString() ?? 'Developer';

    final role = data['role']?.toString() ?? '';

    final email = data['email']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(_roleIcon(role), color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatRole(role),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTeam extends StatelessWidget {
  const _EmptyTeam();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 64, color: Color(0xFF94A3B8)),
            SizedBox(height: 18),
            Text(
              'No team members yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Team members assigned to this project will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
