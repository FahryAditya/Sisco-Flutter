import 'package:cloud_firestore/cloud_firestore.dart';

class KasTransaction {
  final String id;
  final String organizationId;
  final String type; // 'masuk' atau 'keluar'
  final double amount;
  final String description;
  final String? category; // 'kas_anggota', 'donasi', 'konsumsi', 'transport', dll
  final String? memberId; // jika dari kas anggota
  final String? memberName; // nama anggota untuk kemudahan
  final DateTime date;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final String? notes;
  final Map<String, dynamic>? metadata; // data tambahan

  KasTransaction({
    required this.id,
    required this.organizationId,
    required this.type,
    required this.amount,
    required this.description,
    this.category,
    this.memberId,
    this.memberName,
    required this.date,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.notes,
    this.metadata,
  });

  factory KasTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return KasTransaction(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      type: data['type'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      category: data['category'],
      memberId: data['memberId'],
      memberName: data['memberName'],
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'],
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'type': type,
      'amount': amount,
      'description': description,
      'category': category,
      'memberId': memberId,
      'memberName': memberName,
      'date': Timestamp.fromDate(date),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
      'metadata': metadata,
    };
  }

  KasTransaction copyWith({
    String? id,
    String? organizationId,
    String? type,
    double? amount,
    String? description,
    String? category,
    String? memberId,
    String? memberName,
    DateTime? date,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return KasTransaction(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper methods
  bool get isMasuk => type == 'masuk';
  bool get isKeluar => type == 'keluar';
  
  String get formattedAmount {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]}.',
    )}';
  }
}

// Model untuk saldo kas organisasi
class KasSaldo {
  final String organizationId;
  final double saldo;
  final double totalMasuk;
  final double totalKeluar;
  final DateTime lastUpdated;
  final String lastUpdatedBy;

  KasSaldo({
    required this.organizationId,
    required this.saldo,
    required this.totalMasuk,
    required this.totalKeluar,
    required this.lastUpdated,
    required this.lastUpdatedBy,
  });

  factory KasSaldo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return KasSaldo(
      organizationId: doc.id,
      saldo: (data['saldo'] ?? 0).toDouble(),
      totalMasuk: (data['totalMasuk'] ?? 0).toDouble(),
      totalKeluar: (data['totalKeluar'] ?? 0).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdatedBy: data['lastUpdatedBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'saldo': saldo,
      'totalMasuk': totalMasuk,
      'totalKeluar': totalKeluar,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'lastUpdatedBy': lastUpdatedBy,
    };
  }

  String get formattedSaldo {
    return 'Rp ${saldo.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]}.',
    )}';
  }
}