import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/team_model.dart';

class TeamService {
  TeamService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore =
            firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>>
      get _teamsCollection =>
          _firestore.collection('teams');

  String? get currentDeveloperId =>
      _auth.currentUser?.uid;

  String _requireDeveloper() {
    final uid = currentDeveloperId;

    if (uid == null || uid.trim().isEmpty) {
      throw const TeamServiceException(
        'You must be logged in as a developer.',
      );
    }

    return uid;
  }

  // ---------------------------------------------------------------------------
  // TEAM STREAMS
  // ---------------------------------------------------------------------------

  /// Streams teams where the current developer is a member.
Stream<List<TeamModel>> watchMyTeams() {
  final developerId = currentDeveloperId;

  if (developerId == null) {
    return Stream.value(<TeamModel>[]);
  }

  return _teamsCollection
      .where(
        'memberIds',
        arrayContains: developerId,
      )
      .snapshots()
      .map((snapshot) {
        final teams = _documentsToTeams(snapshot);

        teams.sort((a, b) {
          final aDate = a.createdAt;
          final bDate = b.createdAt;

          if (aDate == null && bDate == null) {
            return 0;
          }

          if (aDate == null) {
            return 1;
          }

          if (bDate == null) {
            return -1;
          }

          return bDate.compareTo(aDate);
        });

        return teams;
      });
}

  /// Streams one team.
  Stream<TeamModel?> watchTeam(
    String teamId,
  ) {
    return _teamsCollection
        .doc(teamId)
        .snapshots()
        .map(
          (snapshot) {
            if (!snapshot.exists) {
              return null;
            }

            return TeamModel.fromFirestore(snapshot);
          },
        );
  }

  // ---------------------------------------------------------------------------
  // TEAM FETCHING
  // ---------------------------------------------------------------------------

  Future<List<TeamModel>> getMyTeams() async {
  final developerId = _requireDeveloper();

  final snapshot = await _teamsCollection
      .where(
        'memberIds',
        arrayContains: developerId,
      )
      .get();

  final teams = _documentsToTeams(snapshot);

  teams.sort((a, b) {
    final aDate = a.createdAt;
    final bDate = b.createdAt;

    if (aDate == null && bDate == null) {
      return 0;
    }

    if (aDate == null) {
      return 1;
    }

    if (bDate == null) {
      return -1;
    }

    return bDate.compareTo(aDate);
  });

  return teams;
}

  Future<TeamModel?> getTeam(
    String teamId,
  ) async {
    if (teamId.trim().isEmpty) {
      throw const TeamServiceException(
        'Team ID cannot be empty.',
      );
    }

    final snapshot =
        await _teamsCollection.doc(teamId).get();

    if (!snapshot.exists) {
      return null;
    }

    return TeamModel.fromFirestore(snapshot);
  }

  // ---------------------------------------------------------------------------
  // TEAM CREATION
  // ---------------------------------------------------------------------------

  Future<String> createTeam({
    required String name,
    required String projectId,
    required String projectTitle,
    required List<String> memberIds,
    String description = '',
  }) async {
    final developerId = _requireDeveloper();

    if (name.trim().isEmpty) {
      throw const TeamServiceException(
        'Team name cannot be empty.',
      );
    }

    if (projectId.trim().isEmpty) {
      throw const TeamServiceException(
        'Project ID cannot be empty.',
      );
    }

    final members = <String>{
      developerId,
      ...memberIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty),
    }.toList();

    final now = FieldValue.serverTimestamp();

    final document =
        await _teamsCollection.add({
      'name': name.trim(),
      'projectId': projectId.trim(),
      'projectTitle': projectTitle.trim(),
      'ownerId': developerId,
      'memberIds': members,
      'status': 'active',
      'description': description.trim(),
      'createdAt': now,
      'updatedAt': now,
    });

    return document.id;
  }

  // ---------------------------------------------------------------------------
  // TEAM UPDATES
  // ---------------------------------------------------------------------------

  Future<void> updateTeam(
    String teamId,
    Map<String, dynamic> updates,
  ) async {
    final developerId = _requireDeveloper();

    if (teamId.trim().isEmpty) {
      throw const TeamServiceException(
        'Team ID cannot be empty.',
      );
    }

    if (updates.isEmpty) {
      return;
    }

    final team = await getTeam(teamId);

    if (team == null) {
      throw const TeamServiceException(
        'Team not found.',
      );
    }

    if (team.ownerId != developerId) {
      throw const TeamServiceException(
        'Only the team owner can update the team.',
      );
    }

    final safeUpdates =
        Map<String, dynamic>.from(updates);

    safeUpdates['updatedAt'] =
        FieldValue.serverTimestamp();

    await _teamsCollection
        .doc(teamId)
        .update(safeUpdates);
  }

  Future<void> updateTeamStatus(
    String teamId,
    String status,
  ) async {
    final normalizedStatus =
        status.trim().toLowerCase();

    const validStatuses = {
      'active',
      'completed',
      'archived',
    };

    if (!validStatuses.contains(normalizedStatus)) {
      throw TeamServiceException(
        'Invalid team status: $status',
      );
    }

    await updateTeam(
      teamId,
      {
        'status': normalizedStatus,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TEAM MEMBERS
  // ---------------------------------------------------------------------------

  Future<void> addMember(
    String teamId,
    String developerId,
  ) async {
    if (developerId.trim().isEmpty) {
      throw const TeamServiceException(
        'Developer ID cannot be empty.',
      );
    }

    final team = await getTeam(teamId);

    if (team == null) {
      throw const TeamServiceException(
        'Team not found.',
      );
    }

    final currentUser = _requireDeveloper();

    if (team.ownerId != currentUser) {
      throw const TeamServiceException(
        'Only the team owner can add members.',
      );
    }

    await _teamsCollection.doc(teamId).update({
      'memberIds': FieldValue.arrayUnion([
        developerId.trim(),
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeMember(
    String teamId,
    String developerId,
  ) async {
    final team = await getTeam(teamId);

    if (team == null) {
      throw const TeamServiceException(
        'Team not found.',
      );
    }

    final currentUser = _requireDeveloper();

    if (team.ownerId != currentUser) {
      throw const TeamServiceException(
        'Only the team owner can remove members.',
      );
    }

    if (developerId == team.ownerId) {
      throw const TeamServiceException(
        'The team owner cannot be removed.',
      );
    }

    await _teamsCollection.doc(teamId).update({
      'memberIds': FieldValue.arrayRemove([
        developerId.trim(),
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<void> deleteTeam(
    String teamId,
  ) async {
    final team = await getTeam(teamId);

    if (team == null) {
      throw const TeamServiceException(
        'Team not found.',
      );
    }

    final developerId = _requireDeveloper();

    if (team.ownerId != developerId) {
      throw const TeamServiceException(
        'Only the team owner can delete the team.',
      );
    }

    await _teamsCollection.doc(teamId).delete();
  }

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  List<TeamModel> searchTeams(
    List<TeamModel> teams,
    String query,
  ) {
    final normalizedQuery =
        query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return teams;
    }

    return teams.where((team) {
      final searchableText = [
        team.name,
        team.projectTitle,
        team.description,
        team.status,
      ].join(' ').toLowerCase();

      return searchableText.contains(
        normalizedQuery,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  List<TeamModel> _documentsToTeams(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map(TeamModel.fromFirestore)
        .toList();
  }
}

class TeamServiceException implements Exception {
  const TeamServiceException(this.message);

  final String message;

  @override
  String toString() =>
      'TeamServiceException: $message';
}