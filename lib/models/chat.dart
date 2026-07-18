import 'package:cloud_firestore/cloud_firestore.dart';

/// Ringkasan satu percakapan 1-lawan-1 antar staff.
///
/// Disimpan di collection `conversations/{conversationId}` dengan
/// `conversationId` = gabungan dua UID terurut (lihat [ChatService.conversationId]).
/// Nama & role tiap peserta di-denormalisasi ke [participantsMeta] agar daftar
/// percakapan bisa menampilkan lawan bicara tanpa query tambahan.
class Conversation {
  final String id;
  final List<String> participantIds;
  final Map<String, ConversationParticipant> participantsMeta;
  final String lastMessage;
  final String lastSenderId;
  final DateTime lastMessageAt;

  /// Jumlah pesan belum dibaca per uid. Di-increment saat lawan mengirim,
  /// direset ke 0 saat pemilik uid membuka ruang.
  final Map<String, int> unread;

  /// Kapan tiap uid terakhir membaca percakapan (untuk tanda "dibaca").
  final Map<String, DateTime> lastReadAt;

  /// Kapan tiap uid terakhir "membersihkan" percakapan. Pesan yang dibuat
  /// sebelum waktu ini disembunyikan HANYA untuk uid tersebut (clear per-user,
  /// mirip "Bersihkan chat" di WhatsApp) — lawan bicara tetap melihatnya.
  final Map<String, DateTime> clearedAt;

  /// Pesan yang disematkan di header ruang (opsional).
  final PinnedMessage? pinned;

  Conversation({
    required this.id,
    required this.participantIds,
    required this.participantsMeta,
    this.lastMessage = '',
    this.lastSenderId = '',
    required this.lastMessageAt,
    this.unread = const {},
    this.lastReadAt = const {},
    this.clearedAt = const {},
    this.pinned,
  });

