import 'package:cloud_firestore/cloud_firestore.dart';
class ActivityLog {
  final String id;
  final String userId;
  final String userNama;
  final String aksi;
  final String tabel;
  final String? recordId;
  final String deskripsi;
  final String? ipAddress;
  final DateTime createdAt;

  ActivityLog({
    required this.id,
    required this.userId,
    required this.userNama,
    required this.aksi,
    required this.tabel,
    this.recordId,
    required this.deskripsi,
    this.ipAddress,
    required this.createdAt,
  });

  factory ActivityLog.fromMap(Map<String, dynamic> map, String docId) {
    return ActivityLog(
      id: docId,
      userId: map['userId'] as String? ?? '',
      userNama: map['userNama'] as String? ?? '',
      aksi: map['aksi'] as String? ?? 'CREATE',
      tabel: map['tabel'] as String? ?? '',
      recordId: map['recordId'] as String?,
      deskripsi: map['deskripsi'] as String? ?? '',
      ipAddress: map['ipAddress'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userNama': userNama,
      'aksi': aksi,
      'tabel': tabel,
      'recordId': recordId,
      'deskripsi': deskripsi,
      'ipAddress': ipAddress,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String get aksiIcon {
    switch (aksi) {
      case 'CREATE': return 'add_circle';
      case 'UPDATE': return 'edit';
      case 'DELETE': return 'delete';
      case 'LOGIN': return 'login';
      case 'LOGOUT': return 'logout';
      default: return 'info';
    }
  }

  String get aksiColor {
    switch (aksi) {
      case 'CREATE': return 'success';
      case 'UPDATE': return 'info';
      case 'DELETE': return 'danger';
      case 'LOGIN': return 'primary';
      case 'LOGOUT': return 'warning';
      default: return 'grey';
    }
  }
}

