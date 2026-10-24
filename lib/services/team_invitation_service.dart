
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/team_invitation_model.dart';

class TeamInvitationService {
  TeamInvitationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _invitations =>
      _firestore.collection('teamInvitations');

  CollectionReference<Map<String, dynamic>> get _teams =>
      _firestore.collection('teams');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  String get _currentUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      throw Exception('Please sign in to continue.');
    }
    return uid;
  }

  // ---------------------------------------------------------------------------
  // RECEIVED INVITATIONS
  // ---------------------------------------------------------------------------

  Stream<List<TeamInvitationModel>> watchReceivedInvitations() {
    final uid = _currentUid;

    return _invitations
        .where('recipientId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final invitations = snapshot.docs
          .map(TeamInvitationModel.fromFirestore)
          .toList();

      invitations.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      return invitations;
    });
  }

  // ---------------------------------------------------------------------------
  // SENT INVITATIONS
  // ---------------------------------------------------------------------------

  Stream<List<TeamInvitationModel>> watchSentInvitations(
    String teamId,
  ) {
    final uid = _currentUid;

    return _invitations
        .where('teamId', isEqualTo: teamId)
        .where('senderId', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(TeamInvitationModel.fromFirestore)
              .toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // SEND INVITATION + NOTIFY RECIPIENT
  // ---------------------------------------------------------------------------

  Future<String> sendInvitation({
    required String teamId,
    required String developerId,
  }) async {
    final uid = _currentUid;

    if (teamId.trim().isEmpty) {
      throw Exception('Team ID cannot be empty.');
    }

    if (developerId.trim().isEmpty || developerId == uid) {
      throw Exception('Select another valid developer.');
    }

    final teamRef = _teams.doc(teamId);
    final teamSnapshot = await teamRef.get();

    if (!teamSnapshot.exists) {
      throw Exception('Team not found.');
    }

    final team = teamSnapshot.data()!;

    if (team['ownerId'] != uid) {
      throw Exception('Only the team owner can invite developers.');
    }

    if (team['status'] != 'active') {
      throw Exception('Only active teams can invite developers.');
    }

    final members = List<String>.from(team['memberIds'] ?? []);

    if (members.contains(developerId)) {
      throw Exception('This developer is already a team member.');
    }

    final existing = await _invitations
        .where('teamId', isEqualTo: teamId)
        .where('recipientId', isEqualTo: developerId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('An invitation is already pending.');
    }

    final invitationRef = _invitations.doc();
    final notificationRef = _notifications.doc();

    final teamName = (team['name'] ?? 'a team').toString();
    final projectTitle = (team['projectTitle'] ?? '').toString();

    // Commit the invitation and its notification together.
    final batch = _firestore.batch();

    batch.set(invitationRef, {
      'teamId': teamId,
      'teamName': teamName,
      'projectTitle': projectTitle,
      'senderId': uid,
      'recipientId': developerId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
    });

    batch.set(notificationRef, {
      'developerId': developerId,
      'title': 'New team invitation',
      'body': projectTitle.trim().isEmpty
          ? 'You have been invited to join "$teamName".'
          : 'You have been invited to join "$teamName" for "$projectTitle".',
      'type': 'team_invitation',
      'isRead': false,
      'projectId': team['projectId']?.toString(),
      'applicationId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return invitationRef.id;
  }

  // ---------------------------------------------------------------------------
  // ACCEPT INVITATION + NOTIFY TEAM OWNER
  // ---------------------------------------------------------------------------

  Future<void> acceptInvitation(String invitationId) async {
    final uid = _currentUid;
    final invitationRef = _invitations.doc(invitationId);
    final notificationRef = _notifications.doc();

    await _firestore.runTransaction((transaction) async {
      final invitationSnapshot = await transaction.get(invitationRef);

      if (!invitationSnapshot.exists) {
        throw Exception('Invitation not found.');
      }

      final invitation = invitationSnapshot.data()!;

      if (invitation['recipientId'] != uid) {
        throw Exception('This invitation belongs to another developer.');
      }

      if (invitation['status'] != 'pending') {
        throw Exception('This invitation has already been processed.');
      }

      final teamId = invitation['teamId'] as String?;
      if (teamId == null || teamId.isEmpty) {
        throw Exception('Invalid team invitation.');
      }

      final senderId = invitation['senderId']?.toString() ?? '';
      if (senderId.isEmpty) {
        throw Exception('The invitation has no valid team owner.');
      }

      final teamRef = _teams.doc(teamId);
      final teamSnapshot = await transaction.get(teamRef);

      if (!teamSnapshot.exists) {
        throw Exception('The team no longer exists.');
      }

      final team = teamSnapshot.data()!;

      if (team['status'] != 'active') {
        throw Exception('This team is no longer accepting members.');
      }

      final memberIds = List<String>.from(team['memberIds'] ?? []);
      final teamName =
          (invitation['teamName'] ?? team['name'] ?? 'the team').toString();

      if (!memberIds.contains(uid)) {
        transaction.update(teamRef, {
          'memberIds': FieldValue.arrayUnion([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.update(invitationRef, {
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(notificationRef, {
        'developerId': senderId,
        'title': 'Team invitation accepted',
        'body': 'The developer you invited accepted the invitation to "$teamName".',
        'type': 'team_invitation',
        'isRead': false,
        'projectId': team['projectId']?.toString(),
        'applicationId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ---------------------------------------------------------------------------
  // REJECT INVITATION + NOTIFY TEAM OWNER
  // ---------------------------------------------------------------------------

  Future<void> rejectInvitation(String invitationId) async {
    final uid = _currentUid;
    final invitationRef = _invitations.doc(invitationId);
    final notificationRef = _notifications.doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(invitationRef);

      if (!snapshot.exists) {
        throw Exception('Invitation not found.');
      }

      final invitation = snapshot.data()!;

      if (invitation['recipientId'] != uid) {
        throw Exception('This invitation belongs to another developer.');
      }

      if (invitation['status'] != 'pending') {
        throw Exception('This invitation has already been processed.');
      }

      final senderId = invitation['senderId']?.toString() ?? '';
      if (senderId.isEmpty) {
        throw Exception('The invitation has no valid team owner.');
      }

      final teamName =
          (invitation['teamName'] ?? 'the team').toString();

      transaction.update(invitationRef, {
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(notificationRef, {
        'developerId': senderId,
        'title': 'Team invitation declined',
        'body': 'The developer you invited declined the invitation to "$teamName".',
        'type': 'team_invitation',
        'isRead': false,
        'projectId': null,
        'applicationId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
