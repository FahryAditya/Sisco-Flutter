import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat.dart';
import '../models/user.dart';

/// Layanan chat realtime 1-lawan-1 antar staff (administrator, admin org/eskul,
/// pembina org/eskul).
///
/// Struktur Firestore:
///   conversations/{conversationId}
///     - participantIds: [uidA, uidB]        (untuk query arrayContains)
///     - participantsMeta: { uid: {nama, role} }  (denormalisasi utk tampilan)
///     - lastMessage, lastSenderId, lastMessageAt
///     - unread: { uid: int }                 (jumlah pesan belum dibaca)
///     - lastReadAt: { uid: Timestamp }       (tanda "dibaca")
///     - pinned: { text, senderName, pinnedBy } (opsional)
///   conversations/{conversationId}/messages/{messageId}
///     - senderId, text, createdAt, replyTo?, reactions?, editedAt?, deleted?
///   conversations/{conversationId}/typing/{uid}
///     - typing: bool, at: Timestamp          (indikator "sedang mengetik")
///
/// [conversationId] dibuat deterministik dari pasangan UID terurut sehingga
/// dua orang yang sama SELALU memakai satu dokumen percakapan (anti-duplikat).
class ChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference get _convos => _db.collection('conversations');

  static CollectionReference _messagesRef(String conversationId) =>
      _convos.doc(conversationId).collection('messages');

  static CollectionReference _typingRef(String conversationId) =>
      _convos.doc(conversationId).collection('typing');

  /// Dianggap masih "mengetik" bila update typing terjadi ≤ 6 detik lalu.
  static const _typingTtl = Duration(seconds: 6);

  /// ID percakapan deterministik: dua UID diurutkan lalu digabung dengan '_'.
  /// UID Firebase Auth bersifat alfanumerik (tanpa '_'), sehingga aman dipecah
  /// kembali di Security Rules.
  static String conversationId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Stream percakapan milik [uid], diurutkan pesan terbaru di atas.
  ///
  /// Sengaja TIDAK memakai orderBy di query (agar tak butuh composite index
  /// untuk kombinasi arrayContains + orderBy); pengurutan dilakukan di klien.
  static Stream<List<Conversation>> conversationsStream(String uid) {
    return _convos
        .where('participantIds', arrayContains: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) =>
              Conversation.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      list.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      return list;
    });
  }

  /// Stream satu dokumen percakapan (untuk header: pinned, tanda dibaca).
  static Stream<Conversation?> conversationStream(String conversationId) {
    return _convos.doc(conversationId).snapshots().map((d) {
      if (!d.exists) return null;
      return Conversation.fromMap(d.data() as Map<String, dynamic>, d.id);
    });
  }

  /// Stream total pesan belum dibaca milik [uid] di semua percakapan
  /// (untuk badge pada ikon Pesan di beranda).
  static Stream<int> totalUnreadStream(String uid) {
    return _convos
        .where('participantIds', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs.fold<int>(0, (total, d) {
              final data = d.data() as Map<String, dynamic>;
              final unread = data['unread'];
              if (unread is Map) {
                final v = unread[uid];
                if (v is num) return total + v.toInt();
              }
              return total;
            }));
  }

  /// Jumlah pesan terakhir yang dimuat. Riwayat lebih lama dimuat via paginasi
  /// (belum diekspos di UI) — membatasi payload agar percakapan panjang ringan.
  static const _messageWindow = 200;

  /// Stream pesan sebuah percakapan, terlama di atas → terbaru di bawah.
  /// Dibatasi [_messageWindow] pesan terbaru agar tidak memuat seluruh riwayat.
  static Stream<List<ChatMessage>> messagesStream(String conversationId) {
    return _messagesRef(conversationId)
        .orderBy('createdAt', descending: false)
        .limitToLast(_messageWindow)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                ChatMessage.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// Kirim pesan dari [sender] ke [recipient]. Membuat dokumen percakapan bila
  /// belum ada (SetOptions.merge) sekaligus menambahkan pesan — dalam satu batch
  /// agar konsisten. Menaikkan counter belum-dibaca milik penerima.
  ///
  /// Memakai [FieldValue.serverTimestamp] agar urutan pesan & tanda "dibaca"
  /// konsisten lintas perangkat (tidak terpengaruh selisih jam HP). Selagi
  /// menunggu server, snapshot lokal mengembalikan null → model jatuh ke waktu
  /// lokal sehingga pesan tetap tampil seketika tanpa kedip.
  static Future<void> sendMessage({
    required UserModel sender,
    required String recipientId,
    required String recipientName,
    required String recipientRole,
    required String text,
    ReplyPreview? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final cid = conversationId(sender.id, recipientId);
    final ts = FieldValue.serverTimestamp();

    final batch = _db.batch();
    batch.set(
      _convos.doc(cid),
      {
        'participantIds': [sender.id, recipientId],
        'participantsMeta': {
          sender.id: {'nama': sender.nama, 'role': sender.role},
          recipientId: {'nama': recipientName, 'role': recipientRole},
        },
        'lastMessage': trimmed,
        'lastSenderId': sender.id,
        'lastMessageAt': ts,
        'updatedAt': ts,
        // Penerima +1 belum dibaca; pengirim jelas sudah "membaca".
        'unread': {
          recipientId: FieldValue.increment(1),
          sender.id: 0,
        },
        'lastReadAt': {sender.id: ts},
      },
      SetOptions(merge: true),
    );
    batch.set(_messagesRef(cid).doc(), {
      'senderId': sender.id,
      'text': trimmed,
      'createdAt': ts,
      if (replyTo != null) 'replyTo': replyTo.toMap(),
    });

    await batch.commit();

    // Bersihkan indikator mengetik milik pengirim setelah terkirim.
    await setTyping(conversationId: cid, uid: sender.id, typing: false);
  }

  /// Tandai percakapan sudah dibaca oleh [uid]: reset counter & catat waktu.
  /// Dipanggil saat membuka/aktif di ruang chat.
  ///
  /// Memakai [update] dengan dotted-path sehingga HANYA menyentuh field milik
  /// [uid] tanpa menimpa data peserta lain, dan TIDAK membuat dokumen baru bila
  /// percakapan belum ada (mis. ruang dibuka sebelum ada pesan) — menghindari
  /// dokumen setengah jadi & error permission dari rules `create`.
  static Future<void> markRead({
    required String conversationId,
    required String uid,
  }) async {
    try {
      await _convos.doc(conversationId).update({
        'unread.$uid': 0,
        'lastReadAt.$uid': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-kritis (mis. dokumen belum ada): jangan ganggu UI.
    }
  }

  // ── Indikator "sedang mengetik" ──────────────────────────────────────────

  /// Set/hapus status mengetik milik [uid] pada sebuah percakapan.
  static Future<void> setTyping({
    required String conversationId,
    required String uid,
    required bool typing,
  }) async {
    try {
      await _typingRef(conversationId).doc(uid).set({
        'typing': typing,
        'at': Timestamp.now(),
      });
    } catch (_) {/* non-kritis */}
  }

  /// Stream apakah [otherUid] sedang mengetik.
  ///
  /// Selain mendengar dokumen typing, stream ini me-RE-EVALUASI TTL secara
  /// berkala di sisi klien. Tanpa ini, bila lawan menutup app dengan status
  /// terakhir `typing:true` (tak sempat menulis `false`), indikator akan
  /// "nyangkut" selamanya karena dokumen tak berubah lagi. Timer memastikan
  /// nilai berubah menjadi `false` begitu melewati [_typingTtl].
  static Stream<bool> typingStream({
    required String conversationId,
    required String otherUid,
  }) {
    final controller = StreamController<bool>();
    Timestamp? lastAt;
    bool rawTyping = false;
    Timer? ticker;
    StreamSubscription? sub;

    bool compute() {
      if (!rawTyping || lastAt == null) return false;
      return DateTime.now().difference(lastAt!.toDate()) <= _typingTtl;
    }

    void emit() {
      if (!controller.isClosed) controller.add(compute());
    }

    controller.onListen = () {
      sub = _typingRef(conversationId).doc(otherUid).snapshots().listen((d) {
        final data = d.exists ? d.data() as Map<String, dynamic>? : null;
        rawTyping = data?['typing'] == true;
        lastAt = data?['at'] as Timestamp?;
        emit();
      });
      // Re-cek tiap 2 dtk agar status kedaluwarsa hilang otomatis.
      ticker = Timer.periodic(const Duration(seconds: 2), (_) => emit());
    };
    controller.onCancel = () async {
      ticker?.cancel();
      await sub?.cancel();
    };

    return controller.stream.distinct();
  }

  // ── Reaksi emoji ─────────────────────────────────────────────────────────

  /// Toggle reaksi [emoji] milik [uid] pada sebuah pesan. Bila sudah ada →
  /// dicabut; bila belum → ditambahkan.
  static Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
    required String uid,
  }) async {
    final ref = _messagesRef(conversationId).doc(messageId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final rawReactions = (data['reactions'] as Map?) ?? {};
      final current = <String, List<String>>{};
      rawReactions.forEach((k, v) {
        if (v is List) current[k.toString()] = v.map((e) => e.toString()).toList();
      });

      final users = current[emoji] ?? <String>[];
      if (users.contains(uid)) {
        users.remove(uid);
      } else {
        users.add(uid);
      }
      if (users.isEmpty) {
        current.remove(emoji);
      } else {
        current[emoji] = users;
      }
      tx.update(ref, {'reactions': current});
    });
  }

  // ── Edit & hapus pesan ───────────────────────────────────────────────────

  /// Edit teks sebuah pesan (hanya oleh pengirim — divalidasi juga di rules).
  static Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newText,
  }) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    await _messagesRef(conversationId).doc(messageId).update({
      'text': trimmed,
      'editedAt': Timestamp.now(),
    });
  }

  /// Hapus pesan (soft delete): teks dikosongkan, ditandai `deleted`.
  static Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _messagesRef(conversationId).doc(messageId).update({
      'deleted': true,
      'text': '',
      'reactions': {},
    });
  }

  // ── Pin pesan ────────────────────────────────────────────────────────────

  /// Sematkan sebuah pesan di header ruang.
  static Future<void> pinMessage({
    required String conversationId,
    required ChatMessage message,
    required String senderName,
    required String pinnedBy,
  }) async {
    await _convos.doc(conversationId).set({
      'pinned': {
        'text': message.text,
        'senderName': senderName,
        'pinnedBy': pinnedBy,
      },
    }, SetOptions(merge: true));
  }

  /// Lepas pesan yang disematkan.
  static Future<void> unpin(String conversationId) async {
    await _convos.doc(conversationId).set({
      'pinned': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // ── Bersihkan pesan (clear per-pengguna) ───────────────────────────────────

  /// Bersihkan pesan chat HANYA untuk [uid]. Alih-alih menghapus dokumen pesan
  /// (yang akan menghilangkannya juga bagi lawan bicara), kita mencatat waktu
  /// "bersihkan" milik uid ini. UI lalu menyembunyikan pesan yang dibuat
  /// sebelum waktu tersebut untuk uid ybs. Lawan bicara tetap melihat semuanya.
  ///
  /// Sekaligus mereset counter belum-dibaca uini agar badge tidak menyisa.
  static Future<void> clearMessagesForUser({
    required String conversationId,
    required String uid,
  }) async {
    await _convos.doc(conversationId).set({
      'clearedAt': {uid: FieldValue.serverTimestamp()},
      'unread': {uid: 0},
    }, SetOptions(merge: true));
  }
}
