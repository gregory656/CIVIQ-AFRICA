import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});

class CloudinaryService {
  static const maxUploadBytes = 6 * 1024 * 1024;

  Future<String> uploadMedia(
    File file, {
    String folder = 'civiq/profiles',
  }) async {
    final size = await file.length();
    if (size > maxUploadBytes) {
      throw Exception('Image is too large. Choose an image under 6 MB.');
    }

    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/${Env.cloudinaryCloudName}/auto/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = Env.cloudinaryUploadPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Upload failed! (${response.statusCode}).');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = body['secure_url'] as String?;
    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception('Did not return a secure URL.');
    }
    return secureUrl;
  }
}
