// TODO Implement this library.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IndividualChatService {
  IndividualChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _currentUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Please sign in to use private chat.');
    }
    return uid;
  }

  String chatIdFor(String otherUid) {
    final ids = [_currentUid, otherUid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _db.collection('individualChats').doc(chatId).collection('messages');

  Future<String> openChat({
    required String otherUid,
    required String otherName,
    required String teamId,
  }) async {
    final uid = _currentUid;

    if (otherUid.trim().isEmpty || otherUid == uid) {
      throw ArgumentError('Select another team member to chat with.');
    }

    // Confirm both users are still members of this team.
    final teamSnapshot = await _db.collection('teams').doc(teamId).get();

    if (!teamSnapshot.exists) {
      throw StateError('This team no longer exists.');
    }

    final team = teamSnapshot.data()!;
    final memberIds = List<String>.from(team['memberIds'] ?? []);

    if (!memberIds.contains(uid) || !memberIds.contains(otherUid)) {
      throw StateError('Private chat is available to team members only.');
    }

    if (team['status'] != 'active') {
      throw StateError('This team is not active.');
    }

    final chatId = chatIdFor(otherUid);
    final chatRef = _db.collection('individualChats').doc(chatId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(chatRef);

      if (!snapshot.exists) {
        transaction.set(chatRef, {
          'participants': [uid, otherUid]..sort(),
          'participantNames': {
            uid: _auth.currentUser?.displayName ?? 'Team member',
            otherUid: otherName,
          },
          'teamIds': [teamId],
          'lastMessage': '',
          'lastSenderId': '',
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = snapshot.data()!;
        final participants = List<String>.from(data['participants'] ?? []);

        if (!participants.contains(uid) ||
            !participants.contains(otherUid) ||
            participants.length != 2) {
          throw StateError('This private conversation is invalid.');
        }

        transaction.update(chatRef, {
          'teamIds': FieldValue.arrayUnion([teamId]),
        });
      }
    });

    return chatId;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchConversations() {
    final uid = _currentUid;

    return _db
        .collection('individualChats')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String chatId) {
    return _messages(chatId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final message = text.trim();
    if (message.isEmpty) return;

    final uid = _currentUid;
    final chatRef = _db.collection('individualChats').doc(chatId);
    final chatSnapshot = await chatRef.get();

    if (!chatSnapshot.exists) {
      throw StateError('This conversation does not exist.');
    }

    final chat = chatSnapshot.data()!;
    final participants = List<String>.from(chat['participants'] ?? []);

    if (participants.length != 2 || !participants.contains(uid)) {
      throw StateError('You cannot send messages in this conversation.');
    }

    final userSnapshot = await _db.collection('users').doc(uid).get();
    final user = userSnapshot.data() ?? {};

    final senderName =
        (user['name'] ??
                user['displayName'] ??
                _auth.currentUser?.displayName ??
                'Team member')
            .toString();

    final batch = _db.batch();

    batch.set(_messages(chatId).doc(), {
      'senderId': uid,
      'senderName': senderName,
      'text': message,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(chatRef, {
      'lastMessage': message,
      'lastSenderId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
