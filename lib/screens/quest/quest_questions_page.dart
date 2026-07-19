import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/quest_question.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/character_dialog.dart';
import '../../widgets/empty_state.dart';
import 'quest_import.dart';

/// Manajemen soal Airlangga QR Quest: daftar, tambah, edit, hapus, dan lihat QR.
/// Soal berupa esai; peserta menyalin soal dari web dan menjawab di kertas.
class QuestQuestionsPage extends StatelessWidget {
  const QuestQuestionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Soal Quest'),
        actions: [
          IconButton(
            tooltip: 'Impor JSON',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: () => QuestImport.show(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Soal'),
      ),
      body: StreamBuilder<List<QuestQuestion>>(
        stream: FirestoreService.questQuestionsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Gagal memuat soal: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          if (all.isEmpty) {
            return EmptyState(
              icon: Icons.quiz_outlined,
              message: 'Belum ada soal',
              subtitle: 'Tambahkan soal esai. Tiap soal punya QR sendiri\n'
                  'yang bisa dipindai peserta untuk membuka pertanyaan.',
              actionLabel: 'Tambah Soal',
              onAction: () => _openForm(context),
            );
          }

          final main = all.where((q) => !q.isBackup).toList();
          final backup = all.where((q) => q.isBackup).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              if (main.isNotEmpty) ...[
                _sectionLabel('SOAL UTAMA (${main.length})'),
                ...main.map((q) => _questionCard(context, q)),
              ],
              if (backup.isNotEmpty) ...[
                _sectionLabel('SOAL CADANGAN (${backup.length})'),
                ...backup.map((q) => _questionCard(context, q)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _questionCard(BuildContext context, QuestQuestion q) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (q.aktif ? AppColors.primary : AppColors.textHint)
              .withAlpha(30),
          child: Text(
            q.kode.replaceAll(RegExp(r'[^0-9]'), ''),
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: q.aktif ? AppColors.primary : AppColors.textHint,
              fontSize: 13,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              q.kode,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Text('${q.poin} poin',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (!q.aktif) ...[
              const SizedBox(width: 8),
              Icon(Icons.visibility_off_outlined,
                  size: 14, color: AppColors.textHint),
            ],
          ],
        ),
        subtitle: Text(
          q.pertanyaan,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'edit':
                _openForm(context, existing: q);
                break;
              case 'delete':
                _confirmDelete(context, q);
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Edit'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.danger),
                title: Text('Hapus', style: TextStyle(color: AppColors.danger)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: () => _openForm(context, existing: q),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, QuestQuestion q) async {
    final ok = await AppDialogs.showConfirm(
      context,
      message: 'Hapus soal ${q.kode}? Tindakan ini tidak bisa dibatalkan.',
      confirmLabel: 'Hapus',
      cancelLabel: 'Batal',
    );
    if (!ok || !context.mounted) return;
    final actor = context.read<AuthProvider>().user;
    try {
      await FirestoreService.deleteQuestQuestion(q.id);
      await FirestoreService.logAction(
        userId: actor?.id ?? '',
        userNama: actor?.nama ?? '',
        aksi: 'DELETE',
        tabel: 'quest_questions',
        recordId: q.id,
        deskripsi: 'Menghapus soal quest ${q.kode}',
      );
    } catch (e) {
      if (context.mounted) {
        await AppDialogs.showError(context, 'Gagal menghapus: $e');
      }
    }
  }

  Future<void> _openForm(BuildContext context, {QuestQuestion? existing}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _QuestionForm(existing: existing),
    );
  }
}

/// Form tambah/edit soal.
class _QuestionForm extends StatefulWidget {
  final QuestQuestion? existing;

  const _QuestionForm({this.existing});

  @override
  State<_QuestionForm> createState() => _QuestionFormState();
}

class _QuestionFormState extends State<_QuestionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _kode;
  late final TextEditingController _pertanyaan;
  late final TextEditingController _poin;
  late final TextEditingController _urutan;
  late bool _isBackup;
  late bool _aktif;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final q = widget.existing;
    _kode = TextEditingController(text: q?.kode ?? '');
    _pertanyaan = TextEditingController(text: q?.pertanyaan ?? '');
    _poin = TextEditingController(text: (q?.poin ?? 10).toString());
    _urutan = TextEditingController(text: (q?.urutan ?? 0).toString());
    _isBackup = q?.isBackup ?? false;
    _aktif = q?.aktif ?? true;
  }

  @override
  void dispose() {
    _kode.dispose();
    _pertanyaan.dispose();
    _poin.dispose();
    _urutan.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final actor = context.read<AuthProvider>().user;
    final model = QuestQuestion(
      id: widget.existing?.id ?? '',
      kode: _kode.text.trim(),
      pertanyaan: _pertanyaan.text.trim(),
      poin: int.tryParse(_poin.text.trim()) ?? 0,
      urutan: int.tryParse(_urutan.text.trim()) ?? 0,
      isBackup: _isBackup,
      aktif: _aktif,
    );
    try {
      if (_isEdit) {
        await FirestoreService.updateQuestQuestion(model.id, model);
      } else {
        await FirestoreService.createQuestQuestion(model);
      }
      await FirestoreService.logAction(
        userId: actor?.id ?? '',
        userNama: actor?.nama ?? '',
        aksi: _isEdit ? 'UPDATE' : 'CREATE',
        tabel: 'quest_questions',
        recordId: model.id,
        deskripsi: '${_isEdit ? 'Mengubah' : 'Menambah'} soal quest ${model.kode}',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        await AppDialogs.showError(context, 'Gagal menyimpan: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Soal' : 'Tambah Soal'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _kode,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Kode',
                            hintText: 'SL01',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Wajib diisi'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          controller: _poin,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Poin'),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n < 0) return 'Angka';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pertanyaan,
                    maxLines: 5,
                    minLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Pertanyaan (esai)',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      controller: _urutan,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Urutan'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Soal cadangan (SB)'),
                    subtitle: const Text('Dikelompokkan terpisah dari soal utama',
                        style: TextStyle(fontSize: 12)),
                    value: _isBackup,
                    onChanged: (v) => setState(() => _isBackup = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif'),
                    subtitle: const Text('Soal nonaktif tidak tampil di web',
                        style: TextStyle(fontSize: 12)),
                    value: _aktif,
                    onChanged: (v) => setState(() => _aktif = v),
                  ),
                ],
              ),
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
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
