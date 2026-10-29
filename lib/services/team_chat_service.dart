import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamChatService {
  TeamChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final SupabaseClient _supabase = Supabase.instance.client;

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

  /// Counts unread messages across every active team the given user belongs to.
  /// Each message stores the UIDs that have not read it in `unreadFor`.
  Stream<int> watchUnreadCount(String uid) {
    final controller = StreamController<int>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? teamsSubscription;
    final messageSubscriptions =
        <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
    final unreadCountByTeam = <String, int>{};

    void emitTotal() {
      if (controller.isClosed) return;
      final total = unreadCountByTeam.values.fold<int>(
        0,
        (runningTotal, teamUnread) => runningTotal + teamUnread,
      );
      controller.add(total);
    }

    teamsSubscription = _firestore
        .collection('teams')
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .listen(
          (teamsSnapshot) {
            final activeTeamIds = teamsSnapshot.docs
                .where((doc) => doc.data()['status'] == 'active')
                .map((doc) => doc.id)
                .toSet();

            for (final teamId in messageSubscriptions.keys.toList()) {
              if (!activeTeamIds.contains(teamId)) {
                unreadCountByTeam.remove(teamId);
                final subscription = messageSubscriptions.remove(teamId);
                if (subscription != null) {
                  unawaited(subscription.cancel());
                }
              }
            }

            for (final teamId in activeTeamIds) {
              if (messageSubscriptions.containsKey(teamId)) continue;

              final unreadMessages = _messages(teamId)
                  .where('unreadFor', arrayContains: uid)
                  .snapshots();

              messageSubscriptions[teamId] = unreadMessages.listen(
                (messagesSnapshot) {
                  unreadCountByTeam[teamId] = messagesSnapshot.docs.length;
                  emitTotal();
                },
                onError: (Object error, StackTrace stackTrace) {
                  if (!controller.isClosed) {
                    controller.addError(error, stackTrace);
                  }
                },
              );
            }

            emitTotal();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );

    controller.onCancel = () async {
      await teamsSubscription?.cancel();
      final subscriptions = messageSubscriptions.values.toList();
      messageSubscriptions.clear();
      await Future.wait(
        subscriptions.map((subscription) => subscription.cancel()),
      );
    };

    return controller.stream;
  }

  /// Provides the unread count for one team, for example in the team list.
  Stream<int> watchTeamUnreadCount(String teamId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream<int>.value(0);

    return _messages(teamId)
        .where('unreadFor', arrayContains: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Removes only the current member's UID from unread messages in this team.
  Future<void> markMessagesRead(String teamId) async {
    final uid = _uid;
    final unreadSnapshot = await _messages(teamId)
        .where('unreadFor', arrayContains: uid)
        .get();
    final docs = unreadSnapshot.docs;

    // Firestore write batches are limited to 500 operations; leave headroom.
    for (var start = 0; start < docs.length; start += 450) {
      final end = start + 450 < docs.length ? start + 450 : docs.length;
      final batch = _firestore.batch();

      for (var index = start; index < end; index++) {
        batch.update(docs[index].reference, {
          'unreadFor': FieldValue.arrayRemove([uid]),
        });
      }

      await batch.commit();
    }
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

    return {'uid': uid, 'name': name, 'memberIds': members};
  }

  List<String> _unreadRecipients(Map<String, dynamic> sender) {
    final uid = sender['uid'] as String;
    final members = List<String>.from(sender['memberIds'] as List);
    return members.where((memberUid) => memberUid != uid).toList();
  }

  Future<void> sendMessage({
    required String teamId,
    required String text,
    String? replyToMessageId,
    String? replyToMessage,
    String? replyToSenderName,
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
      'unreadFor': _unreadRecipients(sender),
      'replyToMessageId': replyToMessageId,
      'replyToMessage': replyToMessage,
      'replyToSenderName': replyToSenderName,
      'isEdited': false,
    });
  }

  Future<void> _ensureSupabaseRole() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to use team chat.');
    }

    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    await functions.httpsCallable('ensureSupabaseRole').call();
    await user.getIdToken(true);

    final tokenResult = await user.getIdTokenResult();
    if (tokenResult.claims?['role'] != 'authenticated') {
      throw StateError('Firebase token is missing role=authenticated.');
    }
  }

  Future<void> sendImageMessage({
    required String teamId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError('The selected image is empty.');
    }

    if (imageBytes.length > 20 * 1024 * 1024) {
      throw StateError('Images must be 20 MB or smaller.');
    }

    final sender = await _validateTeamMember(teamId);
    final uid = sender['uid'] as String;
    await _ensureSupabaseRole();

    final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final contentType = _contentType(safeFileName);
    final storagePath =
        '$uid/$teamId/${DateTime.now().microsecondsSinceEpoch}_$safeFileName';

    final bucket = _supabase.storage.from('team-chat-media');

    await bucket.uploadBinary(
      storagePath,
      imageBytes,
      fileOptions: FileOptions(
        contentType: contentType,
        cacheControl: '3600',
        upsert: false,
      ),
    );

    final imageUrl = bucket.getPublicUrl(storagePath);

    try {
      await _messages(teamId).add({
        'senderId': uid,
        'senderName': sender['name'],
        'type': 'image',
        'text': '',
        'imageUrl': imageUrl,
        'fileName': fileName,
        'storagePath': storagePath,
        'fileSize': imageBytes.length,
        'mimeType': contentType,
        'createdAt': FieldValue.serverTimestamp(),
        'unreadFor': _unreadRecipients(sender),
      });
    } catch (error) {
      try {
        await bucket.remove([storagePath]);
      } catch (cleanupError) {
        debugPrint('Supabase image cleanup failed: $cleanupError');
      }
      rethrow;
    }
  }

  Future<void> sendFileMessage({
    required String teamId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('The selected file is empty.');
    }

    if (bytes.length > 20 * 1024 * 1024) {
      throw StateError('Files must be 20 MB or smaller.');
    }

    final sender = await _validateTeamMember(teamId);
    final uid = sender['uid'] as String;
    await _ensureSupabaseRole();

    final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        '$uid/$teamId/${DateTime.now().microsecondsSinceEpoch}_$safeFileName';

    final bucket = _supabase.storage.from('team-chat-media');

    await bucket.uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        cacheControl: '3600',
        upsert: false,
      ),
    );

    final fileUrl = bucket.getPublicUrl(storagePath);

    try {
      await _messages(teamId).add({
        'senderId': uid,
        'senderName': sender['name'],
        'type': 'file',
        'text': '',
        'fileUrl': fileUrl,
        'fileName': fileName,
        'storagePath': storagePath,
        'fileSize': bytes.length,
        'mimeType': contentType,
        'createdAt': FieldValue.serverTimestamp(),
        'unreadFor': _unreadRecipients(sender),
      });
    } catch (error) {
      try {
        await bucket.remove([storagePath]);
      } catch (cleanupError) {
        debugPrint('Supabase file cleanup failed: $cleanupError');
      }
      rethrow;
    }
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
