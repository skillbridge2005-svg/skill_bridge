
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamInvitationModel {
  const TeamInvitationModel({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.projectTitle,
    required this.senderId,
    required this.recipientId,
    required this.status,
    this.createdAt,
    this.respondedAt,
  });

  final String id;
  final String teamId;
  final String teamName;
  final String projectTitle;
  final String senderId;
  final String recipientId;
  final String status;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  factory TeamInvitationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return TeamInvitationModel(
      id: snapshot.id,
      teamId: data['teamId'] as String? ?? '',
      teamName: data['teamName'] as String? ?? '',
      projectTitle: data['projectTitle'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      recipientId: data['recipientId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: parseDate(data['createdAt']),
      respondedAt: parseDate(data['respondedAt']),
    );
  }

  bool get isPending => status == 'pending';
}