  factory Conversation.fromMap(Map<String, dynamic> map, String docId) {
    final rawIds = map['participantIds'];
    final ids =
        rawIds is List ? rawIds.map((e) => e.toString()).toList() : <String>[];

    final rawMeta = map['participantsMeta'];
    final meta = <String, ConversationParticipant>{};
    if (rawMeta is Map) {
      rawMeta.forEach((key, value) {
        if (value is Map) {
          meta[key.toString()] = ConversationParticipant(
            nama: value['nama'] as String? ?? '',
            role: value['role'] as String? ?? '',
          );
        }
      });
    }

    final rawUnread = map['unread'];
    final unread = <String, int>{};
    if (rawUnread is Map) {
      rawUnread.forEach((k, v) {
        unread[k.toString()] = (v is num) ? v.toInt() : 0;
      });
    }

    final rawRead = map['lastReadAt'];
    final lastRead = <String, DateTime>{};
    if (rawRead is Map) {
      rawRead.forEach((k, v) {
        if (v is Timestamp) lastRead[k.toString()] = v.toDate();
      });
    }

    final rawCleared = map['clearedAt'];
    final cleared = <String, DateTime>{};
    if (rawCleared is Map) {
      rawCleared.forEach((k, v) {
        if (v is Timestamp) cleared[k.toString()] = v.toDate();
      });
    }

    final rawPinned = map['pinned'];
    PinnedMessage? pinned;
    if (rawPinned is Map) {
      final text = rawPinned['text'] as String?;
      if (text != null && text.isNotEmpty) {
        pinned = PinnedMessage(
          text: text,
          senderName: rawPinned['senderName'] as String? ?? '',
          pinnedBy: rawPinned['pinnedBy'] as String? ?? '',
        );
      }
    }

    return Conversation(
      id: docId,
      participantIds: ids,
      participantsMeta: meta,
      lastMessage: map['lastMessage'] as String? ?? '',
      lastSenderId: map['lastSenderId'] as String? ?? '',
      lastMessageAt:
          (map['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unread: unread,
      lastReadAt: lastRead,
      clearedAt: cleared,
      pinned: pinned,
    );
  }

  /// Waktu "bersihkan" untuk [uid], atau null bila belum pernah dibersihkan.
  DateTime? clearedFor(String uid) => clearedAt[uid];

  /// UID lawan bicara dari sudut pandang [currentUid].
  ///
  /// Tahan-banting terhadap data lama: bila uid yang login tidak persis cocok
  /// dengan id yang tersimpan (mis. akun pernah dibuat ulang sehingga ada dua
  /// uid untuk orang yang sama), pemilihan berdasarkan id saja bisa salah dan
  /// malah menunjuk diri sendiri. Karena itu kita juga menghindari peserta yang
  /// NAMA-nya sama dengan [currentName] (nama kita).
  String otherId(String currentUid, {String? currentName}) {
    // Prioritas: id berbeda DAN nama berbeda dari diri sendiri.
    for (final id in participantIds) {
      if (id == currentUid) continue;
      final nama = participantsMeta[id]?.nama ?? '';
      if (currentName != null &&
          currentName.isNotEmpty &&
          nama == currentName) {
        continue;
      }
      return id;
    }
    // Cadangan: peserta mana pun yang id-nya bukan kita.
    return participantIds.firstWhere(
      (id) => id != currentUid,
      orElse: () => currentUid,
    );
  }

  /// Data lawan bicara (nama & role). Bila tak ditemukan, kembalikan nilai
  /// kosong agar UI tetap aman.
  ConversationParticipant other(String currentUid, {String? currentName}) =>
      participantsMeta[otherId(currentUid, currentName: currentName)] ??
      const ConversationParticipant(nama: 'Pengguna', role: '');

  /// Jumlah pesan belum dibaca untuk [uid].
  int unreadFor(String uid) => unread[uid] ?? 0;

  /// True bila pesan terakhir (dari kita) sudah dibaca lawan.
  bool readByOther(String currentUid, {String? currentName}) {
    final otherRead =
        lastReadAt[otherId(currentUid, currentName: currentName)];
    if (otherRead == null) return false;
    // Dianggap terbaca bila lawan membaca pada/atau setelah pesan terakhir.
    return !otherRead.isBefore(lastMessageAt);
  }
}

/// Info ringkas peserta percakapan yang di-denormalisasi ke dokumen conversation.
class ConversationParticipant {
  final String nama;
  final String role;

  const ConversationParticipant({required this.nama, required this.role});
}

/// Pesan yang disematkan di header ruang chat.
class PinnedMessage {
  final String text;
  final String senderName;
  final String pinnedBy;

  const PinnedMessage({
    required this.text,
    required this.senderName,
    required this.pinnedBy,
  });
}

/// Ringkasan pesan yang sedang dibalas (quote), disimpan inline pada pesan baru
/// agar bisa ditampilkan tanpa query tambahan.
class ReplyPreview {
  final String messageId;
  final String senderId;
  final String text;

  const ReplyPreview({
    required this.messageId,
    required this.senderId,
    required this.text,
  });

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'senderId': senderId,
        'text': text,
      };

  static ReplyPreview? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['messageId'] as String?;
    if (id == null) return null;
    return ReplyPreview(
      messageId: id,
      senderId: raw['senderId'] as String? ?? '',
      text: raw['text'] as String? ?? '',
    );
  }
}

/// Satu pesan dalam sebuah percakapan
/// (`conversations/{conversationId}/messages/{messageId}`).
class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  /// Pesan yang di-quote (opsional).
  final ReplyPreview? replyTo;

  /// Reaksi emoji: `{emoji: [uid, ...]}`.
  final Map<String, List<String>> reactions;

  /// Waktu terakhir diedit (null bila belum pernah).
  final DateTime? editedAt;

  /// True bila pesan sudah dihapus (soft delete).
  final bool deleted;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.replyTo,
    this.reactions = const {},
    this.editedAt,
    this.deleted = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, String docId) {
    final rawReactions = map['reactions'];
    final reactions = <String, List<String>>{};
    if (rawReactions is Map) {
      rawReactions.forEach((emoji, uids) {
        if (uids is List) {
          reactions[emoji.toString()] =
              uids.map((e) => e.toString()).toList();
        }
      });
    }

    return ChatMessage(
      id: docId,
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replyTo: ReplyPreview.fromMap(map['replyTo']),
      reactions: reactions,
      editedAt: (map['editedAt'] as Timestamp?)?.toDate(),
      deleted: map['deleted'] as bool? ?? false,
    );
  }

  bool get isEdited => editedAt != null;
}
