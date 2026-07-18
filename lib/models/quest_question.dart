import 'package:cloud_firestore/cloud_firestore.dart';

/// Satu soal Airlangga QR Quest.
///
/// Disimpan di collection `quest_questions`. Soal berupa esai; peserta menyalin
/// dan menjawab di kertas, jadi tidak ada jawaban yang disubmit lewat web.
/// [kode] adalah label tampilan (SL01–SL10, atau SB01+ untuk cadangan).
class QuestQuestion {
  final String id;
  final String kode;
  final String pertanyaan;
  final int poin;
  final int urutan;

  /// Soal cadangan (SB) — dipisahkan dari soal utama (SL) di daftar.
  final bool isBackup;

  /// Soal aktif ditampilkan; nonaktif disembunyikan dari web tapi tetap tersimpan.
  final bool aktif;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const QuestQuestion({
    this.id = '',
    required this.kode,
    required this.pertanyaan,
    this.poin = 0,
    this.urutan = 0,
    this.isBackup = false,
    this.aktif = true,
    this.createdAt,
    this.updatedAt,
  });

  factory QuestQuestion.fromMap(Map<String, dynamic> map, String id) {
    return QuestQuestion(
      id: id,
      kode: map['kode'] as String? ?? '',
      pertanyaan: map['pertanyaan'] as String? ?? '',
      poin: (map['poin'] as num?)?.toInt() ?? 0,
      urutan: (map['urutan'] as num?)?.toInt() ?? 0,
      isBackup: map['isBackup'] as bool? ?? false,
      aktif: map['aktif'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kode': kode,
      'pertanyaan': pertanyaan,
      'poin': poin,
      'urutan': urutan,
      'isBackup': isBackup,
      'aktif': aktif,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  QuestQuestion copyWith({
    String? kode,
    String? pertanyaan,
    int? poin,
    int? urutan,
    bool? isBackup,
    bool? aktif,
  }) {
    return QuestQuestion(
      id: id,
      kode: kode ?? this.kode,
      pertanyaan: pertanyaan ?? this.pertanyaan,
      poin: poin ?? this.poin,
      urutan: urutan ?? this.urutan,
      isBackup: isBackup ?? this.isBackup,
      aktif: aktif ?? this.aktif,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
