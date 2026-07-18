import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/attendance.dart';
import '../../providers/organization_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/excel_export_service.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/character_dialog.dart';

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  String? _selectedOrgId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    context.read<OrganizationProvider>().loadOrgs();
  }

  String get _orgName {
    final orgs = context.read<OrganizationProvider>().orgs;
    for (final o in orgs) {
      if (o.id == _selectedOrgId) return o.nama;
    }
    return 'data';
  }

  /// Nama file aman: spasi/karakter aneh → underscore, plus stempel tanggal.
  String _fileName(String prefix) {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final safeOrg = _orgName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return '${prefix}_${safeOrg}_$stamp.xlsx';
  }

  /// Simpan bytes Excel ke perangkat.
  ///
  /// - Android/iOS: tulis berkas nyata ke direktori aplikasi lalu buka lembar
  ///   berbagi/simpan sistem (Share). Dari sana admin bisa memilih "Simpan ke
  ///   File", Google Drive, WhatsApp, dll. — file benar-benar keluar ke
  ///   penyimpanan yang bisa diakses, bukan folder privat aplikasi.
  /// - Desktop: pakai dialog "Simpan sebagai" (FilePicker.saveFile).
  Future<void> _saveExcel(List<int> bytes, String fileName) async {
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
      // Simpan dulu ke penyimpanan sementara (butuh file fisik untuk dibagikan).
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(data, flush: true);

      final result = await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: fileName,
          ),
        ],
        subject: fileName,
        text: 'Export data $fileName',
      );

      if (!mounted) return;
      final msg = result.status == ShareResultStatus.success
          ? 'File Excel berhasil diekspor: $fileName'
          : 'File siap: $fileName';
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
        dialogTitle: 'Simpan file Excel',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
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

  Future<void> _run(Future<List<int>> Function() build, String prefix) async {
    if (_selectedOrgId == null) return;
    setState(() => _loading = true);
    AppDialogs.showLoading(context,
        kind: LoadingKind.sinkronasi, message: 'Menyiapkan file Excel...');
    try {
      final bytes = await build();
      if (bytes.isEmpty) {
        throw Exception('Tidak ada data untuk diekspor');
      }
      if (mounted) AppDialogs.hide(context);
      await _saveExcel(bytes, _fileName(prefix));
    } catch (e) {
      if (mounted) {
        AppDialogs.hide(context);
        await AppDialogs.showError(context, 'Gagal: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportMembers() => _run(() async {
        final members = await FirestoreService.getMembers(_selectedOrgId!);
        return ExcelExportService.buildMembers(members);
      }, 'anggota');

  Future<void> _exportAttendance() => _run(() async {
        final members = await FirestoreService.getMembers(_selectedOrgId!);
        final att = await FirestoreService.getAttendanceByDate(
            _selectedOrgId!, DateTime.now());
        final attMap = <String, Attendance>{for (final a in att) a.memberId: a};
        return ExcelExportService.buildAttendance(members, attMap,
            date: DateTime.now());
      }, 'absensi');

  Future<void> _exportCash() => _run(() async {
        final tx = await FirestoreService.getCashTransactions(_selectedOrgId!);
        final ex = await FirestoreService.getExpenses(_selectedOrgId!);
        return ExcelExportService.buildCash(tx, ex);
      }, 'kas');

  @override
  Widget build(BuildContext context) {
    final orgs = context.watch<OrganizationProvider>().orgs;
    return Scaffold(
      appBar: const GradientAppBar(
          title: 'Export Data', colors: [Color(0xFF26A69A), Color(0xFF00695C)]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppDropdown<String>(
          label: 'Organisasi',
          icon: Icons.business_outlined,
          value: _selectedOrgId,
          items: orgs
              .map((o) => AppDropdownItem(value: o.id, label: o.nama))
              .toList(),
          onChanged: (v) => setState(() => _selectedOrgId = v),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 15, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'File diekspor sebagai Excel (.xlsx). Pilih tujuan simpan '
                  '(mis. "Simpan ke File"/Download, Drive) saat diminta.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: ElevatedButton.icon(
            icon: const Icon(Icons.people, size: 18),
            label: const Text('Anggota'),
            onPressed:
                _selectedOrgId == null || _loading ? null : _exportMembers,
          )),
          const SizedBox(width: 8),
          Expanded(
              child: ElevatedButton.icon(
            icon: const Icon(Icons.checklist, size: 18),
            label: const Text('Absensi'),
            onPressed:
                _selectedOrgId == null || _loading ? null : _exportAttendance,
          )),
          const SizedBox(width: 8),
          Expanded(
              child: ElevatedButton.icon(
            icon: const Icon(Icons.account_balance_wallet, size: 18),
            label: const Text('Kas'),
            onPressed: _selectedOrgId == null || _loading ? null : _exportCash,
          )),
        ]),
        if (_loading) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
      ]),
    );
  }
}
