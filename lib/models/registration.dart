import 'package:cloud_firestore/cloud_firestore.dart';
class Registration {
  final String id;
  final String organizationId;
  final String namaPeserta;
  final String kelas;
  final String kejuruan;
  final String emailGmail;
  final String? nisn;
  final String status;
  final String? qrToken;
  final DateTime? qrTokenExpired;
  final String? acceptReason;
  final String? rejectReason;
  final DateTime createdAt;

  Registration({
    required this.id,
    required this.organizationId,
    required this.namaPeserta,
    required this.kelas,
    required this.kejuruan,
    required this.emailGmail,
    this.nisn,
    this.status = 'MENUNGGU',
    this.qrToken,
    this.qrTokenExpired,
    this.acceptReason,
    this.rejectReason,
    required this.createdAt,
  });

  factory Registration.fromMap(Map<String, dynamic> map, String docId) {
    return Registration(
      id: docId,
      organizationId: map['organizationId'] as String? ?? '',
      namaPeserta: map['namaPeserta'] as String? ?? '',
      kelas: map['kelas'] as String? ?? '',
      kejuruan: map['kejuruan'] as String? ?? '',
      emailGmail: map['emailGmail'] as String? ?? '',
      nisn: map['nisn'] as String?,
      status: map['status'] as String? ?? 'MENUNGGU',
      qrToken: map['qrToken'] as String?,
      qrTokenExpired: (map['qrTokenExpired'] as Timestamp?)?.toDate(),
      acceptReason: map['acceptReason'] as String?,
      rejectReason: map['rejectReason'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'namaPeserta': namaPeserta,
      'kelas': kelas,
      'kejuruan': kejuruan,
      'emailGmail': emailGmail,
      'nisn': nisn,
      'status': status,
      'qrToken': qrToken,
      'qrTokenExpired': qrTokenExpired != null ? Timestamp.fromDate(qrTokenExpired!) : null,
      'acceptReason': acceptReason,
      'rejectReason': rejectReason,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String get statusDisplay {
    switch (status) {
      case 'MENUNGGU': return 'Menunggu';
      case 'DITERIMA': return 'Diterima';
      case 'DITOLAK': return 'Ditolak';
      case 'CALON': return 'Calon';
      default: return status;
    }
  }
}

