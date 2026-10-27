import 'package:flutter/material.dart';

import '../../models/project_model.dart';
import '../../services/application_service.dart';
import '../../services/project_service.dart';
import '../../services/team_service.dart';
import '../../models/team_model.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/team_invitation_service.dart';
import '../../services/individual_chat_service.dart';
import '../../widgets/skillbridge_avatar.dart';
import '../developer/team_chat_screen.dart';
import 'individual_chat_screen.dart' hide IndividualChatService;
import 'developer_public_profile_screen.dart';
import 'individual_chats_screen.dart';

class Teams extends StatefulWidget {
  const Teams({super.key});

  @override
  State<Teams> createState() => _TeamsState();
}

class _TeamsState extends State<Teams> {
  final TeamService _teamService = TeamService();
  final ApplicationService _applicationService = ApplicationService();
  final ProjectService _projectService = ProjectService();

  final TextEditingController _searchController = TextEditingController();

  final TeamInvitationService _invitationService = TeamInvitationService();
  final IndividualChatService _individualChatService = IndividualChatService();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TeamModel> _filterTeams(List<TeamModel> teams) {
    if (_searchQuery.isEmpty) {
      return teams;
    }

    return _teamService.searchTeams(teams, _searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            Navigator.of(context).maybePop();
          },
        ),
        title: const Text(
          'Teams',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),

