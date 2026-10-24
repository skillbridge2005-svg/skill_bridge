import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  SupabaseStorageService._();

  static final SupabaseStorageService instance = SupabaseStorageService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  static const String bucketName = 'skillbridge';

  /// Uploads an image and returns its public URL.

  Future<String> uploadProjectImage({
    required Uint8List bytes,
    required String fileName,
    required String projectId,
    required String contentType,
  }) async {
    final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final storagePath =
        'project-designs/$projectId/${DateTime.now().microsecondsSinceEpoch}_$safeFileName';

    try {
      debugPrint('Supabase upload starting');
      debugPrint('Bucket: $bucketName');
      debugPrint('Path: $storagePath');
      debugPrint('Image size: ${bytes.length} bytes');
      debugPrint('Content type: $contentType');

      await _supabase.storage
          .from(bucketName)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );

      final url = _supabase.storage.from(bucketName).getPublicUrl(storagePath);

      debugPrint('Supabase upload successful: $url');
      return url;
    } catch (error, stackTrace) {
      debugPrint('Supabase image upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}
