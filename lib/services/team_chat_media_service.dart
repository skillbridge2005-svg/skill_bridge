
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class TeamChatMediaService {
  TeamChatMediaService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String bucket = 'team-chat-media';

  Future<String> uploadMedia({
    required String teamId,
    required String messageId,
    required File file,
    required String extension,
    required String contentType,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Please sign in to upload media.');
    }

    final path = '$teamId/$messageId/$uid.$extension';

    await _client.storage.from(bucket).upload(
      path,
      file,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: false,
      ),
    );

    return path;
  }

  Future<String> createSignedUrl(String path) {
    return _client.storage
        .from(bucket)
        .createSignedUrl(path, 3600);
  }
}
