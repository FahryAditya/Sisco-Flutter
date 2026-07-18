import 'package:cloud_firestore/cloud_firestore.dart';
class InterviewSession {
  final String id;
  final String organizationId;
  final String status;
  final DateTime? jadwalMulai;
  final DateTime? jadwalSelesai;
  final DateTime? finalizedAt;
  final DateTime? lockedAt;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  InterviewSession({
    required this.id,
    required this.organizationId,
    this.status = 'SCHEDULED',
    this.jadwalMulai,
    this.jadwalSelesai,
    this.finalizedAt,
    this.lockedAt,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InterviewSession.fromMap(Map<String, dynamic> map, String docId) {
    return InterviewSession(
      id: docId,
      organizationId: map['organizationId'] as String? ?? '',
      status: map['status'] as String? ?? 'SCHEDULED',
      jadwalMulai: (map['jadwalMulai'] as Timestamp?)?.toDate(),
      jadwalSelesai: (map['jadwalSelesai'] as Timestamp?)?.toDate(),
      finalizedAt: (map['finalizedAt'] as Timestamp?)?.toDate(),
      lockedAt: (map['lockedAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'status': status,
      'jadwalMulai': jadwalMulai != null ? Timestamp.fromDate(jadwalMulai!) : null,
      'jadwalSelesai': jadwalSelesai != null ? Timestamp.fromDate(jadwalSelesai!) : null,
      'finalizedAt': finalizedAt != null ? Timestamp.fromDate(finalizedAt!) : null,
      'lockedAt': lockedAt != null ? Timestamp.fromDate(lockedAt!) : null,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  String get statusDisplay {
    switch (status) {
      case 'SCHEDULED': return 'Terjadwal';
      case 'ACTIVE': return 'Sedang Berjalan';
      case 'SELESAI': return 'Selesai';
      case 'DIBATALKAN': return 'Dibatalkan';
      default: return status;
    }
  }

  bool get isActive => status == 'ACTIVE';
  bool get isScheduled => status == 'SCHEDULED';
  bool get isFinished => status == 'SELESAI';
  bool get isCancelled => status == 'DIBATALKAN';
}

class InterviewQueue {
  Map<String, dynamic> toMap() {
    return {
      'sesiId': sesiId,
      'qrId': qrId,
      'nama': nama,
      'kelas': kelas,
      'nomorAntrian': nomorAntrian,
      'status': status,
      'scanToken': scanToken,
      'ipAddress': ipAddress,
      'ipCountry': ipCountry,
      'ipIsp': ipIsp,
      'ipStatus': ipStatus,
      'gpsLat': gpsLat,
      'gpsLng': gpsLng,
      'jarakMeter': jarakMeter,
      'statusValidasi': statusValidasi,
      'alasanValidasi': alasanValidasi,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  final String id;
  final String sesiId;
  final String? qrId;
  final String nama;
  final String kelas;
  final int nomorAntrian;
  final String status;
  final String? scanToken;
  final String? ipAddress;
  final String? ipCountry;
  final String? ipIsp;
  final String ipStatus;
  final double? gpsLat;
  final double? gpsLng;
  final double? jarakMeter;
  final String statusValidasi;
  final String? alasanValidasi;
  final DateTime createdAt;
  final DateTime updatedAt;

  InterviewQueue({
    required this.id,
    required this.sesiId,
    this.qrId,
    required this.nama,
    required this.kelas,
    required this.nomorAntrian,
    this.status = 'MENUNGGU',
    this.scanToken,
    this.ipAddress,
    this.ipCountry,
    this.ipIsp,
    this.ipStatus = 'TIDAK_DIKETAHUI',
    this.gpsLat,
    this.gpsLng,
    this.jarakMeter,
    this.statusValidasi = 'SAH',
    this.alasanValidasi,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InterviewQueue.fromMap(Map<String, dynamic> map, String docId) {
    return InterviewQueue(
      id: docId,
      sesiId: map['sesiId'] as String? ?? '',
      qrId: map['qrId'] as String?,
      nama: map['nama'] as String? ?? '',
      kelas: map['kelas'] as String? ?? '',
      nomorAntrian: map['nomorAntrian'] as int? ?? 0,
      status: map['status'] as String? ?? 'MENUNGGU',
      scanToken: map['scanToken'] as String?,
      ipAddress: map['ipAddress'] as String?,
      ipCountry: map['ipCountry'] as String?,
      ipIsp: map['ipIsp'] as String?,
      ipStatus: map['ipStatus'] as String? ?? 'TIDAK_DIKETAHUI',
      gpsLat: (map['gpsLat'] as num?)?.toDouble(),
      gpsLng: (map['gpsLng'] as num?)?.toDouble(),
      jarakMeter: (map['jarakMeter'] as num?)?.toDouble(),
      statusValidasi: map['statusValidasi'] as String? ?? 'SAH',
      alasanValidasi: map['alasanValidasi'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'MENUNGGU': return 'Menunggu';
      case 'WAWANCARA': return 'Wawancara';
      case 'SELESAI_WAWANCARA': return 'Selesai Wawancara';
      default: return status;
    }
  }
}

class InterviewResult {
  Map<String, dynamic> toMap() {
    return {
      'antrianId': antrianId,
      'interviewerId': interviewerId,
      'keterangan': keterangan,
      'hasil': hasil,
      'persentase': persentase,
      'catatan': catatan,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  final String id;
  final String antrianId;
  final String interviewerId;
  final String keterangan;
  final String hasil;
  final double persentase;
  final String? catatan;
  final DateTime createdAt;

  InterviewResult({
    required this.id,
    required this.antrianId,
    required this.interviewerId,
    this.keterangan = 'AKTIF',
    this.hasil = 'PENDING',
    this.persentase = 0,
    this.catatan,
    required this.createdAt,
  });

  factory InterviewResult.fromMap(Map<String, dynamic> map, String docId) {
    return InterviewResult(
      id: docId,
      antrianId: map['antrianId'] as String? ?? '',
      interviewerId: map['interviewerId'] as String? ?? '',
      keterangan: map['keterangan'] as String? ?? 'AKTIF',
      hasil: map['hasil'] as String? ?? 'PENDING',
      persentase: (map['persentase'] as num?)?.toDouble() ?? 0,
      catatan: map['catatan'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get hasilDisplay {
    switch (hasil) {
      case 'DITERIMA': case 'LOLOS': return 'Lolos';
      case 'DITOLAK': case 'TIDAK_LOLOS': return 'Tidak Lolos';
      case 'DIPERTIMBANGKAN': return 'Dipertimbangkan';
      case 'PENDING': return 'Pending';
      default: return hasil;
    }
  }
}

class InterviewChat {
  Map<String, dynamic> toMap() {
    return {
      'sesiId': sesiId,
      'senderId': senderId,
      'pesan': pesan,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  final String id;
  final String sesiId;
  final String senderId;
  final String pesan;
  final DateTime createdAt;

  InterviewChat({
    required this.id,
    required this.sesiId,
    required this.senderId,
    required this.pesan,
    required this.createdAt,
  });

  factory InterviewChat.fromMap(Map<String, dynamic> map, String docId) {
    return InterviewChat(
      id: docId,
      sesiId: map['sesiId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      pesan: map['pesan'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class InterviewQr {
  Map<String, dynamic> toMap() {
    return {
      'sesiId': sesiId,
      'token': token,
      'aktif': aktif,
      'validFrom': Timestamp.fromDate(validFrom),
      'validUntil': Timestamp.fromDate(validUntil),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  final String id;
  final String sesiId;
  final String token;
  final bool aktif;
  final DateTime validFrom;
  final DateTime validUntil;
  final String? createdBy;
  final DateTime createdAt;

  InterviewQr({
    required this.id,
    required this.sesiId,
    required this.token,
    this.aktif = true,
    required this.validFrom,
    required this.validUntil,
    this.createdBy,
    required this.createdAt,
  });

  factory InterviewQr.fromMap(Map<String, dynamic> map, String docId) {
    return InterviewQr(
      id: docId,
      sesiId: map['sesiId'] as String? ?? '',
      token: map['token'] as String? ?? '',
      aktif: map['aktif'] as bool? ?? true,
      validFrom: (map['validFrom'] as Timestamp?)?.toDate() ?? DateTime.now(),
      validUntil: (map['validUntil'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  bool get isValid => aktif && DateTime.now().isBefore(validUntil);
}

