import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeamChatService {
  TeamChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Please sign in to use team chat.');
    }
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _team(String teamId) =>
      _firestore.collection('teams').doc(teamId);

  CollectionReference<Map<String, dynamic>> _messages(String teamId) =>
      _team(teamId).collection('messages');

  Stream<bool> watchMembership(String teamId) {
    return _team(teamId).snapshots().map((snapshot) {
      final data = snapshot.data();
      final members = List<String>.from(data?['memberIds'] ?? []);
      return snapshot.exists && members.contains(_auth.currentUser?.uid);
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String teamId) {
    return _messages(teamId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<void> sendMessage({
    required String teamId,
    required String text,
  }) async {
    final message = text.trim();
    if (message.isEmpty) return;

    final uid = _uid;
    final teamSnapshot = await _team(teamId).get();

    if (!teamSnapshot.exists) {
      throw StateError('This team no longer exists.');
    }

    final teamData = teamSnapshot.data()!;
    final members = List<String>.from(teamData['memberIds'] ?? []);

    if (!members.contains(uid)) {
      throw StateError('Only accepted team members can send messages.');
    }

    if (teamData['status'] != 'active') {
      throw StateError('This team is not active.');
    }

    final userSnapshot = await _firestore.collection('users').doc(uid).get();
    final userData = userSnapshot.data() ?? {};

    final name =
        (userData['name'] ??
                userData['displayName'] ??
                _auth.currentUser?.displayName ??
                'Team member')
            .toString();

    await _messages(teamId).add({
      'senderId': uid,
      'senderName': name,
      'text': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
