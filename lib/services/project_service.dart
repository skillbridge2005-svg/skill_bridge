import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/project_model.dart';

/// Service responsible for all project-related Firestore operations.
///
/// Firestore structure:
///
/// projects/{projectId}
///
/// savedProjects/{developerUid}/items/{projectId}
///
/// This keeps Firestore logic outside the UI so the Discover Projects screen
/// remains focused on presentation and interaction.
class ProjectService {
  ProjectService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _projectsCollection {
    return _firestore.collection('projects');
  }

  User? get currentUser => _auth.currentUser;

  String? get currentDeveloperId => _auth.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // PROJECT STREAMS
  // ---------------------------------------------------------------------------

  /// Streams all currently open projects.
  ///
  /// Ordered by newest first.
Stream<List<ProjectModel>> watchOpenProjects() {
  return _projectsCollection
      .where(
        'status',
        whereIn: ['open', 'requirement'],
      )
      .snapshots()
      .map(_documentsToProjects);
}

  /// Streams every project.
  ///
  /// Mainly useful for admin/client-side features.
  Stream<List<ProjectModel>> watchAllProjects() {
    return _projectsCollection
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots()
        .map(_documentsToProjects);
  }

  /// Streams one project.
  Stream<ProjectModel?> watchProject(
    String projectId,
  ) {
    return _projectsCollection
        .doc(projectId)
        .snapshots()
        .map(
          (snapshot) {
            if (!snapshot.exists) {
              return null;
            }

            return ProjectModel.fromFirestore(snapshot);
          },
        );
  }

  // ---------------------------------------------------------------------------
  // PROJECT FETCHING
  // ---------------------------------------------------------------------------

  /// Fetches all open projects once.
Future<List<ProjectModel>> getOpenProjects() async {
  final snapshot = await _projectsCollection
      .where(
        'status',
        whereIn: ['open', 'requirement'],
      )
      .get();

  return _documentsToProjects(snapshot);
}
  /// Fetches one project.
  Future<ProjectModel?> getProject(
    String projectId,
  ) async {
    final snapshot = await _projectsCollection
        .doc(projectId)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    return ProjectModel.fromFirestore(snapshot);
  }

