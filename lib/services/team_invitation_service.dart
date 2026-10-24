
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

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection('developerProfiles');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  String get _currentUid {
    final uid = _auth.currentUser?.uid;

    if (uid == null || uid.trim().isEmpty) {
      throw Exception('Please sign in to continue.');
    }

    return uid;
  }

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

  /// Creates an invitation with the selected role and responsibilities.
  ///
  /// Role and responsibilities are optional temporarily so existing callers
  /// continue compiling until the team invitation dialog is updated.
  Future<String> sendInvitation({
    required String teamId,
    required String developerId,
    String role = '',
    String responsibilities = '',
  }) async {
    final uid = _currentUid;

    if (teamId.trim().isEmpty || developerId.trim().isEmpty) {
      throw Exception('Team and developer are required.');
    }

    if (developerId == uid) {
      throw Exception('You cannot invite yourself.');
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

    final memberIds = List<String>.from(team['memberIds'] ?? []);

    if (memberIds.contains(developerId)) {
      throw Exception('This developer is already a team member.');
    }

    // Check that the recipient is a developer and is open to team invitations.
    final userSnapshot = await _users.doc(developerId).get();

    if (!userSnapshot.exists) {
      throw Exception('Developer account not found.');
    }

    final userData = userSnapshot.data()!;

    if ((userData['role'] ?? '').toString().toLowerCase() !=
        'developer') {
      throw Exception('You can only invite developer accounts.');
    }

    final profileSnapshot = await _profiles.doc(developerId).get();
    final profile = profileSnapshot.data() ?? {};

    if (profile['openToTeams'] == false) {
      throw Exception('This developer is not accepting team invitations.');
    }

    // Prevent another pending invitation to the same developer for this team.
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
    final teamDescription = (team['description'] ?? '').toString();
    final projectId = team['projectId']?.toString();

    final cleanRole = role.trim();
    final cleanResponsibilities = responsibilities.trim();

    final batch = _firestore.batch();

    batch.set(invitationRef, {
      'teamId': teamId,
      'teamName': teamName,
      'projectTitle': projectTitle,
      'teamDescription': teamDescription,
      'senderId': uid,
      'recipientId': developerId,
      'role': cleanRole,
      'responsibilities': cleanResponsibilities,
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
      'projectId': projectId,
      'applicationId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return invitationRef.id;
  }

  /// Accepts an invitation and adds the developer to the team.
  ///
  /// The role is stored against the developer UID in the team's memberRoles
  /// map. The developer is added only when the invitation is accepted.
  Future<void> acceptInvitation(String invitationId) async {
    final uid = _currentUid;

    final invitationRef = _invitations.doc(invitationId);
    final notificationRef = _notifications.doc();

    await _firestore.runTransaction((transaction) async {
      final invitationSnapshot =
          await transaction.get(invitationRef);

      if (!invitationSnapshot.exists) {
        throw Exception('Invitation not found.');
      }

      final invitation = invitationSnapshot.data()!;

      if (invitation['recipientId'] != uid) {
        throw Exception(
          'This invitation belongs to another developer.',
        );
      }

      if (invitation['status'] != 'pending') {
        throw Exception(
          'This invitation has already been processed.',
        );
      }

      final teamId = invitation['teamId']?.toString() ?? '';

      if (teamId.isEmpty) {
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
        throw Exception(
          'This team is no longer accepting members.',
        );
      }

      // Prevent a stale or altered invitation from adding someone to a
      // team whose owner no longer matches the invitation sender.
      if (team['ownerId'] != senderId) {
        throw Exception(
          'The team owner no longer matches this invitation.',
        );
      }

      final memberIds = List<String>.from(team['memberIds'] ?? []);
      final memberRoles = Map<String, dynamic>.from(
        team['memberRoles'] ?? {},
      );
      final memberResponsibilities = Map<String, dynamic>.from(
        team['memberResponsibilities'] ?? {},
      );

      final role = (invitation['role'] ?? '').toString().trim();
      final responsibilities =
          (invitation['responsibilities'] ?? '').toString().trim();

      final teamName =
          (invitation['teamName'] ?? team['name'] ?? 'the team')
              .toString();

      // Add the developer and their role only if they are not already
      // a member. Keep existing member roles unchanged.
      if (!memberIds.contains(uid)) {
        memberIds.add(uid);

        if (role.isNotEmpty) {
          memberRoles[uid] = role;
        }

        if (responsibilities.isNotEmpty) {
          memberResponsibilities[uid] = responsibilities;
        }

        transaction.update(teamRef, {
          'memberIds': memberIds,
          'memberRoles': memberRoles,
          'memberResponsibilities': memberResponsibilities,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // If already a member, do not overwrite an existing role.
        // This avoids silently changing a member's role on a duplicate
        // or stale invitation.
      }

      transaction.update(invitationRef, {
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(notificationRef, {
        'developerId': senderId,
        'title': 'Team invitation accepted',
        'body': role.isEmpty
            ? 'The developer you invited accepted the invitation to "$teamName".'
            : 'The developer you invited accepted the "$role" role on "$teamName".',
        'type': 'team_invitation',
        'isRead': false,
        'projectId': team['projectId']?.toString(),
        'applicationId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Declines an invitation without adding the developer to the team.
  Future<void> rejectInvitation(String invitationId) async {
    final uid = _currentUid;

    final invitationRef = _invitations.doc(invitationId);
    final notificationRef = _notifications.doc();

    await _firestore.runTransaction((transaction) async {
      final invitationSnapshot =
          await transaction.get(invitationRef);

      if (!invitationSnapshot.exists) {
        throw Exception('Invitation not found.');
      }

      final invitation = invitationSnapshot.data()!;

      if (invitation['recipientId'] != uid) {
        throw Exception(
          'This invitation belongs to another developer.',
        );
      }

      if (invitation['status'] != 'pending') {
        throw Exception(
          'This invitation has already been processed.',
        );
      }

      final senderId = invitation['senderId']?.toString() ?? '';

      if (senderId.isEmpty) {
        throw Exception('The invitation has no valid team owner.');
      }

      final teamName =
          (invitation['teamName'] ?? 'the team').toString();

      final teamId = invitation['teamId']?.toString() ?? '';
      String? projectId;

      if (teamId.isNotEmpty) {
        final teamSnapshot =
            await transaction.get(_teams.doc(teamId));

        if (teamSnapshot.exists) {
          projectId = teamSnapshot.data()?['projectId']?.toString();
        }
      }

      transaction.update(invitationRef, {
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(notificationRef, {
        'developerId': senderId,
        'title': 'Team invitation declined',
        'body':
            'The developer you invited declined the invitation to "$teamName".',
        'type': 'team_invitation',
        'isRead': false,
        'projectId': projectId,
        'applicationId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
