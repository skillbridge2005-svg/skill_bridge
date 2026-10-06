import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification_model.dart';

class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore =
            firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>>
      get _notificationsCollection =>
          _firestore.collection('notifications');

  String? get currentDeveloperId =>
      _auth.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // NOTIFICATION STREAMS
  // ---------------------------------------------------------------------------

  /// Streams all notifications for the logged-in developer.
  ///
  /// Sorting is done locally so we don't require a Firestore
  /// composite index.
  Stream<List<NotificationModel>>
      watchMyNotifications() {
    final developerId = currentDeveloperId;

    if (developerId == null) {
      return Stream.value(
        <NotificationModel>[],
      );
    }

    return _notificationsCollection
        .where(
          'developerId',
          isEqualTo: developerId,
        )
        .snapshots()
        .map((snapshot) {
      final notifications =
          _documentsToNotifications(
        snapshot,
      );

      notifications.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;

        if (aDate == null && bDate == null) {
          return 0;
        }

        if (aDate == null) {
          return 1;
        }

        if (bDate == null) {
          return -1;
        }

        return bDate.compareTo(aDate);
      });

      return notifications;
    });
  }

  /// Streams the number of unread notifications.
  Stream<int> watchUnreadCount() {
    return watchMyNotifications().map(
      (notifications) {
        return notifications
            .where(
              (notification) =>
                  notification.isUnread,
            )
            .length;
      },
    );
  }

  /// Streams one notification.
  Stream<NotificationModel?> watchNotification(
    String notificationId,
  ) {
    return _notificationsCollection
        .doc(notificationId)
        .snapshots()
        .map(
      (snapshot) {
        if (!snapshot.exists) {
          return null;
        }

        return NotificationModel.fromFirestore(
          snapshot,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // FETCH
  // ---------------------------------------------------------------------------

  Future<List<NotificationModel>>
      getMyNotifications() async {
    final developerId =
        _requireDeveloper();

    final snapshot = await _notificationsCollection
        .where(
          'developerId',
          isEqualTo: developerId,
        )
        .get();

    final notifications =
        _documentsToNotifications(
      snapshot,
    );

    notifications.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;

      if (aDate == null && bDate == null) {
        return 0;
      }

      if (aDate == null) {
        return 1;
      }

      if (bDate == null) {
        return -1;
      }

      return bDate.compareTo(aDate);
    });

    return notifications;
  }

  Future<NotificationModel?>
      getNotification(
    String notificationId,
  ) async {
    if (notificationId.trim().isEmpty) {
      throw const NotificationServiceException(
        'Notification ID cannot be empty.',
      );
    }

    final snapshot =
        await _notificationsCollection
            .doc(notificationId)
            .get();

    if (!snapshot.exists) {
      return null;
    }

    return NotificationModel.fromFirestore(
      snapshot,
    );
  }

  // ---------------------------------------------------------------------------
  // CREATE
  // ---------------------------------------------------------------------------

  Future<String> createNotification({
    required String developerId,
    required String title,
    required String body,
    required String type,
    String? projectId,
    String? applicationId,
  }) async {
    if (developerId.trim().isEmpty) {
      throw const NotificationServiceException(
        'Developer ID cannot be empty.',
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

    final document =
        await _notificationsCollection.add({
      'developerId': developerId.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'type': type.trim(),
      'isRead': false,
      'projectId': projectId?.trim(),
      'applicationId':
          applicationId?.trim(),
      'createdAt':
          FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  // ---------------------------------------------------------------------------
  // READ / UNREAD
  // ---------------------------------------------------------------------------

  Future<void> markAsRead(
    String notificationId,
  ) async {
    final developerId =
        _requireDeveloper();

    final notification =
        await getNotification(
      notificationId,
    );

    if (notification == null) {
      throw const NotificationServiceException(
        'Notification not found.',
      );
    }

    if (notification.developerId !=
        developerId) {
      throw const NotificationServiceException(
        'You cannot update this notification.',
      );
    }

    await _notificationsCollection
        .doc(notificationId)
        .update({
      'isRead': true,
    });
  }

  Future<void> markAsUnread(
    String notificationId,
  ) async {
    final developerId =
        _requireDeveloper();

    final notification =
        await getNotification(
      notificationId,
    );

    if (notification == null) {
      throw const NotificationServiceException(
        'Notification not found.',
      );
    }

    if (notification.developerId !=
        developerId) {
      throw const NotificationServiceException(
        'You cannot update this notification.',
      );
    }

    await _notificationsCollection
        .doc(notificationId)
        .update({
      'isRead': false,
    });
  }

  Future<void> markAllAsRead() async {
    final developerId =
        _requireDeveloper();

    final snapshot =
        await _notificationsCollection
            .where(
              'developerId',
              isEqualTo: developerId,
            )
            .get();

    final unreadDocuments =
        snapshot.docs.where((doc) {
      final data = doc.data();

      return data['isRead'] != true;
    }).toList();

    if (unreadDocuments.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final document
        in unreadDocuments) {
      batch.update(
        document.reference,
        {
          'isRead': true,
        },
      );
    }

    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<void> deleteNotification(
    String notificationId,
  ) async {
    final developerId =
        _requireDeveloper();

    final notification =
        await getNotification(
      notificationId,
    );

    if (notification == null) {
      throw const NotificationServiceException(
        'Notification not found.',
      );
    }

    if (notification.developerId !=
        developerId) {
      throw const NotificationServiceException(
        'You cannot delete this notification.',
      );
    }

    await _notificationsCollection
        .doc(notificationId)
        .delete();
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _requireDeveloper() {
    final uid = currentDeveloperId;

    if (uid == null || uid.trim().isEmpty) {
      throw const NotificationServiceException(
        'You must be logged in as a developer.',
      );
    }

    return uid;
  }

  List<NotificationModel>
      _documentsToNotifications(
    QuerySnapshot<Map<String, dynamic>>
        snapshot,
  ) {
    return snapshot.docs
        .map(
          NotificationModel.fromFirestore,
        )
        .toList();
  }
}

class NotificationServiceException
    implements Exception {
  const NotificationServiceException(
    this.message,
  );

  final String message;

  @override
  String toString() =>
      'NotificationServiceException: $message';
}