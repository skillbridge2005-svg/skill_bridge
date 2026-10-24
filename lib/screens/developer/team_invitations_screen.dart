
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/team_invitation_model.dart';
import '../../services/team_invitation_service.dart';

class TeamInvitationsScreen extends StatefulWidget {
  const TeamInvitationsScreen({super.key});

  @override
  State<TeamInvitationsScreen> createState() =>
      _TeamInvitationsScreenState();
}

class _TeamInvitationsScreenState
    extends State<TeamInvitationsScreen> {
  final TeamInvitationService _service = TeamInvitationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _processing = {};

  Future<Map<String, dynamic>> _loadLeaderInfo(String uid) async {
    final userSnapshot =
        await _firestore.collection('users').doc(uid).get();

    final userData = userSnapshot.data() ?? {};

    // Profile information is stored separately in developerProfiles.
    final profileSnapshot = await _firestore
        .collection('developerProfiles')
        .doc(uid)
        .get();

    final profileData = profileSnapshot.data() ?? {};

    return {
      'name': (userData['name'] ??
              profileData['name'] ??
              userData['displayName'] ??
              'Team leader')
          .toString(),
      'email': (userData['email'] ??
              profileData['email'] ??
              '')
          .toString(),
      'headline': (profileData['headline'] ?? '').toString(),
      'photoUrl': (profileData['photoUrl'] ?? '').toString(),
    };
  }

  Future<void> _respond(
    TeamInvitationModel invitation, {
    required bool accept,
  }) async {
    if (_processing.contains(invitation.id)) return;

    setState(() => _processing.add(invitation.id));

    try {
      if (accept) {
        await _service.acceptInvitation(invitation.id);
      } else {
        await _service.rejectInvitation(invitation.id);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Invitation accepted.'
                : 'Invitation declined.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not respond to invitation: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processing.remove(invitation.id));
      }
    }
  }

  Widget _infoSection({
    required IconData icon,
    required String title,
    required String value,
  }) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: const Color(0xFF4F46E5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    height: 1.45,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderSection(String senderId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadLeaderInfo(senderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        final leader = snapshot.data ?? {};
        final name = leader['name']?.toString() ?? 'Team leader';
        final headline = leader['headline']?.toString() ?? '';
        final email = leader['email']?.toString() ?? '';
        final photoUrl = leader['photoUrl']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE5EAF2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFFE0E7FF),
                backgroundImage: photoUrl.startsWith('http')
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.startsWith('http')
                    ? null
                    : const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF4338CA),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'INVITED BY',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (headline.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        headline,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvitationCard(
    TeamInvitationModel invitation,
    bool busy,
  ) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: Color(0xFFE5EAF2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.teamName.isEmpty
                            ? 'Team invitation'
                            : invitation.teamName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        invitation.projectTitle.isEmpty
                            ? 'Project not specified'
                            : invitation.projectTitle,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.mail_outline_rounded,
                  color: Color(0xFF2563EB),
                ),
              ],
            ),

            _leaderSection(invitation.senderId),

            _infoSection(
              icon: Icons.badge_outlined,
              title: 'Your assigned role',
              value: invitation.role,
            ),

            _infoSection(
              icon: Icons.assignment_outlined,
              title: 'Responsibilities',
              value: invitation.responsibilities,
            ),

            _infoSection(
              icon: Icons.description_outlined,
              title: 'About the team',
              value: invitation.teamDescription,
            ),

            if (invitation.createdAt != null) ...[
              const SizedBox(height: 16),
              Text(
                'Received ${invitation.createdAt!.toLocal().toString().split('.').first}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _respond(
                              invitation,
                              accept: false,
                            ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () => _respond(
                              invitation,
                              accept: true,
                            ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text(
          'Team Invitations',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: StreamBuilder<List<TeamInvitationModel>>(
        stream: _service.watchReceivedInvitations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load invitations.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final invitations = (snapshot.data ?? [])
              .where((invitation) => invitation.isPending)
              .toList();

          if (invitations.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: 58,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No pending invitations',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'When a team invites you, it will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: invitations.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final invitation = invitations[index];
              final busy = _processing.contains(invitation.id);

              return _buildInvitationCard(invitation, busy);
            },
          );
        },
      ),
    );
  }
}
