import 'dart:async';
import 'project_details.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:skill_bridge/models/project_model.dart';
import 'package:skill_bridge/services/project_service.dart';

class DiscoverProjects extends StatefulWidget {
  const DiscoverProjects({
    super.key,
  });

  @override
  State<DiscoverProjects> createState() => _DiscoverProjectsState();
}

class _DiscoverProjectsState extends State<DiscoverProjects>
    with TickerProviderStateMixin {
  final ProjectService _projectService = ProjectService();
late final Stream<List<ProjectModel>> _openProjectsStream;
StreamSubscription<List<ProjectModel>>? _projectsSubscription;

String? _lastProjectSnapshotSignature;

  final TextEditingController _searchController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  late final AnimationController _headerController;
  late final AnimationController _contentController;

  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  late final Animation<double> _contentFade;

  StreamSubscription<Set<String>>? _savedProjectsSubscription;

  List<ProjectModel> _allProjects = [];
  List<ProjectModel> _filteredProjects = [];
  List<ProjectRecommendation> _recommendations = [];

  Set<String> _savedProjectIds = {};

  List<String> _developerSkills = [];
  List<String> _developerTechnologies = [];

  String? _developerProjectType;
  String? _developerWorkMode;
  String? _developerDuration;

  String _selectedWorkMode = 'All';
  String _selectedProjectType = 'All';
  String _selectedDuration = 'All';
  String _selectedTechnology = 'All';
  String _selectedSkill = 'All';
  String _sortBy = 'newest';

  double? _minimumBudget;
  double? _maximumBudget;

  bool _isRefreshing = false;

  String? _errorMessage;

  bool _showFilters = false;
  bool _showRecommendations = true;

  int _visibleProjectCount = 8;

  @override
  void initState() {
    super.initState();
_openProjectsStream =
    _projectService.watchOpenProjects();

_projectsSubscription = _openProjectsStream.listen(
  (projects) {
    _onProjectsChanged(projects);
  },
  onError: (error) {
    if (!mounted) return;

    setState(() {
      _errorMessage =
          'Unable to load projects. Please try again.';
    });
  },
);

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

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
    _searchController.dispose();
    _scrollController.dispose();
    _headerController.dispose();
    _contentController.dispose();
_savedProjectsSubscription?.cancel();
_projectsSubscription?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // PROFILE
  // ===========================================================================
String _projectSnapshotSignature(
  List<ProjectModel> projects,
) {
  return projects
      .map(
        (project) => [
          project.id,
          project.title,
          project.description,
          project.clientId,
          project.clientName,
          project.status,
          project.budget.toString(),
          project.budgetMin.toString(),
          project.budgetMax.toString(),
          project.duration,
          project.projectType,
          project.workMode,
          project.skills.join(','),
          project.technologies.join(','),
          project.applicationsCount.toString(),
          project.updatedAt?.millisecondsSinceEpoch.toString() ?? '',
          project.createdAt?.millisecondsSinceEpoch.toString() ?? '',
        ].join('|'),
      )
      .join('||');
}
  Future<void> _loadDeveloperProfile() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
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

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to load your developer preferences. '
              'Projects can still be explored.';
        });
      }
    }
  }

  // ===========================================================================
  // SAVED PROJECTS
  // ===========================================================================

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
          _savedProjectIds = {};
        });
      },
    );
  }

  // ===========================================================================
  // PROJECT DATA
  // ===========================================================================

  void _onProjectsChanged(
  List<ProjectModel> projects,
) {
  if (!mounted) return;

  final signature = _projectSnapshotSignature(projects);

  if (signature == _lastProjectSnapshotSignature) {
    return;
  }

  _lastProjectSnapshotSignature = signature;

  setState(() {
    _allProjects = List<ProjectModel>.from(projects);
    _applyFilters();
    _calculateRecommendations();
    _errorMessage = null;
  });
}

  void _applyFilters() {
    final filtered = _projectService.filterProjects(
      _allProjects,
      query: _searchController.text,
      technology: _selectedTechnology == 'All'
          ? null
          : _selectedTechnology,
      skill: _selectedSkill == 'All'
          ? null
          : _selectedSkill,
      workMode: _selectedWorkMode == 'All'
          ? null
          : _selectedWorkMode,
      projectType: _selectedProjectType == 'All'
          ? null
          : _selectedProjectType,
      duration: _selectedDuration == 'All'
          ? null
          : _selectedDuration,
      minimumBudget: _minimumBudget,
      maximumBudget: _maximumBudget,
    );

    final sorted = _projectService.sortProjects(
      filtered,
      sortBy: _sortBy,
    );

    _filteredProjects = sorted;

    if (_visibleProjectCount > sorted.length) {
      _visibleProjectCount = sorted.length;
    }

    if (_visibleProjectCount == 0 && sorted.isNotEmpty) {
      _visibleProjectCount =
          sorted.length < 8 ? sorted.length : 8;
    }
  }

  void _calculateRecommendations() {
    _recommendations =
        _projectService.getRecommendedProjects(
      _allProjects,
      developerSkills: _developerSkills,
      developerTechnologies: _developerTechnologies,
      developerProjectType: _developerProjectType,
      developerWorkMode: _developerWorkMode,
      developerDuration: _developerDuration,
      minimumScore: 20,
      limit: 6,
    );
  }

  Future<void> _refreshProjects() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _loadDeveloperProfile();

      final projects =
          await _projectService.getOpenProjects();

      _onProjectsChanged(projects);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to refresh projects. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  void _onSearchChanged(String value) {
    setState(() {
      _visibleProjectCount = 8;
      _applyFilters();
      _calculateRecommendations();
    });
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _visibleProjectCount = 8;
      _applyFilters();
      _calculateRecommendations();
    });
  }

  // ===========================================================================
  // FILTERS
  // ===========================================================================

  void _resetFilters() {
    setState(() {
      _selectedWorkMode = 'All';
      _selectedProjectType = 'All';
      _selectedDuration = 'All';
      _selectedTechnology = 'All';
      _selectedSkill = 'All';

      _minimumBudget = null;
      _maximumBudget = null;

      _sortBy = 'newest';

      _visibleProjectCount = 8;

      _applyFilters();
      _calculateRecommendations();
    });
  }

  void _setWorkMode(String value) {
    setState(() {
      _selectedWorkMode = value;
      _visibleProjectCount = 8;
      _applyFilters();
    });
  }

  void _setProjectType(String value) {
    setState(() {
      _selectedProjectType = value;
      _visibleProjectCount = 8;
      _applyFilters();
    });
  }

  void _setDuration(String value) {
    setState(() {
      _selectedDuration = value;
      _visibleProjectCount = 8;
      _applyFilters();
    });
  }

  void _setTechnology(String value) {
    setState(() {
      _selectedTechnology = value;
      _visibleProjectCount = 8;
      _applyFilters();
    });
  }

  void _setSkill(String value) {
    setState(() {
      _selectedSkill = value;
      _visibleProjectCount = 8;
      _applyFilters();
    });
  }

  void _setSort(String value) {
    setState(() {
      _sortBy = value;
      _applyFilters();
    });
  }

  void _setBudgetRange(
    double? minimum,
    double? maximum,
  ) {
    setState(() {
      _minimumBudget = minimum;
      _maximumBudget = maximum;
      _visibleProjectCount = 8;
      _applyFilters();
    });
  }

  // ===========================================================================
  // SAVING
  // ===========================================================================

  Future<void> _toggleSave(
    ProjectModel project,
  ) async {
    final isSaved = _savedProjectIds.contains(project.id);

    try {
      if (isSaved) {
        await _projectService.unsaveProject(
          project.id,
        );
      } else {
        await _projectService.saveProject(
          project.id,
        );
      }

      if (!mounted) return;

      _showSnackBar(
        isSaved
            ? 'Project removed from saved projects.'
            : 'Project saved successfully.',
        icon: isSaved
            ? Icons.bookmark_border_rounded
            : Icons.bookmark_rounded,
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Unable to update saved project.',
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    }
  }

  // ===========================================================================
  // UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child:StreamBuilder<List<ProjectModel>>(
  stream: _openProjectsStream,
  builder: (context, snapshot) {
    // ---------------------------------------------------------------
    // ERROR
    // ---------------------------------------------------------------
    if (snapshot.hasError) {
      return _buildErrorState(
        theme,
        snapshot.error.toString(),
      );
    }

    // ---------------------------------------------------------------
    // LOADING
    // ---------------------------------------------------------------
    if (snapshot.connectionState == ConnectionState.waiting &&
        _allProjects.isEmpty) {
      return _buildLoadingState(theme);
    }

    // ---------------------------------------------------------------
    // FIRESTORE DATA RECEIVED
    // ---------------------------------------------------------------
    if (snapshot.hasData) {
      final projects = snapshot.data!;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _onProjectsChanged(projects);
      });
    }

    // ---------------------------------------------------------------
    // MAIN CONTENT
    // ---------------------------------------------------------------
    return _buildMainContent(
      context,
      theme,
    );
  },
),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    ThemeData theme,
  ) {
    return RefreshIndicator(
      onRefresh: _refreshProjects,
      color: _primaryColor,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: _buildHeader(
                  context,
                  theme,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: _buildSearchSection(
                context,
                theme,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: _buildFilterBar(
                context,
                theme,
              ),
            ),
          ),

          if (_showRecommendations &&
              _recommendations.isNotEmpty)
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _contentFade,
                child: _buildRecommendationsSection(
                  context,
                  theme,
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: _buildProjectsHeader(
                context,
                theme,
              ),
            ),
          ),

          if (_filteredProjects.isEmpty)
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _contentFade,
                child: _buildEmptyState(
                  context,
                  theme,
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                _horizontalPadding(context),
                0,
                _horizontalPadding(context),
                32,
              ),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final project =
                        _filteredProjects[index];

                    return _AnimatedProjectCard(
                      key: ValueKey(project.id),
                      project: project,
                      index: index,
                      isSaved:
                          _savedProjectIds.contains(
                        project.id,
                      ),
                      matchPercentage:
                          _getMatchPercentage(project),
                      onSave: () =>
                          _toggleSave(project),
                      onOpen: () =>
                          _openProject(project),
                    );
                  },
                  childCount: _visibleProjectCount,
                ),
                gridDelegate:
                    _gridDelegate(context),
              ),
            ),

          if (_visibleProjectCount <
                  _filteredProjects.length &&
              _filteredProjects.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildLoadMoreButton(
                context,
                theme,
              ),
            ),

          if (_errorMessage != null)
            SliverToBoxAdapter(
              child: _buildInfoBanner(
                theme,
                _errorMessage!,
              ),
            ),

          const SliverPadding(
            padding: EdgeInsets.only(
              bottom: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalPadding(context),
        28,
        _horizontalPadding(context),
        20,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 650;

          return Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding:
                              const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient:
                                const LinearGradient(
                              colors: [
                                Color(0xFF4F46E5),
                                Color(0xFF6366F1),
                              ],
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF4F46E5,
                                ).withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 18,
                                offset:
                                    const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.explore_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Discover Projects',
                          style: TextStyle(
                            fontSize:
                                compact ? 25 : 30,
                            fontWeight:
                                FontWeight.w800,
                            color: const Color(
                              0xFF111827,
                            ),
                            letterSpacing: -0.7,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Find projects that match your skills, '
                      'experience and career goals.',
                      style: TextStyle(
                        fontSize: compact ? 13 : 15,
                        color: const Color(
                          0xFF6B7280,
                        ),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              if (!compact)
                _buildRefreshButton(theme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRefreshButton(
    ThemeData theme,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _isRefreshing
            ? null
            : _refreshProjects,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 12,
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration:
                    const Duration(milliseconds: 250),
                child: _isRefreshing
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        key: ValueKey('refresh'),
                        Icons.refresh_rounded,
                        size: 19,
                      ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Refresh',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection(
    BuildContext context,
    ThemeData theme,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _horizontalPadding(context),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.035,
              ),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText:
                'Search projects, skills, technologies...',
            hintStyle: const TextStyle(
              color: Color(0xFF9CA3AF),
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 10,
              ),
              child: Icon(
                Icons.search_rounded,
                color: Color(0xFF6366F1),
              ),
            ),
            suffixIcon: AnimatedSwitcher(
              duration:
                  const Duration(milliseconds: 180),
              child: _searchController.text.isNotEmpty
                  ? IconButton(
                      key: const ValueKey(
                        'clear-search',
                      ),
                      onPressed: _clearSearch,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey(
                        'empty-search',
                      ),
                    ),
            ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    ThemeData theme,
  ) {
    final technologies =
        _availableTechnologies();
    final skills = _availableSkills();

    final hasActiveFilters =
        _selectedWorkMode != 'All' ||
            _selectedProjectType != 'All' ||
            _selectedDuration != 'All' ||
            _selectedTechnology != 'All' ||
            _selectedSkill != 'All' ||
            _minimumBudget != null ||
            _maximumBudget != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalPadding(context),
        16,
        _horizontalPadding(context),
        8,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics:
                      const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _FilterButton(
                        icon: Icons.tune_rounded,
                        label: 'Filters',
                        active: hasActiveFilters,
                        onTap: () {
                          setState(() {
                            _showFilters =
                                !_showFilters;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        icon:
                            Icons.work_outline_rounded,
                        label: _selectedWorkMode,
                        active:
                            _selectedWorkMode != 'All',
                        onTap: () =>
                            _showSingleFilterMenu(
                          context,
                          title: 'Work Mode',
                          options: const [
                            'All',
                            'Remote',
                            'Hybrid',
                            'On-site',
                          ],
                          selected:
                              _selectedWorkMode,
                          onSelected:
                              _setWorkMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        icon:
                            Icons.category_outlined,
                        label: _selectedProjectType,
                        active:
                            _selectedProjectType !=
                                'All',
                        onTap: () =>
                            _showSingleFilterMenu(
                          context,
                          title: 'Project Type',
                          options: const [
                            'All',
                            'Full Time',
                            'Part Time',
                            'Freelance',
                            'Contract',
                            'Both',
                          ],
                          selected:
                              _selectedProjectType,
                          onSelected:
                              _setProjectType,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        icon:
                            Icons.schedule_rounded,
                        label: _selectedDuration,
                        active:
                            _selectedDuration != 'All',
                        onTap: () =>
                            _showSingleFilterMenu(
                          context,
                          title: 'Duration',
                          options: const [
                            'All',
                            'Less than 1 week',
                            '1-4 weeks',
                            '1-3 months',
                            '3-6 months',
                            'Flexible',
                          ],
                          selected:
                              _selectedDuration,
                          onSelected:
                              _setDuration,
                        ),
                      ),
                      if (technologies.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _FilterButton(
                          icon:
                              Icons.code_rounded,
                          label:
                              _selectedTechnology,
                          active:
                              _selectedTechnology !=
                                  'All',
                          onTap: () =>
                              _showSingleFilterMenu(
                            context,
                            title:
                                'Technology',
                            options: [
                              'All',
                              ...technologies,
                            ],
                            selected:
                                _selectedTechnology,
                            onSelected:
                                _setTechnology,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildSortButton(
                context,
                theme,
              ),
            ],
          ),
          AnimatedCrossFade(
            duration:
                const Duration(milliseconds: 300),
            crossFadeState: _showFilters
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild:
                const SizedBox.shrink(),
            secondChild: _buildAdvancedFilters(
              context,
              theme,
              skills,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFilters(
    BuildContext context,
    ThemeData theme,
    List<String> skills,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        top: 12,
        bottom: 8,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 650;

          return Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.filter_alt_outlined,
                    color: Color(0xFF4F46E5),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Advanced Filters',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text(
                      'Reset',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (skills.isNotEmpty)
                _buildFilterDropdown(
                  label: 'Required Skill',
                  value: _selectedSkill,
                  options: [
                    'All',
                    ...skills,
                  ],
                  onChanged: _setSkill,
                  compact: compact,
                ),
              const SizedBox(height: 14),
              _buildBudgetSelector(
                context,
                compact,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBudgetSelector(
    BuildContext context,
    bool compact,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Budget Range',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _BudgetChip(
              label: 'Any',
              active:
                  _minimumBudget == null &&
                      _maximumBudget == null,
              onTap: () =>
                  _setBudgetRange(null, null),
            ),
            _BudgetChip(
              label: 'Under ₹10K',
              active:
                  _minimumBudget == null &&
                      _maximumBudget == 10000,
              onTap: () =>
                  _setBudgetRange(null, 10000),
            ),
            _BudgetChip(
              label: '₹10K - ₹25K',
              active:
                  _minimumBudget == 10000 &&
                      _maximumBudget == 25000,
              onTap: () =>
                  _setBudgetRange(10000, 25000),
            ),
            _BudgetChip(
              label: '₹25K - ₹50K',
              active:
                  _minimumBudget == 25000 &&
                      _maximumBudget == 50000,
              onTap: () =>
                  _setBudgetRange(25000, 50000),
            ),
            _BudgetChip(
              label: '₹50K+',
              active:
                  _minimumBudget == 50000 &&
                      _maximumBudget == null,
              onTap: () =>
                  _setBudgetRange(50000, null),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    required bool compact,
  }) {
    return SizedBox(
      width: compact
          ? double.infinity
          : 320,
      child: DropdownButtonFormField<String>(
        initialValue:
            options.contains(value)
                ? value
                : 'All',
        decoration:
            InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFE5E7EB),
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        items: options
            .map(
              (option) =>
                  DropdownMenuItem(
                value: option,
                child: Text(
                  option,
                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }

  Widget _buildSortButton(
    BuildContext context,
    ThemeData theme,
  ) {
    return PopupMenuButton<String>(
      tooltip: 'Sort projects',
      onSelected: _setSort,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'newest',
          child: Text('Newest first'),
        ),
        PopupMenuItem(
          value: 'oldest',
          child: Text('Oldest first'),
        ),
        PopupMenuItem(
          value: 'budget_high',
          child: Text('Highest budget'),
        ),
        PopupMenuItem(
          value: 'budget_low',
          child: Text('Lowest budget'),
        ),
        PopupMenuItem(
          value: 'applications_low',
          child: Text('Fewest applications'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(13),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
        ),
        child: const Icon(
          Icons.sort_rounded,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection(
    BuildContext context,
    ThemeData theme,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalPadding(context),
        24,
        _horizontalPadding(context),
        12,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFFEEF2FF,
                  ),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF4F46E5),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended for You',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Based on your developer profile',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showRecommendations =
                        !_showRecommendations;
                  });
                },
                child: Text(
                  _showRecommendations
                      ? 'Hide'
                      : 'Show',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics:
                  const BouncingScrollPhysics(),
              itemCount:
                  _recommendations.length,
              separatorBuilder:
                  (_, index) =>
                      const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final recommendation =
                    _recommendations[index];

                return _RecommendationCard(
                  recommendation:
                      recommendation,
                  isSaved: _savedProjectIds
                      .contains(
                    recommendation.project.id,
                  ),
                  onSave: () => _toggleSave(
                    recommendation.project,
                  ),
                  onOpen: () =>
                      _openProject(
                    recommendation.project,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsHeader(
    BuildContext context,
    ThemeData theme,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalPadding(context),
        22,
        _horizontalPadding(context),
        14,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'All Projects',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Explore currently available opportunities',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration:
                const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey(
                _filteredProjects.length,
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Text(
                '${_filteredProjects.length} found',
                style: const TextStyle(
                  color: Color(0xFF4F46E5),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton(
    BuildContext context,
    ThemeData theme,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalPadding(context),
        4,
        _horizontalPadding(context),
        28,
      ),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _visibleProjectCount += 8;

              if (_visibleProjectCount >
                  _filteredProjects.length) {
                _visibleProjectCount =
                    _filteredProjects.length;
              }
            });
          },
          icon: const Icon(
            Icons.expand_more_rounded,
          ),
          label: const Text(
            'Load more projects',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor:
                const Color(0xFF4F46E5),
            side: const BorderSide(
              color: Color(0xFFD9DDFB),
            ),
            padding:
                const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(13),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ThemeData theme,
  ) {
    final hasFilters =
        _searchController.text.isNotEmpty ||
            _selectedWorkMode != 'All' ||
            _selectedProjectType != 'All' ||
            _selectedDuration != 'All' ||
            _selectedTechnology != 'All' ||
            _selectedSkill != 'All' ||
            _minimumBudget != null ||
            _maximumBudget != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalPadding(context),
        30,
        _horizontalPadding(context),
        20,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 50,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters
                    ? Icons.search_off_rounded
                    : Icons.work_off_outlined,
                size: 34,
                color: const Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasFilters
                  ? 'No matching projects'
                  : 'No projects available',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try changing your search or filters '
                    'to discover more opportunities.'
                  : 'New opportunities will appear here '
                    'when clients publish projects.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: _resetFilters,
                child: const Text(
                  'Clear filters',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(
    ThemeData theme,
  ) {
    return CustomScrollView(
      physics:
          const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              30,
              24,
              20,
            ),
            child: _SkeletonBox(
              height: 90,
              radius: 18,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
            ),
            child: _SkeletonBox(
              height: 64,
              radius: 18,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverGrid(
            delegate:
                SliverChildBuilderDelegate(
              (context, index) {
                return const _ProjectSkeletonCard();
              },
              childCount: 6,
            ),
            gridDelegate:
                _gridDelegateForWidth(
              MediaQuery.sizeOf(context).width,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(
    ThemeData theme,
    String error,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFDC2626),
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Unable to load projects',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refreshProjects,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(
    ThemeData theme,
    String message,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        8,
        24,
        20,
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius:
              BorderRadius.circular(13),
          border: Border.all(
            color: const Color(0xFFFDE68A),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFD97706),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PROJECT OPENING
  // ===========================================================================

  void _openProject(
    ProjectModel project,
  ) {
    _showProjectPreview(
      project,
    );
  }

  void _showProjectPreview(
    ProjectModel project,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ProjectPreviewSheet(
          project: project,
          isSaved:
              _savedProjectIds.contains(
            project.id,
          ),
          matchPercentage:
              _getMatchPercentage(project),
          onSave: () async {
            Navigator.of(context).pop();
            await _toggleSave(project);
          },
        );
      },
    );
  }

  // ===========================================================================
  // FILTER MENU
  // ===========================================================================

  Future<void> _showSingleFilterMenu(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                14,
                20,
                20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFD1D5DB),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            Navigator.pop(
                          sheetContext,
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...options.map(
                    (option) {
                      final active =
                          option == selected;

                      return ListTile(
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                        ),
                        tileColor: active
                            ? const Color(
                                0xFFEEF2FF,
                              )
                            : null,
                        title: Text(
                          option,
                          style: TextStyle(
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: active
                                ? const Color(
                                    0xFF4F46E5,
                                  )
                                : const Color(
                                    0xFF374151,
                                  ),
                          ),
                        ),
                        trailing: active
                            ? const Icon(
                                Icons
                                    .check_circle_rounded,
                                color:
                                    Color(0xFF4F46E5),
                              )
                            : null,
                        onTap: () {
                          onSelected(option);
                          Navigator.pop(
                            sheetContext,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  double _horizontalPadding(
    BuildContext context,
  ) {
    final width =
        MediaQuery.sizeOf(context).width;

    if (width >= 1400) return 44;
    if (width >= 1000) return 32;
    if (width >= 650) return 24;

    return 16;
  }

  SliverGridDelegate _gridDelegate(
    BuildContext context,
  ) {
    return _gridDelegateForWidth(
      MediaQuery.sizeOf(context).width,
    );
  }

  SliverGridDelegate _gridDelegateForWidth(
    double width,
  ) {
    if (width >= 1500) {
      return const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        childAspectRatio: 1.30,
      );
    }

    if (width >= 1050) {
      return const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        childAspectRatio: 1.28,
      );
    }

    if (width >= 700) {
      return const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.12,
      );
    }

    return const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 1,
      crossAxisSpacing: 0,
      mainAxisSpacing: 14,
      childAspectRatio: 1.38,
    );
  }

  List<String> _availableTechnologies() {
    final values = <String>{};

    for (final project in _allProjects) {
      values.addAll(
        project.technologies
            .where((item) => item.trim().isNotEmpty),
      );
    }

    final result = values.toList();

    result.sort(
      (a, b) => a.toLowerCase().compareTo(
        b.toLowerCase(),
      ),
    );

    return result;
  }

  List<String> _availableSkills() {
    final values = <String>{};

    for (final project in _allProjects) {
      values.addAll(
        project.skills
            .where((item) => item.trim().isNotEmpty),
      );
    }

    final result = values.toList();

    result.sort(
      (a, b) => a.toLowerCase().compareTo(
        b.toLowerCase(),
      ),
    );

    return result;
  }

  int _getMatchPercentage(
    ProjectModel project,
  ) {
    return project.getMatchPercentage(
      developerSkills: _developerSkills,
      developerTechnologies:
          _developerTechnologies,
      developerProjectType:
          _developerProjectType,
      developerWorkMode:
          _developerWorkMode,
      developerDuration:
          _developerDuration,
    );
  }

  List<String> _readStringList(
    dynamic value,
  ) {
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

    return [];
  }

  String? _readString(
    dynamic value,
  ) {
    if (value == null) return null;

    final stringValue =
        value.toString().trim();

    if (stringValue.isEmpty) {
      return null;
    }

    return stringValue;
  }

  void _showSnackBar(
    String message, {
    required IconData icon,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFB91C1C)
              : const Color(0xFF111827),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(13),
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

  Color get _primaryColor =>
      const Color(0xFF4F46E5);
}

// =============================================================================
// PROJECT CARD
// =============================================================================

class _AnimatedProjectCard extends StatefulWidget {
  const _AnimatedProjectCard({
    super.key,
    required this.project,
    required this.index,
    required this.isSaved,
    required this.matchPercentage,
    required this.onSave,
    required this.onOpen,
  });

  final ProjectModel project;
  final int index;
  final bool isSaved;
  final int matchPercentage;
  final VoidCallback onSave;
  final VoidCallback onOpen;

  @override
  State<_AnimatedProjectCard> createState() =>
      _AnimatedProjectCardState();
}

class _AnimatedProjectCardState
    extends State<_AnimatedProjectCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _hovering = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 550),
    );

    Future<void>.delayed(
      Duration(
        milliseconds:
            40 + (widget.index * 60),
      ),
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
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
          ),
        ),
        child: MouseRegion(
          onEnter: (_) {
            setState(() {
              _hovering = true;
            });
          },
          onExit: (_) {
            setState(() {
              _hovering = false;
            });
          },
          cursor: SystemMouseCursors.click,
          child: AnimatedScale(
            scale: _hovering ? 1.012 : 1,
            duration:
                const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: _buildCard(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
  ) {
    final project = widget.project;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: _hovering ? 5 : 0,
      shadowColor:
          const Color(0xFF4F46E5).withValues(
        alpha: 0.10,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onOpen,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color: _hovering
                  ? const Color(0xFFD8DDFC)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration:
                                  BoxDecoration(
                                gradient:
                                    const LinearGradient(
                                  colors: [
                                    Color(
                                      0xFFEEF2FF,
                                    ),
                                    Color(
                                      0xFFE0E7FF,
                                    ),
                                  ],
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  10,
                                ),
                              ),
                              child: const Icon(
                                Icons
                                    .rocket_launch_rounded,
                                color:
                                    Color(0xFF4F46E5),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                project.title,
                                maxLines: 2,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w800,
                                  color:
                                      Color(0xFF111827),
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onSave,
                    tooltip: widget.isSaved
                        ? 'Remove from saved'
                        : 'Save project',
                    splashRadius: 20,
                    icon: AnimatedSwitcher(
                      duration: const Duration(
                        milliseconds: 220,
                      ),
                      child: Icon(
                        widget.isSaved
                            ? Icons
                                .bookmark_rounded
                            : Icons
                                .bookmark_border_rounded,
                        key: ValueKey(
                          widget.isSaved,
                        ),
                        color: widget.isSaved
                            ? const Color(
                                0xFF4F46E5,
                              )
                            : const Color(
                                0xFF9CA3AF,
                              ),
                        size: 21,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 13),

              Text(
                project.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  height: 1.55,
                ),
              ),

              const SizedBox(height: 14),

              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (project.workMode
                      .trim()
                      .isNotEmpty)
                    _SmallTag(
                      icon: Icons.public_rounded,
                      label: project.workMode,
                    ),
                  if (project.duration
                      .trim()
                      .isNotEmpty)
                    _SmallTag(
                      icon:
                          Icons.schedule_rounded,
                      label: project.duration,
                    ),
                ],
              ),

              const Spacer(),

              if (project.skills.isNotEmpty)
                SizedBox(
                  height: 26,
                  child: ListView.separated(
                    scrollDirection:
                        Axis.horizontal,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    itemCount:
                        project.skills.length > 3
                            ? 3
                            : project.skills.length,
                    separatorBuilder:
                        (_, index) =>
                            const SizedBox(width: 5),
                    itemBuilder:
                        (context, index) {
                      return _SkillChip(
                        label:
                            project.skills[index],
                      );
                    },
                  ),
                ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Budget',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatBudget(project),
                          style:
                              const TextStyle(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w800,
                            color:
                                Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.matchPercentage > 0)
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFECFDF5,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          9,
                        ),
                      ),
                      child: Text(
                        '${widget.matchPercentage}% match',
                        style:
                            const TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w800,
                          color: Color(
                            0xFF047857,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: AnimatedContainer(
                  duration:
                      const Duration(
                    milliseconds: 180,
                  ),
                  decoration: BoxDecoration(
                    color: _hovering
                        ? const Color(
                            0xFF4338CA,
                          )
                        : const Color(
                            0xFF4F46E5,
                          ),
                    borderRadius:
                        BorderRadius.circular(11),
                  ),
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(
                      vertical: 10,
                    ),
                    child: Center(
                      child: Text(
                        'View Project',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBudget(
    ProjectModel project,
  ) {
    final minimum =
        project.effectiveBudgetMin;
    final maximum =
        project.effectiveBudgetMax;

    if (minimum <= 0 && maximum <= 0) {
      return 'Budget flexible';
    }

    if (minimum > 0 &&
        maximum > minimum) {
      return '₹${_compactNumber(minimum)}'
          ' - '
          '₹${_compactNumber(maximum)}';
    }

    final value =
        maximum > 0 ? maximum : minimum;

    return '₹${_compactNumber(value)}';
  }

  String _compactNumber(
    double value,
  ) {
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(value % 100000 == 0 ? 0 : 1)}L';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }

    return value
        .toStringAsFixed(0);
  }
}

// =============================================================================
// RECOMMENDATION CARD
// =============================================================================

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.isSaved,
    required this.onSave,
    required this.onOpen,
  });

  final ProjectRecommendation recommendation;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final project =
        recommendation.project;

    return SizedBox(
      width: 310,
      child: Material(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(18),
          onTap: onOpen,
          child: Container(
            padding:
                const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(18),
              border: Border.all(
                color:
                    const Color(0xFFE5E7EB),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF4F46E5,
                  ).withValues(
                    alpha: 0.035,
                  ),
                  blurRadius: 18,
                  offset:
                      const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFEEF2FF,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          9,
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color:
                            Color(0xFF4F46E5),
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        project.title,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onSave,
                      visualDensity:
                          VisualDensity.compact,
                      icon: Icon(
                        isSaved
                            ? Icons
                                .bookmark_rounded
                            : Icons
                                .bookmark_border_rounded,
                        color: isSaved
                            ? const Color(
                                0xFF4F46E5,
                              )
                            : const Color(
                                0xFF9CA3AF,
                              ),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  project.description,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color:
                        Color(0xFF6B7280),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFECFDF5,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          8,
                        ),
                      ),
                      child: Text(
                        '${recommendation.matchPercentage}% Match',
                        style:
                            const TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              Color(0xFF047857),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _budget(project),
                      style:
                          const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w800,
                      ),
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

  String _budget(ProjectModel project) {
    final min =
        project.effectiveBudgetMin;
    final max =
        project.effectiveBudgetMax;

    if (min <= 0 && max <= 0) {
      return 'Flexible';
    }

    final value =
        max > 0 ? max : min;

    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    }

    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(0)}K';
    }

    return '₹${value.toStringAsFixed(0)}';
  }
}

// =============================================================================
// PROJECT PREVIEW
// =============================================================================

class _ProjectPreviewSheet extends StatelessWidget {
  const _ProjectPreviewSheet({
    required this.project,
    required this.isSaved,
    required this.matchPercentage,
    required this.onSave,
  });

  final ProjectModel project;
  final bool isSaved;
  final int matchPercentage;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (
        context,
        scrollController,
      ) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FD),
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    22,
                    12,
                    22,
                    10,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFD1D5DB,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration:
                                BoxDecoration(
                              gradient:
                                  const LinearGradient(
                                colors: [
                                  Color(
                                    0xFF4F46E5,
                                  ),
                                  Color(
                                    0xFF6366F1,
                                  ),
                                ],
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                            ),
                            child: const Icon(
                              Icons
                                  .rocket_launch_rounded,
                              color:
                                  Colors.white,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  project.title,
                                  style:
                                      const TextStyle(
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                                if (project
                                    .clientName
                                    .isNotEmpty)
                                  Padding(
                                    padding:
                                        const EdgeInsets
                                            .only(
                                      top: 4,
                                    ),
                                    child: Text(
                                      'Posted by ${project.clientName}',
                                      style:
                                          const TextStyle(
                                        color:
                                            Color(
                                          0xFF6B7280,
                                        ),
                                        fontSize:
                                            12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed:
                                onSave,
                            icon: Icon(
                              isSaved
                                  ? Icons
                                      .bookmark_rounded
                                  : Icons
                                      .bookmark_border_rounded,
                              color:
                                  const Color(
                                0xFF4F46E5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 22,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      if (matchPercentage > 0)
                        _PreviewMatchBanner(
                          percentage:
                              matchPercentage,
                        ),
                      const SizedBox(height: 16),
                      _PreviewSection(
                        title: 'About the project',
                        icon:
                            Icons.description_outlined,
                        child: Text(
                          project.description,
                          style:
                              const TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color:
                                Color(0xFF4B5563),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _PreviewSection(
                        title: 'Project details',
                        icon:
                            Icons.info_outline_rounded,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _DetailPill(
                              icon:
                                  Icons.payments_outlined,
                              label:
                                  _budget(project),
                            ),
                            _DetailPill(
                              icon:
                                  Icons.schedule_rounded,
                              label:
                                  project.duration,
                            ),
                            _DetailPill(
                              icon:
                                  Icons.public_rounded,
                              label:
                                  project.workMode,
                            ),
                            _DetailPill(
                              icon:
                                  Icons.category_outlined,
                              label:
                                  project.projectType,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (project.skills.isNotEmpty)
                        _PreviewSection(
                          title:
                              'Required skills',
                          icon:
                              Icons.psychology_outlined,
                          child: Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: project.skills
                                .map(
                                  (skill) =>
                                      _SkillChip(
                                    label: skill,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 18),
                      if (project
                          .technologies
                          .isNotEmpty)
                        _PreviewSection(
                          title:
                              'Technologies',
                          icon:
                              Icons.code_rounded,
                          child: Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: project
                                .technologies
                                .map(
                                  (technology) =>
                                      _TechnologyChip(
                                    label:
                                        technology,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child:
                            ElevatedButton.icon(
                          onPressed: () {
                            
                          Navigator.of(context).pop();

Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ProjectDetails(
      projectId: project.id,
      initialProject: project,
    ),
  ),
);
                         
                          },
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                          ),
                          label: const Text(
                            'View Full Project',
                          ),
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                const Color(
                              0xFF4F46E5,
                            ),
                            foregroundColor:
                                Colors.white,
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 15,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _budget(ProjectModel project) {
    final min =
        project.effectiveBudgetMin;
    final max =
        project.effectiveBudgetMax;

    if (min <= 0 && max <= 0) {
      return 'Budget Flexible';
    }

    if (min > 0 && max > min) {
      return '₹${_number(min)} - ₹${_number(max)}';
    }

    return '₹${_number(max > 0 ? max : min)}';
  }

  String _number(double value) {
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)}L';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }

    return value.toStringAsFixed(0);
  }
}

// =============================================================================
// SMALL COMPONENTS
// =============================================================================

class _PreviewMatchBanner extends StatelessWidget {
  const _PreviewMatchBanner({
    required this.percentage,
  });

  final int percentage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFEEF2FF),
            Color(0xFFF5F3FF),
          ],
        ),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFDDE2FF),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF4F46E5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This project matches $percentage% '
              'of your developer profile.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3730A3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: const Color(0xFF4F46E5),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(10),
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
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? const Color(0xFFEEF2FF)
          : Colors.white,
      borderRadius:
          BorderRadius.circular(12),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? const Color(0xFFC7D2FE)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: active
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: active
                      ? const Color(0xFF4338CA)
                      : const Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetChip extends StatelessWidget {
  const _BudgetChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? const Color(0xFFEEF2FF)
          : Colors.white,
      borderRadius:
          BorderRadius.circular(10),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? const Color(0xFFC7D2FE)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: active
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius:
            BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: const Color(0xFF6B7280),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius:
            BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }
}

class _TechnologyChip extends StatelessWidget {
  const _TechnologyChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFDDE2FF),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4338CA),
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.height,
    required this.radius,
  });

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFF5),
        borderRadius:
            BorderRadius.circular(radius),
      ),
    );
  }
}

class _ProjectSkeletonCard extends StatelessWidget {
  const _ProjectSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _SkeletonBox(
            height: 40,
            radius: 10,
          ),
          SizedBox(height: 15),
          _SkeletonBox(
            height: 12,
            radius: 6,
          ),
          SizedBox(height: 8),
          _SkeletonBox(
            height: 12,
            radius: 6,
          ),
          SizedBox(height: 8),
          _SkeletonBox(
            height: 12,
            radius: 6,
          ),
          Spacer(),
          _SkeletonBox(
            height: 34,
            radius: 10,
          ),
        ],
      ),
    );
  }
}