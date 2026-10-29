// TODO Implement this library.
import 'package:cloud_firestore/cloud_firestore.dart';

/// A short opinion posted by a top performer, shown in a cloud on the podium.
class PodiumMessage {
  const PodiumMessage({
    required this.userId,
    required this.text,
    this.updatedAt,
  });

  final String userId;
  final String text;
  final DateTime? updatedAt;
}

/// Stores one message per user in `podium_messages/{userId}`.
///
/// Everyone can read; only the owner can write their own document
/// (see the Firestore rules in the instructions).
class PodiumMessageService {
  PodiumMessageService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const int maxLength = 60;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('podium_messages');

  /// Live messages for the given user ids (max 10 ids per Firestore `whereIn`).
  Stream<Map<String, PodiumMessage>> watchMessages(List<String> userIds) {
    final ids = userIds.take(10).toList();
    if (ids.isEmpty) {
      return Stream.value(const <String, PodiumMessage>{});
    }

    return _collection
        .where(FieldPath.documentId, whereIn: ids)
        .snapshots()
        .map((snapshot) {
          final result = <String, PodiumMessage>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final text = (data['text'] as String?)?.trim() ?? '';
            if (text.isEmpty) continue;
            result[doc.id] = PodiumMessage(
              userId: doc.id,
              text: text,
              updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
            );
          }
          return result;
        });
  }

  Future<void> setMessage({
    required String userId,
    required String name,
    required String text,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }

    await _collection.doc(userId).set({
      'userId': userId,
      'name': name,
      'text': clean.length > maxLength ? clean.substring(0, maxLength) : clean,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String userId) {
    return _collection.doc(userId).delete();
  }
}
