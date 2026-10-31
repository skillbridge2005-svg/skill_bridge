import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'apply_project.dart';

import 'package:skill_bridge/models/project_model.dart';
import 'package:skill_bridge/services/project_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class DiscoverProjects extends StatefulWidget {
  const DiscoverProjects({super.key});

  @override
  State<DiscoverProjects> createState() => _DiscoverProjectsState();
}

class _DiscoverProjectsState extends State<DiscoverProjects>
    with TickerProviderStateMixin {
  final ProjectService _projectService = ProjectService();

  late final Stream<List<ProjectModel>> _openProjectsStream;

  // Keeps the exact stream list that has already been applied to state.
  // This prevents StreamBuilder rebuilds from scheduling endless setState calls.

  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  late final AnimationController _headerController;
  late final AnimationController _contentController;

  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  late final Animation<double> _contentFade;

  StreamSubscription<Set<String>>? _savedProjectsSubscription;
  StreamSubscription<List<ProjectModel>>? _projectsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _applicationStatusSubscription;

  bool _projectsLoading = true;
  int? _profileCompletion;
  List<ProjectModel> _allProjects = [];
  List<ProjectModel> _filteredProjects = [];
  List<ProjectRecommendation> _recommendations = [];

  Set<String> _savedProjectIds = {};
  Map<String, String> _applicationStatusByProjectId = {};

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
  bool _showSavedOnly = false;
  int _visibleProjectCount = 8;

  @override
  void initState() {
    super.initState();
    _openProjectsStream = _projectService.watchOpenProjects();

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

    _headerSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
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

    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) {
        _contentController.forward();
      }
    });

    _loadDeveloperProfile();
    _listenToSavedProjects();
    _listenToApplicationStatuses();

    void listenToProjects() {
      _projectsSubscription = _openProjectsStream.listen(
        (projects) {
          if (!mounted) return;

          _onProjectsChanged(projects);

          setState(() {
            _projectsLoading = false;
          });
        },
        onError: (error) {
          if (!mounted) return;

          setState(() {
            _projectsLoading = false;
            _errorMessage = 'Unable to load projects: $error';
          });
        },
      );
    }

    listenToProjects();
  }

  void _listenToApplicationStatuses() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      setState(() {
        _applicationStatusByProjectId = {};
      });
      return;
    }

    _applicationStatusSubscription?.cancel();

    _applicationStatusSubscription = FirebaseFirestore.instance
        .collection('applications')
        .where('developerId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;

            // Sort newest application updates first.
            final docs = [...snapshot.docs];

            DateTime timestampOf(
              QueryDocumentSnapshot<Map<String, dynamic>> doc,
            ) {
              final data = doc.data();
              final value = data['updatedAt'] ?? data['createdAt'];

              if (value is Timestamp) return value.toDate();
              if (value is DateTime) return value;

              return DateTime.fromMillisecondsSinceEpoch(0);
            }

            docs.sort((a, b) => timestampOf(b).compareTo(timestampOf(a)));

            final statusByProjectId = <String, String>{};

            for (final doc in docs) {
              final data = doc.data();
              final projectId = data['projectId']?.toString();

              if (projectId == null ||
                  projectId.isEmpty ||
                  statusByProjectId.containsKey(projectId)) {
                continue;
              }

              statusByProjectId[projectId] = (data['status'] ?? 'pending')
                  .toString()
                  .trim()
                  .toLowerCase();
            }

            setState(() {
              _applicationStatusByProjectId = statusByProjectId;
            });
          },
          onError: (Object error) {
            debugPrint('Unable to listen to application statuses: $error');
          },
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _headerController.dispose();
    _contentController.dispose();
    _savedProjectsSubscription?.cancel();
    _projectsSubscription?.cancel();
    _applicationStatusSubscription?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // PROFILE
  // ===========================================================================
  Future<void> _loadDeveloperProfile() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        throw Exception('No authenticated developer account was found.');
      }

      final profileSnapshot = await FirebaseFirestore.instance
          .collection('developerProfiles')
          .doc(uid)
          .get();

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final profileData = profileSnapshot.data() ?? <String, dynamic>{};

      final userData = userSnapshot.data() ?? <String, dynamic>{};
      final completionValue =
          profileData['profileCompletion'] ?? userData['profileCompletion'];

      final int? profileCompletion = completionValue is num
          ? completionValue.toInt()
          : null;

      _developerSkills = _readStringList(profileData['skills']);

      _developerTechnologies = _readStringList(profileData['technologies']);

      _developerProjectType =
          _readString(profileData['projectType']) ??
          _readString(userData['projectType']);

      _developerWorkMode =
          _readString(profileData['workMode']) ??
          _readString(userData['workMode']);

      _developerDuration =
          _readString(profileData['projectDuration']) ??
          _readString(profileData['duration']);
      if (!mounted) return;

      setState(() {
        _profileCompletion = profileCompletion;
        _calculateRecommendations();
      });
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
    _savedProjectsSubscription = _projectService.watchSavedProjectIds().listen(
      (ids) {
        if (!mounted) return;

        setState(() {
          _savedProjectIds = ids;
          _applyFilters();
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

  void _onProjectsChanged(List<ProjectModel> projects) {
    if (!mounted) return;

    setState(() {
      _allProjects = List<ProjectModel>.from(projects);
      _applyFilters();
      _calculateRecommendations();
      _errorMessage = null;
    });
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _projectService.filterProjects(
      _allProjects,
      technology: _selectedTechnology == 'All' ? null : _selectedTechnology,
      skill: _selectedSkill == 'All' ? null : _selectedSkill,
      workMode: _selectedWorkMode == 'All' ? null : _selectedWorkMode,
      projectType: _selectedProjectType == 'All' ? null : _selectedProjectType,
      duration: _selectedDuration == 'All' ? null : _selectedDuration,
      minimumBudget: _minimumBudget,
      maximumBudget: _maximumBudget,
    );

    final searched = query.isEmpty
        ? filtered
        : filtered.where((project) {
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

            return searchableText.contains(query);
          }).toList();

    final sorted = _projectService.sortProjects(searched, sortBy: _sortBy);

    _filteredProjects = _showSavedOnly
        ? sorted
              .where((project) => _savedProjectIds.contains(project.id))
              .toList()
        : sorted;

    if (_visibleProjectCount > _filteredProjects.length) {
      _visibleProjectCount = _filteredProjects.length;
    }

    if (_visibleProjectCount == 0 && _filteredProjects.isNotEmpty) {
      _visibleProjectCount = _filteredProjects.length < 8
          ? _filteredProjects.length
          : 8;
    }
  }

  void _calculateRecommendations() {
    _recommendations = _projectService.getRecommendedProjects(
      _allProjects,
      developerSkills: _developerSkills,
      developerTechnologies: _developerTechnologies,
      developerProjectType: _developerProjectType,
      developerWorkMode: _developerWorkMode,
      developerDuration: _developerDuration,
      minimumScore: 0,
      limit: 3,
    );
  }

  Future<void> _refreshProjects() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _loadDeveloperProfile();

      final projects = await _projectService.getOpenProjects();

      _onProjectsChanged(projects);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to refresh projects. Please try again.';
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

  void _setBudgetRange(double? minimum, double? maximum) {
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

  Future<void> _toggleSave(ProjectModel project) async {
    final isSaved = _savedProjectIds.contains(project.id);

    try {
      if (isSaved) {
        await _projectService.unsaveProject(project.id);
      } else {
        await _projectService.saveProject(project.id);
      }

      if (!mounted) return;

      _showSnackBar(
        isSaved
            ? 'Project removed from saved projects.'
            : 'Project saved successfully.',
        icon: isSaved ? Icons.bookmark_border_rounded : Icons.bookmark_rounded,
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

  Widget _buildProfileCompletionBanner(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalPadding(context),
        12,
        _horizontalPadding(context),
        4,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.person_outline_rounded,
              color: Color(0xFFD97706),
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete your developer profile',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Please complete and save your developer '
                    'profile to 100% before applying for projects.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF92400E),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_projectsLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        body: SafeArea(child: _buildLoadingState(theme)),
      );
    }

    if (_errorMessage != null && _allProjects.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        body: SafeArea(child: _buildErrorState(theme, _errorMessage!)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(child: _buildMainContent(context, theme)),
    );
  }

  Widget _buildMainContent(BuildContext context, ThemeData theme) {
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
                child: _buildHeader(context, theme),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: _buildSearchSection(context, theme),
            ),
          ),
          if (_profileCompletion == null || _profileCompletion! < 100)
            SliverToBoxAdapter(child: _buildProfileCompletionBanner(context)),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: _buildFilterBar(context, theme),
            ),
          ),

          if (_showRecommendations &&
              !_showSavedOnly &&
              _recommendations.isNotEmpty)
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _contentFade,
                child: _buildRecommendationsSection(context, theme),
              ),
            ),

          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: _buildProjectsHeader(context, theme),
            ),
          ),

          if (_filteredProjects.isEmpty)
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _contentFade,
                child: _buildEmptyState(context, theme),
              ),
            )
          else if (MediaQuery.sizeOf(context).width < 700)
            // Mobile: use naturally sized cards in a list. A fixed-height grid
            // clips the card's budget and action button on narrow screens.
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                _horizontalPadding(context),
                0,
                _horizontalPadding(context),
                32,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final project = _filteredProjects[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _AnimatedProjectCard(
                      key: ValueKey(project.id),
                      project: project,
                      index: index,
                      isSaved: _savedProjectIds.contains(project.id),
                      matchPercentage: _getMatchPercentage(project),
                      onSave: () => _toggleSave(project),
                      onOpen: () => _openProject(project),
                    ),
                  );
                }, childCount: _visibleProjectCount),
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
                delegate: SliverChildBuilderDelegate((context, index) {
                  final project = _filteredProjects[index];

                  return _AnimatedProjectCard(
                    key: ValueKey(project.id),
                    project: project,
                    index: index,
                    isSaved: _savedProjectIds.contains(project.id),
                    matchPercentage: _getMatchPercentage(project),
                    onSave: () => _toggleSave(project),
                    onOpen: () => _openProject(project),
                  );
                }, childCount: _visibleProjectCount),
                gridDelegate: _gridDelegate(context),
              ),
            ),

          if (_visibleProjectCount < _filteredProjects.length &&
              _filteredProjects.isNotEmpty)
            SliverToBoxAdapter(child: _buildLoadMoreButton(context, theme)),

          if (_errorMessage != null)
            SliverToBoxAdapter(child: _buildInfoBanner(theme, _errorMessage!)),

          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalPadding(context),
        28,
        _horizontalPadding(context),
        20,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 24),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5)
                                    .withValues(alpha: 0.22),
                                blurRadius: 18,
                                offset: const Offset(0, 7),
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
                            fontSize: compact ? 25 : 30,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
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
                        color: const Color(0xFF6B7280),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              if (!compact) _buildRefreshButton(theme),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRefreshButton(ThemeData theme) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _isRefreshing ? null : _refreshProjects,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isRefreshing
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection(BuildContext context, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding(context)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
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
            hintText: 'Search projects, skills, technologies...',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 18, right: 10),
              child: Icon(Icons.search_rounded, color: Color(0xFF6366F1)),
            ),
            suffixIcon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _searchController.text.isNotEmpty
                  ? IconButton(
                      key: const ValueKey('clear-search'),
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    )
                  : const SizedBox(key: ValueKey('empty-search')),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, ThemeData theme) {
    final technologies = _availableTechnologies();
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
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _FilterButton(
                        icon: Icons.tune_rounded,
                        label: 'Filters',
                        active: hasActiveFilters,
                        onTap: () {
                          setState(() {
                            _showFilters = !_showFilters;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        icon: Icons.bookmark_rounded,
                        label: 'Saved Projects',
                        active: _showSavedOnly,
                        onTap: () {
                          setState(() {
                            _showSavedOnly = !_showSavedOnly;
                            _visibleProjectCount = 8;
                            _applyFilters();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        icon: Icons.work_outline_rounded,
                        label: _selectedWorkMode,
                        active: _selectedWorkMode != 'All',
                        onTap: () => _showSingleFilterMenu(
                          context,
                          title: 'Work Mode',
                          options: const ['All', 'Remote', 'Hybrid', 'On-site'],
                          selected: _selectedWorkMode,
                          onSelected: _setWorkMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        icon: Icons.category_outlined,
                        label: _selectedProjectType,
                        active: _selectedProjectType != 'All',
                        onTap: () => _showSingleFilterMenu(
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
                          selected: _selectedProjectType,
                          onSelected: _setProjectType,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        icon: Icons.schedule_rounded,
                        label: _selectedDuration,
                        active: _selectedDuration != 'All',
                        onTap: () => _showSingleFilterMenu(
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
                          selected: _selectedDuration,
                          onSelected: _setDuration,
                        ),
                      ),
                      if (technologies.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _FilterButton(
                          icon: Icons.code_rounded,
                          label: _selectedTechnology,
                          active: _selectedTechnology != 'All',
                          onTap: () => _showSingleFilterMenu(
                            context,
                            title: 'Technology',
                            options: ['All', ...technologies],
                            selected: _selectedTechnology,
                            onSelected: _setTechnology,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildSortButton(context, theme),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _showFilters
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _buildAdvancedFilters(context, theme, skills),
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
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (skills.isNotEmpty)
                _buildFilterDropdown(
                  label: 'Required Skill',
                  value: _selectedSkill,
                  options: ['All', ...skills],
                  onChanged: _setSkill,
                  compact: compact,
                ),
              const SizedBox(height: 14),
              _buildBudgetSelector(context, compact),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBudgetSelector(BuildContext context, bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              active: _minimumBudget == null && _maximumBudget == null,
              onTap: () => _setBudgetRange(null, null),
            ),
            _BudgetChip(
              label: 'Under ₹10K',
              active: _minimumBudget == null && _maximumBudget == 10000,
              onTap: () => _setBudgetRange(null, 10000),
            ),
            _BudgetChip(
              label: '₹10K - ₹25K',
              active: _minimumBudget == 10000 && _maximumBudget == 25000,
              onTap: () => _setBudgetRange(10000, 25000),
            ),
            _BudgetChip(
              label: '₹25K - ₹50K',
              active: _minimumBudget == 25000 && _maximumBudget == 50000,
              onTap: () => _setBudgetRange(25000, 50000),
            ),
            _BudgetChip(
              label: '₹50K+',
              active: _minimumBudget == 50000 && _maximumBudget == null,
              onTap: () => _setBudgetRange(50000, null),
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
      width: compact ? double.infinity : 320,
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : 'All',
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
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

  Widget _buildSortButton(BuildContext context, ThemeData theme) {
    return PopupMenuButton<String>(
      tooltip: 'Sort projects',
      onSelected: _setSort,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'newest', child: Text('Newest first')),
        PopupMenuItem(value: 'oldest', child: Text('Oldest first')),
        PopupMenuItem(value: 'budget_high', child: Text('Highest budget')),
        PopupMenuItem(value: 'budget_low', child: Text('Lowest budget')),
        PopupMenuItem(
          value: 'applications_low',
          child: Text('Fewest applications'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Icon(Icons.sort_rounded, size: 20),
      ),
    );
  }

  Widget _buildRecommendationsSection(BuildContext context, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalPadding(context),
        24,
        _horizontalPadding(context),
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended for You',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Based on your developer profile',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showRecommendations = !_showRecommendations;
                  });
                },
                child: Text(_showRecommendations ? 'Hide' : 'Show'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _recommendations.length,
              separatorBuilder: (_, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final recommendation = _recommendations[index];

                return _RecommendationCard(
                  recommendation: recommendation,
                  isSaved: _savedProjectIds.contains(recommendation.project.id),
                  onSave: () => _toggleSave(recommendation.project),
                  onOpen: () => _openProject(recommendation.project),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsHeader(BuildContext context, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalPadding(context),
        22,
        _horizontalPadding(context),
        14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _showSavedOnly ? 'Saved Projects' : 'All Projects',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  _showSavedOnly
                      ? 'Projects you have bookmarked'
                      : 'Explore currently available opportunities',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey(_filteredProjects.length),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
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

  Widget _buildLoadMoreButton(BuildContext context, ThemeData theme) {
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

              if (_visibleProjectCount > _filteredProjects.length) {
                _visibleProjectCount = _filteredProjects.length;
              }
            });
          },
          icon: const Icon(Icons.expand_more_rounded),
          label: const Text('Load more projects'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4F46E5),
            side: const BorderSide(color: Color(0xFFD9DDFB)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    final hasFilters =
        _showSavedOnly ||
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
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 50),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5E7EB)),
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
                hasFilters ? Icons.search_off_rounded : Icons.work_off_outlined,
                size: 34,
                color: const Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _showSavedOnly
                  ? 'No saved projects yet'
                  : hasFilters
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
              _showSavedOnly
                  ? 'Bookmark a project to find it here later.'
                  : hasFilters
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
                onPressed: () {
                  if (_showSavedOnly) {
                    setState(() {
                      _showSavedOnly = false;
                      _visibleProjectCount = 8;
                      _applyFilters();
                    });
                  } else {
                    _resetFilters();
                  }
                },
                child: Text(
                  _showSavedOnly ? 'View all projects' : 'Clear filters',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
            child: _SkeletonBox(height: 90, radius: 18),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _SkeletonBox(height: 64, radius: 18),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              return const _ProjectSkeletonCard();
            }, childCount: 6),
            gridDelegate: _gridDelegateForWidth(
              MediaQuery.sizeOf(context).width,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refreshProjects,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(ThemeData theme, String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
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

  void _openProject(ProjectModel project) {
    _showProjectPreview(project);
  }

  Future<void> _showProjectPreview(ProjectModel project) async {
    // The preview sheet contains the full project information. Close it first
    // and then open the existing application form directly.
    final shouldApply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ProjectPreviewSheet(
          project: project,
          isSaved: _savedProjectIds.contains(project.id),
          isApplied:
              _applicationStatusByProjectId.containsKey(project.id) &&
              _applicationStatusByProjectId[project.id] != 'withdrawn',
          applicationStatus: _applicationStatusByProjectId[project.id],
          matchPercentage: _getMatchPercentage(project),
          onSave: () async {
            Navigator.of(sheetContext).pop(false);
            await _toggleSave(project);
          },
          onApply: () {
            Navigator.of(sheetContext).pop(true);
          },
        );
      },
    );

    if (!mounted || shouldApply != true) return;

    if (!project.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This project is no longer accepting applications.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ApplyProject(projectId: project.id, initialProject: project),
      ),
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final screenHeight = MediaQuery.sizeOf(sheetContext).height;
        final sheetHeight = screenHeight * 0.72;

        return SafeArea(
          child: Container(
            height: sheetHeight,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final active = option == selected;

                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: active ? const Color(0xFFEEF2FF) : null,
                          title: Text(
                            option,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active
                                  ? const Color(0xFF4F46E5)
                                  : const Color(0xFF374151),
                            ),
                          ),
                          trailing: active
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF4F46E5),
                                )
                              : null,
                          onTap: () {
                            onSelected(option);
                            Navigator.pop(sheetContext);
                          },
                        );
                      },
                    ),
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

  double _horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 1400) return 44;
    if (width >= 1000) return 32;
    if (width >= 650) return 24;

    return 16;
  }

  SliverGridDelegate _gridDelegate(BuildContext context) {
    return _gridDelegateForWidth(MediaQuery.sizeOf(context).width);
  }

  SliverGridDelegate _gridDelegateForWidth(double width) {
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

  // Filter menus should contain concise labels, not Markdown or whole project
  // descriptions that may have accidentally been stored in a skills/technology
  // field in older project documents.
  bool _isValidFilterOption(String value) {
    final item = value.trim();
    if (item.isEmpty || item.length > 40) return false;
    if (item.contains('\n') || item.contains('\r')) return false;
    if (item.contains('**') || item.contains('```')) return false;
    if (item.startsWith('#') ||
        item.contains('Project Title:') ||
        item.contains('Project Description:') ||
        item.contains('Technology:**')) {
      return false;
    }
    if (RegExp(r'[.!?]\s*$').hasMatch(item)) return false;
    return true;
  }

  List<String> _availableTechnologies() {
    final values = <String>{};

    for (final project in _allProjects) {
      for (final technology in project.technologies) {
        final cleaned = technology.trim();
        if (_isValidFilterOption(cleaned)) values.add(cleaned);
      }
    }

    final result = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return result;
  }

  List<String> _availableSkills() {
    final values = <String>{};

    for (final project in _allProjects) {
      for (final skill in project.skills) {
        final cleaned = skill.trim();
        if (_isValidFilterOption(cleaned)) values.add(cleaned);
      }
    }

    final result = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return result;
  }

  int _getMatchPercentage(ProjectModel project) {
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
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return [];
  }

  String? _readString(dynamic value) {
    if (value == null) return null;

    final stringValue = value.toString().trim();

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
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFB91C1C)
              : const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  Color get _primaryColor => const Color(0xFF4F46E5);
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
  State<_AnimatedProjectCard> createState() => _AnimatedProjectCardState();
}

class _AnimatedProjectCardState extends State<_AnimatedProjectCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _hovering = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    Future<void>.delayed(Duration(milliseconds: 40 + (widget.index * 60)), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
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
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: _buildCard(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final project = widget.project;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: _hovering ? 5 : 0,
      shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onOpen,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovering
                  ? const Color(0xFFD8DDFC)
                  : const Color(0xFFE5E7EB),
            ),
          ),
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
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFEEF2FF),
                                    Color(0xFFE0E7FF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.rocket_launch_rounded,
                                color: Color(0xFF4F46E5),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                project.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
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
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        widget.isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        key: ValueKey(widget.isSaved),
                        color: widget.isSaved
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF9CA3AF),
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
                  if (project.workMode.trim().isNotEmpty)
                    _SmallTag(
                      icon: Icons.public_rounded,
                      label: project.workMode,
                    ),
                  if (project.duration.trim().isNotEmpty)
                    _SmallTag(
                      icon: Icons.schedule_rounded,
                      label: project.duration,
                    ),
                ],
              ),

              // Keep the card content in normal flow. Spacer requires a
              // bounded height and can cause overflow in responsive lists.
              const SizedBox(height: 16),

              if (project.skills.isNotEmpty)
                SizedBox(
                  height: 26,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: project.skills.length > 3
                        ? 3
                        : project.skills.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 5),
                    itemBuilder: (context, index) {
                      return _SkillChip(label: project.skills[index]);
                    },
                  ),
                ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Budget',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatBudget(project),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${widget.matchPercentage}% match',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: _hovering
                        ? const Color(0xFF4338CA)
                        : const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text(
                        'View Project',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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

  String _formatBudget(ProjectModel project) {
    final minimum = project.effectiveBudgetMin;
    final maximum = project.effectiveBudgetMax;

    if (minimum <= 0 && maximum <= 0) {
      return 'Budget flexible';
    }

    if (minimum > 0 && maximum > minimum) {
      return '₹${_compactNumber(minimum)}'
          ' - '
          '₹${_compactNumber(maximum)}';
    }

    final value = maximum > 0 ? maximum : minimum;

    return '₹${_compactNumber(value)}';
  }

  String _compactNumber(double value) {
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(value % 100000 == 0 ? 0 : 1)}L';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }

    return value.toStringAsFixed(0);
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
    final project = recommendation.project;

    return SizedBox(
      width: 310,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.035),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF4F46E5),
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        project.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onSave,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: isSaved
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF9CA3AF),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${recommendation.matchPercentage}% Match',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _budget(project),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
    final min = project.effectiveBudgetMin;
    final max = project.effectiveBudgetMax;

    if (min <= 0 && max <= 0) {
      return 'Flexible';
    }

    final value = max > 0 ? max : min;

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
    required this.onApply,
    required this.isApplied,
    required this.applicationStatus,
  });

  final ProjectModel project;
  final bool isSaved;
  final int matchPercentage;
  final VoidCallback onSave;
  final VoidCallback onApply;
  final bool isApplied;
  final String? applicationStatus;

  String _cleanProjectText(String value) {
    return value.trim();
  }

  String _cleanTechnology(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^(?:[-•*]\s+|\d+[.)]\s+)'), '')
        .replaceAll('**', '')
        .replaceAll('`', '')
        .trim();
  }

  bool _isLikelyTechnologyName(String value) {
    final item = _cleanTechnology(value);

    if (item.isEmpty || item.length > 90) return false;

    if (RegExp(r'[.!?;]$').hasMatch(item)) {
      return false;
    }

    return !RegExp(
      r'\b(allows|provides|ensures|supports|enables|reducing|'
      r'delivering|significantly|because|therefore|architecture|'
      r'codebase|performance|compliance|handling|improving|'
      r'maintaining|offers|built-in)\b',
      caseSensitive: false,
    ).hasMatch(item);
  }

  Map<String, List<String>> _extractTechnologyGroups(List<String> rawItems) {
    final groups = <String, List<String>>{};

    void addTechnology(String category, String value) {
      final technology = _cleanTechnology(value);

      if (!_isLikelyTechnologyName(technology)) return;

      final categoryName = category.trim().isEmpty
          ? 'Technologies'
          : category.trim();

      final items = groups.putIfAbsent(categoryName, () => <String>[]);

      if (!items.any(
        (item) => item.toLowerCase() == technology.toLowerCase(),
      )) {
        items.add(technology);
      }
    }

    final combinedText = rawItems.join('\n');

    final isStructured = RegExp(
      r'^\s*#{1,6}\s|'
      r'^\s*(?:[-*•]\s*)?\*{0,2}\s*'
      r'(?:technology|technologies|tech stack|why|reason)\s*:',
      multiLine: true,
      caseSensitive: false,
    ).hasMatch(combinedText);

    // Support normal technology lists also.
    if (!isStructured) {
      for (final line in combinedText.split('\n')) {
        final value = _cleanTechnology(line);

        if (_isLikelyTechnologyName(value)) {
          addTechnology('Technologies', value);
        }
      }

      return groups;
    }

    String currentCategory = 'Technologies';
    bool skippingExplanation = false;

    for (final rawLine in combinedText.split('\n')) {
      final line = rawLine.trim();

      if (line.isEmpty) continue;

      // Detect category headings such as:
      // ### 1. Frontend (Mobile Application)
      final headingMatch = RegExp(
        r'^#{1,6}\s*(?:(?:\d+)\s*[.)]\s*)?(.+?)\s*#*$',
      ).firstMatch(line);

      if (headingMatch != null) {
        currentCategory = _cleanTechnology(headingMatch.group(1) ?? '');

        skippingExplanation = false;
        continue;
      }

      // Extract only Technology: values.
      final technologyMatch = RegExp(
        r'^(?:[-*•]\s*)?\*{0,2}\s*'
        r'(?:technology|technologies|tech stack|tools?)'
        r'\s*:?\s*\*{0,2}\s*(.*?)\s*$',
        caseSensitive: false,
      ).firstMatch(line);

      if (technologyMatch != null) {
        final rawTechnology = technologyMatch.group(1) ?? '';

        final inlineWhy = RegExp(
          r'\s+\*{0,2}\s*(?:why|reason)\s*:.*$',
          caseSensitive: false,
        );

        final hasInlineExplanation = inlineWhy.hasMatch(rawTechnology);

        final technology = rawTechnology.replaceFirst(inlineWhy, '');

        addTechnology(currentCategory, technology);

        skippingExplanation = hasInlineExplanation;
        continue;
      }

      // Detect explanation sections.
      final isExplanation = RegExp(
        r'^(?:[-*•]\s*)?\*{0,2}\s*'
        r'(?:why|reason|purpose|benefit|rationale|'
        r'explanation|description)\s*:',
        caseSensitive: false,
      ).hasMatch(line);

      if (isExplanation) {
        skippingExplanation = true;
        continue;
      }

      // Ignore all continuation lines of Why explanations.
      if (skippingExplanation) continue;

      // Support simple bullet lists inside a category.
      final bulletMatch = RegExp(r'^[-*•]\s+(.+)$').firstMatch(line);

      if (bulletMatch != null) {
        addTechnology(currentCategory, bulletMatch.group(1) ?? '');
      }
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final detailPills = <Widget>[
      if (project.effectiveBudgetMin > 0 || project.effectiveBudgetMax > 0)
        _DetailPill(icon: Icons.payments_outlined, label: _budget(project)),

      if (project.duration.trim().isNotEmpty)
        _DetailPill(icon: Icons.schedule_rounded, label: project.duration),

      if (project.workMode.trim().isNotEmpty)
        _DetailPill(icon: Icons.public_rounded, label: project.workMode),

      if (project.projectType.trim().isNotEmpty)
        _DetailPill(icon: Icons.category_outlined, label: project.projectType),
    ];

    final technologyGroups = _extractTechnologyGroups(project.technologies);
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FD),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.rocket_launch_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  project.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (project.clientName.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Posted by ${project.clientName}',
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: onSave,
                            icon: Icon(
                              isSaved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              color: const Color(0xFF4F46E5),
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
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PreviewMatchBanner(percentage: matchPercentage),
                      const SizedBox(height: 16),
                      _PreviewSection(
                        title: 'About the project',
                        icon: Icons.description_outlined,
                        child: _DetailParagraph(
                          text: project.description.trim().isEmpty
                              ? 'No description provided.'
                              : _cleanProjectText(project.description),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (detailPills.isNotEmpty) ...[
                        _PreviewSection(
                          title: 'Project details',
                          icon: Icons.info_outline_rounded,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: detailPills,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _ProjectAdditionalDetails(projectId: project.id),
                      const SizedBox(height: 18),
                      if (project.skills.isNotEmpty)
                        _PreviewSection(
                          title: 'Required skills',
                          icon: Icons.psychology_outlined,
                          child: Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: project.skills
                                .map((skill) => _SkillChip(label: skill))
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 18),
                      if (technologyGroups.isNotEmpty)
                        _PreviewSection(
                          title: 'Technologies',
                          icon: Icons.code_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: technologyGroups.entries.map((entry) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4F46E5)
                                          .withValues(alpha: 0.035),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEF0FF),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.layers_rounded,
                                            color: Color(0xFF4F46E5),
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 11),
                                        Expanded(
                                          child: Text(
                                            entry.key,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF27324A),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEF0FF),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            '${entry.value.length}',
                                            style: const TextStyle(
                                              color: Color(0xFF4F46E5),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFF0F1F5),
                                    ),
                                    const SizedBox(height: 5),

                                    ...entry.value.map(
                                      (technology) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              size: 17,
                                              color: Color(0xFF6366F1),
                                            ),
                                            const SizedBox(width: 11),
                                            Expanded(
                                              child: Text(
                                                technology,
                                                softWrap: true,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF374151),
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isApplied ? null : onApply,
                          icon: Icon(
                            isApplied
                                ? (applicationStatus == 'shortlisted'
                                      ? Icons.star_rounded
                                      : applicationStatus == 'rejected'
                                      ? Icons.cancel_outlined
                                      : applicationStatus == 'accepted'
                                      ? Icons.verified_rounded
                                      : Icons.hourglass_top_rounded)
                                : Icons.send_rounded,
                          ),
                          label: Text(
                            !isApplied
                                ? 'Apply Now'
                                : switch (applicationStatus) {
                                    'shortlisted' => 'Shortlisted',
                                    'rejected' => 'Application Rejected',
                                    'accepted' => 'Application Accepted',
                                    'pending' => 'Application Pending',
                                    'withdrawn' => 'Apply Again',
                                    _ => 'Application Submitted',
                                  },
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !isApplied
                                ? const Color(0xFF4F46E5)
                                : applicationStatus == 'rejected'
                                ? const Color(0xFFDC2626)
                                : applicationStatus == 'shortlisted' ||
                                      applicationStatus == 'accepted'
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF64748B),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                applicationStatus == 'rejected'
                                ? const Color(0xFFDC2626)
                                : applicationStatus == 'shortlisted' ||
                                      applicationStatus == 'accepted'
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF64748B),
                            disabledForegroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
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
    final min = project.effectiveBudgetMin;
    final max = project.effectiveBudgetMax;

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
  const _PreviewMatchBanner({required this.percentage});

  final int percentage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE2FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4F46E5)),
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

/// Loads fields that are not yet represented by ProjectModel (for example,
/// uploaded reference images and richer project requirements) directly from
/// the source Firestore project document.

/// Loads the complete accepted project data from the existing Firestore
/// document: projects/{projectId}.
///
/// This widget does not write or modify any Firestore data.
class _ProjectAdditionalDetails extends StatefulWidget {
  const _ProjectAdditionalDetails({required this.projectId});

  final String projectId;

  @override
  State<_ProjectAdditionalDetails> createState() =>
      _ProjectAdditionalDetailsState();
}

class _ProjectAdditionalDetailsState extends State<_ProjectAdditionalDetails> {
  late final Future<Map<String, dynamic>?> _projectDataFuture;

  @override
  void initState() {
    super.initState();
    _projectDataFuture = _loadData();
  }

  Future<Map<String, dynamic>?> _loadData() async {
    if (widget.projectId.trim().isEmpty) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .get();

    return snapshot.data();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    return <String, dynamic>{};
  }

  bool _isValidImageUrl(dynamic value) {
    if (value == null) return false;

    final uri = Uri.tryParse(value.toString().trim());

    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  /// Extracts image URLs from strings, lists and common image objects.
  List<String> _extractImageUrls(dynamic value) {
    final result = <String>{};

    void visit(dynamic item) {
      if (item == null) return;

      if (item is String) {
        final url = item.trim();

        if (_isValidImageUrl(url)) {
          result.add(url);
        }

        return;
      }

      if (item is Map) {
        const urlKeys = [
          'url',
          'imageUrl',
          'imageURL',
          'downloadURL',
          'downloadUrl',
          'publicUrl',
          'publicURL',
          'image_url',
          'download_url',
          'public_url',
          'path',
        ];

        bool foundUrl = false;

        for (final key in urlKeys) {
          if (item.containsKey(key)) {
            foundUrl = true;
            visit(item[key]);
          }
        }

        if (!foundUrl) {
          for (final nestedValue in item.values) {
            visit(nestedValue);
          }
        }

        return;
      }

      if (item is Iterable && item is! String) {
        for (final child in item) {
          visit(child);
        }
      }
    }

    visit(value);
    return result.toList();
  }

  /// Searches nested plan data for additional image references.
  void _collectNestedImages(dynamic value, Set<String> result) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();

        if (RegExp(
          r'image|design|reference|attachment',
          caseSensitive: false,
        ).hasMatch(key)) {
          result.addAll(_extractImageUrls(entry.value));
        } else {
          _collectNestedImages(entry.value, result);
        }
      }
    } else if (value is Iterable && value is! String) {
      for (final item in value) {
        _collectNestedImages(item, result);
      }
    }
  }

  bool _hasDisplayableValue(dynamic value) {
    if (value == null) return false;

    if (value is String) {
      return value.trim().isNotEmpty;
    }

    if (value is Map) {
      return value.values.any(_hasDisplayableValue);
    }

    if (value is Iterable && value is! String) {
      return value.any(_hasDisplayableValue);
    }

    return true;
  }

  String _readable(dynamic value) {
    if (value == null) return '';

    if (value is Timestamp) {
      return value.toDate().toLocal().toString().split('.').first;
    }

    if (value is DateTime) {
      return value.toLocal().toString().split('.').first;
    }

    if (value is bool) {
      return value ? 'Yes' : 'No';
    }

    if (value is num) {
      return value.toString();
    }

    if (value is Iterable && value is! String) {
      return value
          .where((item) => item != null && item is! Map)
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .map((item) => '• $item')
          .join('\n');
    }

    if (value is Map) return '';

    return value.toString().trim();
  }

  Widget _textSection(String title, IconData icon, dynamic value) {
    final text = _readable(value);

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: _PreviewSection(
        title: title,
        icon: icon,
        child: _DetailParagraph(text: text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _projectDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Unable to load additional project information.',
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;

        // ============================================================
        // 1. DESIGN IMAGES
        // ============================================================

        final imageUrls = <String>{};

        // Exact field used by the existing Client acceptance flow.
        _collectNestedImages(data, imageUrls);

        const legacyImageKeys = [
          'imageUrls',
          'images',
          'uploadedImages',
          'projectImages',
          'referenceImages',
          'designImages',
          'attachments',
          'imageUrl',
          'imageURL',
          'designImageUrl',
          'uploadedImageUrl',
          'referenceImageUrl',
          'coverImageUrl',
        ];

        for (final key in legacyImageKeys) {
          imageUrls.addAll(_extractImageUrls(data[key]));
        }

        // ============================================================
        // 2. ACCEPTED PLAN AND ESTIMATE
        // ============================================================

        final plan = _asMap(data['plan']);

        final estimate = _asMap(data['estimate']).isNotEmpty
            ? _asMap(data['estimate'])
            : _asMap(plan['estimate']);

        // The estimate is shown separately, so do not show it twice
        // inside the complete plan.
        final planDetails = Map<String, dynamic>.from(plan);
        planDetails.remove('estimate');

        final planText = data['plan'] is String
            ? data['plan'].toString().trim()
            : '';

        // ============================================================
        // 3. ADDITIONAL ROOT-LEVEL PROJECT INFORMATION
        // ============================================================

        const excludedKeys = {
          'projectid',
          'clientid',
          'clientuid',
          'developerid',
          'assigneddeveloperid',
          'planid',
          'createdat',
          'updatedat',
          'title',
          'projecttitle',
          'clientname',
          'description',
          'categories',
          'category',
          'requirements',
          'projectrequirements',
          'technologies',
          'suggestedtechnologies',
          'plan',
          'estimate',
          'acceptedscope',
          'budget',
          'budgetmin',
          'budgetmax',
          'amount',
          'currency',
          'duration',
          'projecttype',
          'workmode',
          'skills',
          'applicationscount',
        };

        final additionalData = <String, dynamic>{};

        for (final entry in data.entries) {
          final key = entry.key.toLowerCase();

          if (excludedKeys.contains(key)) continue;

          // Images are displayed in the gallery, not as raw URLs.
          if (RegExp(
            r'image|design|reference|attachment',
            caseSensitive: false,
          ).hasMatch(key)) {
            continue;
          }

          if (!_hasDisplayableValue(entry.value)) continue;

          additionalData[entry.key] = entry.value;
        }

        final hasAcceptedScope = _hasDisplayableValue(data['acceptedScope']);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========================================================
            // 4. CLIENT UPLOADED + AI GENERATED DESIGN IMAGES
            // ========================================================

            if (imageUrls.isNotEmpty) ...[
              _PreviewSection(
                title: 'UI Designs & Project References',
                icon: Icons.photo_library_outlined,
                child: _ProjectDesignGallery(imageUrls: imageUrls.toList()),
              ),
              const SizedBox(height: 22),
            ],

            // ========================================================
            // 5. COMPLETE CLIENT REQUIREMENTS
            // ========================================================
            _textSection(
              'Project Categories',
              Icons.category_outlined,
              data['categories'] ?? data['category'],
            ),

            _textSection(
              'Complete Project Requirements',
              Icons.checklist_rounded,
              data['requirements'] ?? data['projectRequirements'],
            ),

            _textSection(
              'Suggested Technologies',
              Icons.code_rounded,
              data['technologies'] ?? data['suggestedTechnologies'],
            ),

            // ========================================================
            // 6. ACCEPTED SCOPE
            // ========================================================
            if (hasAcceptedScope) ...[
              _CompleteProjectDataTree(
                title: 'Client Accepted Scope',
                icon: Icons.verified_outlined,
                data: {'Accepted Items': data['acceptedScope']},
              ),
              const SizedBox(height: 18),
            ],

            // ========================================================
            // 7. COMPLETE ESTIMATE
            // ========================================================
            if (estimate.isNotEmpty) ...[
              _EstimateHighlights(estimate: estimate),
              const SizedBox(height: 18),

              _CompleteProjectDataTree(
                title: 'Complete Project Estimate',
                icon: Icons.analytics_outlined,
                data: estimate,
              ),
              const SizedBox(height: 20),
            ],

            // ========================================================
            // 8. COMPLETE AI GENERATED PROJECT PLAN
            // ========================================================
            if (planDetails.isNotEmpty) ...[
              _CompleteProjectDataTree(
                title: 'Complete AI Project Plan',
                icon: Icons.account_tree_outlined,
                data: planDetails,
              ),
              const SizedBox(height: 20),
            ],

            // Also support older records where plan was stored as text.
            if (planText.isNotEmpty) ...[
              _textSection(
                'Complete Project Plan',
                Icons.description_outlined,
                planText,
              ),
            ],

            // ========================================================
            // 9. OTHER EXISTING PROJECT INFORMATION
            // ========================================================
            if (additionalData.isNotEmpty) ...[
              _CompleteProjectDataTree(
                title: 'Additional Project Information',
                icon: Icons.info_outline_rounded,
                data: additionalData,
              ),
              const SizedBox(height: 18),
            ],
          ],
        );
      },
    );
  }
}

