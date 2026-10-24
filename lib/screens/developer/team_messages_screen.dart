
import 'package:flutter/material.dart';

import '../../models/team_model.dart';
import '../../services/team_service.dart';
import 'team_chat_screen.dart';

class TeamMessagesScreen extends StatefulWidget {
  const TeamMessagesScreen({super.key});

  @override
  State<TeamMessagesScreen> createState() =>
      _TeamMessagesScreenState();
}

class _TeamMessagesScreenState
    extends State<TeamMessagesScreen> {
  final TeamService _teamService = TeamService();
  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChat(TeamModel team) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TeamChatScreen(
          teamId: team.id,
          teamName: team.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2563EB);
    const ink = Color(0xFF0F172A);
    const muted = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: ink),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(
              20, 4, 20, 20,
            ),
            child: const Text(
              'Connect with your project teams.',
              style: TextStyle(
                color: muted,
                fontSize: 14,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16, 18, 16, 12,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search teams or projects...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TeamModel>>(
              stream: _teamService.watchMyTeams(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Unable to load your teams. '
                        'Please check your connection and '
                        'Firestore permissions.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final teams = (snapshot.data ?? <TeamModel>[])
                    .where((team) {
                  final matchesSearch = team.name
                          .toLowerCase()
                          .contains(_searchQuery) ||
                      team.projectTitle
                          .toLowerCase()
                          .contains(_searchQuery);

                  return matchesSearch && team.isActive;
                }).toList();

                if (teams.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius:
                                  BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.forum_outlined,
                              size: 42,
                              color: primary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No matching teams'
                                : 'No active teams yet',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Teams you belong to will appear here. '
                            'Accept a team invitation or create a '
                            'team to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: muted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    16, 4, 16, 24,
                  ),
                  itemCount: teams.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final team = teams[index];

                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openChat(team),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius:
                                      BorderRadius.circular(17),
                                ),
                                child: const Icon(
                                  Icons.groups_rounded,
                                  color: primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      team.name.isEmpty
                                          ? 'Unnamed team'
                                          : team.name,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w800,
                                        color: ink,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      team.projectTitle.isEmpty
                                          ? 'Team group chat'
                                          : team.projectTitle,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.people_outline,
                                          size: 15,
                                          color: muted,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${team.memberCount} members',
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration:
                                              const BoxDecoration(
                                            color: Color(0xFF16A34A),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        const Text(
                                          'Active',
                                          style: TextStyle(
                                            color: Color(0xFF15803D),
                                            fontSize: 11,
                                            fontWeight:
                                                FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: muted,
                              ),
                            ],
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
      ),
    );
  }
}
