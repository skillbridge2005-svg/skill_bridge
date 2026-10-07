import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a project posted by a client on SkillBridge.
///
/// Firestore collection:
///     projects/{projectId}
///
/// This model intentionally keeps all project-related data in one place so
/// that the Discover Projects screen, project details screen, application
/// flow, recommendations and saved-project system can use the same object.
class ProjectModel {
  final String id;
  final String title;
  final String description;

  final String clientId;
  final String clientName;

  final List<String> skills;
  final List<String> technologies;

  final double budget;
  final double budgetMin;
  final double budgetMax;

  final String duration;
  final String projectType;
  final String workMode;

  final String status;

  final int applicationsCount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.clientId,
    required this.clientName,
    required this.skills,
    required this.technologies,
    required this.budget,
    required this.budgetMin,
    required this.budgetMax,
    required this.duration,
    required this.projectType,
    required this.workMode,
    required this.status,
    required this.applicationsCount,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a ProjectModel from a Firestore document.
  factory ProjectModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};

    return ProjectModel(
      id: snapshot.id,
      title: _stringValue(data['title']),
      description: _stringValue(data['description']),
      clientId: _stringValue(data['clientId']),
      clientName: _stringValue(data['clientName']),
      skills: _stringList(data['skills']),
      technologies: _stringList(data['technologies']),
      budget: _doubleValue(data['budget']),
      budgetMin: _doubleValue(data['budgetMin']),
      budgetMax: _doubleValue(data['budgetMax']),
      duration: _stringValue(data['duration']),
      projectType: _stringValue(data['projectType']),
      workMode: _stringValue(data['workMode']),
      status: _stringValue(
        data['status'],
        fallback: 'open',
      ),
      applicationsCount: _intValue(data['applicationsCount']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
    );
  }

  /// Creates a ProjectModel from a normal Map.
  ///
  /// Useful when working with locally generated data or when a map has
  /// already been obtained from Firestore.
  factory ProjectModel.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    return ProjectModel(
      id: id,
      title: _stringValue(data['title']),
      description: _stringValue(data['description']),
      clientId: _stringValue(data['clientId']),
      clientName: _stringValue(data['clientName']),
      skills: _stringList(data['skills']),
      technologies: _stringList(data['technologies']),
      budget: _doubleValue(data['budget']),
      budgetMin: _doubleValue(data['budgetMin']),
      budgetMax: _doubleValue(data['budgetMax']),
      duration: _stringValue(data['duration']),
      projectType: _stringValue(data['projectType']),
      workMode: _stringValue(data['workMode']),
      status: _stringValue(
        data['status'],
        fallback: 'open',
      ),
      applicationsCount: _intValue(data['applicationsCount']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
    );
  }

  /// Converts the model into a Firestore-compatible map.
  ///
  /// The ID is intentionally not included because Firestore uses the
  /// document ID separately.
  Map<String, dynamic> toMap({
    bool includeTimestamps = true,
  }) {
    final map = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'clientId': clientId.trim(),
      'clientName': clientName.trim(),
      'skills': skills,
      'technologies': technologies,
      'budget': budget,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'duration': duration.trim(),
      'projectType': projectType.trim(),
      'workMode': workMode.trim(),
      'status': status.trim().isEmpty ? 'open' : status.trim(),
      'applicationsCount': applicationsCount,
    };

    if (includeTimestamps) {
      if (createdAt != null) {
        map['createdAt'] = Timestamp.fromDate(createdAt!);
      }

      if (updatedAt != null) {
        map['updatedAt'] = Timestamp.fromDate(updatedAt!);
      }
    }

    return map;
  }

  /// Creates a copy with selected fields changed.
  ProjectModel copyWith({
    String? id,
    String? title,
    String? description,
    String? clientId,
    String? clientName,
    List<String>? skills,
    List<String>? technologies,
    double? budget,
    double? budgetMin,
    double? budgetMax,
    String? duration,
    String? projectType,
    String? workMode,
    String? status,
    int? applicationsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      skills: skills ?? List<String>.from(this.skills),
      technologies: technologies ?? List<String>.from(this.technologies),
      budget: budget ?? this.budget,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      duration: duration ?? this.duration,
      projectType: projectType ?? this.projectType,
      workMode: workMode ?? this.workMode,
      status: status ?? this.status,
      applicationsCount: applicationsCount ?? this.applicationsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Whether this project is currently open for applications.
bool get isOpen {
  final normalizedStatus = status.trim().toLowerCase();

  return normalizedStatus == 'open' ||
      normalizedStatus == 'requirement';
}

  /// Whether the project has a defined budget range.
  bool get hasBudgetRange =>
      budgetMin > 0 || budgetMax > 0;

  /// Returns the effective minimum budget.
  double get effectiveBudgetMin {
    if (budgetMin > 0) return budgetMin;
    if (budget > 0) return budget;
    return 0;
  }

  /// Returns the effective maximum budget.
  double get effectiveBudgetMax {
    if (budgetMax > 0) return budgetMax;
    if (budget > 0) return budget;
    return 0;
  }

  /// Returns all searchable technologies and skills.
  List<String> get searchableKeywords {
    return {
      ...skills.map((e) => e.toLowerCase().trim()),
      ...technologies.map((e) => e.toLowerCase().trim()),
    }.where((e) => e.isNotEmpty).toList();
  }

  /// Simple local search matching.
  ///
  /// The service layer can use this when Firestore cannot perform the
  /// requested multi-field search directly.
  bool matchesSearch(String query) {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return true;
    }

    final searchableText = [
      title,
      description,
      clientName,
      projectType,
      workMode,
      duration,
      ...skills,
      ...technologies,
    ].join(' ').toLowerCase();

    return searchableText.contains(normalizedQuery);
  }

  /// Calculates a deterministic recommendation score against a developer
  /// profile.
  ///
  /// Weighting:
  /// Skills        = 40%
  /// Technologies  = 30%
  /// Project Type  = 10%
  /// Work Mode     = 10%
  /// Duration      = 10%
  ///
  /// No AI/API is required for this first version.
  double calculateMatchScore({
    List<String> developerSkills = const [],
    List<String> developerTechnologies = const [],
    String? developerProjectType,
    String? developerWorkMode,
    String? developerDuration,
  }) {
    final projectSkills = _normalizeList(skills);
    final projectTechnologies = _normalizeList(technologies);

    final userSkills = _normalizeList(developerSkills);
    final userTechnologies = _normalizeList(developerTechnologies);

    final skillScore = _overlapPercentage(
      userSkills,
      projectSkills,
    );

    final technologyScore = _overlapPercentage(
      userTechnologies,
      projectTechnologies,
    );

    final projectTypeScore = _textMatchScore(
      developerProjectType,
      projectType,
    );

    final workModeScore = _textMatchScore(
      developerWorkMode,
      workMode,
    );

    final durationScore = _textMatchScore(
      developerDuration,
      duration,
    );

    final score =
        (skillScore * 0.40) +
        (technologyScore * 0.30) +
        (projectTypeScore * 0.10) +
        (workModeScore * 0.10) +
        (durationScore * 0.10);

    return score.clamp(0, 100).toDouble();
  }

  /// Returns a whole-number match percentage.
  int getMatchPercentage({
    List<String> developerSkills = const [],
    List<String> developerTechnologies = const [],
    String? developerProjectType,
    String? developerWorkMode,
    String? developerDuration,
  }) {
    return calculateMatchScore(
      developerSkills: developerSkills,
      developerTechnologies: developerTechnologies,
      developerProjectType: developerProjectType,
      developerWorkMode: developerWorkMode,
      developerDuration: developerDuration,
    ).round();
  }

  static List<String> _normalizeList(
    List<String> values,
  ) {
    return values
        .map(
          (value) => value
              .trim()
              .toLowerCase(),
        )
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  static double _overlapPercentage(
    List<String> first,
    List<String> second,
  ) {
    if (second.isEmpty) {
      return 0;
    }

    if (first.isEmpty) {
      return 0;
    }

    final firstSet = first.toSet();
    final secondSet = second.toSet();

    final matches = secondSet
        .where(firstSet.contains)
        .length;

    return (matches / secondSet.length) * 100;
  }

  static double _textMatchScore(
    String? developerValue,
    String projectValue,
  ) {
    if (developerValue == null ||
        developerValue.trim().isEmpty ||
        projectValue.trim().isEmpty) {
      return 0;
    }

    final developer = developerValue
        .trim()
        .toLowerCase();

    final project = projectValue
        .trim()
        .toLowerCase();

    if (developer == project) {
      return 100;
    }

    if (developer.contains(project) ||
        project.contains(developer)) {
      return 75;
    }

    // Handle common "Both" / "Any" style preferences.
    if (developer == 'both' ||
        developer == 'any' ||
        developer == 'flexible') {
      return 100;
    }

    return 0;
  }

  static String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    return value.toString();
  }

  static List<String> _stringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
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

  static double _doubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }

  static int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  static DateTime? _dateTimeValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  @override
  String toString() {
    return 'ProjectModel('
        'id: $id, '
        'title: $title, '
        'clientId: $clientId, '
        'status: $status'
        ')';
  }
}