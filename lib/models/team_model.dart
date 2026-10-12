import 'package:cloud_firestore/cloud_firestore.dart';

class TeamModel {
  const TeamModel({
    required this.id,
    required this.name,
    required this.projectId,
    required this.projectTitle,
    required this.ownerId,
    required this.memberIds,
    required this.status,
    this.description = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String projectId;
  final String projectTitle;
  final String ownerId;
  final List<String> memberIds;
  final String status;
  final String description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TeamModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};

    return TeamModel(
      id: snapshot.id,
      name: _stringValue(data['name']),
      projectId: _stringValue(data['projectId']),
      projectTitle: _stringValue(data['projectTitle']),
      ownerId: _stringValue(data['ownerId']),
      memberIds: _stringList(data['memberIds']),
      status: _stringValue(
        data['status'],
        fallback: 'active',
      ),
      description: _stringValue(data['description']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
    );
  }

  factory TeamModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return TeamModel(
      id: id,
      name: _stringValue(data['name']),
      projectId: _stringValue(data['projectId']),
      projectTitle: _stringValue(data['projectTitle']),
      ownerId: _stringValue(data['ownerId']),
      memberIds: _stringList(data['memberIds']),
      status: _stringValue(
        data['status'],
        fallback: 'active',
      ),
      description: _stringValue(data['description']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'projectId': projectId,
      'projectTitle': projectTitle,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'status': status,
      'description': description,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  TeamModel copyWith({
    String? name,
    String? projectId,
    String? projectTitle,
    String? ownerId,
    List<String>? memberIds,
    String? status,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeamModel(
      id: id,
      name: name ?? this.name,
      projectId: projectId ?? this.projectId,
      projectTitle: projectTitle ?? this.projectTitle,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isActive =>
      status.trim().toLowerCase() == 'active';

  int get memberCount => memberIds.length;

  static String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    return value.toString().trim();
  }

  static List<String> _stringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
    }

    return <String>[];
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
}