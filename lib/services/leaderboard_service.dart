import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leaderboard_entry.dart';

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches the leaderboard for either developers or clients.
  Future<List<LeaderboardEntry>> getLeaderboard({required String role}) async {
    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .get();

      final projectsSnapshot = await _firestore.collection('projects').get();

      final users = usersSnapshot.docs;
      final projects = projectsSnapshot.docs;

      final List<LeaderboardEntry> entries = [];

      for (final userDoc in users) {
        final userData = userDoc.data();
        final uid = userDoc.id;

        final name =
            (userData['name'] ??
                    userData['displayName'] ??
                    userData['fullName'] ??
                    'Unknown User')
                .toString();

        final profileImageUrl =
            (userData['profileImageUrl'] ??
                    userData['photoURL'] ??
                    userData['photoUrl'])
                ?.toString();

        int completedProjects = 0;
        double totalRating = 0;
        int ratingCount = 0;

        for (final projectDoc in projects) {
          final project = projectDoc.data();

          if (!_isCompleted(project)) {
            continue;
          }

          if (role == 'developer' && _belongsToDeveloper(project, uid)) {
            completedProjects++;

            final rating = _getDeveloperRating(project);

            if (rating != null && rating >= 0 && rating <= 5) {
              totalRating += rating;
              ratingCount++;
            }
          } else if (role == 'client' && _belongsToClient(project, uid)) {
            completedProjects++;
          }
        }

        // Do not include users who have not completed any projects.
        if (completedProjects == 0) {
          continue;
        }

        final double? averageRating = ratingCount > 0
            ? totalRating / ratingCount
            : null;

        // Score: 100 points per completed project.
        // Developers receive an additional rating-based bonus.
        final int score =
            completedProjects * 100 +
            (role == 'developer' && averageRating != null
                ? (averageRating * 20).round()
                : 0);

        entries.add(
          LeaderboardEntry(
            uid: uid,
            name: name,
            role: role,
            profileImageUrl: profileImageUrl,
            score: score,
            rank: 0,
            completedProjects: completedProjects,
            averageRating: averageRating,
          ),
        );
      }

      // Sort by score, then completed projects, then rating.
      entries.sort((a, b) {
        final scoreComparison = b.score.compareTo(a.score);

        if (scoreComparison != 0) {
          return scoreComparison;
        }

        final projectComparison = b.completedProjects.compareTo(
          a.completedProjects,
        );

        if (projectComparison != 0) {
          return projectComparison;
        }

        return (b.averageRating ?? 0).compareTo(a.averageRating ?? 0);
      });

      // Assign ranks and return only the top 10.
      final rankedEntries = <LeaderboardEntry>[];

      for (int i = 0; i < entries.length && i < 10; i++) {
        rankedEntries.add(entries[i].withRank(i + 1));
      }

      return rankedEntries;
    } catch (e) {
      throw Exception('Failed to load leaderboard: $e');
    }
  }

  /// Checks whether a project has a completed status.
  bool _isCompleted(Map<String, dynamic> project) {
    final status =
        (project['status'] ??
                project['projectStatus'] ??
                project['state'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();

    return {'completed', 'complete', 'done', 'finished'}.contains(status);
  }

  /// Checks whether the project belongs to a developer.
  bool _belongsToDeveloper(Map<String, dynamic> project, String uid) {
    final possibleFields = [
      'developerId',
      'developerUid',
      'assignedDeveloperId',
      'assignedDeveloperUid',
      'freelancerId',
      'assignedTo',
    ];

    for (final field in possibleFields) {
      if (_containsUid(project[field], uid)) {
        return true;
      }
    }

    return false;
  }

  /// Checks whether the project belongs to a client.
  bool _belongsToClient(Map<String, dynamic> project, String uid) {
    final possibleFields = ['clientId', 'clientUid', 'ownerId', 'createdBy'];

    for (final field in possibleFields) {
      if (_containsUid(project[field], uid)) {
        return true;
      }
    }

    return false;
  }

  /// Supports IDs stored as strings, lists, or maps.
  bool _containsUid(dynamic value, String uid) {
    if (value is String) {
      return value == uid;
    }

    if (value is List) {
      return value.any((item) => _containsUid(item, uid));
    }

    if (value is Map) {
      if (value['uid'] == uid || value['userId'] == uid || value['id'] == uid) {
        return true;
      }

      return false;
    }

    return false;
  }

  /// Retrieves a developer rating from supported project fields.
  double? _getDeveloperRating(Map<String, dynamic> project) {
    final value =
        project['developerRating'] ??
        project['developerReviewRating'] ??
        project['reviewRating'];

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }
}
