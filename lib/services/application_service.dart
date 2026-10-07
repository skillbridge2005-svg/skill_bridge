import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/application_model.dart';
import 'notification_service.dart';

/// Service responsible for all developer application-related
/// Firestore operations.
class ApplicationService {
  ApplicationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    NotificationService? notificationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _notificationService =
            notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NotificationService _notificationService;

  CollectionReference<Map<String, dynamic>>
      get _applicationsCollection {
    return _firestore.collection('applications');
  }

  User? get currentUser => _auth.currentUser;

  String? get currentDeveloperId => _auth.currentUser?.uid;

  // ===========================================================================
  // APPLICATION STREAMS
  // ===========================================================================

  /// Streams all applications submitted by the current developer.
  Stream<List<ApplicationModel>> watchMyApplications() {
    final developerId = currentDeveloperId;

    if (developerId == null) {
      return Stream<List<ApplicationModel>>.value(
        <ApplicationModel>[],
      );
    }

    return _applicationsCollection
        .where(
          'developerId',
          isEqualTo: developerId,
        )
        .snapshots()
        .map(_documentsToApplications);
  }

  /// Streams a single application.
  Stream<ApplicationModel?> watchApplication(
    String applicationId,
  ) {
    return _applicationsCollection
        .doc(applicationId)
        .snapshots()
        .map(
      (snapshot) {
        if (!snapshot.exists) {
          return null;
        }

        return ApplicationModel.fromFirestore(snapshot);
      },
    );
  }

  // ===========================================================================
  // FETCHING
  // ===========================================================================

  /// Fetches all applications submitted by the current developer.
  Future<List<ApplicationModel>> getMyApplications() async {
    final developerId = _requireDeveloper();

    final snapshot = await _applicationsCollection
        .where(
          'developerId',
          isEqualTo: developerId,
        )
        .get();

    return _documentsToApplications(snapshot);
  }

  /// Fetches one application by ID.
  Future<ApplicationModel?> getApplication(
    String applicationId,
  ) async {
    if (applicationId.trim().isEmpty) {
      return null;
    }

    final snapshot = await _applicationsCollection
        .doc(applicationId)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    return ApplicationModel.fromFirestore(snapshot);
  }

  /// Fetches all applications for a specific project.
  ///
  /// This will be useful later for the client-side application review.
  Future<List<ApplicationModel>> getProjectApplications(
    String projectId,
  ) async {
    if (projectId.trim().isEmpty) {
      return <ApplicationModel>[];
    }

    final snapshot = await _applicationsCollection
        .where(
          'projectId',
          isEqualTo: projectId,
        )
        .get();

    return _documentsToApplications(snapshot);
  }

  // ===========================================================================
  // DUPLICATE CHECK
  // ===========================================================================

