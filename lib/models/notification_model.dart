import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.developerId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.projectId,
    this.applicationId,
    this.createdAt,
  });

  final String id;
  final String developerId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String? projectId;
  final String? applicationId;
  final DateTime? createdAt;

  factory NotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};

    return NotificationModel(
      id: snapshot.id,
      developerId: _stringValue(data['developerId']),
      title: _stringValue(data['title']),
      body: _stringValue(data['body']),
      type: _stringValue(data['type']),
      isRead: _boolValue(data['isRead']),
      projectId: _nullableStringValue(data['projectId']),
      applicationId:
          _nullableStringValue(data['applicationId']),
      createdAt: _dateTimeValue(data['createdAt']),
    );
  }

  factory NotificationModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return NotificationModel(
      id: id,
      developerId: _stringValue(data['developerId']),
      title: _stringValue(data['title']),
      body: _stringValue(data['body']),
      type: _stringValue(data['type']),
      isRead: _boolValue(data['isRead']),
      projectId: _nullableStringValue(data['projectId']),
      applicationId:
          _nullableStringValue(data['applicationId']),
      createdAt: _dateTimeValue(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'developerId': developerId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'projectId': projectId,
      'applicationId': applicationId,
      'createdAt': createdAt,
    };
  }

  NotificationModel copyWith({
    String? developerId,
    String? title,
    String? body,
    String? type,
    bool? isRead,
    String? projectId,
    String? applicationId,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id,
      developerId: developerId ?? this.developerId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      projectId: projectId ?? this.projectId,
      applicationId:
          applicationId ?? this.applicationId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isUnread => !isRead;

  static String _stringValue(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  static String? _nullableStringValue(dynamic value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    if (result.isEmpty) {
      return null;
    }

    return result;
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    return false;
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