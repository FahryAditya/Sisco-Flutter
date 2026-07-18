import 'package:cloud_firestore/cloud_firestore.dart';

/// Sebuah "slot" QR pada Airlangga QR Quest.
///
/// Slot adalah token stabil yang tercetak di dalam QR. Sebuah slot (pos)
/// menampung sekumpulan soal ([questionIds]); saat QR dipindai, halaman web
/// menampilkan SATU soal acak dari kumpulan itu. Isi kumpulan bisa
/// diubah/diacak kapan saja TANPA mengganti QR fisik. Inilah kunci mitigasi
/// kebocoran: peserta berbeda bisa mendapat soal berbeda, dan bila isi sebuah
/// QR bocor, cukup ubah/acak ulang soal — QR tetap sama.
///
/// Disimpan di collection `quest_slots`. [id] dokumen = token dalam QR.
class QuestSlot {
  final String id;
  final String label;

  /// Kumpulan soal yang ditugaskan ke slot ini (boleh kosong bila belum diisi).
  final List<String> questionIds;

  final int urutan;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const QuestSlot({
    this.id = '',
    required this.label,
    this.questionIds = const [],
    this.urutan = 0,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAssigned => questionIds.isNotEmpty;
  int get jumlahSoal => questionIds.length;

  /// Baca daftar soal dari dokumen, kompatibel dengan format lama yang memakai
  /// satu field `questionId` tunggal.
  static List<String> _readQuestionIds(Map<String, dynamic> map) {
    final raw = map['questionIds'];
    if (raw is List) {
      return raw.whereType<String>().where((e) => e.isNotEmpty).toList();
    }
    final single = map['questionId'] as String?;
    if (single != null && single.isNotEmpty) return [single];
    return const [];
  }

  factory QuestSlot.fromMap(Map<String, dynamic> map, String id) {
    return QuestSlot(
      id: id,
      label: map['label'] as String? ?? '',
      questionIds: _readQuestionIds(map),
      urutan: (map['urutan'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'questionIds': questionIds,
      'urutan': urutan,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  QuestSlot copyWith({
    String? label,
    List<String>? questionIds,
    int? urutan,
  }) {
    return QuestSlot(
      id: id,
      label: label ?? this.label,
      questionIds: questionIds ?? this.questionIds,
      urutan: urutan ?? this.urutan,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
