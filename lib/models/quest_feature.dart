import 'package:cloud_firestore/cloud_firestore.dart';

/// Konfigurasi aktivasi fitur "Airlangga QR Quest".
///
/// Disimpan sebagai dokumen tunggal di `app_features/airlangga_qr_quest`.
/// - [accessUserIds] = pemegang akses; user inilah yang menu quest-nya muncul.
///   (Administrator selalu melihat menu walau tidak ada di daftar ini.)
/// - [participantOrgIds] = organisasi peserta quest (validasi 2–6 di UI).
class QuestFeatureConfig {
  /// ID dokumen tetap untuk fitur ini.
  static const String docId = 'airlangga_qr_quest';

  final bool enabled;
  final List<String> accessUserIds;
  final List<String> participantOrgIds;
  final String? activatedBy;
  final String? activatedByNama;
  final DateTime? activatedAt;
  final DateTime? updatedAt;

  const QuestFeatureConfig({
    this.enabled = false,
    this.accessUserIds = const [],
    this.participantOrgIds = const [],
    this.activatedBy,
    this.activatedByNama,
    this.activatedAt,
    this.updatedAt,
  });

  /// Konfigurasi kosong/default (fitur belum pernah diaktifkan).
  static const QuestFeatureConfig empty = QuestFeatureConfig();

  factory QuestFeatureConfig.fromMap(Map<String, dynamic> map) {
    List<String> asStringList(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return const [];
    }

    return QuestFeatureConfig(
      enabled: map['enabled'] as bool? ?? false,
      accessUserIds: asStringList(map['accessUserIds']),
      participantOrgIds: asStringList(map['participantOrgIds']),
      activatedBy: map['activatedBy'] as String?,
      activatedByNama: map['activatedByNama'] as String?,
      activatedAt: (map['activatedAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'accessUserIds': accessUserIds,
      'participantOrgIds': participantOrgIds,
      'activatedBy': activatedBy,
      'activatedByNama': activatedByNama,
      if (activatedAt != null) 'activatedAt': Timestamp.fromDate(activatedAt!),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }

  /// Apakah [userId] termasuk pemegang akses yang dipilih administrator.
  bool hasAccess(String userId) =>
      enabled && accessUserIds.contains(userId);

  QuestFeatureConfig copyWith({
    bool? enabled,
    List<String>? accessUserIds,
    List<String>? participantOrgIds,
    String? activatedBy,
    String? activatedByNama,
    DateTime? activatedAt,
    DateTime? updatedAt,
  }) {
    return QuestFeatureConfig(
      enabled: enabled ?? this.enabled,
      accessUserIds: accessUserIds ?? this.accessUserIds,
      participantOrgIds: participantOrgIds ?? this.participantOrgIds,
      activatedBy: activatedBy ?? this.activatedBy,
      activatedByNama: activatedByNama ?? this.activatedByNama,
      activatedAt: activatedAt ?? this.activatedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
