import 'package:cloud_firestore/cloud_firestore.dart';

class DeveloperNote {
  final String id;
  final String userId;
  final String title;
  final String category;
  final String content;
  final String? projectId;
  final Map<String, dynamic> details;
  final List<String> tags;
  final bool isPinned;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DeveloperNote({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.content,
    this.projectId,
    this.details = const {},
    this.tags = const [],
    this.isPinned = false,
    this.createdAt,
    this.updatedAt,
  });

  factory DeveloperNote.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return DeveloperNote(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? 'project_idea',
      content: data['content'] as String? ?? '',
      projectId: data['projectId'] as String?,
      details: Map<String, dynamic>.from(data['details'] as Map? ?? {}),
      tags: List<String>.from(data['tags'] as List? ?? []),
      isPinned: data['isPinned'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'category': category,
      'content': content,
      'projectId': projectId,
      'details': details,
      'tags': tags,
      'isPinned': isPinned,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static const String projectIdea = 'project_idea';
  static const String bugSolution = 'bug_solution';
  static const String dailyWork = 'daily_work';

  String get categoryLabel {
    switch (category) {
      case projectIdea:
        return 'Project Ideas';
      case bugSolution:
        return 'Bugs & Solutions';
      case dailyWork:
        return 'Daily Work';
      default:
        return 'Other';
    }
  }
}
