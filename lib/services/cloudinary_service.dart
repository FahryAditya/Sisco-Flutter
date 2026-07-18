import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static String get _cloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get _uploadPreset =>
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  static Future<String> uploadImage(File file) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = _uploadPreset;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('Upload timeout (60 detik)'),
    );

    final response = await streamedResponse.stream.bytesToString();
    final data = jsonDecode(response) as Map<String, dynamic>;

    if (streamedResponse.statusCode != 200) {
      throw Exception(data['error']['message'] ?? 'Gagal upload ke Cloudinary');
    }

    return data['secure_url'] as String;
  }

  static Future<String> uploadBytes(List<int> bytes, String fileName) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = _uploadPreset;
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
    ));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('Upload timeout (60 detik)'),
    );

    final response = await streamedResponse.stream.bytesToString();
    final data = jsonDecode(response) as Map<String, dynamic>;

    if (streamedResponse.statusCode != 200) {
      throw Exception(data['error']['message'] ?? 'Gagal upload ke Cloudinary');
    }

    return data['secure_url'] as String;
  }
}
