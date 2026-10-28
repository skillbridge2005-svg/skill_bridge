import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DeveloperRatingSummary extends StatelessWidget {
  final String developerId;

  const DeveloperRatingSummary({super.key, required this.developerId});

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
          return const Text('Unable to load ratings.');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews = snapshot.data?.docs ?? [];

        if (reviews.isEmpty) {
          return _buildEmptyRating();
        }

        double totalRating = 0;

        for (final review in reviews) {
          final data = review.data();
          totalRating += (data['rating'] as num?)?.toDouble() ?? 0;
        }

        final averageRating = totalRating / reviews.length;

        return Card(
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
                const Text(
                  'Developer Rating',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 34,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${reviews.length} '
                        '${reviews.length == 1 ? 'review' : 'reviews'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < averageRating.round()
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFF59E0B),
                      size: 24,
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyRating() {
    return Card(
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Developer Rating',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.star_outline_rounded,
                  size: 30,
                  color: Color(0xFFF59E0B),
                ),
                SizedBox(width: 8),
                Text(
                  'No reviews yet',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