class _EstimateHighlights extends StatelessWidget {
  const _EstimateHighlights({required this.estimate});

  final Map<String, dynamic> estimate;

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(
        value.replaceAll(',', '').replaceAll('₹', '').trim(),
      );
    }

    return null;
  }

  String _format(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  String _range(dynamic minimum, dynamic maximum, String unit) {
    final min = _number(minimum);
    final max = _number(maximum);

    if (min != null && max != null) {
      return '${_format(min)} – ${_format(max)} $unit';
    }

    if (min != null) return 'From ${_format(min)} $unit';
    if (max != null) return 'Up to ${_format(max)} $unit';

    return '';
  }

  String _cost() {
    final min = _number(estimate['costMinINR']);
    final max = _number(estimate['costMaxINR']);

    final currency = (estimate['currency'] ?? 'INR').toString();
    final symbol = currency.toUpperCase() == 'INR' ? '₹' : '$currency ';

    if (min != null && max != null) {
      return '$symbol${_format(min)} – $symbol${_format(max)}';
    }

    if (min != null) return 'From $symbol${_format(min)}';
    if (max != null) return 'Up to $symbol${_format(max)}';

    return (estimate['costRange'] ?? '').toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final cost = _cost();

    final timeline = _range(
      estimate['timelineMinWeeks'],
      estimate['timelineMaxWeeks'],
      'weeks',
    );

    final effort = _range(
      estimate['effortHoursMin'],
      estimate['effortHoursMax'],
      'hours',
    );

    final metrics = <Map<String, dynamic>>[
      if (cost.isNotEmpty)
        {
          'title': 'Estimated Cost',
          'value': cost,
          'icon': Icons.payments_outlined,
        },
      if (timeline.isNotEmpty)
        {
          'title': 'Timeline',
          'value': timeline,
          'icon': Icons.calendar_month_outlined,
        },
      if (effort.isNotEmpty)
        {
          'title': 'Estimated Effort',
          'value': effort,
          'icon': Icons.schedule_rounded,
        },
    ];

    if (metrics.isEmpty) return const SizedBox.shrink();

    return _PreviewSection(
      title: 'Estimate at a glance',
      icon: Icons.analytics_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 10.0;

          final columns = constraints.maxWidth >= 600
              ? 3
              : constraints.maxWidth >= 350
              ? 2
              : 1;

          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: metrics.map((metric) {
              return Container(
                width: width,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      metric['icon'] as IconData,
                      color: const Color(0xFF4F46E5),
                      size: 20,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      metric['title'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      metric['value'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// RECURSIVE PROJECT DATA VIEWER
//
// Displays nested maps, lists, strings, numbers, dates and booleans.
// This also supports new fields added to the AI plan in the future.
// ===========================================================================

class _CompleteProjectDataTree extends StatelessWidget {
  const _CompleteProjectDataTree({
    required this.title,
    required this.icon,
    required this.data,
  });

  final String title;
  final IconData icon;
  final Map<String, dynamic> data;

  String _label(String value) {
    final spaced = value
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim();

    return spaced
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) {
          if (word.toUpperCase() == 'INR') return 'INR';

          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  String _value(dynamic value) {
    if (value == null) return '';

    if (value is Timestamp) {
      return value.toDate().toLocal().toString().split('.').first;
    }

    if (value is DateTime) {
      return value.toLocal().toString().split('.').first;
    }

    if (value is bool) return value ? 'Yes' : 'No';

    if (value is num) return value.toString();

    return value.toString().trim();
  }

  bool _hasValue(dynamic value) {
    if (value == null) return false;

    if (value is String) return value.trim().isNotEmpty;

    if (value is Map) {
      return value.values.any(_hasValue);
    }

    if (value is Iterable && value is! String) {
      return value.any(_hasValue);
    }

    return true;
  }

  Widget _renderNode(
    BuildContext context,
    String label,
    dynamic value, {
    int depth = 0,
  }) {
    if (!_hasValue(value)) {
      return const SizedBox.shrink();
    }

    // Nested objects: modules, tasks, team roles, risks, phases, etc.
    if (value is Map) {
      final entries = value.entries
          .where((entry) => _hasValue(entry.value))
          .toList();

      return Container(
        width: double.infinity,
        margin: EdgeInsets.only(top: depth == 0 ? 0 : 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: depth == 0 ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _label(label),
              style: TextStyle(
                fontSize: depth == 0 ? 14 : 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF312E81),
              ),
            ),
            const SizedBox(height: 10),
            ...entries.map(
              (entry) => _renderNode(
                context,
                entry.key.toString(),
                entry.value,
                depth: depth + 1,
              ),
            ),
          ],
        ),
      );
    }

    // Lists: requirements, tasks, technologies, phases, etc.
    if (value is Iterable && value is! String) {
      final items = value.toList();

      if (items.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _label(label),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            ...items.asMap().entries.map((entry) {
              final item = entry.value;

              if (item is Map || (item is Iterable && item is! String)) {
                return _renderNode(
                  context,
                  '${_label(label)} ${entry.key + 1}',
                  item,
                  depth: depth + 1,
                );
              }

              final text = _value(item);

              if (text.isEmpty) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(
                        Icons.circle,
                        size: 7,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: _ProjectMarkdown(data: text)),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }

    // Normal values: long descriptions, notes, numbers and booleans.
    final text = _value(value);

    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _label(label),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 5),
          _ProjectMarkdown(data: text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    return _PreviewSection(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.entries.map((entry) {
          return _renderNode(context, entry.key, entry.value);
        }).toList(),
      ),
    );
  }
}

// ===========================================================================
// PROJECT DESIGN GALLERY
//
// Responsive grid. Displays whole images without cropping.
// Tap an image to zoom and inspect it.
// ===========================================================================

class _ProjectDesignGallery extends StatelessWidget {
  const _ProjectDesignGallery({required this.imageUrls});

  final List<String> imageUrls;

  Future<void> _showFullImage(BuildContext context, String url) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);

        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: SizedBox(
            width: size.width * 0.94,
            height: size.height * 0.78,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 5,
                    child: Image.network(
                      url,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: IconButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 560
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: imageUrls.asMap().entries.map((entry) {
            final index = entry.key;
            final url = entry.value;

            return SizedBox(
              width: itemWidth,
              height: 200,
              child: Material(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _showFullImage(context, url),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;

                          return const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4F46E5),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.broken_image_outlined,
                                  size: 34,
                                  color: Color(0xFF6B7280),
                                ),
                                SizedBox(height: 7),
                                Text(
                                  'Image unavailable',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Positioned(
                        left: 9,
                        bottom: 9,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.68),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Design ${index + 1}  •  View',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ===========================================================================
// MARKDOWN RENDERER
//
// Reuses the same Markdown support already used by the Client estimate screen.
// Preserves headings, lists, bold text, links and code blocks.
// ===========================================================================

class _ProjectMarkdown extends StatelessWidget {
  const _ProjectMarkdown({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    if (data.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    const baseStyle = TextStyle(
      color: Color(0xFF4B5563),
      fontSize: 13,
      height: 1.65,
    );

    return MarkdownBody(
      data: data.trim(),
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle,
        h1: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 20,
          height: 1.35,
          fontWeight: FontWeight.w800,
        ),
        h2: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 17,
          height: 1.4,
          fontWeight: FontWeight.w800,
        ),
        h3: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w800,
        ),
        strong: const TextStyle(
          color: Color(0xFF111827),
          fontWeight: FontWeight.w800,
        ),
        listBullet: baseStyle.copyWith(fontWeight: FontWeight.w700),
        blockquote: baseStyle.copyWith(color: Color(0xFF6B7280)),
        code: const TextStyle(
          color: Color(0xFF4F46E5),
          fontSize: 13,
          fontFamily: 'monospace',
          backgroundColor: Color(0xFFF1F5F9),
        ),
        blockquoteDecoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          border: Border(left: BorderSide(color: Color(0xFF4F46E5), width: 3)),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        listIndent: 22,
        blockSpacing: 8,
      ),
    );
  }
}

class _DetailParagraph extends StatelessWidget {
  const _DetailParagraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: _ProjectMarkdown(data: text),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
  const _DetailPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF6366F1)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
      color: active ? const Color(0xFFEEF2FF) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? const Color(0xFFC7D2FE) : const Color(0xFFE5E7EB),
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
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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
      color: active ? const Color(0xFFEEF2FF) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? const Color(0xFFC7D2FE) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? const Color(0xFF4F46E5) : const Color(0xFF4B5563),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7280)),
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
  const _SkillChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(7),
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
  const _TechnologyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE2FF)),
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
  const _SkeletonBox({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFF5),
        borderRadius: BorderRadius.circular(radius),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(height: 40, radius: 10),
          SizedBox(height: 15),
          _SkeletonBox(height: 12, radius: 6),
          SizedBox(height: 8),
          _SkeletonBox(height: 12, radius: 6),
          SizedBox(height: 8),
          _SkeletonBox(height: 12, radius: 6),
          Spacer(),
          _SkeletonBox(height: 34, radius: 10),
        ],
      ),
    );
  }
}
