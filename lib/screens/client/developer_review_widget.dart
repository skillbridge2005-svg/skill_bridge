import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DeveloperReviewWidget extends StatefulWidget {
  final String projectId;
  final String projectTitle;
  final String developerId;
  final String projectStatus;
  final int progress;

  const DeveloperReviewWidget({
    super.key,
    required this.projectId,
    required this.projectTitle,
    required this.developerId,
    required this.projectStatus,
    required this.progress,
  });

  @override
  State<DeveloperReviewWidget> createState() => _DeveloperReviewWidgetState();
}

class _DeveloperReviewWidgetState extends State<DeveloperReviewWidget> {
  final TextEditingController _commentController = TextEditingController();

  int _rating = 0;
  bool _submitting = false;

  static const Color _primary = Color(0xFF4F46E5);
  static const Color _green = Color(0xFF16A34A);

  bool get _isCompleted =>
      widget.projectStatus.trim().toLowerCase() == 'completed' ||
      widget.progress >= 100;

  DocumentReference<Map<String, dynamic>> get _reviewRef {
    return FirebaseFirestore.instance
        .collection('reviews')
        .doc(widget.projectId);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please log in to submit your review.');
      return;
    }

    if (!_isCompleted) {
      _showMessage('You can review the developer after project completion.');
      return;
    }

    if (widget.developerId.isEmpty) {
      _showMessage('Developer information is unavailable for this project.');
      return;
    }

    if (_rating < 1 || _rating > 5) {
      _showMessage('Please select a star rating.');
      return;
    }

    final comment = _commentController.text.trim();

    if (comment.isEmpty) {
      _showMessage('Please write a comment.');
      return;
    }

    if (comment.length < 5) {
      _showMessage('Your comment must contain at least 5 characters.');
      return;
    }

    setState(() => _submitting = true);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final projectRef = FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId);

        final projectSnapshot = await transaction.get(projectRef);

        final existingReview = await transaction.get(_reviewRef);

        if (!projectSnapshot.exists) {
          throw Exception('PROJECT_NOT_FOUND');
        }

        if (existingReview.exists) {
          throw Exception('REVIEW_ALREADY_EXISTS');
        }

        final projectData = projectSnapshot.data() ?? <String, dynamic>{};

        final currentUserId = user.uid;

        if (projectData['clientId'] != currentUserId) {
          throw Exception('NOT_PROJECT_CLIENT');
        }

        final currentStatus = projectData['status']?.toString().toLowerCase();

        final projectProgress = (projectData['progress'] as num?)?.toInt() ?? 0;

        final rawMilestones = projectData['milestones'];

        final milestones = rawMilestones is Map
            ? Map<String, dynamic>.from(rawMilestones)
            : <String, dynamic>{};

        const milestoneKeys = [
          'requirements',
          'architecture',
          'design',
          'development',
          'testing',
          'deployment',
        ];

        final allMilestonesCompleted = milestoneKeys.every(
          (key) => milestones[key] == true,
        );

        if (currentStatus != 'completed' &&
            projectProgress < 100 &&
            !allMilestonesCompleted) {
          throw Exception('PROJECT_NOT_COMPLETED');
        }

        final projectDeveloperId =
            (projectData['developerId']?.toString().trim().isNotEmpty == true)
            ? projectData['developerId'].toString().trim()
            : (projectData['assignedDeveloperId']?.toString().trim() ?? '');

        if (projectDeveloperId.isEmpty ||
            projectDeveloperId != widget.developerId) {
          throw Exception('DEVELOPER_MISMATCH');
        }

        transaction.set(_reviewRef, {
          'projectId': widget.projectId,
          'projectTitle': widget.projectTitle,
          'clientId': currentUserId,
          'developerId': projectDeveloperId,
          'rating': _rating,
          'comment': comment,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      _commentController.clear();

      setState(() {
        _rating = 0;
      });

      _showMessage('Your review was submitted successfully!');
    } catch (error) {
      if (!mounted) return;

      final message = error.toString();

      if (message.contains('REVIEW_ALREADY_EXISTS')) {
        _showMessage('You have already reviewed this project.');
      } else if (message.contains('PROJECT_NOT_COMPLETED')) {
        _showMessage(
          'You can review the developer after all milestones are completed.',
        );
      } else if (message.contains('NOT_PROJECT_CLIENT')) {
        _showMessage('Only the project owner can submit this review.');
      } else if (message.contains('DEVELOPER_MISMATCH')) {
        _showMessage('The assigned developer does not match this project.');
      } else if (message.contains('PROJECT_NOT_FOUND')) {
        _showMessage('Project not found.');
      } else {
        _showMessage('Unable to submit your review. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (!_isCompleted || user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _reviewRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Text(
            'Unable to load the developer review.',
            style: TextStyle(color: Colors.red),
          );
        }

        final reviewSnapshot = snapshot.data;

        if (reviewSnapshot?.exists == true) {
          final review = reviewSnapshot!.data()!;
          final rating = (review['rating'] as num?)?.toInt() ?? 0;

          final comment = review['comment']?.toString() ?? '';

          return _buildSubmittedReview(rating, comment);
        }

        return _buildReviewForm();
      },
    );
  }

  Widget _buildReviewForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.rate_review_rounded, color: _primary, size: 25),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Rate Your Developer',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Text(
            'Your feedback helps other clients choose the right developer.',
            style: TextStyle(
              color: Color(0xFF667085),
              fontSize: 13,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          const Center(
            child: Text(
              'How was your experience?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),

          const SizedBox(height: 10),

          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;

                return IconButton(
                  tooltip: '$starNumber star${starNumber == 1 ? '' : 's'}',
                  onPressed: _submitting
                      ? null
                      : () {
                          setState(() {
                            _rating = starNumber;
                          });
                        },
                  icon: Icon(
                    starNumber <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 38,
                    color: const Color(0xFFF59E0B),
                  ),
                );
              }),
            ),
          ),

          Center(
            child: Text(
              _rating == 0
                  ? 'Select your rating'
                  : _rating == 1
                  ? 'Poor'
                  : _rating == 2
                  ? 'Fair'
                  : _rating == 3
                  ? 'Good'
                  : _rating == 4
                  ? 'Very Good'
                  : 'Excellent',
              style: const TextStyle(
                color: Color(0xFF475467),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Your Comment',
            style: TextStyle(
              color: Color(0xFF344054),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 9),

          TextField(
            controller: _commentController,
            enabled: !_submitting,
            minLines: 4,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Share your experience working with this developer...',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: Color(0xFF98A2B3),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 49,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submitReview,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _submitting ? 'Submitting...' : 'Submit Review',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedReview(int rating, String comment) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_rounded, color: _green, size: 25),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Thank You for Your Review!',
                  style: TextStyle(
                    color: Color(0xFF166534),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: const Color(0xFFF59E0B),
                size: 25,
              );
            }),
          ),

          const SizedBox(height: 12),

          Text(
            comment,
            style: const TextStyle(
              color: Color(0xFF344054),
              height: 1.6,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Your review has been recorded for this project.',
            style: TextStyle(
              color: Color(0xFF15803D),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
