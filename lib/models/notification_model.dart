import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  const NotificationModel({
    required this.id,
    String? recipientId,
    String? developerId,
    this.recipientRole = 'user',
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.isDismissed = false,
    this.projectId,
    this.projectTitle,
    this.applicationId,
    this.meetingId,
    this.teamId,
    this.chatId,
    this.otherUid,
    this.otherName,
    this.createdAt,
  }) : recipientId = recipientId ?? developerId ?? '';

  final String id;

  /// UID of the person receiving this notification.
  final String recipientId;

  /// Expected values: client, developer, or user for legacy records.
  final String recipientRole;

  /// Backward compatibility for existing developer-side code.
  @Deprecated('Use recipientId instead.')
  String get developerId => recipientId;

  final String title;
  final String body;
  final String type;
  final bool isRead;
  final bool isDismissed;

  final String? projectId;
  final String? projectTitle;
  final String? applicationId;
  final String? meetingId;
  final String? teamId;
  final String? chatId;
  final String? otherUid;
  final String? otherName;

  final DateTime? createdAt;

  factory NotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};

    return NotificationModel.fromMap(snapshot.id, data);
  }

  factory NotificationModel.fromMap(String id, Map<String, dynamic> data) {
    final legacyDeveloperId = _nullableStringValue(data['developerId']);

    return NotificationModel(
      id: id,

      // Prefer the new shared schema, then fall back to old records.
      recipientId:
          _nullableStringValue(data['recipientId']) ?? legacyDeveloperId ?? '',

      recipientRole:
          _nullableStringValue(data['recipientRole']) ??
          (legacyDeveloperId != null ? 'developer' : 'user'),

      title: _stringValue(data['title']),
      body: _stringValue(data['body'] ?? data['message']),
      type: _stringValue(data['type']),
      isRead: _boolValue(data['isRead']),
      isDismissed: _boolValue(data['isDismissed']),

      projectId: _nullableStringValue(data['projectId']),
      projectTitle: _nullableStringValue(data['projectTitle']),
      applicationId: _nullableStringValue(data['applicationId']),
      meetingId: _nullableStringValue(data['meetingId']),
      teamId: _nullableStringValue(data['teamId']),
      chatId: _nullableStringValue(data['chatId']),
      otherUid: _nullableStringValue(data['otherUid']),
      otherName: _nullableStringValue(data['otherName']),

      createdAt: _dateTimeValue(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientId': recipientId,
      'recipientRole': recipientRole,

      // Retained while old queries use developerId.
      'developerId': recipientId,

      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'isDismissed': isDismissed,

      'projectId': projectId,
      'projectTitle': projectTitle,
      'applicationId': applicationId,
      'meetingId': meetingId,
      'teamId': teamId,
      'chatId': chatId,
      'otherUid': otherUid,
      'otherName': otherName,

      'createdAt': createdAt,
    };
  }

  NotificationModel copyWith({
    String? recipientId,
    String? recipientRole,
    String? developerId,
    String? title,
    String? body,
    String? type,
    bool? isRead,
    bool? isDismissed,
    String? projectId,
    String? projectTitle,
    String? applicationId,
    String? meetingId,
    String? teamId,
    String? chatId,
    String? otherUid,
    String? otherName,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id,
      recipientId: recipientId ?? developerId ?? this.recipientId,
      recipientRole: recipientRole ?? this.recipientRole,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
      projectId: projectId ?? this.projectId,
      projectTitle: projectTitle ?? this.projectTitle,
      applicationId: applicationId ?? this.applicationId,
      meetingId: meetingId ?? this.meetingId,
      teamId: teamId ?? this.teamId,
      chatId: chatId ?? this.chatId,
      otherUid: otherUid ?? this.otherUid,
      otherName: otherName ?? this.otherName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isUnread => !isRead;

  static String _stringValue(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String? _nullableStringValue(dynamic value) {
    if (value == null) return null;

    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    if (value is String) {
      return value.toLowerCase().trim() == 'true';
    }

    return false;
  }

  static DateTime? _dateTimeValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
