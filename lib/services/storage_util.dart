import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageUtil {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<String?> tryGetDownloadURL(Reference ref) async {
    try {
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        debugPrint('StorageUtil: File tidak ditemukan — ${ref.fullPath}');
        return null;
      }
      rethrow;
    }
  }

  static Future<String?> tryGetDownloadURLFromPath(String path) async {
    return tryGetDownloadURL(_storage.ref(path));
  }

  static Future<bool> exists(Reference ref) async {
    try {
      await ref.getDownloadURL();
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return false;
      rethrow;
    }
  }

  static Future<bool> existsPath(String path) async {
    return exists(_storage.ref(path));
  }

  static Future<String?> uploadAndGetURL({
    required String path,
    required List<int> data,
  }) async {
    try {
      final ref = _storage.ref(path);
      await ref.putData(Uint8List.fromList(data));
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint('StorageUtil: Upload gagal — $path (${e.code}: ${e.message})');
      return null;
    }
  }
}
