import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/quest_question.dart';
import '../../models/quest_slot.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/character_dialog.dart';
import '../../widgets/empty_state.dart';
import 'quest_qr_page.dart';

/// Kelola SLOT QR. Slot = token stabil yang tercetak dalam QR; isi soalnya
/// bisa diacak tanpa mengganti QR. Bila isi sebuah QR bocor, gunakan
/// "Acak Ulang Semua" untuk mengganti soal di seluruh slot sekaligus.
class QuestSlotsPage extends StatefulWidget {
  const QuestSlotsPage({super.key});

  @override
  State<QuestSlotsPage> createState() => _QuestSlotsPageState();
}

class _QuestSlotsPageState extends State<QuestSlotsPage> {
  bool _shuffling = false;

  Future<void> _addSlot() async {
    final slots = await FirestoreService.getQuestSlots();
    final defaultLabel = 'Pos ${slots.length + 1}';
    if (!mounted) return;
    final controller = TextEditingController(text: defaultLabel);
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Slot QR'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Label slot',
            hintText: 'mis. Pos 1',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty || !mounted) return;
    final actor = context.read<AuthProvider>().user;
    final id = await FirestoreService.createQuestSlot(label, urutan: slots.length);
    await FirestoreService.logAction(
      userId: actor?.id ?? '',
      userNama: actor?.nama ?? '',
      aksi: 'CREATE',
      tabel: 'quest_slots',
      recordId: id,
      deskripsi: 'Menambah slot QR "$label"',
    );
  }

  Future<void> _shuffleAll() async {
    final slots = await FirestoreService.getQuestSlots();
    if (!mounted) return;

    final anyAssigned = slots.any((s) => s.isAssigned);
    if (!anyAssigned) {
      await AppDialogs.showError(
          context, 'Belum ada slot yang berisi soal untuk diacak.');
      return;
    }

    final ok = await AppDialogs.showConfirm(
      context,
      message: 'Acak ulang soal antar SEMUA slot? Soal seluruh slot diaduk lalu '
          'dibagikan ulang (jumlah soal tiap slot tetap). Isi tiap QR berubah, '
          'tapi QR fisik tetap sama. Gunakan ini bila ada QR yang bocor.',
      confirmLabel: 'Acak Ulang',
      cancelLabel: 'Batal',
    );
    if (!ok || !mounted) return;

    setState(() => _shuffling = true);
    final actor = context.read<AuthProvider>().user;
    try {
      final count = await FirestoreService.shuffleQuestSlots();
      await FirestoreService.logAction(
        userId: actor?.id ?? '',
        userNama: actor?.nama ?? '',
        aksi: 'UPDATE',
        tabel: 'quest_slots',
        deskripsi: 'Mengacak ulang soal pada $count slot QR',
      );
      if (mounted) {
        await AppDialogs.showSuccess(
            context, 'Soal diacak ulang untuk $count slot. QR tidak berubah.');
      }
    } catch (e) {
      if (mounted) await AppDialogs.showError(context, 'Gagal mengacak: $e');
    } finally {
      if (mounted) setState(() => _shuffling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slot QR'),
        actions: [
          IconButton(
            tooltip: 'Acak ulang semua',
            icon: _shuffling
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.shuffle),
            onPressed: _shuffling ? null : _shuffleAll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSlot,
        icon: const Icon(Icons.add),
        label: const Text('Slot'),
      ),
      body: StreamBuilder<List<QuestSlot>>(
        stream: FirestoreService.questSlotsStream(),
        builder: (context, slotSnap) {
          if (slotSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Gagal memuat slot: ${slotSnap.error}'),
              ),
            );
          }
          if (!slotSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final slots = slotSnap.data!;
          if (slots.isEmpty) {
            return EmptyState(
              icon: Icons.qr_code_2,
              message: 'Belum ada slot QR',
              subtitle: 'Buat slot untuk tiap pos/lokasi. Tiap slot punya QR\n'
                  'permanen; isinya bisa diacak kapan saja.',
              actionLabel: 'Tambah Slot',
              onAction: _addSlot,
            );
          }

          // Ambil daftar soal sekali untuk memetakan questionId -> soal.
          return StreamBuilder<List<QuestQuestion>>(
            stream: FirestoreService.questQuestionsStream(),
            builder: (context, qSnap) {
              final byId = <String, QuestQuestion>{
                for (final q in (qSnap.data ?? const <QuestQuestion>[]))
                  q.id: q
              };
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                children: [
                  _infoCard(),
                  ...slots.map((s) => _slotCard(context, s, byId)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'QR menempel pada slot, bukan soal. Jika isi sebuah QR bocor, '
              'tekan tombol acak (kanan atas) — semua QR berganti soal tanpa '
              'perlu dicetak ulang.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotCard(
    BuildContext context,
    QuestSlot slot,
    Map<String, QuestQuestion> byId,
  ) {
    final kodes = slot.questionIds
        .map((id) => byId[id]?.kode ?? '?')
        .toList();
    final assignedText = !slot.isAssigned
        ? 'Belum ada soal'
        : '${slot.jumlahSoal} soal • ${kodes.join(", ")}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(30),
          child: const Icon(Icons.qr_code_2, color: AppColors.primary, size: 20),
        ),
        title: Text(
          slot.label,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          assignedText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: slot.isAssigned ? AppColors.textSecondary : AppColors.textHint,
            fontStyle: slot.isAssigned ? FontStyle.normal : FontStyle.italic,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'qr':
                Navigator.of(context).push(
                  SmoothPageRoute(builder: (_) => QuestQrPage(slot: slot)),
                );
                break;
              case 'assign':
                _manageQuestions(context, slot);
                break;
              case 'delete':
                _confirmDelete(context, slot);
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'qr',
              child: ListTile(
                leading: Icon(Icons.qr_code_2),
                title: Text('Lihat QR'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'assign',
              child: ListTile(
                leading: Icon(Icons.playlist_add_check),
                title: Text('Kelola Soal'),
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
        onTap: () => Navigator.of(context).push(
          SmoothPageRoute(builder: (_) => QuestQrPage(slot: slot)),
        ),
      ),
    );
  }

  Future<void> _manageQuestions(BuildContext context, QuestSlot slot) async {
    final questions = await FirestoreService.getQuestQuestions();
    if (!context.mounted) return;
    // Dialog mengembalikan daftar id terpilih, atau null bila batal.
    final chosen = await showDialog<List<String>?>(
      context: context,
      builder: (ctx) => _ManageQuestionsDialog(
        questions: questions,
        selected: slot.questionIds,
        slotLabel: slot.label,
      ),
    );
    if (chosen == null || !context.mounted) return;
    final actor = context.read<AuthProvider>().user;
    await FirestoreService.setQuestSlotQuestions(slot.id, chosen);
    await FirestoreService.logAction(
      userId: actor?.id ?? '',
      userNama: actor?.nama ?? '',
      aksi: 'UPDATE',
      tabel: 'quest_slots',
      recordId: slot.id,
      deskripsi: 'Mengatur ${chosen.length} soal untuk slot "${slot.label}"',
    );
  }

  Future<void> _confirmDelete(BuildContext context, QuestSlot slot) async {
    final ok = await AppDialogs.showConfirm(
      context,
      message: 'Hapus slot "${slot.label}"? QR yang sudah tercetak untuk slot '
          'ini tidak akan berfungsi lagi.',
      confirmLabel: 'Hapus',
      cancelLabel: 'Batal',
    );
    if (!ok || !context.mounted) return;
    final actor = context.read<AuthProvider>().user;
    await FirestoreService.deleteQuestSlot(slot.id);
    await FirestoreService.logAction(
      userId: actor?.id ?? '',
      userNama: actor?.nama ?? '',
      aksi: 'DELETE',
      tabel: 'quest_slots',
      recordId: slot.id,
      deskripsi: 'Menghapus slot QR "${slot.label}"',
    );
  }
}

/// Dialog memilih BANYAK soal (SL01..) untuk sebuah slot/pos. Soal dipilih
/// via checkbox; slot bisa memiliki beberapa soal sekaligus. Saat QR dipindai,
/// halaman web menampilkan satu soal acak dari kumpulan ini.
class _ManageQuestionsDialog extends StatefulWidget {
  final List<QuestQuestion> questions;
  final List<String> selected;
  final String slotLabel;

  const _ManageQuestionsDialog({
    required this.questions,
    required this.selected,
    required this.slotLabel,
  });

  @override
  State<_ManageQuestionsDialog> createState() => _ManageQuestionsDialogState();
}

class _ManageQuestionsDialogState extends State<_ManageQuestionsDialog> {
  late final Set<String> _chosen = {...widget.selected};
  String _query = '';

  List<QuestQuestion> get _filtered {
    // Urutkan berdasar kode (SL01..SL40) agar mudah dipilih berurutan.
    final sorted = [...widget.questions]
      ..sort((a, b) => a.kode.toLowerCase().compareTo(b.kode.toLowerCase()));
    if (_query.isEmpty) return sorted;
    final q = _query.toLowerCase();
    return sorted
        .where((e) =>
            e.kode.toLowerCase().contains(q) ||
            e.pertanyaan.toLowerCase().contains(q))
        .toList();
  }

  void _toggle(String id, bool? on) {
    setState(() {
      if (on == true) {
        _chosen.add(id);
      } else {
        _chosen.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    // Adaptif: 60% tinggi layar, dibatasi 260..520 supaya tetap enak dilihat
    // di HP mungil sekaligus tidak melar di tablet.
    final screenH = MediaQuery.sizeOf(context).height;
    final dialogH = screenH * 0.6;
    final clampedH = dialogH.clamp(260.0, 520.0);
    return AlertDialog(
      title: Text('Soal untuk ${widget.slotLabel}'),
      content: SizedBox(
        width: double.maxFinite,
        height: clampedH,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Cari kode atau isi soal',
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_chosen.length} soal dipilih',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const Divider(height: 8),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('Tidak ada soal cocok'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final q = list[i];
                        return CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _chosen.contains(q.id),
                          onChanged: (v) => _toggle(q.id, v),
                          title: Text(q.kode,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            q.pertanyaan,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _chosen.toList()),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
