import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/developer_note.dart';

class DeveloperNotesService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DeveloperNotesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _notesCollection =>
      _firestore.collection('developer_notes');

  String get _userId {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to access your notes.');
    }

    return user.uid;
  }

  // CREATE NOTE
  Future<String> createNote({
    required String title,
    required String category,
    required String content,
    Map<String, dynamic> details = const {},
    List<String> tags = const [],
  }) async {
    final userId = _userId;

    final document = _notesCollection.doc();

    await document.set({
      'userId': userId,
      'title': title.trim(),
      'category': category,
      'content': content.trim(),
      'details': details,
      'tags': tags,
      'isPinned': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  // READ NOTES IN REAL TIME
  Stream<List<DeveloperNote>> watchNotes() {
    final userId = _userId;

    return _notesCollection.where('userId', isEqualTo: userId).snapshots().map((
      snapshot,
    ) {
      final notes = snapshot.docs.map(DeveloperNote.fromFirestore).toList();

      // Pinned notes appear first.
      notes.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }

        final aDate =
            a.updatedAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final bDate =
            b.updatedAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      });

      return notes;
    });
  }

  // UPDATE NOTE
  Future<void> updateNote({
    required String noteId,
    required String title,
    required String category,
    required String content,
    Map<String, dynamic> details = const {},
    List<String> tags = const [],
  }) async {
    final userId = _userId;

    final document = _notesCollection.doc(noteId);
    final existing = await document.get();

    if (!existing.exists || existing.data()?['userId'] != userId) {
      throw StateError('Note not found or access denied.');
    }

    await document.update({
      'title': title.trim(),
      'category': category,
      'content': content.trim(),
      'details': details,
      'tags': tags,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // DELETE NOTE
  Future<void> deleteNote(String noteId) async {
    final userId = _userId;

    final document = _notesCollection.doc(noteId);
    final existing = await document.get();

    if (!existing.exists || existing.data()?['userId'] != userId) {
      throw StateError('Note not found or access denied.');
    }

    await document.delete();
  }

  // PIN OR UNPIN NOTE
  Future<void> togglePin({
    required String noteId,
    required bool isPinned,
  }) async {
    final userId = _userId;

    final document = _notesCollection.doc(noteId);
    final existing = await document.get();

    if (!existing.exists || existing.data()?['userId'] != userId) {
      throw StateError('Note not found or access denied.');
    }

    await document.update({
      'isPinned': !isPinned,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // SEARCH NOTES
  // Searches titles, content, and tags locally.
  List<DeveloperNote> searchNotes(List<DeveloperNote> notes, String query) {
    final searchText = query.trim().toLowerCase();

    if (searchText.isEmpty) {
      return notes;
    }

    return notes.where((note) {
      return note.title.toLowerCase().contains(searchText) ||
          note.content.toLowerCase().contains(searchText) ||
          note.tags.any((tag) => tag.toLowerCase().contains(searchText)) ||
          note.categoryLabel.toLowerCase().contains(searchText);
    }).toList();
  }
}
