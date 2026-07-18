import 'package:cloud_firestore/cloud_firestore.dart';
class Schedule {
  final String id;
  final String judul;
  final DateTime tanggal;
  final String? waktu;
  final String? lokasi;
  final String? keterangan;
  final String organizationId;
  final bool wajibHadir;
  final String createdBy;
  final DateTime createdAt;

  Schedule({
    required this.id,
    required this.judul,
    required this.tanggal,
    this.waktu,
    this.lokasi,
    this.keterangan,
    required this.organizationId,
    this.wajibHadir = false,
    required this.createdBy,
    required this.createdAt,
  });

  factory Schedule.fromMap(Map<String, dynamic> map, String docId) {
    return Schedule(
      id: docId,
      judul: map['judul'] as String? ?? '',
      tanggal: (map['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now(),
      waktu: map['waktu'] as String?,
      lokasi: map['lokasi'] as String?,
      keterangan: map['keterangan'] as String?,
      organizationId: map['organizationId'] as String? ?? '',
      wajibHadir: map['wajibHadir'] as bool? ?? false,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'judul': judul,
      'tanggal': Timestamp.fromDate(tanggal),
      'waktu': waktu,
      'lokasi': lokasi,
      'keterangan': keterangan,
      'organizationId': organizationId,
      'wajibHadir': wajibHadir,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

