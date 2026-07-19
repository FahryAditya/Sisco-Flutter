import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'backup_service.dart';
import 'storage_util.dart';

class DriveBackupService {
  static final DriveBackupService instance = DriveBackupService._();
  DriveBackupService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _backupPrefix = 'backups';
  static const _metaCollection = 'backup_meta';

  Future<BackupResult> buildBackup({String? exportedBy}) {
    return BackupService.buildBackup(exportedBy: exportedBy);
  }

  Future<String?> uploadToCloud({
    required String json,
    required String fileName,
  }) async {
    final path = '$_backupPrefix/$fileName';
    final bytes = utf8.encode(json);
    final url = await StorageUtil.uploadAndGetURL(
      path: path,
      data: bytes,
    );
    if (url == null) return null;

    await _db.collection(_metaCollection).doc(fileName).set({
      'fileName': fileName,
      'uploadedAt': FieldValue.serverTimestamp(),
      'sizeBytes': bytes.length,
      'downloadUrl': url,
    });

    return url;
  }

  Future<List<CloudBackupMeta>> listCloudBackups() async {
    final snap = await _db
        .collection(_metaCollection)
        .orderBy('uploadedAt', descending: true)
        .get();
    return snap.docs
        .map((d) => CloudBackupMeta.fromMap(d.data(), d.id))
        .toList();
  }

  Future<String?> downloadFromCloud(String fileName) async {
    try {
      final ref = _storage.ref('$_backupPrefix/$fileName');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await ref.writeToFile(file);
      return file.path;
    } catch (e) {
      debugPrint('Download backup error: $e');
      return null;
    }
  }

  Future<bool> deleteFromCloud(String fileName) async {
    try {
      await _storage.ref('$_backupPrefix/$fileName').delete();
      await _db.collection(_metaCollection).doc(fileName).delete();
      return true;
    } catch (e) {
      debugPrint('Delete backup error: $e');
      return false;
    }
  }

  Future<String?> shareToDevice(String json, String fileName) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(json, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json', name: fileName)],
        subject: fileName,
        text: 'Backup data $fileName',
      );
      return file.path;
    } catch (e) {
      debugPrint('Share backup error: $e');
      return null;
    }
  }
}

class CloudBackupMeta {
  final String id;
  final String fileName;
  final DateTime? uploadedAt;
  final int sizeBytes;
  final String downloadUrl;

  CloudBackupMeta({
    required this.id,
    required this.fileName,
    this.uploadedAt,
    required this.sizeBytes,
    required this.downloadUrl,
  });

  factory CloudBackupMeta.fromMap(Map<String, dynamic> map, String docId) {
    return CloudBackupMeta(
      id: docId,
      fileName: map['fileName'] as String? ?? docId,
      uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate(),
      sizeBytes: map['sizeBytes'] as int? ?? 0,
      downloadUrl: map['downloadUrl'] as String? ?? '',
    );
  }

  String get sizeLabel {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
