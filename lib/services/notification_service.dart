import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification_model.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection('notifications');

  /// Current logged-in user's UID.
  String? get currentUserId => _auth.currentUser?.uid;

  /// Backward compatibility for existing developer-side code.
  String? get currentDeveloperId => currentUserId;

  // ---------------------------------------------------------------------------
  // DELETE ALL
  // ---------------------------------------------------------------------------

  Future<void> Function() get deleteAllNotifications => () async {
    final uid = _requireUser();

    final snapshot = await _notificationsCollection
        .where('developerId', isEqualTo: uid)
        .get();

    for (var start = 0; start < snapshot.docs.length; start += 450) {
      final end = start + 450 < snapshot.docs.length
          ? start + 450
          : snapshot.docs.length;

      final batch = _firestore.batch();

      for (final document in snapshot.docs.sublist(start, end)) {
        batch.delete(document.reference);
      }

      await batch.commit();
    }
  };

  Future<void> Function() get clearAllNotifications => deleteAllNotifications;

  // ---------------------------------------------------------------------------
  // NOTIFICATION STREAMS
  // ---------------------------------------------------------------------------

  /// Streams notifications for either a client or a developer.
  ///
  /// New notifications store developerId as a backward-compatible
  /// recipient UID. Older developer notifications continue to work.
  Stream<List<NotificationModel>> watchMyNotifications() {
    final uid = currentUserId;

    if (uid == null || uid.trim().isEmpty) {
      return Stream.value(<NotificationModel>[]);
    }

    return _notificationsCollection
        .where('developerId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .where((doc) => doc.data()['isDismissed'] != true)
              .map(NotificationModel.fromFirestore)
              .toList();

          notifications.sort((a, b) {
            final aDate = a.createdAt;
            final bDate = b.createdAt;

            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;

            return bDate.compareTo(aDate);
          });

          return notifications;
        });
  }

  /// Number of unread, non-dismissed notifications.
  Stream<int> watchUnreadCount() {
    return watchMyNotifications().map(
      (items) => items.where((item) => item.isUnread).length,
    );
  }

  /// Streams one notification only if it belongs to the current user.
  Stream<NotificationModel?> watchNotification(String notificationId) {
    final uid = currentUserId;

    if (uid == null || uid.trim().isEmpty) {
      return Stream.value(null);
    }

    return _notificationsCollection.doc(notificationId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return null;

      final data = snapshot.data();
      if (data == null || !_isOwnedByUser(data, uid)) {
        return null;
      }

      if (data['isDismissed'] == true) return null;

      return NotificationModel.fromFirestore(snapshot);
    });
  }

  // ---------------------------------------------------------------------------
  // FETCH
  // ---------------------------------------------------------------------------

  Future<List<NotificationModel>> getMyNotifications() async {
    final uid = _requireUser();

    final snapshot = await _notificationsCollection
        .where('developerId', isEqualTo: uid)
        .get();

    final notifications = snapshot.docs
        .where((doc) => doc.data()['isDismissed'] != true)
        .map(NotificationModel.fromFirestore)
        .toList();

    notifications.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return notifications;
  }

  Future<NotificationModel?> getNotification(String notificationId) async {
    if (notificationId.trim().isEmpty) {
      throw const NotificationServiceException(
        'Notification ID cannot be empty.',
      );
    }

    final uid = _requireUser();
    final snapshot = await _notificationsCollection.doc(notificationId).get();

    if (!snapshot.exists) return null;

    final data = snapshot.data();
    if (data == null || !_isOwnedByUser(data, uid)) {
      throw const NotificationServiceException(
        'You cannot access this notification.',
      );
    }

    return NotificationModel.fromFirestore(snapshot);
  }

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  /// Creates a notification for any recipient in the app.
  ///
  /// Use recipientId + recipientRole for new client/developer features.
  /// developerId is retained so existing developer calls do not break.
  Future<String> createNotification({
    String? recipientId,
    String? recipientRole,
    String? developerId,
    required String title,
    required String body,
    required String type,
    String? projectId,
    String? applicationId,
    String? meetingId,
    String? teamId,
    String? chatId,
    String? otherUid,
    String? otherName,
  }) async {
    final newRecipientId = (recipientId ?? developerId ?? '').trim();

    if (newRecipientId.isEmpty) {
      throw const NotificationServiceException('Recipient ID cannot be empty.');
    }

    if (recipientId != null &&
        developerId != null &&
        recipientId.trim() != developerId.trim()) {
      throw const NotificationServiceException(
        'Recipient ID and developer ID do not match.',
      );
    }

    if (title.trim().isEmpty) {
      throw const NotificationServiceException(
        'Notification title cannot be empty.',
      );
    }

    if (body.trim().isEmpty) {
      throw const NotificationServiceException(
        'Notification body cannot be empty.',
      );
    }

    if (type.trim().isEmpty) {
      throw const NotificationServiceException(
        'Notification type cannot be empty.',
      );
    }

    final role = (recipientRole ?? (developerId != null ? 'developer' : 'user'))
        .trim()
        .toLowerCase();

    final document = await _notificationsCollection.add({
      // Standard fields for the shared notification system.
      'recipientId': newRecipientId,
      'recipientRole': role,

      // Compatibility field:
      // existing queries and NotificationModel use developerId.
      // It represents the recipient UID for new notifications.
      'developerId': newRecipientId,

      'title': title.trim(),
      'body': body.trim(),
      'type': type.trim(),
      'isRead': false,
      'isDismissed': false,

      'projectId': _clean(projectId),
      'applicationId': _clean(applicationId),
      'meetingId': _clean(meetingId),
      'teamId': _clean(teamId),
      'chatId': _clean(chatId),
      'otherUid': _clean(otherUid),
      'otherName': _clean(otherName),

      'createdAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  // ---------------------------------------------------------------------------
  // READ / UNREAD
  // ---------------------------------------------------------------------------

  Future<void> markAsRead(String notificationId) async {
    await _updateOwnedNotification(notificationId, {'isRead': true});
  }

  Future<void> markAsUnread(String notificationId) async {
    await _updateOwnedNotification(notificationId, {'isRead': false});
  }

  Future<void> markAllAsRead() async {
    final uid = _requireUser();

    final snapshot = await _notificationsCollection
        .where('developerId', isEqualTo: uid)
        .get();

    final unreadDocuments = snapshot.docs.where((doc) {
      final data = doc.data();

      return data['isDismissed'] != true && data['isRead'] != true;
    }).toList();

    for (var start = 0; start < unreadDocuments.length; start += 450) {
      final end = start + 450 < unreadDocuments.length
          ? start + 450
          : unreadDocuments.length;

      final batch = _firestore.batch();

      for (final document in unreadDocuments.sublist(start, end)) {
        batch.update(document.reference, {'isRead': true});
      }

      await batch.commit();
    }
  }

  // ---------------------------------------------------------------------------
  // DISMISS
  // ---------------------------------------------------------------------------

  /// Hides a notification without permanently deleting its record.
  Future<void> dismissNotification(String notificationId) async {
    await _updateOwnedNotification(notificationId, {
      'isDismissed': true,
      'dismissedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<void> deleteNotification(String notificationId) async {
    final uid = _requireUser();

    final reference = _notificationsCollection.doc(notificationId);
    final snapshot = await reference.get();

    if (!snapshot.exists) {
      throw const NotificationServiceException('Notification not found.');
    }

    final data = snapshot.data();

    if (data == null || !_isOwnedByUser(data, uid)) {
      throw const NotificationServiceException(
        'You cannot delete this notification.',
      );
    }

    await reference.delete();
  }

  // ---------------------------------------------------------------------------
  // CLIENT NOTIFICATIONS
  // Keeps the existing users/{uid}/notifications path unchanged.
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _clientNotificationsFor(
    String uid,
  ) {
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  /// Streams the logged-in user's existing Client notifications.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  watchMyClientNotifications() {
    final uid = currentUserId;

    if (uid == null || uid.trim().isEmpty) {
      return Stream.value(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    }

    return _clientNotificationsFor(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((document) => document.data()['isDismissed'] != true)
              .toList(),
        );
  }

  /// Marks a notification belonging to the current Client as read.
  Future<void> markMyClientNotificationAsRead(String notificationId) async {
    await _updateMyClientNotification(notificationId, {'isRead': true});
  }

  /// Dismisses a Client notification without permanently deleting it.
  Future<void> dismissMyClientNotification(String notificationId) async {
    await _updateMyClientNotification(notificationId, {
      'isDismissed': true,
      'dismissedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateMyClientNotification(
    String notificationId,
    Map<String, dynamic> updates,
  ) async {
    if (notificationId.trim().isEmpty) {
      throw const NotificationServiceException(
        'Notification ID cannot be empty.',
      );
    }

    final uid = _requireUser();

    // Use the authenticated user's own nested collection.
    // Do not compare developerId here: on Client notifications,
    // that field can identify the developer who triggered the event.
    final reference = _clientNotificationsFor(uid).doc(notificationId);

    final snapshot = await reference.get();

    if (!snapshot.exists) {
      throw const NotificationServiceException(
        'Client notification not found.',
      );
    }

    await reference.update(updates);
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Future<void> _updateOwnedNotification(
    String notificationId,
    Map<String, dynamic> updates,
  ) async {
    if (notificationId.trim().isEmpty) {
      throw const NotificationServiceException(
        'Notification ID cannot be empty.',
      );
    }

    final uid = _requireUser();
    final reference = _notificationsCollection.doc(notificationId);
    final snapshot = await reference.get();

    if (!snapshot.exists) {
      throw const NotificationServiceException('Notification not found.');
    }

    final data = snapshot.data();

    if (data == null || !_isOwnedByUser(data, uid)) {
      throw const NotificationServiceException(
        'You cannot update this notification.',
      );
    }

    await reference.update(updates);
  }

  bool _isOwnedByUser(Map<String, dynamic> data, String uid) {
    // recipientId supports the shared schema.
    // developerId supports existing records and older code.
    return data['recipientId'] == uid || data['developerId'] == uid;
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) return null;

    return cleaned;
  }

  String _requireUser() {
    final uid = currentUserId;

    if (uid == null || uid.trim().isEmpty) {
      throw const NotificationServiceException(
        'You must be logged in to access notifications.',
      );
    }

    return uid;
  }
}

class NotificationServiceException implements Exception {
  const NotificationServiceException(this.message);

  final String message;

  @override
  String toString() => 'NotificationServiceException: $message';
}
