import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DeveloperReviewsList extends StatelessWidget {
  final String developerId;

  const DeveloperReviewsList({super.key, required this.developerId});

  @override
  Widget build(BuildContext context) {
    if (developerId.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('developerId', isEqualTo: developerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Unable to load client reviews.');
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Client Reviews',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            if (reviews.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No client reviews yet.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                ),
              )
            else
              ...reviews.map((review) {
                final data = review.data();
                final rating = (data['rating'] as num?)?.toInt() ?? 0;
                final comment = data['comment']?.toString() ?? '';
                final projectTitle =
                    data['projectTitle']?.toString() ?? 'Project';
                final rawCreatedAt = data['createdAt'];
                final createdAt = rawCreatedAt is Timestamp
                    ? rawCreatedAt
                    : null;
                final dateText = createdAt == null
                    ? 'Recently'
                    : '${createdAt.toDate().day}/'
                          '${createdAt.toDate().month}/'
                          '${createdAt.toDate().year}';

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  elevation: 0,
                  color: const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFDBEAFE),
                              child: Icon(
                                Icons.person_outline,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    projectTitle,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    dateText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: const Color(0xFFF59E0B),
                              size: 23,
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          comment.isEmpty ? 'No comment provided.' : comment,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