        actions: [
          IconButton(
            tooltip: 'Individual Chats',
            icon: const Icon(Icons.forum_outlined, color: Color(0xFF2563EB)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => IndividualChatsScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _showCreateTeamDialog,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Create Team'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<TeamModel>>(
        stream: _teamService.watchMyTeams(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final teams = snapshot.data ?? <TeamModel>[];

          final filteredTeams = _filterTeams(teams);

          return Column(
            children: [
              _buildHeader(teams.length),
              Expanded(
                child: filteredTeams.isEmpty
                    ? _buildEmptyState(hasTeams: teams.isNotEmpty)
                    : _buildTeamList(filteredTeams),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(int teamCount) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Teams',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            teamCount == 0
                ? 'Create or join teams for your projects.'
                : '$teamCount '
                      '${teamCount == 1 ? 'team' : 'teams'} found',
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search teams or projects...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF7F8FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamList(List<TeamModel> teams) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: teams.length,
      itemBuilder: (context, index) {
        final team = teams[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildTeamCard(team),
        );
      },
    );
  }

  Widget _buildTeamCard(TeamModel team) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _showTeamDetails(team);
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name.isEmpty ? 'Unnamed Team' : team.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          team.projectTitle.isEmpty
                              ? 'Project not specified'
                              : team.projectTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(team.status),
                ],
              ),
              const SizedBox(height: 18),
              if (team.description.isNotEmpty) ...[
                Text(
                  team.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  const Icon(
                    Icons.people_outline_rounded,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${team.memberCount} '
                    '${team.memberCount == 1 ? 'member' : 'members'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'View Team',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: Color(0xFF2563EB),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final normalized = status.trim().toLowerCase();

    final label = normalized.isEmpty
        ? 'Active'
        : '${normalized[0].toUpperCase()}'
              '${normalized.substring(1)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: normalized == 'completed'
            ? const Color(0xFFECFDF5)
            : normalized == 'archived'
            ? const Color(0xFFF3F4F6)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: normalized == 'completed'
              ? const Color(0xFF047857)
              : normalized == 'archived'
              ? const Color(0xFF6B7280)
              : const Color(0xFF2563EB),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool hasTeams}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.groups_outlined,
                size: 44,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasTeams ? 'No teams found' : 'No teams yet',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasTeams
                  ? 'Try a different search.'
                  : 'Create a team for one of '
                        'your active projects to get started.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _showCreateTeamDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Team'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load teams',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateTeamDialog() async {
    final nameController = TextEditingController();

    final descriptionController = TextEditingController();

    String? selectedProjectId;

    List<ProjectModel> activeProjects = <ProjectModel>[];

    bool loadingProjects = true;
    String? projectError;

    try {
      final applications = await _applicationService.getMyApplications();

      final acceptedApplications = applications
          .where(
            (application) =>
                application.status.trim().toLowerCase() == 'accepted',
          )
          .toList();

      for (final application in acceptedApplications) {
        final project = await _projectService.getProject(application.projectId);

        if (project != null) {
          activeProjects.add(project);
        }
      }

      if (activeProjects.isNotEmpty) {
        selectedProjectId = activeProjects.first.id;
      }
    } catch (e) {
      projectError = e.toString();
    } finally {
      loadingProjects = false;
    }

    if (!mounted) {
      nameController.dispose();
      descriptionController.dispose();
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isCreating = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> createTeam() async {
              final name = nameController.text.trim();

              final description = descriptionController.text.trim();

              if (name.isEmpty) {
                _showSnackBar('Please enter a team name.');
                return;
              }

              if (selectedProjectId == null || selectedProjectId!.isEmpty) {
                _showSnackBar('Please select a project.');
                return;
              }

              final selectedProject = activeProjects.firstWhere(
                (project) => project.id == selectedProjectId,
              );

              setDialogState(() {
                isCreating = true;
              });

              try {
                await _teamService.createTeam(
                  name: name,
                  projectId: selectedProject.id,
                  projectTitle: selectedProject.title,
                  memberIds: const [],
                  description: description,
                );

                if (!mounted) return;
                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop();

                _showSnackBar('Team created successfully.');
              } catch (e) {
                setDialogState(() {
                  isCreating = false;
                });

                _showSnackBar(e.toString());
              }
            }

            return AlertDialog(
              title: const Text(
                'Create Team',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create a team for one of your active projects.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        enabled: !isCreating,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Team Name',
                          hintText: 'e.g. Flutter Development Team',
                          prefixIcon: const Icon(Icons.groups_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (loadingProjects)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Loading active projects...'),
                            ],
                          ),
                        )
                      else if (projectError != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Unable to load active projects.\n'
                            '$projectError',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9A3412),
                            ),
                          ),
                        )
                      else if (activeProjects.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'You currently have no accepted projects. '
                            'You need an accepted project before creating a team.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: selectedProjectId,
                          decoration: InputDecoration(
                            labelText: 'Project',
                            prefixIcon: const Icon(Icons.work_outline_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: activeProjects.map((project) {
                            return DropdownMenuItem<String>(
                              value: project.id,
                              child: SizedBox(
                                width: 330,
                                child: Text(
                                  project.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: isCreating
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    selectedProjectId = value;
                                  });
                                },
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descriptionController,
                        enabled: !isCreating,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          hintText: 'Describe what this team will work on...',
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 54),
                            child: Icon(Icons.description_outlined),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed:
                      isCreating || loadingProjects || activeProjects.isEmpty
                      ? null
                      : createTeam,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                  child: isCreating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Team'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
  }

  Future<void> _showInviteMemberDialog(TeamModel team) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      _showSnackBar('Please sign in to invite a developer.');
      return;
    }

    if (team.ownerId != currentUid) {
      _showSnackBar('Only the team owner can invite members.');
      return;
    }

    if (!team.isActive) {
      _showSnackBar('Only active teams can receive invitations.');
      return;
    }

    final roleController = TextEditingController();
    final responsibilitiesController = TextEditingController();
    final customRoleController = TextEditingController();
    const roles = <String>[
      'Flutter Developer',
      'Frontend Developer',
      'Backend Developer',
      'Full Stack Developer',
      'UI/UX Designer',
      'QA Tester',
      'Database Developer',
      'DevOps Engineer',
      'Other (custom role)',
    ];

    String selectedRole = roles.first;
    String search = '';
    String? sendingUid;
    List<Map<String, dynamic>> developers = [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'developer')
          .get();

      final eligibleDocs = snapshot.docs.where((doc) {
        return doc.id != currentUid && !team.memberIds.contains(doc.id);
      }).toList();

      // Join users data with developerProfiles so the inviter can see
      // headline, skills, technologies and profile photo before inviting.
      final profileResults = await Future.wait(
        eligibleDocs.map((doc) async {
          final profileSnapshot = await FirebaseFirestore.instance
              .collection('developerProfiles')
              .doc(doc.id)
              .get();
          final userData = doc.data();
          final profileData = profileSnapshot.data() ?? <String, dynamic>{};
          return <String, dynamic>{
            'id': doc.id,
            'name':
                (profileData['name'] ??
                        userData['name'] ??
                        userData['displayName'] ??
                        userData['fullName'] ??
                        'Developer')
                    .toString(),
            'email': (profileData['email'] ?? userData['email'] ?? '')
                .toString(),
            'headline': (profileData['headline'] ?? '').toString(),
            'photoUrl':
                (userData['profileImageUrl'] ??
                        userData['photoUrl'] ??
                        profileData['photoUrl'] ??
                        '')
                    .toString(),
            'skills': profileData['skills'] is List
                ? List<String>.from(profileData['skills'])
                : <String>[],
            'technologies': profileData['technologies'] is List
                ? List<String>.from(profileData['technologies'])
                : <String>[],
            'openToTeams': profileData['openToTeams'] != false,
            'profileVisible': profileData['profileVisible'] != false,
          };
        }),
      );

      developers = profileResults
          .where(
            (developer) =>
                developer['openToTeams'] == true &&
                developer['profileVisible'] == true,
          )
          .toList();

      if (!mounted) {
        roleController.dispose();
        responsibilitiesController.dispose();
        customRoleController.dispose();
        return;
      }

      if (developers.isEmpty) {
        _showSnackBar('No eligible developers found.');
        roleController.dispose();
        responsibilitiesController.dispose();
        customRoleController.dispose();
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final filtered = developers.where((developer) {
                final searchable = [
                  developer['name'],
                  developer['email'],
                  developer['headline'],
                  ...(developer['skills'] as List<String>),
                  ...(developer['technologies'] as List<String>),
                ].join(' ').toLowerCase();
                return searchable.contains(search.toLowerCase());
              }).toList();

              final role = selectedRole == 'Other (custom role)'
                  ? customRoleController.text.trim()
                  : selectedRole;

              Future<void> sendTo(Map<String, dynamic> developer) async {
                if (role.trim().isEmpty) {
                  _showSnackBar('Please select or enter a role.');
                  return;
                }
                if (responsibilitiesController.text.trim().isEmpty) {
                  _showSnackBar(
                    'Please enter the responsibilities for this role.',
                  );
                  return;
                }

                final developerId = developer['id'].toString();
                setDialogState(() => sendingUid = developerId);

                try {
                  await _invitationService.sendInvitation(
                    teamId: team.id,
                    developerId: developerId,
                    role: role,
                    responsibilities: responsibilitiesController.text.trim(),
                  );

                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  _showSnackBar('Invitation sent to ${developer['name']}.');
                } catch (error) {
                  setDialogState(() => sendingUid = null);
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Could not send invitation: $error'),
                    ),
                  );
                }
              }

              return AlertDialog(
                title: const Text(
                  'Invite a Developer',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                content: SizedBox(
                  width: 560,
                  height: 620,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite someone to ${team.name} and define their role.',
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Team role',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: roles
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(
                                  item,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: sendingUid != null
                            ? null
                            : (value) {
                                if (value == null) return;
                                setDialogState(() => selectedRole = value);
                              },
                      ),
                      if (selectedRole == 'Other (custom role)') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: customRoleController,
                          enabled: sendingUid == null,
                          decoration: const InputDecoration(
                            labelText: 'Custom role name',
                            hintText: 'e.g. AI Integration Developer',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: responsibilitiesController,
                        enabled: sendingUid == null,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Responsibilities',
                          hintText: 'Describe the tasks this developer will handle...',
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(bottom: 38),
                            child: Icon(Icons.assignment_outlined),
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        enabled: sendingUid == null,
                        decoration: const InputDecoration(
                          hintText: 'Search by name, skill or email',
                          prefixIcon: Icon(Icons.search_rounded),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) =>
                            setDialogState(() => search = value),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose a developer to send the invitation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text('No matching developers found.'),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final developer = filtered[index];
                                  final developerId = developer['id']
                                      .toString();
                                  final photoUrl = developer['photoUrl']
                                      .toString();
                                  final developerName = developer['name']
                                      .toString();
                                  final busy = sendingUid == developerId;
                                  final skills = <String>[
                                    ...(developer['skills'] as List<String>),
                                    ...(developer['technologies']
                                        as List<String>),
                                  ].toSet().take(4).join(' · ');
                                  final subtitle = [
                                    if (developer['headline']
                                        .toString()
                                        .isNotEmpty)
                                      developer['headline'].toString(),
                                    if (skills.isNotEmpty) skills,
                                    if (developer['email']
                                        .toString()
                                        .isNotEmpty)
                                      developer['email'].toString(),
                                  ].join('\n');

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    leading: SkillBridgeAvatar(
                                      profileImageUrl: photoUrl,
                                      name: developerName,
                                      size: 40,
                                      backgroundColor: const Color(0xFFE0E7FF),
                                      foregroundColor: const Color(0xFF4338CA),
                                    ),
                                    title: Text(
                                      developerName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: subtitle.isEmpty
                                        ? const Text('Developer')
                                        : Text(
                                            subtitle,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                    isThreeLine: subtitle.contains('\n'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'View developer profile',
                                          icon: const Icon(
                                            Icons.account_circle_outlined,
                                            color: Color(0xFF4F46E5),
                                          ),
                                          onPressed: () {
                                            Navigator.of(dialogContext).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    DeveloperPublicProfileScreen(
                                                      developerId: developerId,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                        busy
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : IconButton(
                                                tooltip: 'Send invitation',
                                                icon: const Icon(
                                                  Icons
                                                      .person_add_alt_1_rounded,
                                                  color: Color(0xFF2563EB),
                                                ),
                                                onPressed: sendingUid == null
                                                    ? () => sendTo(developer)
                                                    : null,
                                              ),
                                      ],
                                    ),
                                    enabled: sendingUid == null,
                                    onTap: () {
                                      Navigator.of(dialogContext).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              DeveloperPublicProfileScreen(
                                                developerId: developerId,
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
                ),
                actions: [
                  TextButton(
                    onPressed: sendingUid != null
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (error) {
      _showSnackBar('Could not load developers: $error');
    } finally {
      roleController.dispose();
      responsibilitiesController.dispose();
      customRoleController.dispose();
    }
  }

  Future<List<Map<String, dynamic>>> _loadTeamMembers(TeamModel team) async {
    final firestore = FirebaseFirestore.instance;
    final members = <Map<String, dynamic>>[];

    for (final memberId in team.memberIds.toSet()) {
      try {
        final results = await Future.wait([
          firestore.collection('users').doc(memberId).get(),
          firestore.collection('developerProfiles').doc(memberId).get(),
        ]);
        final userData = results[0].data() ?? <String, dynamic>{};
        final profileData = results[1].data() ?? <String, dynamic>{};
        final name =
            (profileData['name'] ??
                    userData['name'] ??
                    userData['displayName'] ??
                    'Developer')
                .toString();
        members.add({
          'id': memberId,
          'name': name,
          'email': (profileData['email'] ?? userData['email'] ?? '').toString(),
          'photoUrl':
              (userData['profileImageUrl'] ??
                      userData['photoUrl'] ??
                      profileData['photoUrl'] ??
                      '')
                  .toString(),
          'headline': (profileData['headline'] ?? '').toString(),
          'skills': _toStringList(profileData['skills']),
          'technologies': _toStringList(profileData['technologies']),
          'isOwner': memberId == team.ownerId,
        });
      } catch (_) {
        members.add({
          'id': memberId,
          'name': 'Team member',
          'email': '',
          'photoUrl': '',
          'headline': '',
          'skills': <String>[],
          'technologies': <String>[],
          'isOwner': memberId == team.ownerId,
        });
      }
    }

    members.sort((a, b) {
      if (a['isOwner'] == true) return -1;
      if (b['isOwner'] == true) return 1;
      return (a['name'] as String).toLowerCase().compareTo(
        (b['name'] as String).toLowerCase(),
      );
    });
    return members;
  }

  List<String> _toStringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  Future<void> _confirmRemoveMember(
    TeamModel team,
    String memberId,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove team member?'),
        content: Text(
          'Remove $name from ${team.name}? They will lose access to this team membership.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove member'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _teamService.removeMember(team.id, memberId);
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnackBar('$name was removed from the team.');
    } catch (error) {
      _showSnackBar('Could not remove member: $error');
    }
  }

  Future<void> _confirmDeleteTeam(TeamModel team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this team?'),
        content: Text(
          'This will permanently delete "${team.name}". This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete team'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _teamService.deleteTeam(team.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnackBar('Team deleted successfully.');
    } catch (error) {
      _showSnackBar('Could not delete team: $error');
    }
  }

  void _showTeamDetails(TeamModel team) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = team.ownerId == currentUid;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(team.name.isEmpty ? 'Team Details' : team.name),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _detailRow(
                    'Project',
                    team.projectTitle.isEmpty
                        ? 'Not specified'
                        : team.projectTitle,
                  ),
                  _detailRow(
                    'Status',
                    team.status.isEmpty ? 'Active' : team.status,
                  ),
                  if (team.description.isNotEmpty)
                    _detailRow('Description', team.description),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Team Members',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      Chip(label: Text('${team.memberIds.toSet().length}')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _loadTeamMembers(team),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Text(
                          'Could not load team members. Please try again.',
                        );
                      }
                      final members = snapshot.data ?? <Map<String, dynamic>>[];
                      if (members.isEmpty)
                        return const Text('No members found.');
                      return Column(
                        children: members.map((member) {
                          final memberId = member['id'].toString();
                          final photoUrl = member['photoUrl'].toString();
                          final skills = <String>[
                            ..._toStringList(member['skills']),
                            ..._toStringList(member['technologies']),
                          ].toSet().take(3).join(' · ');
                          final subtitle = [
                            if (member['isOwner'] == true) 'Team owner',
                            if (member['headline'].toString().isNotEmpty)
                              member['headline'].toString(),
                            if (skills.isNotEmpty) skills,
                            if (member['email'].toString().isNotEmpty)
                              member['email'].toString(),
                          ].join('\n');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            color: const Color(0xFFF8FAFC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              leading: SkillBridgeAvatar(
                                profileImageUrl: photoUrl,
                                name: member['name']?.toString(),
                                size: 40,
                                backgroundColor: const Color(0xFFE0E7FF),
                                foregroundColor: const Color(0xFF4338CA),
                              ),
                              title: Text(
                                member['name'].toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: subtitle.isEmpty
                                  ? null
                                  : Text(
                                      subtitle,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              isThreeLine: subtitle.contains('\n'),
                              onTap: () {
                                Navigator.of(dialogContext).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DeveloperPublicProfileScreen(
                                          developerId: memberId,
                                        ),
                                  ),
                                );
                              },
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Member actions',
                                onSelected: (action) {
                                  if (action == 'profile') {
                                    Navigator.of(dialogContext).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DeveloperPublicProfileScreen(
                                              developerId: memberId,
                                            ),
                                      ),
                                    );
                                  } else if (action == 'message') {
                                    _openIndividualChat(
                                      team,
                                      memberId,
                                      member['name'].toString(),
                                    );
                                  } else if (action == 'remove') {
                                    if (memberId == team.ownerId) {
                                      _showSnackBar(
                                        'The team owner cannot be removed.',
                                      );
                                    } else {
                                      _confirmRemoveMember(
                                        team,
                                        memberId,
                                        member['name'].toString(),
                                      );
                                    }
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'profile',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.account_circle_outlined,
                                      ),
                                      title: Text('View profile'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  if (memberId !=
                                      FirebaseAuth.instance.currentUser?.uid)
                                    const PopupMenuItem(
                                      value: 'message',
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.chat_bubble_outline,
                                        ),
                                        title: Text('Message privately'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  if (isOwner && memberId != team.ownerId)
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.person_remove_outlined,
                                          color: Color(0xFFDC2626),
                                        ),
                                        title: Text('Remove member'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (isOwner && team.isActive)
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _showInviteMemberDialog(team);
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Invite Member'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                ),
              ),
            if (team.memberIds.contains(currentUid))
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(this.context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TeamChatScreen(teamId: team.id, teamName: team.name),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Team Chat'),
              ),
            if (isOwner)
              TextButton.icon(
                onPressed: () => _confirmDeleteTeam(team),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFDC2626),
                ),
                label: const Text(
                  'Delete Team',
                  style: TextStyle(color: Color(0xFFDC2626)),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          ),
        ],
      ),
    );
  }

  Future<void> _openIndividualChat(
    TeamModel team,
    String memberId,
    String memberName,
  ) async {
    try {
      final chatId = await _individualChatService.openChat(
        otherUid: memberId,
        otherName: memberName,
        teamId: team.id,
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IndividualChatScreen(
            chatId: chatId,
            otherUid: memberId,
            otherName: memberName,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open private chat: $error')),
      );
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
