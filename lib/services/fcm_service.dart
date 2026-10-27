import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('Background FCM message: ${message.messageId}');
}

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _messageTapSubscription;

  String? _lastSavedToken;
  String? _associatedUid;
  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'skillbridge_notifications',
    'SkillBridge Notifications',
    description: 'Notifications for SkillBridge activities.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_initialized) return;

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows)) {
      debugPrint('FCM is not supported on this platform.');
      _initialized = true;
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Local notification tapped: ${response.payload}');
      },
    );

    final androidNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidNotifications?.createNotificationChannel(_channel);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'SkillBridge notification permission: '
      '${settings.authorizationStatus}',
    );

    _authSubscription = _auth.authStateChanges().listen(
      (user) async {
        try {
          await _handleAuthChange(user);
        } catch (error, stackTrace) {
          debugPrint('FCM authentication setup failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM authentication listener failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );

    _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
      final uid = _auth.currentUser?.uid;

      if (uid == null) return;

      try {
        await _saveToken(uid, token);
      } catch (error) {
        debugPrint('FCM token refresh failed: $error');
      }
    });

    _messageSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
    _messageTapSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleMessageTap,
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }

    _initialized = true;
  }

  Future<void> _handleAuthChange(User? user) async {
    final newUid = user?.uid;

    if (_associatedUid != null && _associatedUid != newUid) {
      final oldToken = _lastSavedToken ?? await _messaging.getToken();

      if (oldToken != null) {
        try {
          await _firestore.collection('users').doc(_associatedUid).update({
            'fcmTokens': FieldValue.arrayRemove([oldToken]),
          });
        } catch (error) {
          debugPrint('Could not remove previous FCM token: $error');
        }
      }

      _lastSavedToken = null;
    }

    _associatedUid = newUid;
    if (newUid == null) return;

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(newUid, token);
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    if (_lastSavedToken != null && _lastSavedToken != token) {
      try {
        await _firestore.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([_lastSavedToken]),
        });
      } catch (error) {
        debugPrint('Could not remove old FCM token: $error');
      }
    }

    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));

    _lastSavedToken = token;
    debugPrint('SkillBridge FCM token saved for user: $uid');
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    await _localNotifications.show(
      id: message.messageId.hashCode,
      title: title ?? 'SkillBridge',
      body: body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'skillbridge_notifications',
          'SkillBridge Notifications',
          channelDescription: 'Notifications for SkillBridge activities.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    debugPrint('SkillBridge notification tapped.');
    debugPrint('Notification data: ${message.data}');
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _messageTapSubscription?.cancel();

    _authSubscription = null;
    _tokenSubscription = null;
    _messageSubscription = null;
    _messageTapSubscription = null;
    _initialized = false;
  }
}
