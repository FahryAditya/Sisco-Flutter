import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/chat.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/directory_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/page_transitions.dart';
import '../../utils/animations.dart';
import '../../widgets/empty_state.dart';
import 'chat_contacts_page.dart';
import 'chat_room_page.dart';
import '../../widgets/character_dialog.dart';

/// Daftar percakapan pengguna saat ini (realtime). Titik masuk fitur Pesan.
class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;
    if (me == null) {
      return const Scaffold(body: Center(child: Text('Sesi tidak valid')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pesan')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          SmoothPageRoute(builder: (_) => const ChatContactsPage()),
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit_outlined, color: Colors.white),
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: ChatService.conversationsStream(me.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final convos = snapshot.data ?? [];
          if (convos.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline,
              message: 'Belum ada percakapan',
              subtitle: 'Tekan tombol pesan untuk memulai chat dengan staff lain.',
            );
          }
          // Gabungkan percakapan yang menunjuk lawan bicara yang SAMA menjadi
          // satu baris (satu kontak), lalu jumlahkan pesan belum dibaca. Ini
          // menghilangkan baris kembar akibat dokumen lama dengan uid berbeda
          // untuk orang yang sama.
          final entries = _mergeByContact(convos, me.id, me.nama);
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: entries.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 76),
            itemBuilder: (context, i) =>
                _tile(context, entries[i], me.id).animateEntrance(index: i),
          );
        },
      ),
    );
  }

  /// Gabungkan daftar percakapan per lawan bicara. [convos] diasumsikan sudah
  /// terurut pesan terbaru di atas (lihat ChatService), sehingga kemunculan
  /// pertama sebuah kontak dipakai sebagai wakil (pesan & waktu terbaru).
  static List<_ChatEntry> _mergeByContact(
      List<Conversation> convos, String meId, String meName) {
    final byContact = <String, _ChatEntry>{};
    for (final c in convos) {
      final otherId = c.otherId(meId, currentName: meName);
      final other = c.other(meId, currentName: meName);
      // Kunci gabung memakai UID lawan (bukan nama). Ini menyatukan dokumen
      // yang benar-benar menunjuk kontak yang sama, TANPA keliru menggabungkan
      // dua orang berbeda yang kebetulan bernama sama (mis. dua administrator).
      final key = otherId;
      final existing = byContact[key];
      if (existing == null) {
        byContact[key] = _ChatEntry(
          convo: c,
          otherId: otherId,
          other: other,
          unread: c.unreadFor(meId),
        );
      } else {
        // Wakil tetap yang pertama (terbaru); cukup akumulasi unread.
        existing.unread += c.unreadFor(meId);
      }
    }
    return byContact.values.toList();
  }

  Widget _tile(BuildContext context, _ChatEntry e, String meId) {
    final other = e.other;
    final otherId = e.otherId;
    final c = e.convo;
    final color = AppColors.roleBadge(other.role);
    final unread = e.unread;
    final hasUnread = unread > 0;

    return ListTile(
      leading: StreamBuilder<StaffContact?>(
        stream: DirectoryService.contactStream(otherId),
        builder: (context, snap) {
          final online = snap.data?.isOnlineNow ?? false;
          return Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withAlpha(40),
                child: Text(
                  _initials(other.nama),
                  style: GoogleFonts.plusJakartaSans(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (online)
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2.5),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      title: Text(
        other.nama,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: _subtitle(c, meId, otherId, hasUnread),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _timeLabel(c.lastMessageAt),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: hasUnread ? AppColors.primary : AppColors.textHint,
              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 5),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const SizedBox(height: 20),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        SmoothPageRoute(
          builder: (_) => ChatRoomPage(
            recipientId: otherId,
            recipientName: other.nama,
            recipientRole: other.role,
          ),
        ),
      ),
      onLongPress: () => _showEntryOptions(context, c.id, other.nama, meId),
    );
  }

  /// Menu saat menekan lama sebuah percakapan. Berisi "Bersihkan pesan chat"
  /// (clear per-pengguna — pesan hilang dari tampilan kita, lawan tetap lihat).
  static void _showEntryOptions(
      BuildContext context, String conversationId, String otherName, String meId) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined,
                  color: AppColors.danger),
              title: Text(
                'Bersihkan pesan chat',
                style: GoogleFonts.plusJakartaSans(color: AppColors.danger),
              ),
              subtitle: Text(
                'Hapus pesan dari tampilan Anda saja',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmClear(context, conversationId, otherName, meId);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _confirmClear(BuildContext context, String conversationId,
      String otherName, String meId) async {
    final ok = await AppDialogs.showConfirm(context, message: 'Semua pesan dengan $otherName akan dihapus dari tampilan Anda. Lawan bicara tetap dapat melihat percakapan ini. Tindakan ini tidak dapat dibatalkan.', confirmLabel: 'Bersihkan', danger: true);
    if (ok != true) return;
    try {
      await ChatService.clearMessagesForUser(
          conversationId: conversationId, uid: meId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesan chat dibersihkan')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membersihkan: $e')),
        );
      }
    }
  }

  /// Subtitle: "sedang mengetik…" bila lawan mengetik, jika tidak preview pesan.
  Widget _subtitle(
      Conversation c, String meId, String otherId, bool hasUnread) {
    return StreamBuilder<bool>(
      stream: ChatService.typingStream(
        conversationId: c.id,
        otherUid: otherId,
      ),
      builder: (context, snap) {
        if (snap.data == true) {
          return Text(
            'sedang mengetik…',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          );
        }
        // Bila kita sudah "bersihkan" dan tidak ada pesan lebih baru, jangan
        // tampilkan preview pesan lama (yang bagi kita sudah tak terlihat).
        final cleared = c.clearedFor(meId);
        if (cleared != null && !c.lastMessageAt.isAfter(cleared)) {
          return Text(
            'Pesan dibersihkan',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.textHint,
              fontStyle: FontStyle.italic,
            ),
          );
        }
        final prefix = c.lastSenderId == meId ? 'Anda: ' : '';
        return Text(
          '$prefix${c.lastMessage}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
          ),
        );
      },
    );
  }

  static String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) return DateFormat('HH:mm').format(dt);
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day;
    if (isYesterday) return 'Kemarin';
    return DateFormat('dd/MM/yy').format(dt);
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// Satu baris di daftar Pesan: wakil percakapan sebuah kontak + total pesan
/// belum dibaca (hasil penggabungan bila ada dokumen kembar untuk orang sama).
class _ChatEntry {
  final Conversation convo;
  final String otherId;
  final ConversationParticipant other;
  int unread;

  _ChatEntry({
    required this.convo,
    required this.otherId,
    required this.other,
    required this.unread,
  });
}
