import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

class PresenceService with WidgetsBindingObserver {
  PresenceService._();

  static final PresenceService instance = PresenceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _heartbeatTimer;
  StreamSubscription<User?>? _authSubscription;
  bool _started = false;
  bool _isAppActive = true;
  String? _activeUid;
  Future<void> _userChange = Future<void>.value();

  DocumentReference<Map<String, dynamic>> _presenceRef(String uid) {
    return _firestore.collection('userPresence').doc(uid);
  }

  Future<void> start() async {
    if (_started) return;

    _started = true;
    _isAppActive =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChanged,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Presence auth listener error: $error');
      },
    );
  }

  void _handleAuthChanged(User? user) {
    _userChange = _userChange.then((_) => _setActiveUser(user?.uid));
  }

  Future<void> _setActiveUser(String? uid) async {
    if (_activeUid == uid) return;

    final previousUid = _activeUid;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (previousUid != null) {
      await _setOnline(false, uid: previousUid);
    }

    _activeUid = uid;

    if (uid == null || !_isAppActive) return;

    await _setOnline(true, uid: uid);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isAppActive && _activeUid == uid) {
        unawaited(_setOnline(true, uid: uid));
      }
    });
  }

  Future<void> _setOnline(bool online, {required String uid}) async {
    try {
      await _presenceRef(uid).set({
        'userId': uid,
        'isOnline': online,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      debugPrint('Presence update failed: ${error.message}');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
    final uid = _activeUid;

    if (uid == null) return;

    if (_isAppActive) {
      unawaited(_setOnline(true, uid: uid));
      _heartbeatTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (_isAppActive && _activeUid == uid) {
          unawaited(_setOnline(true, uid: uid));
        }
      });
    } else {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      unawaited(_setOnline(false, uid: uid));
    }
  }

  Future<void> stop() async {
    if (!_started) return;

    _started = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    await _authSubscription?.cancel();
    _authSubscription = null;

    final uid = _activeUid;
    _activeUid = null;
    if (uid != null) {
      await _setOnline(false, uid: uid);
    }
  }
}
