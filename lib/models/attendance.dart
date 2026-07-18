import 'package:cloud_firestore/cloud_firestore.dart';
class Attendance {
  final String id;
  final String organizationId;
  final String memberId;
  final DateTime date;
  final String status;
  final int cashAmount;
  final String? notes;
  final DateTime createdAt;

  Attendance({
    required this.id,
    required this.organizationId,
    required this.memberId,
    required this.date,
    this.status = 'hadir',
    this.cashAmount = 0,
    this.notes,
    required this.createdAt,
  });

  factory Attendance.fromMap(Map<String, dynamic> map, String docId) {
    return Attendance(
      id: docId,
      organizationId: map['organizationId'] as String? ?? '',
      memberId: map['memberId'] as String? ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] as String? ?? 'hadir',
      cashAmount: map['cashAmount'] as int? ?? 0,
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'memberId': memberId,
      'date': Timestamp.fromDate(date),
      'status': status,
      'cashAmount': cashAmount,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String get statusDisplay {
    switch (status) {
      case 'hadir': return 'Hadir';
      case 'tidak_hadir': return 'Tidak Hadir';
      case 'izin': return 'Izin';
      case 'sakit': return 'Sakit';
      case 'kas_saja': return 'Kas Saja';
      default: return status;
    }
  }

  String get statusBadgeColor {
    switch (status) {
      case 'hadir': return 'success';
      case 'tidak_hadir': return 'danger';
      case 'izin': return 'info';
      case 'sakit': return 'warning';
      case 'kas_saja': return 'grey';
      default: return 'grey';
    }
  }

  Attendance copyWith({
    String? id,
    String? organizationId,
    String? memberId,
    DateTime? date,
    String? status,
    int? cashAmount,
    String? notes,
    DateTime? createdAt,
  }) {
    return Attendance(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      memberId: memberId ?? this.memberId,
      date: date ?? this.date,
      status: status ?? this.status,
      cashAmount: cashAmount ?? this.cashAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

