import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import '../../models/notification_model.dart';
import '../../services/notification_service.dart';

class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection('notifications');

  String? get currentDeveloperId => _auth.currentUser?.uid;

  Stream<List<NotificationModel>> watchMyNotifications() {
    final developerId = currentDeveloperId;
    if (developerId == null) {
      return Stream.value(<NotificationModel>[]);
    }

    return _notificationsCollection
        .where('developerId', isEqualTo: developerId)
        .snapshots()
        .map((snapshot) {
      final notifications = _documentsToNotifications(snapshot);
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

  Stream<int> watchUnreadCount() {
    return watchMyNotifications().map(
      (notifications) => notifications.where((item) => item.isUnread).length,
    );
  }

  Stream<NotificationModel?> watchNotification(String notificationId) {
    return _notificationsCollection.doc(notificationId).snapshots().map(
      (snapshot) {
        if (!snapshot.exists) return null;
        return NotificationModel.fromFirestore(snapshot);
      },
    );
  }

  Future<List<NotificationModel>> getMyNotifications() async {
    final developerId = _requireDeveloper();
    final snapshot = await _notificationsCollection
        .where('developerId', isEqualTo: developerId)
        .get();
    final notifications = _documentsToNotifications(snapshot);
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
    final snapshot = await _notificationsCollection.doc(notificationId).get();
    if (!snapshot.exists) return null;
    return NotificationModel.fromFirestore(snapshot);
  }

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

    final document = await _notificationsCollection.add({
      'developerId': developerId.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'type': type.trim(),
      'isRead': false,
      'projectId': projectId?.trim(),
      'applicationId': applicationId?.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return document.id;
  }

  Future<void> markAsRead(String notificationId) async {
    final developerId = _requireDeveloper();
    final notification = await getNotification(notificationId);
    if (notification == null) {
      throw const NotificationServiceException('Notification not found.');
    }
    if (notification.developerId != developerId) {
      throw const NotificationServiceException(
        'You cannot update this notification.',
      );
    }
    await _notificationsCollection.doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> markAsUnread(String notificationId) async {
    final developerId = _requireDeveloper();
    final notification = await getNotification(notificationId);
    if (notification == null) {
      throw const NotificationServiceException('Notification not found.');
    }
    if (notification.developerId != developerId) {
      throw const NotificationServiceException(
        'You cannot update this notification.',
      );
    }
    await _notificationsCollection.doc(notificationId).update({
      'isRead': false,
    });
  }

  Future<void> markAllAsRead() async {
    final developerId = _requireDeveloper();
    final snapshot = await _notificationsCollection
        .where('developerId', isEqualTo: developerId)
        .get();

    final unreadDocuments = snapshot.docs.where((doc) {
      return doc.data()['isRead'] != true;
    }).toList();

    // Firestore batches are limited to 500 operations.
    for (var start = 0; start < unreadDocuments.length; start += 450) {
      final batch = _firestore.batch();
      final end = (start + 450 < unreadDocuments.length)
          ? start + 450
          : unreadDocuments.length;
      for (final document in unreadDocuments.sublist(start, end)) {
        batch.update(document.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final developerId = _requireDeveloper();
    final notification = await getNotification(notificationId);
    if (notification == null) {
      throw const NotificationServiceException('Notification not found.');
    }
    if (notification.developerId != developerId) {
      throw const NotificationServiceException(
        'You cannot delete this notification.',
      );
    }
    await _notificationsCollection.doc(notificationId).delete();
  }

  /// Deletes every notification belonging to the current developer only.
  /// Uses multiple batches so accounts with many notifications are supported.
  Future<void> clearAllNotifications() async {
    final developerId = _requireDeveloper();
    while (true) {
      final snapshot = await _notificationsCollection
          .where('developerId', isEqualTo: developerId)
          .limit(450)
          .get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  String _requireDeveloper() {
    final uid = currentDeveloperId;
    if (uid == null || uid.trim().isEmpty) {
      throw const NotificationServiceException(
        'You must be logged in as a developer.',
      );
    }
    return uid;
  }

  List<NotificationModel> _documentsToNotifications(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map(NotificationModel.fromFirestore).toList();
  }
}

class NotificationServiceException implements Exception {
  const NotificationServiceException(this.message);

  final String message;

  @override
  String toString() => 'NotificationServiceException: $message';
}
