// TODO Implement this library.

import 'dart:typed_data';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class TeamChatService {
  TeamChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

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

  Future<Map<String, dynamic>> _validateTeamMember(String teamId) async {
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

    return {'uid': uid, 'name': name};
  }

  Future<void> sendMessage({
    required String teamId,
    required String text,
  }) async {
    final message = text.trim();

    if (message.isEmpty) return;

    final sender = await _validateTeamMember(teamId);

    await _messages(teamId).add({
      'senderId': sender['uid'],
      'senderName': sender['name'],
      'type': 'text',
      'text': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendImageMessage({
    required String teamId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError('The selected image is empty.');
    }

    final sender = await _validateTeamMember(teamId);
    final uid = sender['uid'] as String;

    final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final storageRef = _storage.ref().child(
      'team_chat/$teamId/$uid/'
      '${DateTime.now().millisecondsSinceEpoch}_$safeFileName',
    );

    final metadata = SettableMetadata(contentType: _contentType(safeFileName));

    final uploadOperation = storageRef.putData(imageBytes, metadata);

    final TaskSnapshot uploadTask;

    try {
      uploadTask = await uploadOperation.timeout(
        const Duration(seconds: 60),
        onTimeout: () async {
          await uploadOperation.cancel();
          throw TimeoutException(
            'Image upload timed out. Check Firebase Storage and your internet connection.',
          );
        },
      );
    } catch (error) {
      throw Exception('Firebase image upload failed: $error');
    }

    final imageUrl = await uploadTask.ref.getDownloadURL();

    await _messages(teamId).add({
      'senderId': uid,
      'senderName': sender['name'],
      'type': 'image',
      'text': '',
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _contentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }
}
