
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
    this.role = '',
    this.responsibilities = '',
    this.teamDescription = '',
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

  // Details specific to this invitation.
  final String role;
  final String responsibilities;
  final String teamDescription;

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
      role: data['role'] as String? ?? '',
      responsibilities: data['responsibilities'] as String? ?? '',
      teamDescription: data['teamDescription'] as String? ?? '',
      createdAt: parseDate(data['createdAt']),
      respondedAt: parseDate(data['respondedAt']),
    );
  }

  bool get isPending => status.toLowerCase() == 'pending';
}
