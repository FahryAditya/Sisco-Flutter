import 'package:cloud_firestore/cloud_firestore.dart';
class Achievement {
  final String id;
  final String icon;
  final String nama;
  final String deskripsi;
  final int expReward;
  final String organizationId;
  final DateTime createdAt;

  Achievement({
    required this.id,
    required this.icon,
    required this.nama,
    required this.deskripsi,
    this.expReward = 0,
    required this.organizationId,
    required this.createdAt,
  });

  factory Achievement.fromMap(Map<String, dynamic> map, String docId) {
    return Achievement(
      id: docId,
      icon: map['icon'] as String? ?? 'emoji_events',
      nama: map['nama'] as String? ?? '',
      deskripsi: map['deskripsi'] as String? ?? '',
      expReward: map['expReward'] as int? ?? 0,
      organizationId: map['organizationId'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'icon': icon,
      'nama': nama,
      'deskripsi': deskripsi,
      'expReward': expReward,
      'organizationId': organizationId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class MemberAchievement {
  final String id;
  final String achievementId;
  final String memberId;
  final DateTime tanggal;

  MemberAchievement({
    required this.id,
    required this.achievementId,
    required this.memberId,
    required this.tanggal,
  });

  factory MemberAchievement.fromMap(Map<String, dynamic> map, String docId) {
    return MemberAchievement(
      id: docId,
      achievementId: map['achievementId'] as String? ?? '',
      memberId: map['memberId'] as String? ?? '',
      tanggal: (map['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'achievementId': achievementId,
      'memberId': memberId,
      'tanggal': Timestamp.fromDate(tanggal),
    };
  }
}