  /// Fetches projects created by a particular client.
  Future<List<ProjectModel>> getClientProjects(
    String clientId,
  ) async {
    final snapshot = await _projectsCollection
        .where(
          'clientId',
          isEqualTo: clientId,
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .get();

    return _documentsToProjects(snapshot);
  }

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  /// Searches currently open projects.
  ///
  /// Firestore does not provide a simple contains search across multiple
  /// fields. Therefore this method retrieves the open project set and performs
  /// the multi-field filtering locally.
  ///
  /// This supports searching:
  /// - title
  /// - description
  /// - client name
  /// - skills
  /// - technologies
  /// - project type
  /// - work mode
  /// - duration
  Future<List<ProjectModel>> searchProjects(
    String query,
  ) async {
    final projects = await getOpenProjects();

    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return projects;
    }

    return projects
        .where(
          (project) => project.matchesSearch(
            normalizedQuery,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // FILTERING
  // ---------------------------------------------------------------------------

  /// Applies all common Discover Projects filters locally.
  ///
  /// Keeping this logic here makes the filtering reusable by:
  /// - Discover Projects
  /// - Recommended Projects
  /// - future mobile UI
  /// - future desktop UI
  List<ProjectModel> filterProjects(
    List<ProjectModel> projects, {
    String query = '',
    String? technology,
    String? skill,
    String? workMode,
    String? projectType,
    String? duration,
    double? minimumBudget,
    double? maximumBudget,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedTechnology =
        technology?.trim().toLowerCase();
    final normalizedSkill =
        skill?.trim().toLowerCase();
    final normalizedWorkMode =
        workMode?.trim().toLowerCase();
    final normalizedProjectType =
        projectType?.trim().toLowerCase();
    final normalizedDuration =
        duration?.trim().toLowerCase();

    return projects.where((project) {
      // Search
      if (normalizedQuery.isNotEmpty &&
          !project.matchesSearch(normalizedQuery)) {
        return false;
      }

      // Technology
      if (normalizedTechnology != null &&
          normalizedTechnology.isNotEmpty &&
          !project.technologies.any(
            (item) =>
                item.trim().toLowerCase() ==
                normalizedTechnology,
          )) {
        return false;
      }

      // Skill
      if (normalizedSkill != null &&
          normalizedSkill.isNotEmpty &&
          !project.skills.any(
            (item) =>
                item.trim().toLowerCase() ==
                normalizedSkill,
          )) {
        return false;
      }

      // Work mode
      if (normalizedWorkMode != null &&
          normalizedWorkMode.isNotEmpty &&
          !_matchesFlexibleValue(
            project.workMode,
            normalizedWorkMode,
          )) {
        return false;
      }

      // Project type
      if (normalizedProjectType != null &&
          normalizedProjectType.isNotEmpty &&
          !_matchesFlexibleValue(
            project.projectType,
            normalizedProjectType,
          )) {
        return false;
      }

      // Duration
      if (normalizedDuration != null &&
          normalizedDuration.isNotEmpty &&
          !_matchesFlexibleValue(
            project.duration,
            normalizedDuration,
          )) {
        return false;
      }

      // Budget
      final projectMin = project.effectiveBudgetMin;
      final projectMax = project.effectiveBudgetMax;

      if (minimumBudget != null &&
          projectMax > 0 &&
          projectMax < minimumBudget) {
        return false;
      }

      if (maximumBudget != null &&
          projectMin > 0 &&
          projectMin > maximumBudget) {
        return false;
      }

      return true;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // SORTING
  // ---------------------------------------------------------------------------

  /// Sorts projects locally.
  ///
  /// Supported values:
  /// - newest
  /// - oldest
  /// - budget_high
  /// - budget_low
  /// - applications_low
  List<ProjectModel> sortProjects(
    List<ProjectModel> projects, {
    String sortBy = 'newest',
  }) {
    final sorted = List<ProjectModel>.from(projects);

    switch (sortBy) {
      case 'oldest':
        sorted.sort(
          (a, b) => _dateCompare(
            a.createdAt,
            b.createdAt,
          ),
        );
        break;

      case 'budget_high':
        sorted.sort(
          (a, b) => b.effectiveBudgetMax.compareTo(
            a.effectiveBudgetMax,
          ),
        );
        break;

      case 'budget_low':
        sorted.sort(
          (a, b) => a.effectiveBudgetMin.compareTo(
            b.effectiveBudgetMin,
          ),
        );
        break;

      case 'applications_low':
        sorted.sort(
          (a, b) => a.applicationsCount.compareTo(
            b.applicationsCount,
          ),
        );
        break;

      case 'newest':
      default:
        sorted.sort(
          (a, b) => _dateCompare(
            b.createdAt,
            a.createdAt,
          ),
        );
        break;
    }

    return sorted;
  }

  // ---------------------------------------------------------------------------
  // RECOMMENDATIONS
  // ---------------------------------------------------------------------------

  /// Generates deterministic recommendations using the developer profile.
  ///
  /// Matching weights are implemented inside ProjectModel:
  ///
  /// Skills       40%
  /// Technologies 30%
  /// Project Type 10%
  /// Work Mode    10%
  /// Duration     10%
  ///
  /// Returns projects with their calculated score.
  List<ProjectRecommendation> getRecommendedProjects(
    List<ProjectModel> projects, {
    List<String> developerSkills = const [],
    List<String> developerTechnologies = const [],
    String? developerProjectType,
    String? developerWorkMode,
    String? developerDuration,
    int minimumScore = 20,
    int limit = 10,
  }) {
    final recommendations = <ProjectRecommendation>[];

    for (final project in projects) {
      if (!project.isOpen) {
        continue;
      }

      final score = project.getMatchPercentage(
        developerSkills: developerSkills,
        developerTechnologies: developerTechnologies,
        developerProjectType: developerProjectType,
        developerWorkMode: developerWorkMode,
        developerDuration: developerDuration,
      );

      if (score >= minimumScore) {
        recommendations.add(
          ProjectRecommendation(
            project: project,
            matchPercentage: score,
          ),
        );
      }
    }

    recommendations.sort(
      (a, b) => b.matchPercentage.compareTo(
        a.matchPercentage,
      ),
    );

    if (recommendations.length > limit) {
      return recommendations.take(limit).toList();
    }

    return recommendations;
  }

  // ---------------------------------------------------------------------------
  // SAVED PROJECTS
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>>
      _savedProjectsCollection(
    String developerId,
  ) {
    return _firestore
        .collection('savedProjects')
        .doc(developerId)
        .collection('items');
  }

  /// Saves a project for the currently logged-in developer.
  Future<void> saveProject(
    String projectId,
  ) async {
    final developerId = _requireDeveloper();

    await _savedProjectsCollection(
      developerId,
    ).doc(projectId).set({
      'projectId': projectId,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes a project from saved projects.
  Future<void> unsaveProject(
    String projectId,
  ) async {
    final developerId = _requireDeveloper();

    await _savedProjectsCollection(
      developerId,
    ).doc(projectId).delete();
  }

  /// Checks whether the current developer saved a project.
  Future<bool> isProjectSaved(
    String projectId,
  ) async {
    final developerId = currentDeveloperId;

    if (developerId == null) {
      return false;
    }

    final snapshot = await _savedProjectsCollection(
      developerId,
    ).doc(projectId).get();

    return snapshot.exists;
  }

  /// Streams whether a project is saved.
  Stream<bool> watchProjectSaved(
    String projectId,
  ) {
    final developerId = currentDeveloperId;

    if (developerId == null) {
      return Stream<bool>.value(false);
    }

    return _savedProjectsCollection(
      developerId,
    ).doc(projectId).snapshots().map(
          (snapshot) => snapshot.exists,
        );
  }

  /// Streams all saved project IDs.
  Stream<Set<String>> watchSavedProjectIds() {
    final developerId = currentDeveloperId;

    if (developerId == null) {
      return Stream<Set<String>>.value(<String>{});
    }

    return _savedProjectsCollection(
      developerId,
    ).snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => doc.id,
              )
              .toSet(),
        );
  }

  /// Gets saved project IDs once.
  Future<Set<String>> getSavedProjectIds() async {
    final developerId = _requireDeveloper();

    final snapshot = await _savedProjectsCollection(
      developerId,
    ).get();

    return snapshot.docs
        .map((doc) => doc.id)
        .toSet();
  }

  /// Gets the complete saved ProjectModel objects.
  Future<List<ProjectModel>> getSavedProjects() async {
    final ids = await getSavedProjectIds();

    if (ids.isEmpty) {
      return [];
    }

    final projects = <ProjectModel>[];

    // Firestore whereIn has a limit, so process IDs in chunks.
    final chunks = _chunkList(
      ids.toList(),
      30,
    );

    for (final chunk in chunks) {
      final snapshot = await _projectsCollection
          .where(
            FieldPath.documentId,
            whereIn: chunk,
          )
          .get();

      projects.addAll(
        _documentsToProjects(snapshot),
      );
    }

    projects.sort(
      (a, b) => _dateCompare(
        b.createdAt,
        a.createdAt,
      ),
    );

    return projects;
  }

  // ---------------------------------------------------------------------------
  // PROJECT CREATION
  // ---------------------------------------------------------------------------

  /// Creates a new project.
  ///
  /// This method is included now so the same model/service layer can later
  /// be used by the client-side project posting screen.
  Future<String> createProject({
    required String title,
    required String description,
    required String clientId,
    required String clientName,
    required List<String> skills,
    List<String> technologies = const [],
    double budget = 0,
    double budgetMin = 0,
    double budgetMax = 0,
    required String duration,
    required String projectType,
    required String workMode,
  }) async {
    if (title.trim().isEmpty) {
      throw const ProjectServiceException(
        'Project title cannot be empty.',
      );
    }

    if (description.trim().isEmpty) {
      throw const ProjectServiceException(
        'Project description cannot be empty.',
      );
    }

    if (clientId.trim().isEmpty) {
      throw const ProjectServiceException(
        'Client ID cannot be empty.',
      );
    }

    if (skills.isEmpty) {
      throw const ProjectServiceException(
        'At least one required skill is needed.',
      );
    }

    final now = FieldValue.serverTimestamp();

    final document = await _projectsCollection.add({
      'title': title.trim(),
      'description': description.trim(),
      'clientId': clientId.trim(),
      'clientName': clientName.trim(),
      'skills': _cleanList(skills),
      'technologies': _cleanList(technologies),
      'budget': budget,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'duration': duration.trim(),
      'projectType': projectType.trim(),
      'workMode': workMode.trim(),
      'status': 'open',
      'applicationsCount': 0,
      'createdAt': now,
      'updatedAt': now,
    });

    return document.id;
  }

  // ---------------------------------------------------------------------------
  // PROJECT UPDATES
  // ---------------------------------------------------------------------------

  /// Updates selected project fields.
  Future<void> updateProject(
    String projectId,
    Map<String, dynamic> updates,
  ) async {
    if (projectId.trim().isEmpty) {
      throw const ProjectServiceException(
        'Project ID cannot be empty.',
      );
    }

    if (updates.isEmpty) {
      return;
    }

    final safeUpdates = Map<String, dynamic>.from(
      updates,
    );

    safeUpdates['updatedAt'] =
        FieldValue.serverTimestamp();

    await _projectsCollection
        .doc(projectId)
        .update(safeUpdates);
  }

  /// Changes the status of a project.
  Future<void> updateProjectStatus(
    String projectId,
    String status,
  ) async {
    final normalizedStatus = status.trim().toLowerCase();

    const validStatuses = {
      'open',
      'in_review',
      'assigned',
      'completed',
      'closed',
    };

    if (!validStatuses.contains(normalizedStatus)) {
      throw ProjectServiceException(
        'Invalid project status: $status',
      );
    }

    await updateProject(
      projectId,
      {
        'status': normalizedStatus,
      },
    );
  }

  /// Deletes a project.
  ///
  /// Application/saved-project cleanup can be handled separately when those
  /// features are implemented.
  Future<void> deleteProject(
    String projectId,
  ) async {
    if (projectId.trim().isEmpty) {
      throw const ProjectServiceException(
        'Project ID cannot be empty.',
      );
    }

    await _projectsCollection
        .doc(projectId)
        .delete();
  }

  // ---------------------------------------------------------------------------
  // APPLICATION SUPPORT
  // ---------------------------------------------------------------------------

  /// Checks whether the current developer has already applied to a project.
  ///
  /// This uses the future applications collection:
  ///
  /// applications/{applicationId}
  ///
  /// The Discover/Apply implementation can use this before creating an
  /// application to prevent duplicates.
  Future<bool> hasAppliedToProject(
    String projectId,
  ) async {
    final developerId = currentDeveloperId;

    if (developerId == null) {
      return false;
    }

    final snapshot = await _firestore
        .collection('applications')
        .where(
          'developerId',
          isEqualTo: developerId,
        )
        .where(
          'projectId',
          isEqualTo: projectId,
        )
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Returns the number of applications currently stored for a project.
  Future<int> getApplicationCount(
    String projectId,
  ) async {
    final snapshot = await _firestore
        .collection('applications')
        .where(
          'projectId',
          isEqualTo: projectId,
        )
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

List<ProjectModel> _documentsToProjects(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  return snapshot.docs
      .map(ProjectModel.fromFirestore)
      .toList();
}

  DateTime _safeDate(
    DateTime? date,
  ) {
    return date ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _dateCompare(
    DateTime? first,
    DateTime? second,
  ) {
    return _safeDate(first).compareTo(
      _safeDate(second),
    );
  }

  bool _matchesFlexibleValue(
    String projectValue,
    String requestedValue,
  ) {
    final project = projectValue.trim().toLowerCase();
    final requested = requestedValue.trim().toLowerCase();

    if (project == requested) {
      return true;
    }

    if (project.contains(requested) ||
        requested.contains(project)) {
      return true;
    }

    if (project == 'both' ||
        project == 'any' ||
        project == 'flexible') {
      return true;
    }

    return false;
  }

  List<String> _cleanList(
    List<String> values,
  ) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  List<List<T>> _chunkList<T>(
    List<T> items,
    int size,
  ) {
    final chunks = <List<T>>[];

    for (var i = 0; i < items.length; i += size) {
      final end = (i + size < items.length)
          ? i + size
          : items.length;

      chunks.add(
        items.sublist(i, end),
      );
    }

    return chunks;
  }

  String _requireDeveloper() {
    final uid = currentDeveloperId;

    if (uid == null || uid.trim().isEmpty) {
      throw const ProjectServiceException(
        'You must be logged in as a developer to use this feature.',
      );
    }

    return uid;
  }
}

/// Represents a project together with its calculated recommendation score.
class ProjectRecommendation {
  final ProjectModel project;
  final int matchPercentage;

  const ProjectRecommendation({
    required this.project,
    required this.matchPercentage,
  });

  /// Convenience getter for UI.
  String get matchLabel => '$matchPercentage% Match';
}

/// Custom exception used by ProjectService.
class ProjectServiceException implements Exception {
  final String message;

  const ProjectServiceException(this.message);

  @override
  String toString() {
    return 'ProjectServiceException: $message';
  }
}