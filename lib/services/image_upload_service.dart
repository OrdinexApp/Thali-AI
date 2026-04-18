import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Compresses meal photos and uploads them to the private `meal-images`
/// Storage bucket. Returns the storage path so the caller can persist it
/// alongside the meal row.
class ImageUploadService {
  ImageUploadService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  static const String bucket = 'meal-images';
  static const int _maxDimension = 1024;
  static const int _quality = 80;

  final SupabaseClient _client;

  /// Compress + upload. Returns the object path inside the bucket
  /// (e.g. `<uid>/<mealId>.jpg`). Throws on failure.
  Future<String> uploadMealImage({
    required String localPath,
    required String mealId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Cannot upload meal image without an authenticated user.');
    }

    final compressed = await _compress(localPath);
    final path = '${user.id}/$mealId.jpg';

    await _client.storage.from(bucket).uploadBinary(
          path,
          compressed,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    return path;
  }

  /// Returns a 1-hour signed URL for displaying a previously uploaded image.
  Future<String> signedUrl(String path) {
    return _client.storage.from(bucket).createSignedUrl(path, 3600);
  }

  Future<Uint8List> _compress(String localPath) async {
    final result = await FlutterImageCompress.compressWithFile(
      localPath,
      minWidth: _maxDimension,
      minHeight: _maxDimension,
      quality: _quality,
      format: CompressFormat.jpeg,
    );

    if (result != null) return result;

    // Fallback: send the raw bytes if compression isn't supported on host.
    return File(localPath).readAsBytes();
  }
}
