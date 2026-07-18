import 'package:cloud_firestore/cloud_firestore.dart';
class DailyMaterial {
  final String id;
  final String judul;
  final String deskripsi;
  final DateTime tanggal;
  final String organizationId;
  final String? notulen;
  final String? lokasi;
  final String createdBy;
  final DateTime createdAt;

  DailyMaterial({
    required this.id,
    required this.judul,
    required this.deskripsi,
    required this.tanggal,
    required this.organizationId,
    this.notulen,
    this.lokasi,
    required this.createdBy,
    required this.createdAt,
  });

  factory DailyMaterial.fromMap(Map<String, dynamic> map, String docId) {
    return DailyMaterial(
      id: docId,
      judul: map['judul'] as String? ?? '',
      deskripsi: map['deskripsi'] as String? ?? '',
      tanggal: (map['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now(),
      organizationId: map['organizationId'] as String? ?? '',
      notulen: map['notulen'] as String?,
      lokasi: map['lokasi'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'judul': judul,
      'deskripsi': deskripsi,
      'tanggal': Timestamp.fromDate(tanggal),
      'organizationId': organizationId,
      'notulen': notulen,
      'lokasi': lokasi,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