  /// Checks whether the current developer has already applied
  /// to a specific project.
  Future<bool> hasAppliedToProject(
    String projectId,
  ) async {
    final developerId = currentDeveloperId;

    if (developerId == null) {
      return false;
    }

    final snapshot = await _firestore
        .collection('applications')
        .where(
          'developerId',
          isEqualTo: developerId,
        )
        .where(
          'projectId',
          isEqualTo: projectId,
        )
        .limit(10)
        .get();

    if (snapshot.docs.isEmpty) {
      return false;
    }

    // A withdrawn application should not block
    // the developer from applying again.
    for (final doc in snapshot.docs) {
      final data = doc.data();

      final status = (data['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (status != 'withdrawn') {
        return true;
      }
    }

    return false;
  }

  /// Returns an existing application for the current developer
  /// and project.
  Future<ApplicationModel?> getMyApplicationForProject(
    String projectId,
  ) async {
    final developerId = currentDeveloperId;

    if (developerId == null || projectId.trim().isEmpty) {
      return null;
    }

    final snapshot = await _applicationsCollection
        .where(
          'developerId',
          isEqualTo: developerId,
        )
        .where(
          'projectId',
          isEqualTo: projectId,
        )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return ApplicationModel.fromFirestore(
      snapshot.docs.first,
    );
  }

  // ===========================================================================
  // CREATE APPLICATION
  // ===========================================================================

  /// Creates a new application for the current developer.
  ///
  /// Returns the newly created application ID.
  Future<String> createApplication({
    required String projectId,
    required String clientId,
    required String coverLetter,
    required double proposedBudget,
    required String estimatedDuration,
  }) async {
    final developerId = _requireDeveloper();

    if (projectId.trim().isEmpty) {
      throw const ApplicationServiceException(
        'Project ID cannot be empty.',
      );
    }

    if (clientId.trim().isEmpty) {
      throw const ApplicationServiceException(
        'Client ID cannot be empty.',
      );
    }

    if (coverLetter.trim().isEmpty) {
      throw const ApplicationServiceException(
        'Cover letter cannot be empty.',
      );
    }

    if (estimatedDuration.trim().isEmpty) {
      throw const ApplicationServiceException(
        'Estimated duration cannot be empty.',
      );
    }

    if (proposedBudget <= 0) {
      throw const ApplicationServiceException(
        'Proposed budget must be greater than zero.',
      );
    }

    // Prevent duplicate applications.
    final alreadyApplied = await hasAppliedToProject(
      projectId,
    );

    if (alreadyApplied) {
      throw const ApplicationServiceException(
        'You have already applied to this project.',
      );
    }

    final now = FieldValue.serverTimestamp();

    final document = await _applicationsCollection.add({
      'developerId': developerId,
      'projectId': projectId.trim(),
      'clientId': clientId.trim(),
      'coverLetter': coverLetter.trim(),
      'proposedBudget': proposedBudget,
      'estimatedDuration': estimatedDuration.trim(),
      'status': 'pending',
      'createdAt': now,
      'updatedAt': now,
    });

    // Create a notification for the developer.
    //
    // Notification failure should not cause the already-created
    // application to fail.
    try {
      await _notificationService.createNotification(
        developerId: developerId,
        title: 'Application submitted',
        body:
            'Your application has been submitted successfully.',
        type: 'application',
        projectId: projectId.trim(),
        applicationId: document.id,
      );
    } catch (_) {
      // Intentionally ignored so the application submission
      // remains successful even if notification creation fails.
    }

    return document.id;
  }

  // ===========================================================================
  // UPDATE APPLICATION
  // ===========================================================================

  /// Updates selected application fields.
  ///
  /// This method is intentionally restricted to developer-editable
  /// fields for now.
  Future<void> updateApplication(
    String applicationId,
    Map<String, dynamic> updates,
  ) async {
    final developerId = _requireDeveloper();

    if (applicationId.trim().isEmpty) {
      throw const ApplicationServiceException(
        'Application ID cannot be empty.',
      );
    }

    if (updates.isEmpty) {
      return;
    }

    final application = await getApplication(
      applicationId,
    );

    if (application == null) {
      throw const ApplicationServiceException(
        'Application not found.',
      );
    }

    if (application.developerId != developerId) {
      throw const ApplicationServiceException(
        'You are not allowed to modify this application.',
      );
    }

    final safeUpdates = Map<String, dynamic>.from(
      updates,
    );

    // Do not allow the developer to change ownership
    // or the project/client relationship.
    safeUpdates.remove('developerId');
    safeUpdates.remove('projectId');
    safeUpdates.remove('clientId');

    safeUpdates['updatedAt'] =
        FieldValue.serverTimestamp();

    await _applicationsCollection
        .doc(applicationId)
        .update(safeUpdates);
  }

  // ===========================================================================
  // WITHDRAW APPLICATION
  // ===========================================================================

  /// Withdraws an application submitted by the current developer.
  Future<void> withdrawApplication(
    String applicationId,
  ) async {
    final developerId = _requireDeveloper();

    if (applicationId.trim().isEmpty) {
      throw const ApplicationServiceException(
        'Application ID cannot be empty.',
      );
    }

    final application = await getApplication(
      applicationId,
    );

    if (application == null) {
      throw const ApplicationServiceException(
        'Application not found.',
      );
    }

    if (application.developerId != developerId) {
      throw const ApplicationServiceException(
        'You are not allowed to withdraw this application.',
      );
    }

    if (!application.canWithdraw) {
      throw const ApplicationServiceException(
        'This application can no longer be withdrawn.',
      );
    }

    await _applicationsCollection
        .doc(applicationId)
        .update({
      'status': 'withdrawn',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===========================================================================
  // APPLICATION STATUS
  // ===========================================================================

  /// Updates an application status.
  ///
  /// This is mainly intended for the future client-side review
  /// workflow. Developer UI should normally use withdrawApplication().
  Future<void> updateApplicationStatus(
    String applicationId,
    String status,
  ) async {
    if (applicationId.trim().isEmpty) {
      throw const ApplicationServiceException(
        'Application ID cannot be empty.',
      );
    }

    final normalizedStatus =
        status.trim().toLowerCase();

    const validStatuses = {
      'pending',
      'shortlisted',
      'rejected',
      'accepted',
      'withdrawn',
    };

    if (!validStatuses.contains(normalizedStatus)) {
      throw ApplicationServiceException(
        'Invalid application status: $status',
      );
    }

    await _applicationsCollection
        .doc(applicationId)
        .update({
      'status': normalizedStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===========================================================================
  // COUNTS
  // ===========================================================================

  /// Returns the number of applications submitted by
  /// the current developer.
  Future<int> getMyApplicationCount() async {
    final developerId = currentDeveloperId;

    if (developerId == null) {
      return 0;
    }

    final snapshot = await _applicationsCollection
        .where(
          'developerId',
          isEqualTo: developerId,
        )
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  /// Returns the number of applications for a project.
  Future<int> getProjectApplicationCount(
    String projectId,
  ) async {
    if (projectId.trim().isEmpty) {
      return 0;
    }

    final snapshot = await _applicationsCollection
        .where(
          'projectId',
          isEqualTo: projectId,
        )
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String _requireDeveloper() {
    final developerId = currentDeveloperId;

    if (developerId == null ||
        developerId.trim().isEmpty) {
      throw const ApplicationServiceException(
        'No authenticated developer account was found.',
      );
    }

    return developerId;
  }

  List<ApplicationModel> _documentsToApplications(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map(ApplicationModel.fromFirestore)
        .toList();
  }
}

/// Exception thrown by ApplicationService when an
/// application operation cannot be completed.
class ApplicationServiceException implements Exception {
  final String message;

  const ApplicationServiceException(this.message);

  @override
  String toString() => message;
}