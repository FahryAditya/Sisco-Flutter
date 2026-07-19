import 'package:cloud_firestore/cloud_firestore.dart';

class CashTransaction {
  final String id;
  final String organizationId;
  final String memberId;
  final String? memberName;
  final String? memberKelas;
  final int amount;
  final String description;
  final String category;
  final String type;
  final DateTime tanggal;
  final DateTime createdAt;

  CashTransaction({
    required this.id,
    required this.organizationId,
    required this.memberId,
    this.memberName,
    this.memberKelas,
    required this.amount,
    required this.description,
    this.category = 'Lainnya',
    this.type = 'Pemasukan',
    required this.tanggal,
    required this.createdAt,
  });

  factory CashTransaction.fromMap(Map<String, dynamic> map, String docId) {
    return CashTransaction(
      id: docId,
      organizationId: map['organizationId'] as String? ?? '',
      memberId: map['memberId'] as String? ?? '',
      memberName: map['memberName'] as String?,
      memberKelas: map['memberKelas'] as String?,
      amount: map['amount'] as int? ?? 0,
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'Lainnya',
      type: map['type'] as String? ?? 'Pemasukan',
      tanggal: (map['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'memberId': memberId,
      if (memberName != null) 'memberName': memberName,
      if (memberKelas != null) 'memberKelas': memberKelas,
      'amount': amount,
      'description': description,
      'category': category,
      'type': type,
      'tanggal': Timestamp.fromDate(tanggal),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class CashExpense {
  final String id;
  final String organizationId;
  final int nominal;
  final String keterangan;
  final String kategori;
  final String? buktiUrl;
  final DateTime tanggal;
  final String createdBy;
  final DateTime createdAt;

  CashExpense({
    required this.id,
    required this.organizationId,
    required this.nominal,
    required this.keterangan,
    this.kategori = 'Lainnya',
    this.buktiUrl,
    required this.tanggal,
    required this.createdBy,
    required this.createdAt,
  });

  factory CashExpense.fromMap(Map<String, dynamic> map, String docId) {
    return CashExpense(
      id: docId,
      organizationId: map['organizationId'] as String? ?? '',
      nominal: map['nominal'] as int? ?? 0,
      keterangan: map['keterangan'] as String? ?? '',
      kategori: map['kategori'] as String? ?? 'Lainnya',
      buktiUrl: map['buktiUrl'] as String?,
      tanggal: (map['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'nominal': nominal,
      'keterangan': keterangan,
      'kategori': kategori,
      if (buktiUrl != null) 'buktiUrl': buktiUrl,
      'tanggal': Timestamp.fromDate(tanggal),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
