import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/quest_question.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/character_dialog.dart';

/// Hasil parsing satu file JSON soal.
class QuestParseResult {
  final List<QuestQuestion> questions;
  final List<String> errors;
  QuestParseResult(this.questions, this.errors);
}

/// Impor soal dari file JSON.
///
/// Format yang diterima (salah satu):
/// 1. Array langsung: `[ {"kode": "SL01", ...}, ... ]`
/// 2. Objek dengan kunci `soal`: `{ "soal": [ {...}, ... ] }`
///
/// Field per soal:
/// - `kode` (String, wajib)
/// - `pertanyaan` (String, wajib)
/// - `poin` (int, opsional, default 10)
/// - `urutan` (int, opsional, default urutan dalam file)
/// - `isBackup` (bool, opsional, default false)
/// - `aktif` (bool, opsional, default true)
class QuestImport {
  QuestImport._();

  /// Contoh JSON untuk ditunjukkan ke pengguna.
  static const String sampleJson = '''[
  {
    "kode": "SL01",
    "pertanyaan": "Sebutkan struktur organisasi OSIS beserta tugasnya.",
    "poin": 10
  },
  {
    "kode": "SB01",
    "pertanyaan": "Apa makna lambang OSIS?",
    "poin": 10,
    "isBackup": true
  }
]''';

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ImportDialog(),
    );
  }

  /// Parse teks JSON menjadi daftar soal + daftar error yang informatif.
  static QuestParseResult parse(String jsonText) {
    final errors = <String>[];
    dynamic decoded;
    try {
      decoded = json.decode(jsonText);
    } catch (e) {
      return QuestParseResult([], ['File bukan JSON yang valid: $e']);
    }

    List<dynamic> rawList;
    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map && decoded['soal'] is List) {
      rawList = decoded['soal'] as List;
    } else {
      return QuestParseResult([], [
        'Struktur JSON tidak dikenali. Gunakan array soal, '
            'atau objek dengan kunci "soal".'
      ]);
    }

    if (rawList.isEmpty) {
      return QuestParseResult([], ['Tidak ada soal dalam file.']);
    }

    final questions = <QuestQuestion>[];
    for (var i = 0; i < rawList.length; i++) {
      final baris = i + 1;
      final item = rawList[i];
      if (item is! Map) {
        errors.add('Soal ke-$baris: format bukan objek.');
        continue;
      }
      final kode = (item['kode'] ?? '').toString().trim();
      final pertanyaan = (item['pertanyaan'] ?? '').toString().trim();
      if (kode.isEmpty) {
        errors.add('Soal ke-$baris: "kode" wajib diisi.');
        continue;
      }
      if (pertanyaan.isEmpty) {
        errors.add('Soal ke-$baris ($kode): "pertanyaan" wajib diisi.');
        continue;
      }

      int asInt(dynamic v, int fallback) {
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v.trim()) ?? fallback;
        return fallback;
      }

      bool asBool(dynamic v, bool fallback) {
        if (v is bool) return v;
        if (v is String) {
          final s = v.trim().toLowerCase();
          if (s == 'true' || s == '1' || s == 'ya') return true;
          if (s == 'false' || s == '0' || s == 'tidak') return false;
        }
        return fallback;
      }

      questions.add(QuestQuestion(
        kode: kode,
        pertanyaan: pertanyaan,
        poin: asInt(item['poin'], 10),
        urutan: asInt(item['urutan'], i),
        isBackup: asBool(item['isBackup'], false),
        aktif: asBool(item['aktif'], true),
      ));
    }

    return QuestParseResult(questions, errors);
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  String? _fileName;
  List<QuestQuestion> _parsed = [];
  List<String> _errors = [];
  bool _loading = false;
  bool _saving = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    if (file.size > 5 * 1024 * 1024) {
      setState(() {
        _errors = ['File terlalu besar. Maksimal 5MB.'];
        _fileName = file.name;
        _parsed = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _fileName = file.name;
      _parsed = [];
      _errors = [];
    });

    try {
      final text = utf8.decode(file.bytes!);
      final res = QuestImport.parse(text);
      setState(() {
        _parsed = res.questions;
        _errors = res.errors;
      });
    } catch (e) {
      setState(() => _errors = ['Gagal membaca file: $e']);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    if (_parsed.isEmpty) return;
    setState(() => _saving = true);
    final actor = context.read<AuthProvider>().user;
    try {
      final count = await FirestoreService.importQuestQuestions(_parsed);
      await FirestoreService.logAction(
        userId: actor?.id ?? '',
        userNama: actor?.nama ?? '',
        aksi: 'CREATE',
        tabel: 'quest_questions',
        deskripsi: 'Impor $count soal quest dari JSON',
      );
      if (mounted) Navigator.pop(context);
      if (mounted) {
        await AppDialogs.showSuccess(context, '$count soal berhasil diimpor');
      }
    } catch (e) {
      if (mounted) await AppDialogs.showError(context, 'Gagal mengimpor: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _fileName != null;
    return AlertDialog(
      title: const Text('Impor Soal (JSON)'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pilih file .json berisi array soal. Tiap soal minimal '
                  'punya "kode" dan "pertanyaan".',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                _sampleBox(),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loading || _saving ? null : _pickFile,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(hasFile ? 'Ganti File' : 'Pilih File JSON'),
                ),
                if (hasFile) ...[
                  const SizedBox(height: 8),
                  Text(
                    _fileName!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_loading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_parsed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _resultBanner(
                    Icons.check_circle_outline,
                    AppColors.success,
                    '${_parsed.length} soal siap diimpor',
                  ),
                ],
                if (_errors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _resultBanner(
                    Icons.error_outline,
                    AppColors.danger,
                    '${_errors.length} soal dilewati',
                  ),
                  const SizedBox(height: 8),
                  ..._errors.take(10).map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $e',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.danger)),
                        ),
                      ),
                  if (_errors.length > 10)
                    Text('… dan ${_errors.length - 10} lainnya',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textHint)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: (_parsed.isEmpty || _saving) ? null : _import,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Impor${_parsed.isEmpty ? '' : ' (${_parsed.length})'}'),
        ),
      ],
    );
  }

  Widget _sampleBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contoh format:',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          SelectableText(
            QuestImport.sampleJson,
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _resultBanner(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }
}
