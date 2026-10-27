import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/developer_repository.dart';

class DeveloperRepositoryService {
  DeveloperRepositoryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in to manage your repositories.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _repositoriesCollection =>
      _firestore
          .collection('developerProfiles')
          .doc(_userId)
          .collection('repositories');

  Future<String> createRepository({
    required String name,
    required String url,
    required String description,
    List<String> technologies = const [],
  }) async {
    final document = _repositoriesCollection.doc();
    await document.set({
      'name': name.trim(),
      'url': url.trim(),
      'description': description.trim(),
      'technologies': technologies,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return document.id;
  }

  Stream<List<DeveloperRepository>> watchRepositories() {
    return _repositoriesCollection.snapshots().map((snapshot) {
      final repositories = snapshot.docs
          .map(DeveloperRepository.fromFirestore)
          .toList();
      repositories.sort((a, b) {
        final aDate =
            a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return repositories;
    });
  }

  Future<void> updateRepository({
    required String repositoryId,
    required String name,
    required String url,
    required String description,
    List<String> technologies = const [],
  }) async {
    final document = _repositoriesCollection.doc(repositoryId);
    final existing = await document.get();
    if (!existing.exists) {
      throw StateError('Repository not found.');
    }

    await document.update({
      'name': name.trim(),
      'url': url.trim(),
      'description': description.trim(),
      'technologies': technologies,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRepository(String repositoryId) async {
    final document = _repositoriesCollection.doc(repositoryId);
    final existing = await document.get();
    if (!existing.exists) {
      throw StateError('Repository not found.');
    }
    await document.delete();
  }
}
