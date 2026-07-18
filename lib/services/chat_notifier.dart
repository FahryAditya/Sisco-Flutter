import 'dart:async';
import 'package:flutter/foundation.dart';

import 'chat_service.dart';
import 'notification_service.dart';

/// Jembatan Firestore → NotificationService.
///
/// Mendengarkan seluruh percakapan milik pengguna aktif; setiap kali pesan
/// terakhir sebuah percakapan berubah dan pengirimnya BUKAN pengguna sendiri
/// (dan percakapan itu tidak sedang dibuka), tampilkan notifikasi lokal.
///
/// Alur:
///   1. `start(myUid)` dipanggil sekali setelah login (lihat AuthProvider).
///   2. Listener utama mengikuti `conversationsStream(myUid)`.
///   3. Snapshot pertama dipakai sebagai baseline — TIDAK memicu notifikasi
///      (kalau tidak, notifikasi lama akan "kebanjiran" saat app dibuka).
///   4. Snapshot berikutnya: bandingkan `lastMessageAt` dengan yang tersimpan
///      per conversationId. Bila lebih baru & bukan dari saya & percakapan
///      itu tidak sedang dibuka → panggil `NotificationService.showChatMessage`.
///   5. `stop()` dipanggil saat logout untuk mencegah kebocoran & notifikasi
///      salah alamat setelah ganti akun.
///
/// Halaman `ChatRoomPage` memanggil `setActiveConversation(cid)` saat masuk
/// & `setActiveConversation(null)` saat keluar — supaya pesan yang sedang
/// dibaca tidak juga memicu notifikasi.
class ChatNotifier {
  ChatNotifier._();
  static final ChatNotifier instance = ChatNotifier._();

  StreamSubscription? _sub;
  String? _myUid;

  /// Waktu pesan terakhir per conversationId yang sudah kita ketahui.
  /// Dipakai sebagai baseline agar hanya perubahan NYATA yang memicu notif.
  final Map<String, DateTime> _lastSeen = {};

  /// ConversationId yang saat ini sedang dibuka pengguna (max 1).
  /// Notifikasi ditekan untuk percakapan aktif — sama seperti WhatsApp yang
  /// tidak pop-up saat chat itu sudah di layar.
  String? _activeConversationId;

  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
  }

  /// Mulai memantau notifikasi untuk [myUid]. Aman dipanggil berulang: bila
  /// uid sama & listener aktif → no-op; bila beda → listener lama di-cancel.
  Future<void> start(String myUid) async {
    if (_myUid == myUid && _sub != null) return;
    await stop();
    _myUid = myUid;
    _lastSeen.clear();

    // Pastikan plugin notifikasi siap sebelum stream mulai emit.
    await NotificationService.instance.init();

    var first = true;
    _sub = ChatService.conversationsStream(myUid).listen((convos) {
      if (first) {
        // Baseline: catat waktu pesan terakhir tanpa notifikasi.
        for (final c in convos) {
          _lastSeen[c.id] = c.lastMessageAt;
        }
        first = false;
        return;
      }

      for (final c in convos) {
        final prev = _lastSeen[c.id];
        _lastSeen[c.id] = c.lastMessageAt;

        // Skip: pesan dari saya sendiri.
        if (c.lastSenderId == myUid) continue;
        // Skip: pesan kosong (dokumen conversation baru dibuat, belum ada teks).
        if (c.lastMessage.isEmpty) continue;
        // Skip: percakapan ini sedang dibuka.
        if (_activeConversationId == c.id) continue;
        // Skip: bukan pesan baru (waktu sama / lebih lama dari baseline).
        if (prev != null && !c.lastMessageAt.isAfter(prev)) continue;
        // Skip: pesan lebih tua dari "clearedAt" pengguna ini (chat dibersihkan).
        final cleared = c.clearedFor(myUid);
        if (cleared != null && !c.lastMessageAt.isAfter(cleared)) continue;

        final sender = c.other(myUid);
        NotificationService.instance.showChatMessage(
          conversationId: c.id,
          recipientId: myUid,
          senderName: sender.nama,
          senderRole: sender.role,
          text: c.lastMessage,
        );
      }
    }, onError: (e) {
      // Firestore permission-denied saat logout, dsb. — non-kritis.
      debugPrint('ChatNotifier stream error: $e');
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _myUid = null;
    _lastSeen.clear();
    _activeConversationId = null;
    await NotificationService.instance.cancelAll();
  }
}
