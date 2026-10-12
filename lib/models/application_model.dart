import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a developer's application to a SkillBridge project.
///
/// Firestore structure:
///
/// applications/{applicationId}
///   developerId
///   projectId
///   clientId
///   coverLetter
///   proposedBudget
///   estimatedDuration
///   status
///   createdAt
///   updatedAt
class ApplicationModel {
  final String id;
  final String developerId;
  final String projectId;
  final String clientId;

  final String coverLetter;
  final double proposedBudget;
  final String estimatedDuration;

  final String status;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ApplicationModel({
    required this.id,
    required this.developerId,
    required this.projectId,
    required this.clientId,
    required this.coverLetter,
    required this.proposedBudget,
    required this.estimatedDuration,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates an ApplicationModel from a Firestore document.
  factory ApplicationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};

    return ApplicationModel(
      id: snapshot.id,
      developerId: _stringValue(data['developerId']),
      projectId: _stringValue(data['projectId']),
      clientId: _stringValue(data['clientId']),
      coverLetter: _stringValue(data['coverLetter']),
      proposedBudget: _doubleValue(data['proposedBudget']),
      estimatedDuration: _stringValue(data['estimatedDuration']),
      status: _stringValue(
        data['status'],
        fallback: 'pending',
      ),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
    );
  }

  /// Creates an ApplicationModel from a normal map.
  factory ApplicationModel.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    return ApplicationModel(
      id: id,
      developerId: _stringValue(data['developerId']),
      projectId: _stringValue(data['projectId']),
      clientId: _stringValue(data['clientId']),
      coverLetter: _stringValue(data['coverLetter']),
      proposedBudget: _doubleValue(data['proposedBudget']),
      estimatedDuration: _stringValue(data['estimatedDuration']),
      status: _stringValue(
        data['status'],
        fallback: 'pending',
      ),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
    );
  }

  /// Converts the model into a Firestore-compatible map.
  Map<String, dynamic> toMap({
    bool includeTimestamps = true,
  }) {
    final map = <String, dynamic>{
      'developerId': developerId.trim(),
      'projectId': projectId.trim(),
      'clientId': clientId.trim(),
      'coverLetter': coverLetter.trim(),
      'proposedBudget': proposedBudget,
      'estimatedDuration': estimatedDuration.trim(),
      'status': status.trim().isEmpty
          ? 'pending'
          : status.trim().toLowerCase(),
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
  ApplicationModel copyWith({
    String? id,
    String? developerId,
    String? projectId,
    String? clientId,
    String? coverLetter,
    double? proposedBudget,
    String? estimatedDuration,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApplicationModel(
      id: id ?? this.id,
      developerId: developerId ?? this.developerId,
      projectId: projectId ?? this.projectId,
      clientId: clientId ?? this.clientId,
      coverLetter: coverLetter ?? this.coverLetter,
      proposedBudget: proposedBudget ?? this.proposedBudget,
      estimatedDuration:
          estimatedDuration ?? this.estimatedDuration,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => status.toLowerCase() == 'pending';

  bool get isShortlisted =>
      status.toLowerCase() == 'shortlisted';

  bool get isRejected => status.toLowerCase() == 'rejected';

  bool get isAccepted => status.toLowerCase() == 'accepted';

  bool get isWithdrawn => status.toLowerCase() == 'withdrawn';

  bool get canWithdraw => isPending || isShortlisted;

  @override
  String toString() {
    return 'ApplicationModel('
        'id: $id, '
        'developerId: $developerId, '
        'projectId: $projectId, '
        'clientId: $clientId, '
        'status: $status'
        ')';
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

  static double _doubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
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
}