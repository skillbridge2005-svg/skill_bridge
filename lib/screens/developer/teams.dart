import 'package:flutter/material.dart';
import '../../models/project_model.dart';
import '../../services/application_service.dart';
import '../../services/project_service.dart';
import '../../services/team_service.dart';
import '../../models/team_model.dart';

class Teams extends StatefulWidget {
  const Teams({super.key});

  @override
  State<Teams> createState() => _TeamsState();
}

class _TeamsState extends State<Teams> {
  final TeamService _teamService = TeamService();
  final ApplicationService _applicationService =
      ApplicationService();
  final ProjectService _projectService = ProjectService();

  final TextEditingController _searchController =
      TextEditingController();

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

    return _teamService.searchTeams(
      teams,
      _searchQuery,
    );
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
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _showCreateTeamDialog,
              icon: const Icon(
                Icons.add_rounded,
                size: 19,
              ),
              label: const Text('Create Team'),
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<TeamModel>>(
        stream: _teamService.watchMyTeams(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(
              snapshot.error.toString(),
            );
          }

          final teams =
              snapshot.data ?? <TeamModel>[];

          final filteredTeams =
              _filterTeams(teams);

          return Column(
            children: [
              _buildHeader(teams.length),
              Expanded(
                child: filteredTeams.isEmpty
                    ? _buildEmptyState(
                        hasTeams: teams.isNotEmpty,
                      )
                    : _buildTeamList(
                        filteredTeams,
                      ),
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
      padding: const EdgeInsets.fromLTRB(
        24,
        20,
        24,
        20,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
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
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText:
                  'Search teams or projects...',
              prefixIcon: const Icon(
                Icons.search_rounded,
              ),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                          onPressed: () {
                            _searchController
                                .clear();
                          },
                        )
                      : null,
              filled: true,
              fillColor:
                  const Color(0xFFF7F8FC),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamList(
    List<TeamModel> teams,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: teams.length,
      itemBuilder: (context, index) {
        final team = teams[index];

        return Padding(
          padding: const EdgeInsets.only(
            bottom: 16,
          ),
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
        borderRadius:
            BorderRadius.circular(16),
        side: const BorderSide(
          color: Color(0xFFE5E7EB),
        ),
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: () {
          _showTeamDetails(team);
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFEFF6FF),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color:
                          Color(0xFF2563EB),
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
                              ? 'Unnamed Team'
                              : team.name,
                          style:
                              const TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.w700,
                            color:
                                Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          team.projectTitle
                                  .isEmpty
                              ? 'Project not specified'
                              : team.projectTitle,
                          style:
                              const TextStyle(
                            fontSize: 13,
                            color:
                                Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(
                    team.status,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (team.description.isNotEmpty) ...[
                Text(
                  team.description,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color:
                        Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  const Icon(
                    Icons.people_outline_rounded,
                    size: 18,
                    color:
                        Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${team.memberCount} '
                    '${team.memberCount == 1 ? 'member' : 'members'}',
                    style:
                        const TextStyle(
                      fontSize: 13,
                      color:
                          Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'View Team',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w600,
                      color:
                          Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color:
                        Color(0xFF2563EB),
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
    final normalized =
        status.trim().toLowerCase();

    final label = normalized.isEmpty
        ? 'Active'
        : '${normalized[0].toUpperCase()}'
            '${normalized.substring(1)}';

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: normalized == 'completed'
            ? const Color(0xFFECFDF5)
            : normalized == 'archived'
                ? const Color(0xFFF3F4F6)
                : const Color(0xFFEFF6FF),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight:
              FontWeight.w600,
          color: normalized == 'completed'
              ? const Color(0xFF047857)
              : normalized == 'archived'
                  ? const Color(0xFF6B7280)
                  : const Color(0xFF2563EB),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool hasTeams,
  }) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color:
                    const Color(0xFFEFF6FF),
                borderRadius:
                    BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.groups_outlined,
                size: 44,
                color:
                    Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasTeams
                  ? 'No teams found'
                  : 'No teams yet',
              style: const TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasTeams
                  ? 'Try a different search.'
                  : 'Create a team for one of '
                      'your active projects to get started.',
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color:
                    Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed:
                  _showCreateTeamDialog,
              icon: const Icon(
                Icons.add_rounded,
              ),
              label:
                  const Text('Create Team'),
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFF2563EB),
                foregroundColor:
                    Colors.white,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    String error,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color:
                  Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load teams',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                color:
                    Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateTeamDialog() async {
    final nameController =
        TextEditingController();

    final descriptionController =
        TextEditingController();

    String? selectedProjectId;

    List<ProjectModel> activeProjects =
        <ProjectModel>[];

    bool loadingProjects = true;
    String? projectError;

    try {
      final applications =
          await _applicationService
              .getMyApplications();

      final acceptedApplications =
          applications
              .where(
                (application) =>
                    application.status
                        .trim()
                        .toLowerCase() ==
                    'accepted',
              )
              .toList();

      for (final application
          in acceptedApplications) {
        final project =
            await _projectService.getProject(
          application.projectId,
        );

        if (project != null) {
          activeProjects.add(project);
        }
      }

      if (activeProjects.isNotEmpty) {
        selectedProjectId =
            activeProjects.first.id;
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
          builder:
              (context, setDialogState) {
            Future<void> createTeam() async {
              final name =
                  nameController.text.trim();

              final description =
                  descriptionController.text
                      .trim();

              if (name.isEmpty) {
                _showSnackBar(
                  'Please enter a team name.',
                );
                return;
              }

              if (selectedProjectId ==
                      null ||
                  selectedProjectId!
                      .isEmpty) {
                _showSnackBar(
                  'Please select a project.',
                );
                return;
              }

              final selectedProject =
                  activeProjects.firstWhere(
                (project) =>
                    project.id ==
                    selectedProjectId,
              );

              setDialogState(() {
                isCreating = true;
              });

              try {
                await _teamService.createTeam(
                  name: name,
                  projectId:
                      selectedProject.id,
                  projectTitle:
                      selectedProject.title,
                  memberIds: const [],
                  description:
                      description,
                );

                if (!mounted) return;
if (!dialogContext.mounted) return;

Navigator.of(dialogContext).pop();

                _showSnackBar(
                  'Team created successfully.',
                );
              } catch (e) {
                setDialogState(() {
                  isCreating = false;
                });

                _showSnackBar(
                  e.toString(),
                );
              }
            }

            return AlertDialog(
              title: const Text(
                'Create Team',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Text(
                        'Create a team for one of your active projects.',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      TextField(
                        controller:
                            nameController,
                        enabled:
                            !isCreating,
                        textInputAction:
                            TextInputAction.next,
                        decoration:
                            InputDecoration(
                          labelText:
                              'Team Name',
                          hintText:
                              'e.g. Flutter Development Team',
                          prefixIcon:
                              const Icon(
                            Icons.groups_outlined,
                          ),
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      if (loadingProjects)
                        const Padding(
                          padding:
                              EdgeInsets
                                  .symmetric(
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              ),
                              SizedBox(
                                width: 12,
                              ),
                              Text(
                                'Loading active projects...',
                              ),
                            ],
                          ),
                        )
                      else if (projectError !=
                          null)
                        Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets
                                  .all(
                            12,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFFFF7ED,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                          ),
                          child: Text(
                            'Unable to load active projects.\n'
                            '$projectError',
                            style:
                                const TextStyle(
                              fontSize: 13,
                              color:
                                  Color(
                                0xFF9A3412,
                              ),
                            ),
                          ),
                        )
                      else if (activeProjects
                          .isEmpty)
                        Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets
                                  .all(
                            14,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFF3F4F6,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                          ),
                          child:
                              const Text(
                            'You currently have no accepted projects. '
                            'You need an accepted project before creating a team.',
                            style:
                                TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color:
                                  Color(
                                0xFF4B5563,
                              ),
                            ),
                          ),
                        )
                      else
                        DropdownButtonFormField<
                            String>(
                          initialValue:
                              selectedProjectId,
                          decoration:
                              InputDecoration(
                            labelText:
                                'Project',
                            prefixIcon:
                                const Icon(
                              Icons
                                  .work_outline_rounded,
                            ),
                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                            ),
                          ),
                          items:
                              activeProjects
                                  .map(
                            (project) {
                              return DropdownMenuItem<
                                  String>(
                                value:
                                    project.id,
                                child:
                                    SizedBox(
                                  width:
                                      330,
                                  child:
                                      Text(
                                    project.title,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                  ),
                                ),
                              );
                            },
                          ).toList(),
                          onChanged:
                              isCreating
                                  ? null
                                  : (value) {
                                      setDialogState(
                                        () {
                                          selectedProjectId =
                                              value;
                                        },
                                      );
                                    },
                        ),
                      const SizedBox(
                        height: 16,
                      ),
                      TextField(
                        controller:
                            descriptionController,
                        enabled:
                            !isCreating,
                        maxLines: 4,
                        decoration:
                            InputDecoration(
                          labelText:
                              'Description',
                          hintText:
                              'Describe what this team will work on...',
                          alignLabelWithHint:
                              true,
                          prefixIcon:
                              const Padding(
                            padding:
                                EdgeInsets.only(
                              bottom: 54,
                            ),
                            child: Icon(
                              Icons
                                  .description_outlined,
                            ),
                          ),
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
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
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                  child:
                      const Text('Cancel'),
                ),
                FilledButton(
                  onPressed:
                      isCreating ||
                              loadingProjects ||
                              activeProjects
                                  .isEmpty
                          ? null
                          : createTeam,
                  style:
                      FilledButton.styleFrom(
                    backgroundColor:
                        const Color(
                      0xFF2563EB,
                    ),
                  ),
                  child: isCreating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Text(
                          'Create Team',
                        ),
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

  void _showTeamDetails(
    TeamModel team,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            team.name.isEmpty
                ? 'Team Details'
                : team.name,
          ),
          content:
              SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                _detailRow(
                  'Project',
                  team.projectTitle
                          .isEmpty
                      ? 'Not specified'
                      : team.projectTitle,
                ),
                _detailRow(
                  'Members',
                  '${team.memberCount}',
                ),
                _detailRow(
                  'Status',
                  team.status.isEmpty
                      ? 'Active'
                      : team.status,
                ),
                if (team.description
                    .isNotEmpty)
                  _detailRow(
                    'Description',
                    team.description,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop();
              },
              child:
                  const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                const TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
              color:
                  Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style:
                const TextStyle(
              fontSize: 14,
              color:
                  Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
      ),
    );
  }
}