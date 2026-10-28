class LeaderboardEntry {
  final String uid;
  final String name;
  final String role;
  final String? profileImageUrl;

  final int score;
  final int rank;
  final int completedProjects;

  final double? averageRating;

  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.role,
    required this.score,
    required this.rank,
    required this.completedProjects,
    this.profileImageUrl,
    this.averageRating,
  });

  /// Creates a copy of this entry with an updated rank.
  LeaderboardEntry withRank(int newRank) {
    return LeaderboardEntry(
      uid: uid,
      name: name,
      role: role,
      profileImageUrl: profileImageUrl,
      score: score,
      rank: newRank,
      completedProjects: completedProjects,
      averageRating: averageRating,
    );
  }
}
