import 'dart:async';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:skill_bridge/models/project_model.dart';
import 'package:skill_bridge/services/project_service.dart';

class ProjectDetails extends StatefulWidget {
  const ProjectDetails({
    super.key,
    required this.projectId,
    this.initialProject,
    this.onApply,
  });

  /// Firestore document ID from projects/{projectId}.
  final String projectId;

  /// Optional project already loaded by Discover Projects.
  ///
  /// The screen still listens to Firestore, so the data remains live.
  final ProjectModel? initialProject;

  /// Application flow callback.
  ///
  /// We will connect this to ApplyProject in the next module.
  final VoidCallback? onApply;

  @override
  State<ProjectDetails> createState() => _ProjectDetailsState();
}

class _ProjectDetailsState extends State<ProjectDetails>
    with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _primaryLight = Color(0xFF6366F1);
  static const Color _background = Color(0xFFF7F8FC);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _success = Color(0xFF059669);

  final ProjectService _projectService = ProjectService();

  final ScrollController _scrollController = ScrollController();

  late final AnimationController _headerController;
  late final AnimationController _contentController;
  late final AnimationController _pulseController;

  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _contentFade;

  StreamSubscription<Set<String>>? _savedProjectsSubscription;

  ProjectModel? _initialProject;

  Set<String> _savedProjectIds = <String>{};

  List<String> _developerSkills = <String>[];
  List<String> _developerTechnologies = <String>[];

  String? _developerProjectType;
  String? _developerWorkMode;
  String? _developerDuration;

  bool _isSaving = false;
  bool _isRefreshing = false;
  bool _isProfileLoading = true;

  String? _profileError;

  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();

    _initialProject = widget.initialProject;

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );

    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: Curves.easeOutCubic,
      ),
    );

    _contentFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    );

    _scrollController.addListener(_handleScroll);

    _headerController.forward();

    Future<void>.delayed(
      const Duration(milliseconds: 180),
      () {
        if (mounted) {
          _contentController.forward();
        }
      },
    );

    _loadDeveloperProfile();
    _listenToSavedProjects();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();

    _headerController.dispose();
    _contentController.dispose();
    _pulseController.dispose();

    _savedProjectsSubscription?.cancel();

    super.dispose();
  }

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  void _handleScroll() {
    if (!mounted) return;

    final offset = _scrollController.offset;

    if ((offset - _scrollOffset).abs() < 1) {
      return;
    }

    setState(() {
      _scrollOffset = offset;
    });
  }

  Future<void> _loadDeveloperProfile() async {
    if (!mounted) return;

    setState(() {
      _isProfileLoading = true;
      _profileError = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null || uid.trim().isEmpty) {
        throw Exception(
          'No authenticated developer account was found.',
        );
      }

      final profileSnapshot = await FirebaseFirestore.instance
          .collection('developerProfiles')
          .doc(uid)
          .get();

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final profileData =
          profileSnapshot.data() ?? <String, dynamic>{};

      final userData =
          userSnapshot.data() ?? <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        _developerSkills = _readStringList(
          profileData['skills'],
        );

        _developerTechnologies = _readStringList(
          profileData['technologies'],
        );

        _developerProjectType =
            _readString(profileData['projectType']) ??
                _readString(userData['projectType']);

        _developerWorkMode =
            _readString(profileData['workMode']) ??
                _readString(userData['workMode']);

        _developerDuration =
            _readString(profileData['projectDuration']) ??
                _readString(profileData['duration']);

        _isProfileLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProfileLoading = false;
        _profileError =
            'Your developer preferences could not be loaded. '
            'The project can still be viewed.';
      });
    }
  }

  void _listenToSavedProjects() {
    _savedProjectsSubscription =
        _projectService.watchSavedProjectIds().listen(
      (ids) {
        if (!mounted) return;

        setState(() {
          _savedProjectIds = ids;
        });
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          _savedProjectIds = <String>{};
        });
      },
    );
  }

  // ===========================================================================
  // PROJECT ACTIONS
  // ===========================================================================

  Future<void> _toggleSave(ProjectModel project) async {
    if (_isSaving) return;

    final isSaved = _savedProjectIds.contains(project.id);

    setState(() {
      _isSaving = true;
    });

    try {
      if (isSaved) {
        await _projectService.unsaveProject(project.id);

        _showSnackBar(
          'Project removed from saved projects.',
          icon: Icons.bookmark_border_rounded,
        );
      } else {
        await _projectService.saveProject(project.id);

        _showSnackBar(
          'Project saved successfully.',
          icon: Icons.bookmark_added_rounded,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Unable to update saved project.',
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _loadDeveloperProfile();

      await Future<void>.delayed(
        const Duration(milliseconds: 300),
      );

      if (mounted) {
        _showSnackBar(
          'Project information refreshed.',
          icon: Icons.refresh_rounded,
        );
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          'Unable to refresh project.',
          icon: Icons.error_outline_rounded,
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _handleApply(ProjectModel project) {
    if (!project.isOpen) {
      _showSnackBar(
        'This project is no longer accepting applications.',
        icon: Icons.lock_outline_rounded,
        isError: true,
      );
      return;
    }

    if (widget.onApply != null) {
      widget.onApply!();
      return;
    }

    _showApplicationComingSoon();
  }

  void _showApplicationComingSoon() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _ActionInfoSheet(
          icon: Icons.send_rounded,
          title: 'Application flow',
          description:
              'The project details page is ready. '
              'The application form will be connected in the next module '
              'through the application service.',
          primaryLabel: 'Got it',
          onPrimary: () {
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }

  Future<void> _shareProject(ProjectModel project) async {
    final shareText =
        '${project.title}\n'
        '${project.description}\n\n'
        'Project ID: ${project.id}';

    try {
      await _copyToClipboard(
        shareText,
        message: 'Project information copied.',
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          'Unable to copy project information.',
          icon: Icons.error_outline_rounded,
          isError: true,
        );
      }
    }
  }

  Future<void> _copyToClipboard(
    String value, {
    String message = 'Copied.',
  }) async {
    await Clipboard.setData(
      ClipboardData(text: value),
    );

    if (!mounted) return;

    _showSnackBar(
      message,
      icon: Icons.content_copy_rounded,
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<ProjectModel?>(
          stream: _projectService.watchProject(
            widget.projectId,
          ),
          initialData: _initialProject,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(
                snapshot.error.toString(),
              );
            }

            final project = snapshot.data;

            if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                project == null) {
              return _buildLoadingState();
            }

            if (project == null) {
              return _buildNotFoundState();
            }

            _initialProject = project;

            return _buildProjectPage(project);
          },
        ),
      ),
      bottomNavigationBar: StreamBuilder<ProjectModel?>(
        stream: _projectService.watchProject(
          widget.projectId,
        ),
        initialData: _initialProject,
        builder: (context, snapshot) {
          final project = snapshot.data;

          if (project == null) {
            return const SizedBox.shrink();
          }

          return _buildBottomActionBar(project);
        },
      ),
    );
  }

  Widget _buildProjectPage(ProjectModel project) {
    final isSaved = _savedProjectIds.contains(project.id);
    final matchPercentage = _matchPercentage(project);

    return RefreshIndicator(
      color: _primary,
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: _scrollOffset > 20 ? 4 : 0,
            scrolledUnderElevation: 4,
            backgroundColor: _surface,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.only(
                left: 10,
              ),
              child: _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
              ),
            ),
            title: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _scrollOffset > 90 ? 1 : 0,
              child: Text(
                project.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            actions: [
              _CircleIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: 'Share project',
                onPressed: () {
                  _shareProject(project);
                },
              ),
              const SizedBox(width: 4),
              _CircleIconButton(
                icon: isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                tooltip: isSaved
                    ? 'Remove saved project'
                    : 'Save project',
                color: isSaved ? _primary : _textPrimary,
                onPressed: _isSaving
                    ? null
                    : () {
                        _toggleSave(project);
                      },
              ),
              const SizedBox(width: 10),
            ],
          ),
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: _buildHeroSection(
                  project,
                  matchPercentage,
                  isSaved,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: _buildMainContent(
                project,
                matchPercentage,
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.only(
              bottom: 130,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HERO
  // ===========================================================================

  Widget _buildHeroSection(
    ProjectModel project,
    int matchPercentage,
    bool isSaved,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        24,
        20,
        28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF0F1FF),
            Color(0xFFF8F9FF),
            Color(0xFFFFFFFF),
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1180,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;

              if (compact) {
                return Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _buildProjectIcon(project),
                    const SizedBox(height: 18),
                    _buildHeroText(
                      project,
                      matchPercentage,
                    ),
                    const SizedBox(height: 20),
                    _buildHeroMeta(project),
                  ],
                );
              }

              return Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _buildProjectIcon(project),
                  const SizedBox(width: 22),
                  Expanded(
                    child: _buildHeroText(
                      project,
                      matchPercentage,
                    ),
                  ),
                  const SizedBox(width: 24),
                  _buildHeroMeta(project),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProjectIcon(ProjectModel project) {
    return Hero(
      tag: 'project-${project.id}',
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = 1 +
              (_pulseController.value * 0.015);

          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _primary,
                _primaryLight,
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(
                  alpha: 0.22,
                ),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.rocket_launch_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroText(
    ProjectModel project,
    int matchPercentage,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatusBadge(
              status: project.status,
            ),
            const SizedBox(width: 8),
            if (matchPercentage > 0)
              _MatchBadge(
                percentage: matchPercentage,
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          project.title.isEmpty
              ? 'Untitled Project'
              : project.title,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 12),
        if (project.clientName.trim().isNotEmpty)
          Row(
            children: [
              const Icon(
                Icons.business_rounded,
                size: 18,
                color: _textSecondary,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Posted by ${project.clientName}',
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildHeroMeta(ProjectModel project) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _HeroInfoCard(
          icon: Icons.payments_outlined,
          label: 'Budget',
          value: _budget(project),
        ),
        _HeroInfoCard(
          icon: Icons.schedule_rounded,
          label: 'Duration',
          value: _displayValue(
            project.duration,
            fallback: 'Flexible',
          ),
        ),
        _HeroInfoCard(
          icon: Icons.public_rounded,
          label: 'Work mode',
          value: _displayValue(
            project.workMode,
            fallback: 'Flexible',
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MAIN CONTENT
  // ===========================================================================

  Widget _buildMainContent(
    ProjectModel project,
    int matchPercentage,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1180,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            24,
            20,
            30,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;

              if (wide) {
                return Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        children: [
                          _buildDescriptionCard(
                            project,
                          ),
                          const SizedBox(height: 18),
                          _buildSkillsCard(project),
                          const SizedBox(height: 18),
                          _buildTechnologiesCard(
                            project,
                          ),
                          const SizedBox(height: 18),
                          _buildProjectDetailsCard(
                            project,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _buildMatchCard(
                            project,
                            matchPercentage,
                          ),
                          const SizedBox(height: 18),
                          _buildClientCard(project),
                          const SizedBox(height: 18),
                          _buildActivityCard(project),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  _buildMatchCard(
                    project,
                    matchPercentage,
                  ),
                  const SizedBox(height: 18),
                  _buildDescriptionCard(project),
                  const SizedBox(height: 18),
                  _buildSkillsCard(project),
                  const SizedBox(height: 18),
                  _buildTechnologiesCard(project),
                  const SizedBox(height: 18),
                  _buildProjectDetailsCard(project),
                  const SizedBox(height: 18),
                  _buildClientCard(project),
                  const SizedBox(height: 18),
                  _buildActivityCard(project),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(ProjectModel project) {
    final description = project.description.trim();

    return _AnimatedSection(
      child: _SurfaceCard(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.description_outlined,
              title: 'About this project',
            ),
            const SizedBox(height: 18),
            Text(
              description.isEmpty
                  ? 'No project description has been provided yet.'
                  : description,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 15,
                height: 1.75,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsCard(ProjectModel project) {
    if (project.skills.isEmpty) {
      return _buildEmptySectionCard(
        icon: Icons.psychology_outlined,
        title: 'Required skills',
        message:
            'No specific skills have been listed.',
      );
    }

    return _AnimatedSection(
      delay: const Duration(milliseconds: 80),
      child: _SurfaceCard(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.psychology_outlined,
              title: 'Required skills',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: project.skills
                  .where(
                    (skill) =>
                        skill.trim().isNotEmpty,
                  )
                  .map(
                    (skill) => _SkillChip(
                      label: skill,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnologiesCard(ProjectModel project) {
    if (project.technologies.isEmpty) {
      return _buildEmptySectionCard(
        icon: Icons.code_rounded,
        title: 'Technologies',
        message:
            'No specific technologies have been listed.',
      );
    }

    return _AnimatedSection(
      delay: const Duration(milliseconds: 120),
      child: _SurfaceCard(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.code_rounded,
              title: 'Technologies',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: project.technologies
                  .where(
                    (technology) =>
                        technology.trim().isNotEmpty,
                  )
                  .map(
                    (technology) =>
                        _TechnologyChip(
                      label: technology,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectDetailsCard(ProjectModel project) {
    return _AnimatedSection(
      delay: const Duration(milliseconds: 160),
      child: _SurfaceCard(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.info_outline_rounded,
              title: 'Project information',
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < 520;

                final items = [
                  _InfoTileData(
                    icon: Icons.payments_outlined,
                    label: 'Budget',
                    value: _budget(project),
                  ),
                  _InfoTileData(
                    icon: Icons.schedule_rounded,
                    label: 'Duration',
                    value: _displayValue(
                      project.duration,
                      fallback: 'Flexible',
                    ),
                  ),
                  _InfoTileData(
                    icon: Icons.category_outlined,
                    label: 'Project type',
                    value: _displayValue(
                      project.projectType,
                      fallback: 'Not specified',
                    ),
                  ),
                  _InfoTileData(
                    icon: Icons.public_rounded,
                    label: 'Work mode',
                    value: _displayValue(
                      project.workMode,
                      fallback: 'Flexible',
                    ),
                  ),
                  _InfoTileData(
                    icon: Icons.people_alt_outlined,
                    label: 'Applications',
                    value: project
                        .applicationsCount
                        .toString(),
                  ),
                  _InfoTileData(
                    icon: Icons.flag_outlined,
                    label: 'Status',
                    value: _capitalize(
                      project.status,
                    ),
                  ),
                ];

                if (compact) {
                  return Column(
                    children: items
                        .map(
                          (item) => Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 10,
                            ),
                            child:
                                _InfoTile(data: item),
                          ),
                        )
                        .toList(),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.9,
                  ),
                  itemBuilder: (context, index) {
                    return _InfoTile(
                      data: items[index],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCard(
    ProjectModel project,
    int percentage,
  ) {
    final hasProfileData =
        _developerSkills.isNotEmpty ||
            _developerTechnologies.isNotEmpty ||
            _developerProjectType != null ||
            _developerWorkMode != null ||
            _developerDuration != null;

    return _AnimatedSection(
      delay: const Duration(milliseconds: 40),
      child: _SurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _primary.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: _primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Your project match',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Center(
              child: _MatchCircle(
                percentage: percentage,
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                _matchMessage(percentage),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ),
            if (!hasProfileData) ...[
              const SizedBox(height: 16),
              _ProfileHint(
                message:
                    'Complete your developer profile to get '
                    'more accurate project recommendations.',
              ),
            ],
            if (_profileError != null) ...[
              const SizedBox(height: 12),
              Text(
                _profileError!,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClientCard(ProjectModel project) {
    final clientName = project.clientName.trim();

    return _AnimatedSection(
      delay: const Duration(milliseconds: 200),
      child: _SurfaceCard(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.business_center_outlined,
              title: 'About the client',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFEEF2FF),
                        Color(0xFFE0E7FF),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.business_rounded,
                    color: _primary,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientName.isEmpty
                            ? 'Client'
                            : clientName,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        project.clientId.isEmpty
                            ? 'Client information'
                            : 'Verified account',
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius:
                    BorderRadius.circular(13),
                border: Border.all(
                  color: _border,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    size: 18,
                    color: _success,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Project posted through SkillBridge',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildActivityCard(ProjectModel project) {
    return _AnimatedSection(
      delay: const Duration(milliseconds: 240),
      child: _SurfaceCard(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.timeline_rounded,
              title: 'Project activity',
            ),
            const SizedBox(height: 18),
            _TimelineItem(
              icon: Icons.add_circle_outline_rounded,
              title: 'Project posted',
              subtitle: _formatDate(
                project.createdAt,
                fallback: 'Date not available',
              ),
              isFirst: true,
            ),
            _TimelineItem(
              icon: Icons.update_rounded,
              title: 'Last updated',
              subtitle: _formatDate(
                project.updatedAt,
                fallback: project.createdAt != null
                    ? _formatDate(
                        project.createdAt,
                        fallback: 'Date not available',
                      )
                    : 'Not available',
              ),
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySectionCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: icon,
            title: title,
          ),
          const SizedBox(height: 15),
          Text(
            message,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BOTTOM ACTION BAR
  // ===========================================================================

  Widget _buildBottomActionBar(
    ProjectModel project,
  ) {
    final isSaved =
        _savedProjectIds.contains(project.id);

    final isOpen = project.isOpen;

    return Material(
      color: Colors.white,
      elevation: 18,
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1180,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                14,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 560;

                  if (compact) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isOpen
                                    ? 'Ready to apply?'
                                    : 'Applications are closed',
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontWeight:
                                      FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            Text(
                              _budget(project),
                              style: const TextStyle(
                                color: _primary,
                                fontWeight:
                                    FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSaving
                                    ? null
                                    : () {
                                        _toggleSave(
                                          project,
                                        );
                                      },
                                icon: Icon(
                                  isSaved
                                      ? Icons
                                          .bookmark_rounded
                                      : Icons
                                          .bookmark_border_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  isSaved
                                      ? 'Saved'
                                      : 'Save',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _ApplyButton(
                                enabled: isOpen,
                                onPressed: () {
                                  _handleApply(
                                    project,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOpen
                                  ? 'Interested in this project?'
                                  : 'Applications are currently closed',
                              style: const TextStyle(
                                color: _textPrimary,
                                fontWeight:
                                    FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _budget(project),
                              style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () {
                                _toggleSave(project);
                              },
                        icon: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons
                                  .bookmark_border_rounded,
                          size: 18,
                        ),
                        label: Text(
                          isSaved ? 'Saved' : 'Save Project',
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 190,
                        child: _ApplyButton(
                          enabled: isOpen,
                          onPressed: () {
                            _handleApply(project);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // LOADING / ERROR / EMPTY
  // ===========================================================================

  Widget _buildLoadingState() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.white,
          leading: Padding(
            padding: const EdgeInsets.only(
              left: 10,
            ),
            child: _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () {
                Navigator.of(context).maybePop();
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1180,
                ),
                child: Column(
                  children: [
                    const _SkeletonBox(
                      height: 210,
                      radius: 24,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            children: const [
                              _SkeletonBox(
                                height: 210,
                                radius: 20,
                              ),
                              SizedBox(height: 18),
                              _SkeletonBox(
                                height: 160,
                                radius: 20,
                              ),
                              SizedBox(height: 18),
                              _SkeletonBox(
                                height: 150,
                                radius: 20,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 18),
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: const [
                              _SkeletonBox(
                                height: 300,
                                radius: 20,
                              ),
                              SizedBox(height: 18),
                              _SkeletonBox(
                                height: 190,
                                radius: 20,
                              ),
                            ],
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
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return _CenteredState(
      icon: Icons.cloud_off_rounded,
      title: 'Unable to load project',
      message:
          'Something went wrong while loading this project. '
          'Please check your connection and try again.',
      primaryLabel: 'Retry',
      onPrimary: () {
        setState(() {});
      },
      secondaryLabel: 'Go Back',
      onSecondary: () {
        Navigator.of(context).maybePop();
      },
    );
  }

  Widget _buildNotFoundState() {
    return _CenteredState(
      icon: Icons.search_off_rounded,
      title: 'Project not found',
      message:
          'This project may have been removed, closed, '
          'or is no longer available.',
      primaryLabel: 'Go Back',
      onPrimary: () {
        Navigator.of(context).maybePop();
      },
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  int _matchPercentage(ProjectModel project) {
    if (_isProfileLoading) {
      return 0;
    }

    return project.getMatchPercentage(
      developerSkills: _developerSkills,
      developerTechnologies: _developerTechnologies,
      developerProjectType: _developerProjectType,
      developerWorkMode: _developerWorkMode,
      developerDuration: _developerDuration,
    );
  }

  List<String> _readStringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map(
            (item) => item.toString().trim(),
          )
          .where(
            (item) => item.isNotEmpty,
          )
          .toList();
    }

    if (value is String &&
        value.trim().isNotEmpty) {
      return value
          .split(',')
          .map(
            (item) => item.trim(),
          )
          .where(
            (item) => item.isNotEmpty,
          )
          .toList();
    }

    return <String>[];
  }

  String? _readString(dynamic value) {
    if (value == null) return null;

    final stringValue =
        value.toString().trim();

    if (stringValue.isEmpty) {
      return null;
    }

    return stringValue;
  }

  String _budget(ProjectModel project) {
    final min = project.effectiveBudgetMin;
    final max = project.effectiveBudgetMax;

    if (min <= 0 && max <= 0) {
      return 'Budget Flexible';
    }

    if (min > 0 && max > 0 && max > min) {
      return '₹${_number(min)} - ₹${_number(max)}';
    }

    final value = max > 0 ? max : min;

    return '₹${_number(value)}';
  }

  String _number(double value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    }

    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    }

    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(0)}K';
    }

    return '₹${value.toStringAsFixed(0)}';
  }

  String _displayValue(
    String value, {
    required String fallback,
  }) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return fallback;
    }

    return trimmed;
  }



  String _formatDate(
    DateTime? date, {
    required String fallback,
  }) {
    if (date == null) {
      return fallback;
    }

    final local = date.toLocal();

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

    return '${months[local.month - 1]} '
        '${local.day}, '
        '${local.year}';
  }

  String _matchMessage(int percentage) {
    if (_isProfileLoading) {
      return 'Calculating your compatibility...';
    }

    if (percentage >= 80) {
      return 'Excellent match. This project strongly aligns '
          'with your developer profile.';
    }

    if (percentage >= 60) {
      return 'Strong match. Your profile has several '
          'relevant areas for this project.';
    }

    if (percentage >= 40) {
      return 'Good potential. Consider reviewing the '
          'requirements before applying.';
    }

    if (percentage > 0) {
      return 'Some overlap was found. Review the required '
          'skills carefully.';
    }

    return 'Complete your profile to receive a more '
        'personalized match score.';
  }

  void _showSnackBar(
    String message, {
    required IconData icon,
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFB91C1C)
              : const Color(0xFF111827),
          margin: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            92,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message),
              ),
            ],
          ),
        ),
      );
  }
}

// =============================================================================
// SURFACE CARD
// =============================================================================

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _ProjectDetailsState._border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// =============================================================================
// ANIMATED SECTION
// =============================================================================

class _AnimatedSection extends StatefulWidget {
  const _AnimatedSection({
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<_AnimatedSection> createState() =>
      _AnimatedSectionState();
}

class _AnimatedSectionState
    extends State<_AnimatedSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 600,
      ),
    );

    Future<void>.delayed(
      widget.delay,
      () {
        if (mounted) {
          _controller.forward();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(animation),
        child: widget.child,
      ),
    );
  }
}

// =============================================================================
// SECTION HEADER
// =============================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _ProjectDetailsState._primary
                .withValues(alpha: 0.09),
            borderRadius:
                BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: _ProjectDetailsState._primary,
            size: 19,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color:
                  _ProjectDetailsState._textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// HERO INFO CARD
// =============================================================================

class _HeroInfoCard extends StatelessWidget {
  const _HeroInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 135,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.85,
        ),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: _ProjectDetailsState._border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color:
                _ProjectDetailsState._primary,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color:
                      _ProjectDetailsState._textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color:
                      _ProjectDetailsState._textPrimary,
                  fontSize: 12.5,
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

// =============================================================================
// STATUS BADGE
// =============================================================================

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized =
        status.trim().toLowerCase();

    final open = normalized == 'open';

    final color = open
        ? const Color(0xFF059669)
        : const Color(0xFF6B7280);

    final background = open
        ? const Color(0xFFECFDF5)
        : const Color(0xFFF3F4F6);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            open ? 'Open for applications' : _capitalize(status),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return 'Unavailable';
    }

    return trimmed[0].toUpperCase() +
        trimmed.substring(1).toLowerCase();
  }
}

// =============================================================================
// MATCH BADGE
// =============================================================================

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({
    required this.percentage,
  });

  final int percentage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius:
            BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: _ProjectDetailsState._primary,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            '$percentage% Match',
            style: const TextStyle(
              color:
                  _ProjectDetailsState._primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MATCH CIRCLE
// =============================================================================

class _MatchCircle extends StatelessWidget {
  const _MatchCircle({
    required this.percentage,
  });

  final int percentage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 10,
              color: const Color(0xFFE5E7EB),
            ),
          ),
          SizedBox(
            width: 150,
            height: 150,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: percentage / 100,
              ),
              duration: const Duration(
                milliseconds: 1200,
              ),
              curve: Curves.easeOutCubic,
              builder:
                  (context, value, child) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  color:
                      _ProjectDetailsState._primary,
                );
              },
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percentage%',
                style: const TextStyle(
                  color:
                      _ProjectDetailsState._textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const Text(
                'match',
                style: TextStyle(
                  color:
                      _ProjectDetailsState._textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SKILL CHIP
// =============================================================================

class _SkillChip extends StatelessWidget {
  const _SkillChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE9E5FF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color:
                _ProjectDetailsState._primary,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color:
                  _ProjectDetailsState._textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TECHNOLOGY CHIP
// =============================================================================

class _TechnologyChip extends StatelessWidget {
  const _TechnologyChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: _ProjectDetailsState._border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.code_rounded,
            color:
                _ProjectDetailsState._textSecondary,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color:
                  _ProjectDetailsState._textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// INFO TILE
// =============================================================================

class _InfoTileData {
  const _InfoTileData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.data,
  });

  final _InfoTileData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: _ProjectDetailsState._border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            data.icon,
            color:
                _ProjectDetailsState._primary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:
                        _ProjectDetailsState._textSecondary,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:
                        _ProjectDetailsState._textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
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

// =============================================================================
// TIMELINE
// =============================================================================

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 1,
                      color:
                          _ProjectDetailsState._border,
                    ),
                  ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _ProjectDetailsState
                        ._primary
                        .withValues(
                      alpha: 0.10,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 14,
                    color:
                        _ProjectDetailsState._primary,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color:
                          _ProjectDetailsState._border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color:
                          _ProjectDetailsState._textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color:
                          _ProjectDetailsState._textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PROFILE HINT
// =============================================================================

class _ProfileHint extends StatelessWidget {
  const _ProfileHint({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE9E5FF),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color:
                _ProjectDetailsState._primary,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color:
                    _ProjectDetailsState._textSecondary,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// APPLY BUTTON
// =============================================================================

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: enabled
            ? onPressed
            : null,
        icon: Icon(
          enabled
              ? Icons.send_rounded
              : Icons.lock_outline_rounded,
          size: 18,
        ),
        label: Text(
          enabled
              ? 'Apply Now'
              : 'Applications Closed',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _ProjectDetailsState._primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              const Color(0xFFE5E7EB),
          disabledForegroundColor:
              const Color(0xFF9CA3AF),
          elevation: enabled ? 5 : 0,
          shadowColor:
              _ProjectDetailsState._primary
                  .withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CIRCLE BUTTON
// =============================================================================

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: color ??
              _ProjectDetailsState._textPrimary,
          size: 21,
        ),
        style: IconButton.styleFrom(
          backgroundColor:
              const Color(0xFFF9FAFB),
          disabledForegroundColor:
              const Color(0xFFD1D5DB),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ACTION INFO SHEET
// =============================================================================

class _ActionInfoSheet extends StatelessWidget {
  const _ActionInfoSheet({
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final IconData icon;
  final String title;
  final String description;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _ProjectDetailsState._primary
                  .withValues(alpha: 0.10),
              borderRadius:
                  BorderRadius.circular(17),
            ),
            child: Icon(
              icon,
              color:
                  _ProjectDetailsState._primary,
              size: 27,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color:
                  _ProjectDetailsState._textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color:
                  _ProjectDetailsState._textSecondary,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _ProjectDetailsState._primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(13),
                ),
              ),
              child: Text(
                primaryLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SKELETON
// =============================================================================

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({
    required this.height,
    required this.radius,
  });

  final double height;
  final double radius;

  @override
  State<_SkeletonBox> createState() =>
      _SkeletonBoxState();
}

class _SkeletonBoxState
    extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1200,
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value =
            0.06 +
            (_controller.value * 0.05);

        return Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.fromRGBO(
              229,
              231,
              235,
              value + 0.10,
            ),
            borderRadius:
                BorderRadius.circular(
              widget.radius,
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// CENTERED STATE
// =============================================================================

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: _ProjectDetailsState._primary
                    .withValues(alpha: 0.09),
                borderRadius:
                    BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                color:
                    _ProjectDetailsState._primary,
                size: 38,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:
                    _ProjectDetailsState._textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 480,
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color:
                      _ProjectDetailsState._textSecondary,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: onPrimary,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                  ),
                  label: Text(primaryLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _ProjectDetailsState._primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(13),
                    ),
                  ),
                ),
                if (secondaryLabel != null &&
                    onSecondary != null)
                  OutlinedButton(
                    onPressed: onSecondary,
                    style:
                        OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(13),
                      ),
                    ),
                    child:
                        Text(secondaryLabel!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PRIVATE HELPERS
// =============================================================================

String _capitalize(String value) {
  final trimmed = value.trim();

  if (trimmed.isEmpty) {
    return '';
  }

  return trimmed[0].toUpperCase() +
      trimmed.substring(1).toLowerCase();
}