import 'package:cloud_firestore/cloud_firestore.dart';

class DeveloperRepository {
  const DeveloperRepository({
    required this.id,
    required this.name,
    required this.url,
    required this.description,
    this.technologies = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String url;
  final String description;
  final List<String> technologies;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DeveloperRepository.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final technologies = data['technologies'];

    return DeveloperRepository(
      id: snapshot.id,
      name: data['name']?.toString() ?? '',
      url: data['url']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      technologies: technologies is List
          ? technologies.map((value) => value.toString()).toList()
          : const [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
