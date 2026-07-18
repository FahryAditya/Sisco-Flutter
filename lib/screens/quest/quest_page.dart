import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/quest_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/page_transitions.dart';
import 'quest_questions_page.dart';
import 'quest_slots_page.dart';

/// Halaman Airlangga QR Quest (tahap gerbang aktivasi).
///
/// Untuk sekarang hanya menampilkan status aktivasi + ringkasan pemegang akses
/// dan organisasi peserta. Manajemen quest (soal SL01–SL10, jawaban, skor,
/// leaderboard, web peserta) adalah fase berikutnya.
class QuestPage extends StatelessWidget {
  const QuestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final quest = context.watch<QuestProvider>();
    final config = quest.config;

    return Scaffold(
      appBar: AppBar(title: const Text('Airlangga QR Quest')),
      body: !quest.loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statusCard(config.enabled),
                const SizedBox(height: 12),
                _infoTile(
                  Icons.groups_2_outlined,
                  'Organisasi Peserta',
                  '${config.participantOrgIds.length} organisasi',
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _infoTile(
                  Icons.vpn_key_outlined,
                  'Pemegang Akses',
                  '${config.accessUserIds.length} user',
                  Colors.teal,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    SmoothPageRoute(builder: (_) => const QuestQuestionsPage()),
                  ),
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text('Kelola Soal'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    SmoothPageRoute(builder: (_) => const QuestSlotsPage()),
                  ),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Slot QR & Acak Ulang'),
                ),
              ],
            ),
    );
  }

  Widget _statusCard(bool enabled) {
    return Card(
      color: enabled
          ? Colors.green.withAlpha(24)
          : AppColors.textSecondary.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.check_circle : Icons.pause_circle_outline,
              color: enabled ? Colors.green : AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'Fitur Aktif' : 'Fitur Nonaktif',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Airlangga QR Quest',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        trailing: Text(
          value,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

}
