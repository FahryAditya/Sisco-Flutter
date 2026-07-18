import 'package:cloud_firestore/cloud_firestore.dart';
class Member {
  final String id;
  final String organizationId;
  final String? nis;
  final String name;
  final String? email;
  final String? kelas;
  final String? fotoUrl;
  final int level;
  final int exp;
  final int progress;
  final String jabatan;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Member({
    required this.id,
    required this.organizationId,
    this.nis,
    required this.name,
    this.email,
    this.kelas,
    this.fotoUrl,
    this.level = 1,
    this.exp = 0,
    this.progress = 0,
    this.jabatan = 'Anggota',
    this.status = 'ACTIVE',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Member.fromMap(Map<String, dynamic> map, String docId) {
    return Member(
      id: docId,
      organizationId: map['organizationId'] as String? ?? '',
      nis: map['nis'] as String?,
      name: map['name'] as String? ?? '',
      email: map['email'] as String?,
      kelas: map['kelas'] as String?,
      fotoUrl: map['fotoUrl'] as String?,
      level: map['level'] as int? ?? 1,
      exp: map['exp'] as int? ?? 0,
      progress: map['progress'] as int? ?? 0,
      jabatan: map['jabatan'] as String? ?? 'Anggota',
      status: map['status'] as String? ?? 'ACTIVE',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'nis': nis,
      'name': name,
      'email': email,
      'kelas': kelas,
      'fotoUrl': fotoUrl,
      'level': level,
      'exp': exp,
      'progress': progress,
      'jabatan': jabatan,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  int get maxExp {
    return level * 100;
  }

  double get expPercentage {
    if (maxExp == 0) return 0;
    return exp / maxExp;
  }

  bool get isActive => status == 'ACTIVE';

  Member copyWith({
    String? id,
    String? organizationId,
    String? nis,
    String? name,
    String? email,
    String? kelas,
    String? fotoUrl,
    int? level,
    int? exp,
    int? progress,
    String? jabatan,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Member(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      nis: nis ?? this.nis,
      name: name ?? this.name,
      email: email ?? this.email,
      kelas: kelas ?? this.kelas,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      level: level ?? this.level,
      exp: exp ?? this.exp,
      progress: progress ?? this.progress,
      jabatan: jabatan ?? this.jabatan,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

