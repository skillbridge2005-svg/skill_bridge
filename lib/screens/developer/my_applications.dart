import 'package:flutter/material.dart';

import '../../models/application_model.dart';
import '../../models/project_model.dart';
import '../../services/application_service.dart';
import '../../services/project_service.dart';

class MyApplications extends StatefulWidget {
  const MyApplications({super.key});

  @override
  State<MyApplications> createState() => _MyApplicationsState();
}

class _MyApplicationsState extends State<MyApplications> {
  final ApplicationService _applicationService = ApplicationService();
  final ProjectService _projectService = ProjectService();

  final TextEditingController _searchController =
      TextEditingController();

  String _selectedStatus = 'All';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ApplicationModel> _filterApplications(
    List<ApplicationModel> applications,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    return applications.where((application) {
      final statusMatches = _selectedStatus == 'All' ||
          application.status.toLowerCase() == _selectedStatus.toLowerCase();

      if (!statusMatches) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return application.projectId.toLowerCase().contains(query) ||
          application.clientId.toLowerCase().contains(query) ||
          application.coverLetter.toLowerCase().contains(query);
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return const Color(0xFF16A34A);
      case 'shortlisted':
        return const Color(0xFF2563EB);
      case 'rejected':
        return const Color(0xFFDC2626);
      case 'withdrawn':
        return const Color(0xFF6B7280);
      case 'pending':
      default:
        return const Color(0xFFD97706);
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'Accepted';
      case 'shortlisted':
        return 'Shortlisted';
      case 'rejected':
        return 'Rejected';
      case 'withdrawn':
        return 'Withdrawn';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle_rounded;
      case 'shortlisted':
        return Icons.star_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'withdrawn':
        return Icons.remove_circle_outline_rounded;
      case 'pending':
      default:
        return Icons.schedule_rounded;
    }
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

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<ProjectModel?> _getProject(String projectId) async {
    try {
      return await _projectService.getProject(projectId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _withdrawApplication(
    ApplicationModel application,
  ) async {
    if (!application.canWithdraw) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This application cannot be withdrawn.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Withdraw application?'),
          content: const Text(
            'Are you sure you want to withdraw this application?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Withdraw'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _applicationService.withdrawApplication(
        application.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Application withdrawn successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to withdraw application: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: StreamBuilder<List<ApplicationModel>>(
          stream: _applicationService.watchMyApplications(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(
                snapshot.error.toString(),
              );
            }

            if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                !snapshot.hasData) {
              return _buildLoadingState();
            }

            final applications =
                snapshot.data ?? <ApplicationModel>[];

            final filteredApplications =
                _filterApplications(applications);

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(
                      applications.length,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildFilters(),
                  ),
                  if (filteredApplications.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(
                        hasApplications: applications.isNotEmpty,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        8,
                        24,
                        32,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final application =
                                filteredApplications[index];

                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 16),
                              child: _ApplicationCard(
                                application: application,
                                projectLoader: () {
                                  return _getProject(
                                    application.projectId,
                                  );
                                },
                                statusColor: _statusColor(
                                  application.status,
                                ),
                                statusLabel: _statusLabel(
                                  application.status,
                                ),
                                statusIcon: _statusIcon(
                                  application.status,
                                ),
                                formattedDate: _formatDate(
                                  application.createdAt,
                                ),
                                onWithdraw: application.canWithdraw
                                    ? () {
                                        _withdrawApplication(
                                          application,
                                        );
                                      }
                                    : null,
                              ),
                            );
                          },
                          childCount:
                              filteredApplications.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(int totalApplications) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Applications',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                        letterSpacing: -0.8,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Track every project you have applied to.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.assignment_rounded,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Applications',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$totalApplications total',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFF16A34A),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        0,
        24,
        18,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;

          if (compact) {
            return Column(
              children: [
                _buildSearchField(),
                const SizedBox(height: 10),
                _buildStatusDropdown(),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _buildSearchField(),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 190,
                child: _buildStatusDropdown(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search applications...',
        prefixIcon: const Icon(
          Icons.search_rounded,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(
                  Icons.clear_rounded,
                ),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF4F46E5),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedStatus,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(
          Icons.filter_list_rounded,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: 'All',
          child: Text('All Status'),
        ),
        DropdownMenuItem(
          value: 'pending',
          child: Text('Pending'),
        ),
        DropdownMenuItem(
          value: 'shortlisted',
          child: Text('Shortlisted'),
        ),
        DropdownMenuItem(
          value: 'accepted',
          child: Text('Accepted'),
        ),
        DropdownMenuItem(
          value: 'rejected',
          child: Text('Rejected'),
        ),
        DropdownMenuItem(
          value: 'withdrawn',
          child: Text('Withdrawn'),
        ),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          _selectedStatus = value;
        });
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF4F46E5),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 14),
            const Text(
              'Unable to load applications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool hasApplications,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 40,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasApplications
                  ? 'No matching applications'
                  : 'No applications yet',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasApplications
                  ? 'Try changing your search or status filter.'
                  : 'Applications you submit will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.projectLoader,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
    required this.formattedDate,
    required this.onWithdraw,
  });

  final ApplicationModel application;
  final Future<ProjectModel?> Function() projectLoader;
  final Color statusColor;
  final String statusLabel;
  final IconData statusIcon;
  final String formattedDate;
  final VoidCallback? onWithdraw;

  String _budget(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProjectModel?>(
      future: projectLoader(),
      builder: (context, snapshot) {
        final project = snapshot.data;

        final title = project?.title ??
            'Project ${application.projectId}';

        final skills = project?.skills ?? <String>[];

        final budget = project != null
            ? project.hasBudgetRange
                ? '₹${project.effectiveBudgetMin.toStringAsFixed(0)} - ₹${project.effectiveBudgetMax.toStringAsFixed(0)}'
                : _budget(project.effectiveBudgetMin)
            : 'Budget unavailable';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
            boxShadow: const [
              BoxShadow(
                blurRadius: 20,
                offset: Offset(0, 6),
                color: Color(0x0A000000),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.work_outline_rounded,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$budget • Applied $formattedDate',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (project != null) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (project.projectType.isNotEmpty)
                      _InfoChip(
                        icon: Icons.category_outlined,
                        text: project.projectType,
                      ),
                    if (project.duration.isNotEmpty)
                      _InfoChip(
                        icon: Icons.schedule_rounded,
                        text: project.duration,
                      ),
                    if (project.workMode.isNotEmpty)
                      _InfoChip(
                        icon: Icons.public_rounded,
                        text: project.workMode,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (skills.isNotEmpty)
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: skills.take(5).map((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius:
                              BorderRadius.circular(9),
                        ),
                        child: Text(
                          skill,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
              const SizedBox(height: 18),
              const Divider(
                height: 1,
                color: Color(0xFFE5E7EB),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Proposed: ₹${application.proposedBudget.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Icon(
                    Icons.timelapse_rounded,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      application.estimatedDuration,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  if (onWithdraw != null)
                    TextButton(
                      onPressed: onWithdraw,
                      child: const Text(
                        'Withdraw',
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: const Color(0xFF6B7280),
          ),
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