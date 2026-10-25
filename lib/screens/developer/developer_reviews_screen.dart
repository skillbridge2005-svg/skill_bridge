import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DeveloperReviewsScreen extends StatelessWidget {
  final String developerId;

  const DeveloperReviewsScreen({super.key, required this.developerId});

  Future<String> _getClientName(String clientId) async {
    if (clientId.isEmpty) {
      return 'Unknown Client';
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(clientId)
        .get();

    if (!doc.exists) {
      return 'Unknown Client';
    }

    final data = doc.data() ?? <String, dynamic>{};
    return (data['name'] ?? data['fullName'] ?? data['displayName'] ?? 'Client')
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Developer Reviews',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('developerId', isEqualTo: developerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Something went wrong while loading reviews.'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reviews =
              snapshot.data?.docs.toList() ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          reviews.sort((a, b) {
            final aCreatedAt = a.data()['createdAt'];
            final bCreatedAt = b.data()['createdAt'];
            final aMilliseconds = aCreatedAt is Timestamp
                ? aCreatedAt.millisecondsSinceEpoch
                : 0;
            final bMilliseconds = bCreatedAt is Timestamp
                ? bCreatedAt.millisecondsSinceEpoch
                : 0;

            return bMilliseconds.compareTo(aMilliseconds);
          });

          if (reviews.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No reviews yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Reviews from clients will appear here.'),
                ],
              ),
            );
          }

          double totalRating = 0;

          for (final review in reviews) {
            totalRating += (review.data()['rating'] as num?)?.toDouble() ?? 0;
          }

          final averageRating = totalRating / reviews.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Overall Rating',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              5,
                              (index) => Icon(
                                index < averageRating.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${reviews.length} ${reviews.length == 1 ? 'review' : 'reviews'}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'All Client Reviews',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...reviews.map((review) {
                      final data = review.data();
                      final rating = (data['rating'] as num?)?.toDouble() ?? 0;
                      final comment = (data['comment'] ?? '').toString();
                      final clientId = (data['clientId'] ?? '').toString();
                      final projectTitle =
                          (data['projectTitle'] ?? 'Project Review').toString();
                      final rawCreatedAt = data['createdAt'];
                      final createdAt = rawCreatedAt is Timestamp
                          ? rawCreatedAt.toDate()
                          : null;
                      final formattedDate = createdAt == null
                          ? 'Date unavailable'
                          : '${createdAt.day.toString().padLeft(2, '0')}/'
                                '${createdAt.month.toString().padLeft(2, '0')}/'
                                '${createdAt.year}';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Color(0xFFE0E7FF),
                                    child: Icon(
                                      Icons.person,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        FutureBuilder<String>(
                                          future: _getClientName(clientId),
                                          builder: (context, snapshot) {
                                            return Text(
                                              snapshot.hasError
                                                  ? 'Unable to load client'
                                                  : snapshot.data ??
                                                        'Loading client...',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formattedDate,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                projectTitle,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: List.generate(
                                  5,
                                  (index) => Icon(
                                    index < rating.round()
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${rating.toStringAsFixed(1)} / 5.0',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (comment.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  comment,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
