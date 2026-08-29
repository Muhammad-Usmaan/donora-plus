import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Handles file uploads and signed URL retrieval via Supabase Storage.
class SupabaseStorageService {
  const SupabaseStorageService(this._client);

  final SupabaseClient _client;
  static const _uuid = Uuid();

  /// Uploads [bytes] to [bucket] under a unique path.
  ///
  /// Returns the public URL by default. Set [returnPath] to `true` for
  /// private buckets where a public URL is not accessible (the caller
  /// can later use [getSignedUrl] to create time-limited links).
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
    bool returnPath = false,
  }) async {
    final uniquePath = '$path/${_uuid.v4()}';
    await _client.storage
        .from(bucket)
        .uploadBinary(uniquePath, bytes, fileOptions: FileOptions(contentType: contentType));
    if (returnPath) return uniquePath;
    return _client.storage.from(bucket).getPublicUrl(uniquePath);
  }

  /// Returns a time-limited signed URL for a private object.
  Future<String> getSignedUrl({
    required String bucket,
    required String path,
    Duration expiresIn = const Duration(hours: 1),
  }) async {
    final response = await _client.storage
        .from(bucket)
        .createSignedUrl(path, expiresIn.inSeconds);
    return response;
  }

  /// Deletes an object from the given [bucket].
  Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    await _client.storage.from(bucket).remove([path]);
  }
}
