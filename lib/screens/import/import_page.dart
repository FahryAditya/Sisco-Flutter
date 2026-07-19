import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/organization_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../utils/kelas_helper.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/character_dialog.dart';

class ImportError {
  final int rowNumber;
  final String field;
  final String value;
  final String error;

  ImportError({
    required this.rowNumber,
    required this.field,
    required this.value,
    required this.error,
  });
}

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  String? _selectedOrgId;
  bool _loading = false;
  bool _importing = false;

  List<Map<String, String?>> _parsedRows = [];
  String? _fileName;
  String? _error;

  List<ImportError> _validationErrors = [];
  int? _successCount;
  int? _failCount;

  @override
  void initState() {
    super.initState();
    context.read<OrganizationProvider>().loadOrgs();
  }

  void _resetState() {
    setState(() {
      _error = null;
      _validationErrors = [];
      _successCount = null;
      _failCount = null;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    if (file.size > 5 * 1024 * 1024) {
      setState(() => _error = 'File terlalu besar. Maksimal 5MB.');
      return;
    }

    setState(() {
      _fileName = file.name;
      _error = null;
      _parsedRows = [];
      _validationErrors = [];
      _successCount = null;
      _failCount = null;
      _loading = true;
    });

    try {
      final ext = file.name.split('.').last.toLowerCase();
      List<Map<String, String?>> rows;
      if (ext == 'csv') {
        rows = _parseCsv(file.bytes!);
      } else {
        rows = _parseExcel(file.bytes!);
      }
      setState(() => _parsedRows = rows);
    } catch (e, stack) {
      setState(() => _error = 'Gagal membaca file: $e');
      debugPrint('ImportPage._pickFile error: $e\n$stack');
    }
    setState(() => _loading = false);
  }

  void _splitNamaKelas(Map<String, String?> row) {
    final nama = row['nama'];
    final kelas = row['kelas'];
    if (nama == null || kelas != null || nama.isEmpty) return;
    final tingkat = RegExp(r'\b(X|XI|XII|10|11|12)\b');
    final match = tingkat.firstMatch(nama.toUpperCase());
    if (match == null) return;
    final splitAt = match.start;
    row['nama'] = nama.substring(0, splitAt).trim();
    row['kelas'] = nama.substring(splitAt).trim();
  }

  List<Map<String, String?>> _parseCsv(Uint8List bytes) {
    final text = utf8.decode(bytes);
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) throw Exception('File kosong');
    if (lines.length < 2) throw Exception('File harus memiliki header dan minimal 1 baris data');

    final headers = lines[0].split(',').map((h) => h.trim().toLowerCase()).toList();
    final colMap = _mapColumns(headers);
    final combined = colMap['nama'] == colMap['kelas'];

    final rows = <Map<String, String?>>[];
    for (var i = 1; i < lines.length; i++) {
      final values = lines[i].split(',').map((v) => v.trim()).toList();
      final row = <String, String?>{};
      for (final entry in colMap.entries) {
        final idx = headers.indexOf(entry.value);
        row[entry.key] = idx >= 0 && idx < values.length ? values[idx] : null;
      }
      if (combined) _splitNamaKelas(row);
      if ((row['nama'] ?? '').trim().isNotEmpty) rows.add(row);
    }
    return rows;
  }

  /// Some xlsx files store relationship paths as absolute (`/xl/worksheets/sheet1.xml`)
  /// but the excel package expects relative (`xl/worksheets/sheet1.xml`) and prepends `xl/`,
  /// causing `findFile('xl//xl/worksheets/sheet1.xml')` → null → null-assertion crash.
  /// This method strips the leading `/` so the package can find the worksheet file.
  Uint8List _fixExcelRelsPaths(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      bool patched = false;

      final relsFile = archive.findFile('xl/_rels/workbook.xml.rels');
      if (relsFile != null) {
        relsFile.decompress();
        final content = utf8.decode(relsFile.content);
        final doc = XmlDocument.parse(content);

        for (final rel in doc.findAllElements('Relationship')) {
          final target = rel.getAttribute('Target');
          if (target != null && target.startsWith('/')) {
            // Strip leading "/" — the package already prepends "xl/"
            // e.g. "/xl/worksheets/sheet1.xml" -> "xl/worksheets/sheet1.xml"
            //      (package builds "xl/xl/worksheets/sheet1.xml" — wrong)
            // Strip leading "/" AND "xl/" prefix if present
            // e.g. "/xl/worksheets/sheet1.xml" -> "worksheets/sheet1.xml"
            //      (package builds "xl/worksheets/sheet1.xml" — correct)
            var fixed = target.substring(1);
            if (fixed.startsWith('xl/')) {
              fixed = fixed.substring(3);
            }
            rel.setAttribute('Target', fixed);
            patched = true;
          }
        }

        if (patched) {
          final newBytes = utf8.encode(doc.toXmlString());
          archive.addFile(ArchiveFile('xl/_rels/workbook.xml.rels', newBytes.length, newBytes));
        }
      }

      if (!patched) return bytes;

      final outList = ZipEncoder().encode(archive);
      if (outList != null) return Uint8List.fromList(outList);
      return bytes;
    } catch (_) {
      return bytes;
    }
  }

  String _getCellValueString(CellValue? cellValue) {
    if (cellValue == null) return '';
    try {
      return cellValue.toString();
    } catch (_) {
      return '';
    }
  }

  List<Map<String, String?>> _parseExcel(Uint8List bytes) {
    final fixed = _fixExcelRelsPaths(bytes);
    final excel = Excel.decodeBytes(fixed);
    if (excel.tables.isEmpty) throw Exception('File Excel tidak memiliki sheet');

    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];
    if (sheet == null) throw Exception('Sheet "$sheetName" tidak dapat dibaca');

    if (sheet.rows.isEmpty) throw Exception('Sheet "$sheetName" kosong');
    if (sheet.rows.length < 2) {
      throw Exception('File harus memiliki header dan minimal 1 baris data');
    }

    final headerRow = sheet.rows[0];
    final headers = <String>[];
    for (var c = 0; c < headerRow.length; c++) {
      final cell = headerRow[c];
      final val = cell?.value;
      headers.add(_getCellValueString(val).trim().toLowerCase());
    }

    final colMap = _mapColumns(headers);
    if (!colMap.containsKey('nama')) {
      throw Exception(
        'Kolom "Nama" tidak ditemukan di header. '
        'Pastikan file memiliki kolom "Nama", "Kelas", dll.',
      );
    }
    final combined = colMap['nama'] == colMap['kelas'];

    final rows = <Map<String, String?>>[];
    for (var i = 1; i < sheet.rows.length; i++) {
      try {
        final rowData = sheet.rows[i];
        if (rowData.isEmpty) continue;

        final row = <String, String?>{};
        for (final entry in colMap.entries) {
          final idx = headers.indexOf(entry.value);
          if (idx < 0 || idx >= rowData.length) {
            row[entry.key] = null;
            continue;
          }
          final cell = rowData[idx];
          final val = cell?.value;
          row[entry.key] = _getCellValueString(val).trim();
        }
        if (combined) _splitNamaKelas(row);
        if ((row['nama'] ?? '').isNotEmpty) rows.add(row);
      } catch (e) {
        debugPrint('ImportPage._parseExcel row $i error: $e');
      }
    }
    return rows;
  }

  Map<String, String> _mapColumns(List<String> headers) {
    final map = <String, String>{};
    for (final h in headers) {
      final hl = h.toLowerCase().trim();
      if (!hl.contains('nama') && !hl.contains('kelas') && !hl.contains('nis') && !hl.contains('email') && !hl.contains('jabatan') && !hl.contains('posisi') && !hl.contains('induk')) {
        continue;
      }

      final isNama = hl.contains('nama');
      final isKelas = hl.contains('kelas');
      final isNis = hl.contains('nis') || hl.contains('induk');
      final isEmail = hl.contains('email') || hl.contains('gmail');
      final isJabatan = hl.contains('jabatan') || hl.contains('posisi');

      if (isNama && isKelas) {
        if (!map.containsKey('nama')) map['nama'] = h;
        if (!map.containsKey('kelas')) map['kelas'] = h;
      } else if (isNama && !map.containsKey('nama')) {
        map['nama'] = h;
      } else if (isKelas && !map.containsKey('kelas')) {
        map['kelas'] = h;
      } else if (isNis && !map.containsKey('nis')) {
        map['nis'] = h;
      } else if (isEmail && !map.containsKey('email')) {
        map['email'] = h;
      } else if (isJabatan && !map.containsKey('jabatan')) {
        map['jabatan'] = h;
      }
    }
    return map;
  }

  // ===== VALIDATION =====
  List<ImportError> _validateData() {
    final errors = <ImportError>[];
    for (var i = 0; i < _parsedRows.length; i++) {
      final row = _parsedRows[i];
      final rowNum = i + 1;

      final nama = (row['nama'] ?? '').trim();
      if (nama.isEmpty) {
        errors.add(ImportError(rowNumber: rowNum, field: 'nama', value: '', error: 'Nama tidak boleh kosong'));
      } else if (nama.length < 3) {
        errors.add(ImportError(rowNumber: rowNum, field: 'nama', value: nama, error: 'Nama minimal 3 karakter'));
      } else if (nama.length > 100) {
        errors.add(ImportError(rowNumber: rowNum, field: 'nama', value: nama, error: 'Nama maksimal 100 karakter'));
      }

      final kelas = (row['kelas'] ?? '').trim();
      if (kelas.isEmpty) {
        errors.add(ImportError(rowNumber: rowNum, field: 'kelas', value: '', error: 'Kelas tidak boleh kosong'));
      } else if (!_validateKelas(kelas)) {
        final saran = KelasHelper.suggest(kelas);
        errors.add(ImportError(
          rowNumber: rowNum,
          field: 'kelas',
          value: kelas,
          error: saran != null
              ? 'Kelas tidak valid. Maksud Anda "$saran"? (contoh: ${KelasHelper.contohKelas})'
              : 'Jurusan tidak dikenal. Kelas valid: ${KelasHelper.contohKelas}',
        ));
      }
    }
    return errors;
  }

  bool _validateKelas(String kelas) => KelasHelper.isValid(kelas);

  String _transformKelas(String kelas) => KelasHelper.normalize(kelas) ?? kelas.trim().toUpperCase();

  // ===== EDIT / DELETE PREVIEW =====
  int get _invalidCount {
    var n = 0;
    for (final row in _parsedRows) {
      final k = (row['kelas'] ?? '').trim();
      final nama = (row['nama'] ?? '').trim();
      if (nama.isEmpty || k.isEmpty || !KelasHelper.isValid(k)) n++;
    }
    return n;
  }

  Future<void> _deleteRow(int index) async {
    final row = _parsedRows[index];
    final confirm = await AppDialogs.showConfirm(context, message: 'Baris ${index + 1} (${row['nama'] ?? '-'}) akan dihapus dari daftar import.', confirmLabel: 'Hapus', danger: true);
    if (confirm != true) return;
    setState(() {
      _parsedRows.removeAt(index);
      // Reset status hasil import sebelumnya karena data berubah.
      _successCount = null;
      _failCount = null;
      _validationErrors = [];
    });
  }

  Future<void> _editRow(int index) async {
    final row = _parsedRows[index];
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _EditRowDialog(index: index, row: row),
    );

    if (result != null) {
      setState(() {
        _parsedRows[index] = {...row, ...result};
        // Data berubah -> reset status hasil import sebelumnya.
        _successCount = null;
        _failCount = null;
        _validationErrors = [];
      });
    }
  }

  // ===== IMPORT =====
  Future<void> _import() async {
    if (_selectedOrgId == null || _parsedRows.isEmpty) return;

    _resetState();
    setState(() => _importing = true);

    final user = context.read<AuthProvider>().user;
    final orgName = context.read<OrganizationProvider>().orgs
        .where((o) => o.id == _selectedOrgId)
        .map((o) => o.nama)
        .firstOrNull ?? '';

    // 1. Client-side validation
    final errors = _validateData();
    if (errors.isNotEmpty) {
      setState(() {
        _validationErrors = errors;
        _successCount = 0;
        _failCount = errors.length;
        _importing = false;
      });
      _showFeedbackDialog(
        success: false,
        message: 'Validasi data gagal. Perbaiki error sebelum import.',
      );
      return;
    }

    // 2. Permission check
    if (user == null) {
      setState(() => _importing = false);
      _showFeedbackDialog(success: false, message: 'Anda harus login terlebih dahulu.');
      return;
    }
    if (!user.canExportImport) {
      setState(() => _importing = false);
      _showFeedbackDialog(success: false, message: 'Anda tidak punya akses import data.');
      return;
    }
    if (!user.orgIds.contains(_selectedOrgId) && !user.isAdministrator) {
      setState(() => _importing = false);
      _showFeedbackDialog(
        success: false,
        message: 'Anda hanya bisa import untuk organisasi/eskul Anda sendiri.',
      );
      return;
    }

    // 3. Batch write
    int success = 0;
    final errList = <ImportError>[];

    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < _parsedRows.length; i++) {
      final row = _parsedRows[i];
      final rowNum = i + 1;
      final nama = (row['nama'] ?? '').trim();

      if (nama.isEmpty) {
        errList.add(ImportError(rowNumber: rowNum, field: 'nama', value: '', error: 'Nama kosong'));
        continue;
      }

      try {
        final docRef = FirebaseFirestore.instance.collection('members').doc();
        batch.set(docRef, {
          'organizationId': _selectedOrgId,
          'name': nama,
          'kelas': _transformKelas(row['kelas'] ?? ''),
          'nis': (row['nis'] ?? '').trim().isEmpty ? null : row['nis']?.trim(),
          'email': (row['email'] ?? '').trim().isEmpty ? null : row['email']?.trim(),
          'jabatan': (row['jabatan'] ?? '').trim().isEmpty ? null : row['jabatan']?.trim(),
          'status': 'ACTIVE',
          'level': 1,
          'exp': 0,
          'progress': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        success++;
      } catch (e) {
        errList.add(ImportError(rowNumber: rowNum, field: 'general', value: nama, error: e.toString()));
      }
    }

    try {
      await batch.commit();

      await FirestoreService.logAction(
        userId: user.id,
        userNama: user.nama,
        aksi: 'IMPORT',
        tabel: 'members',
        deskripsi: 'Import $success/${_parsedRows.length} anggota ke $orgName ($_fileName)',
      );
    } catch (e) {
      errList.add(ImportError(
        rowNumber: 0,
        field: 'general',
        value: '',
        error: 'Gagal menyimpan batch: $e',
      ));
      success = 0;
    }

    setState(() {
      _successCount = success;
      _failCount = errList.length;
      _validationErrors = errList;
      _importing = false;
    });

    if (success == _parsedRows.length) {
      _showFeedbackDialog(
        success: true,
        message: 'Import berhasil! $success anggota ditambahkan ke $orgName.',
      );
    } else if (success > 0) {
      _showFeedbackDialog(
        success: false,
        message: 'Import sebagian. $success berhasil, ${errList.length} gagal.',
      );
    } else {
      _showFeedbackDialog(
        success: false,
        message: 'Import gagal. ${errList.length} data tidak dapat diproses.',
      );
    }
  }

  void _showFeedbackDialog({required bool success, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          success ? 'Import Berhasil' : 'Import Gagal',
          style: TextStyle(color: success ? AppColors.success : AppColors.danger),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              if (_successCount != null && _failCount != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Total: ${_parsedRows.length} | Berhasil: $_successCount | Gagal: $_failCount',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                ),
              ],
              if (_validationErrors.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Detail Error:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._validationErrors.take(10).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Row ${e.rowNumber}: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      Expanded(
                        child: Text(
                          '${e.field}: ${e.error}',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )),
                if (_validationErrors.length > 10)
                  Text(
                    '... dan ${_validationErrors.length - 10} error lainnya',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          if (!success)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text('Coba Lagi'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgs = context.watch<OrganizationProvider>().orgs;

    return Scaffold(
      appBar: const GradientAppBar(title: 'Import Data Anggota', colors: [Color(0xFF5C6BC0), Color(0xFF303F9F)]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppDropdown<String>(
            label: 'Organisasi Tujuan',
            icon: Icons.business_outlined,
            value: _selectedOrgId,
            items: orgs.map((o) => AppDropdownItem(value: o.id, label: o.nama)).toList(),
            onChanged: (v) => setState(() => _selectedOrgId = v),
          ),
          const SizedBox(height: 20),

          InkWell(
            onTap: _loading || _importing
                ? null
                : () {
                    if (_selectedOrgId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pilih organisasi tujuan terlebih dahulu')),
                      );
                      return;
                    }
                    _pickFile();
                  },
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border, width: 2, strokeAlign: BorderSide.strokeAlignOutside),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primaryLight.withAlpha(60),
              ),
              child: Column(
                children: [
                  Icon(
                    _fileName != null ? Icons.check_circle : Icons.upload_file,
                    size: 48,
                    color: _fileName != null ? AppColors.success : AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _fileName != null ? _fileName! : 'Klik untuk pilih file Excel/CSV',
                    style: GoogleFonts.plusJakartaSans(
                      color: _fileName != null ? AppColors.success : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '.xlsx, .xls, .csv (maks 5MB)',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: AppColors.danger.withAlpha(20),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: AppColors.danger))),
                  ],
                ),
              ),
            ),
          ],

          if (_loading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],

          // Preview
          if (_parsedRows.isNotEmpty && !_loading) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_parsedRows.length} data ditemukan',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (_successCount != null)
                  Chip(
                    label: Text(
                      '$_successCount/${_parsedRows.length} berhasil',
                      style: GoogleFonts.plusJakartaSans(
                        color: _failCount == 0 ? AppColors.success : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: (_failCount == 0 ? AppColors.success : AppColors.warning).withAlpha(30),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Info edit + jumlah data bermasalah
            Builder(builder: (_) {
              final invalid = _invalidCount;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (invalid > 0 ? AppColors.warning : AppColors.info).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      invalid > 0 ? Icons.warning_amber_rounded : Icons.edit_note,
                      size: 20,
                      color: invalid > 0 ? AppColors.warning : AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        invalid > 0
                            ? '$invalid baris perlu diperbaiki. Ketuk ikon edit untuk memperbaiki langsung — tak perlu ubah file Excel.'
                            : 'Semua data valid. Anda tetap bisa ketuk ikon edit untuk mengubah sebelum import.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: invalid > 0 ? AppColors.warning : AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Nama', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Kelas', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('NIS', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _parsedRows.take(50).toList().asMap().entries.map((e) {
                      final i = e.key;
                      final row = e.value;
                      final kelas = (row['kelas'] ?? '').trim();
                      final kelasInvalid = kelas.isEmpty || !KelasHelper.isValid(kelas);
                      return DataRow(
                        color: kelasInvalid
                            ? WidgetStatePropertyAll(AppColors.danger.withAlpha(20))
                            : null,
                        cells: [
                          DataCell(Text('${i + 1}')),
                          DataCell(Text(row['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                kelas.isEmpty ? '-' : kelas,
                                style: TextStyle(
                                  color: kelasInvalid ? AppColors.danger : null,
                                  fontWeight: kelasInvalid ? FontWeight.w600 : null,
                                ),
                              ),
                              if (kelasInvalid) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
                              ],
                            ],
                          )),
                          DataCell(Text(row['nis'] ?? '-')),
                          DataCell(Text(row['email'] ?? '-')),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                color: AppColors.primary,
                                tooltip: 'Edit',
                                onPressed: _importing ? null : () => _editRow(i),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                color: AppColors.danger,
                                tooltip: 'Hapus',
                                onPressed: _importing ? null : () => _deleteRow(i),
                              ),
                            ],
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            if (_parsedRows.length > 50)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Menampilkan 50 dari ${_parsedRows.length} data',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textHint),
                ),
              ),

            const SizedBox(height: 16),

            // Import button
            ElevatedButton.icon(
              onPressed: _importing ? null : _import,
              icon: _importing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_upload),
              label: Text(_importing ? 'Mengimport...' : 'Import ${_parsedRows.length} Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            // Validation errors
            if (_validationErrors.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: AppColors.danger.withAlpha(15),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_validationErrors.length} Data Bermasalah',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppColors.danger),
                      ),
                      const SizedBox(height: 8),
                      ..._validationErrors.take(10).map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Row ${e.rowNumber}: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.danger)),
                            Expanded(
                              child: Text(
                                '${e.field}: ${e.error}',
                                style: TextStyle(fontSize: 12, color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      )),
                      if (_validationErrors.length > 10)
                        Text('...dan ${_validationErrors.length - 10} lainnya',
                          style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                    ],
                  ),
                ),
              ),
            ],

            // Success banner
            if (_successCount != null && _validationErrors.isEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: AppColors.success.withAlpha(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$_successCount dari ${_parsedRows.length} data berhasil diimport!',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppColors.success),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Dialog edit satu baris data import.
///
/// Dibuat sebagai [StatefulWidget] tersendiri agar [TextEditingController]
/// dikelola & di-dispose oleh State-nya sendiri (setelah widget benar-benar
/// dilepas dari tree), bukan segera setelah dialog ditutup — menghindari error
/// "TextEditingController was used after being disposed".
class _EditRowDialog extends StatefulWidget {
  final int index;
  final Map<String, String?> row;
  const _EditRowDialog({required this.index, required this.row});

  @override
  State<_EditRowDialog> createState() => _EditRowDialogState();
}

class _EditRowDialogState extends State<_EditRowDialog> {
  late final TextEditingController _namaC;
  late final TextEditingController _kelasC;
  late final TextEditingController _nisC;
  late final TextEditingController _emailC;
  late final TextEditingController _jabatanC;

  @override
  void initState() {
    super.initState();
    _namaC = TextEditingController(text: widget.row['nama'] ?? '');
    _kelasC = TextEditingController(text: widget.row['kelas'] ?? '');
    _nisC = TextEditingController(text: widget.row['nis'] ?? '');
    _emailC = TextEditingController(text: widget.row['email'] ?? '');
    _jabatanC = TextEditingController(text: widget.row['jabatan'] ?? '');
  }

  @override
  void dispose() {
    _namaC.dispose();
    _kelasC.dispose();
    _nisC.dispose();
    _emailC.dispose();
    _jabatanC.dispose();
    super.dispose();
  }

  InputDecoration _deco(String label, {String? helper, String? error, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      errorText: error,
      suffixIcon: suffix,
      isDense: true,
    );
  }

  void _save() {
    if (_namaC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama tidak boleh kosong')),
      );
      return;
    }
    final kelasInput = _kelasC.text.trim();
    // Simpan kelas dalam bentuk ternormalisasi bila valid, agar seragam.
    final kelasFinal = KelasHelper.normalize(kelasInput) ?? kelasInput;
    Navigator.pop(context, <String, String>{
      'nama': _namaC.text.trim(),
      'kelas': kelasFinal,
      'nis': _nisC.text.trim(),
      'email': _emailC.text.trim(),
      'jabatan': _jabatanC.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final kelasRaw = _kelasC.text.trim();
    final kelasValid = kelasRaw.isNotEmpty && KelasHelper.isValid(kelasRaw);
    final saran = kelasValid ? null : KelasHelper.suggest(kelasRaw);

    return AlertDialog(
      title: Text('Edit Baris ${widget.index + 1}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _namaC,
              decoration: _deco('Nama'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kelasC,
              decoration: _deco(
                'Kelas',
                helper: kelasValid ? 'Format kelas valid' : 'Contoh: ${KelasHelper.contohKelas}',
                error: (kelasRaw.isEmpty || kelasValid)
                    ? null
                    : (saran != null ? 'Tidak valid. Saran: "$saran"' : 'Jurusan tidak dikenal'),
                suffix: (!kelasValid && saran != null)
                    ? TextButton(
                        onPressed: () {
                          _kelasC.text = saran;
                          setState(() {});
                        },
                        child: const Text('Pakai'),
                      )
                    : (kelasValid
                        ? Icon(Icons.check_circle, color: AppColors.success, size: 20)
                        : null),
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(controller: _nisC, decoration: _deco('NIS (opsional)'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(controller: _emailC, decoration: _deco('Email (opsional)'), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            TextField(controller: _jabatanC, decoration: _deco('Jabatan (opsional)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}
