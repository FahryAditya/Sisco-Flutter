import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/auth_provider.dart';
import '../../services/backup_service.dart';
import '../../services/drive_backup_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/character_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_app_bar.dart';

/// Backup seluruh data Firestore ke satu file JSON.
///
/// Fitur khusus Administrator. Menyimpan file dengan pola yang sama seperti
/// halaman Export: Android/iOS lewat share sheet sistem, desktop lewat dialog
/// "Simpan sebagai".
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _loading = false;
  BackupResult? _lastResult;
  String? _lastFileName;

  String _fileName() {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'sisko_backup_$stamp.json';
  }

  Future<void> _confirmAndBackup() async {
    final ok = await AppDialogs.showConfirm(
      context,
      message: 'Buat cadangan data anggota, absensi, kas, dan penghargaan '
          'ke satu file JSON? Proses ini bisa memakan waktu pada data '
          'yang besar.',
      confirmLabel: 'Backup',
    );
    if (!ok || !mounted) return;
    await _runBackup();
  }

  Future<void> _runBackup() async {
    setState(() => _loading = true);
    AppDialogs.showLoading(context,
        kind: LoadingKind.sinkronasi,
        message: 'Mengumpulkan seluruh data...');
    try {
      final email = context.read<AuthProvider>().user?.email;
      final result = await BackupService.buildBackup(exportedBy: email);
      if (result.total == 0) {
        throw Exception('Tidak ada data untuk dibackup');
      }
      if (mounted) AppDialogs.hide(context);

      final fileName = _fileName();
      final bytes = utf8.encode(result.json);
      await _saveJson(bytes, fileName);
      if (mounted) {
        setState(() {
          _lastResult = result;
          _lastFileName = fileName;
        });
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.hide(context);
        await AppDialogs.showError(context, 'Gagal membuat backup: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmCloudBackup() async {
    final ok = await AppDialogs.showConfirm(
      context,
      message: 'Upload backup ke cloud Firebase Storage?\n'
          'Data tersimpan aman dan bisa diunduh kapan saja.',
      confirmLabel: 'Upload ke Cloud',
    );
    if (!ok || !mounted) return;
    await _runCloudBackup();
  }

  Future<void> _runCloudBackup() async {
    setState(() => _loading = true);
    AppDialogs.showLoading(context,
        kind: LoadingKind.sinkronasi,
        message: 'Mengupload ke cloud...');
    try {
      final email = context.read<AuthProvider>().user?.email;
      final result = await BackupService.buildBackup(exportedBy: email);
      if (result.total == 0) throw Exception('Tidak ada data untuk dibackup');
      final fileName = _fileName();
      final url = await DriveBackupService.instance.uploadToCloud(
        json: result.json,
        fileName: fileName,
      );
      if (url == null) throw Exception('Gagal mengunggah backup ke penyimpanan cloud');
      if (mounted) {
        AppDialogs.hide(context);
        setState(() {
          _lastResult = result;
          _lastFileName = fileName;
        });
        await AppDialogs.showSuccess(context, 'Backup cloud berhasil: $fileName');
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.hide(context);
        await AppDialogs.showError(context, 'Gagal backup cloud: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadFromCloud(String fileName) async {
    AppDialogs.showLoading(context,
        kind: LoadingKind.cariData,
        message: 'Mengunduh $fileName...');
    try {
      final path = await DriveBackupService.instance.downloadFromCloud(fileName);
      if (mounted) AppDialogs.hide(context);
      if (path != null && mounted) {
        await AppDialogs.showSuccess(context, 'Tersimpan di: $path');
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.hide(context);
        await AppDialogs.showError(context, 'Gagal mengunduh: $e');
      }
    }
  }

  Future<void> _deleteCloudBackup(String fileName) async {
    final ok = await AppDialogs.showConfirm(
      context,
      message: 'Hapus backup "$fileName" dari cloud?',
      confirmLabel: 'Hapus',
    );
    if (!ok) return;
    final success = await DriveBackupService.instance.deleteFromCloud(fileName);
    if (mounted) {
      if (success) {
        AppDialogs.showSuccess(context, 'Backup dihapus');
      } else {
        AppDialogs.showError(context, 'Gagal menghapus backup');
      }
    }
  }

  Widget _cloudBackupsSection(BuildContext context) {
    return FutureBuilder<List<CloudBackupMeta>>(
      future: DriveBackupService.instance.listCloudBackups(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ));
        }
        final backups = snap.data ?? [];
        if (backups.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.cloud_done, size: 20, color: AppColors.success),
                const SizedBox(width: 8),
                Text('Backup Cloud',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w700,
                  )),
                const Spacer(),
                Text('${backups.length} file',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppColors.textHint)),
              ]),
              const Divider(height: 20),
              ...backups.map((b) => ListTile(
                dense: true,
                leading: const Icon(Icons.cloud_download_outlined, size: 20),
                title: Text(b.fileName, style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                subtitle: Text(b.sizeLabel, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textHint)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download, size: 18),
                      onPressed: () => _downloadFromCloud(b.fileName),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                      onPressed: () => _deleteCloudBackup(b.fileName),
                    ),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  /// Simpan bytes JSON ke perangkat (pola sama seperti ExportPage).
  Future<void> _saveJson(List<int> bytes, String fileName) async {
    final data = Uint8List.fromList(bytes);
    if (Platform.isAndroid || Platform.isIOS) {
      await _saveMobile(data, fileName);
    } else {
      await _saveDesktop(data, fileName);
    }
  }

  /// Mobile: tulis file lalu tampilkan share sheet sistem.
  Future<void> _saveMobile(Uint8List data, String fileName) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(data, flush: true);

      final result = await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'application/json',
            name: fileName,
          ),
        ],
        subject: fileName,
        text: 'Backup data $fileName',
      );

      if (!mounted) return;
      final msg = result.status == ShareResultStatus.success
          ? 'Backup berhasil disimpan: $fileName'
          : 'File backup siap: $fileName';
      await AppDialogs.showSuccess(context, msg);
    } catch (e) {
      if (mounted) {
        await AppDialogs.showError(context, 'Gagal menyimpan file: $e');
      }
    }
  }

  /// Desktop: dialog "Simpan sebagai"; tulis manual bila plugin hanya
  /// mengembalikan path tanpa menulis berkas.
  Future<void> _saveDesktop(Uint8List data, String fileName) async {
    try {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan file backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: data,
      );

      if (savedPath == null) return; // User membatalkan dialog.

      final f = File(savedPath);
      if (!await f.exists() || await f.length() == 0) {
        await f.writeAsBytes(data, flush: true);
      }

      if (mounted) {
        await AppDialogs.showSuccess(context, 'Tersimpan: $savedPath');
      }
    } catch (e) {
      // Cadangan: simpan ke folder dokumen aplikasi.
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(data, flush: true);
        if (mounted) {
          await AppDialogs.showSuccess(context, 'Tersimpan di: ${file.path}');
        }
      } catch (e2) {
        if (mounted) {
          await AppDialogs.showError(context, 'Gagal menyimpan file: $e2');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Guard: fitur ini khusus Administrator (pola sama seperti AdminPage).
    if (!auth.isAdmin) {
      return Scaffold(
        appBar: const GradientAppBar(
          title: 'Backup Data',
          colors: [Color(0xFF5E35B1), Color(0xFF311B92)],
        ),
        body: EmptyState(
          icon: Icons.lock_outline,
          message: 'Akses khusus Administrator',
          subtitle: 'Hanya administrator yang dapat membuat cadangan data.',
        ),
      );
    }

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Backup Data',
        colors: [Color(0xFF5E35B1), Color(0xFF311B92)],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _infoCard(context),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Backup Sekarang'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5E35B1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _loading ? null : _confirmAndBackup,
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.cloud_upload),
          label: const Text('Backup ke Cloud (Firebase)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1ABC9C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _loading ? null : _confirmCloudBackup,
        ),
        if (_loading) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_lastResult != null && !_loading) _summaryCard(context),
        const SizedBox(height: 24),
        _cloudBackupsSection(context),
      ]),
    );
  }

  /// Kartu penjelasan fitur.
  Widget _infoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF5E35B1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.backup_outlined,
                  color: Color(0xFF5E35B1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Backup Seluruh Data',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            'Menyimpan data inti (daftar anggota beserta URL foto & EXP, '
            'absensi anggota, uang kas masuk/keluar, dan penghargaan) ke satu '
            'file JSON. Simpan file di tempat aman sebagai arsip cadangan.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.info_outline, size: 15, color: AppColors.textHint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Saat diminta, pilih tujuan simpan (mis. "Simpan ke File", '
                'Download, atau Drive).',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  /// Kartu ringkasan hasil backup terakhir.
  Widget _summaryCard(BuildContext context) {
    final result = _lastResult!;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Backup terakhir',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${result.total} dokumen',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ]),
            if (_lastFileName != null) ...[
              const SizedBox(height: 4),
              Text(
                _lastFileName!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
            const Divider(height: 24),
            ..._sortedCounts(result.counts).map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      e.key,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${e.value}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, int>> _sortedCounts(Map<String, int> counts) {
    final list = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return list;
  }
}
