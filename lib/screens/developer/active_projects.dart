import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/application_model.dart';
import '../../models/project_model.dart';
import '../../models/team_model.dart';
import '../../services/application_service.dart';
import '../../services/project_service.dart';
import '../../services/team_service.dart';
import 'developer_project_details_screen.dart';

class ActiveProjects extends StatefulWidget {
  const ActiveProjects({super.key});

  @override
  State<ActiveProjects> createState() => _ActiveProjectsState();
}

class _ActiveProjectsState extends State<ActiveProjects> {
  final ApplicationService _applicationService = ApplicationService();

  final ProjectService _projectService = ProjectService();

  final TeamService _teamService = TeamService();

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;

    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  bool _matchesSearch(ProjectModel project) {
    if (_searchQuery.isEmpty) {
      return true;
    }

    final searchableText = [
      project.title,
      project.description,
      project.clientName,
      project.projectType,
      project.workMode,
      project.duration,
      ...project.skills,
      ...project.technologies,
    ].join(' ').toLowerCase();

    return searchableText.contains(_searchQuery);
  }

  String _formatBudget(ProjectModel project) {
    if (project.budgetMin > 0 && project.budgetMax > 0) {
      return '₹${_formatAmount(project.budgetMin)} - '
          '₹${_formatAmount(project.budgetMax)}';
    }

    if (project.budget > 0) {
      return '₹${_formatAmount(project.budget)}';
    }

    return 'Budget not specified';
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }

    return amount.toStringAsFixed(0);
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Recently';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} '
        '${date.year}';
  }

  Future<ProjectModel?> _getProject(String projectId) async {
    try {
      return await _projectService.getProject(projectId);
    } catch (_) {
      return null;
    }
  }

  void _openProject(ProjectModel project) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            DeveloperProjectDetailsScreen(projectId: project.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(title: const Text('Active Projects')),
        body: const Center(
          child: Text('Please log in to view your active projects.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Active Projects',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<List<TeamModel>>(
        stream: _teamService.watchMyTeams(),
        builder: (context, teamSnapshot) {
          if (teamSnapshot.hasError) {
            return _buildErrorState(teamSnapshot.error.toString());
          }

          return StreamBuilder<List<ApplicationModel>>(
            stream: _applicationService.watchMyApplications(),
            builder: (context, applicationSnapshot) {
              if (applicationSnapshot.hasError) {
                return _buildErrorState(applicationSnapshot.error.toString());
              }

              if (teamSnapshot.connectionState == ConnectionState.waiting ||
                  applicationSnapshot.connectionState ==
                      ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final applications =
                  applicationSnapshot.data ?? <ApplicationModel>[];
              final acceptedApplications = applications.where((application) {
                return application.status.trim().toLowerCase() == 'accepted';
              }).toList();
              final activeTeams = (teamSnapshot.data ?? <TeamModel>[]).where((
                team,
              ) {
                return team.status.trim().toLowerCase() == 'active' &&
                    team.projectId.trim().isNotEmpty;
              }).toList();
              final projectIds = <String>{
                ...acceptedApplications.map(
                  (application) => application.projectId,
                ),
                ...activeTeams.map((team) => team.projectId),
              };

              return Column(
                children: [
                  _buildSearchBar(),
                  Expanded(
                    child: projectIds.isEmpty
                        ? _buildEmptyState()
                        : _buildProjectsFromIds(
                            projectIds.toList(),
                            acceptedApplications,
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProjectsFromIds(
    List<String> projectIds,
    List<ApplicationModel> acceptedApplications,
  ) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return FutureBuilder<List<ProjectModel>>(
      future: Future.wait(projectIds.map(_getProject))
          .then((projects) => projects.whereType<ProjectModel>().toList()),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final projects = snapshot.data ?? <ProjectModel>[];
        final visibleProjects = projects.where(_matchesSearch).toList();

        if (visibleProjects.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 20,
            8,
            isMobile ? 12 : 20,
            32,
          ),
          itemCount: visibleProjects.length,
          itemBuilder: (context, index) {
            final project = visibleProjects[index];
            final application = acceptedApplications
                .where((item) => item.projectId == project.id)
                .firstOrNull;

            return _buildProjectCard(project, application);
          },
        );
      },
    );
  }

  Widget _buildSearchBar() {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 20,
        isMobile ? 12 : 20,
        isMobile ? 12 : 20,
        12,
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search active projects...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear',
                  onPressed: () {
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.clear_rounded),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(
    ProjectModel project,
    ApplicationModel? application,
  ) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Color(0xFF15803D),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        project.title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Client: ${project.clientName.isEmpty ? 'Client' : project.clientName}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.check_circle_rounded,
                  color: const Color(0xFF16A34A),
                  size: 28,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoChip(
                  icon: Icons.payments_outlined,
                  text: _formatBudget(project),
                ),
                _InfoChip(
                  icon: Icons.schedule_outlined,
                  text: project.duration.isEmpty
                      ? 'Flexible'
                      : project.duration,
                ),
                _InfoChip(
                  icon: Icons.work_outline_rounded,
                  text: project.workMode.isEmpty
                      ? 'Flexible'
                      : project.workMode,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              project.description.isEmpty
                  ? 'No description available.'
                  : project.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                height: 1.5,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 16),
            if (project.skills.isNotEmpty)
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: project.skills
                    .take(6)
                    .map(
                      (skill) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          skill,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 18),
            if (isMobile) ...[
              Text(
                application == null
                    ? 'Team project'
                    : 'Accepted on ${_formatDate(application.updatedAt ?? application.createdAt)}',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openProject(project),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View Project'),
                ),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      application == null
                          ? 'Team project'
                          : 'Accepted on ${_formatDate(application.updatedAt ?? application.createdAt)}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openProject(project),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View Project'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.work_history_outlined,
                size: 42,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'No Active Projects',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Projects will appear here when an application is accepted or '
              'you join an active project team.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 50,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load active projects',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}
