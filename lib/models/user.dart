import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String nama;
  final String email;
  final String role;
  final String status;
  final List<String> orgIds;
  final String? password;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.role,
    this.status = 'aktif',
    this.orgIds = const [],
    this.password,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawOrgs = map['orgIds'];
    List<String> orgIds = [];
    if (rawOrgs is List) {
      orgIds = rawOrgs.map((e) => e.toString()).toList();
    }
    return UserModel(
      id: docId,
      nama: map['nama'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: (map['role'] as String?) ?? 'organization_admin',
      status: map['status'] as String? ?? 'aktif',
      orgIds: orgIds,
      password: map['password'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'email': email,
      'role': role,
      'status': status,
      'orgIds': orgIds,
      if (password != null) 'password': password,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? id,
    String? nama,
    String? email,
    String? role,
    List<String>? orgIds,
    String? password,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      role: role ?? this.role,
      orgIds: orgIds ?? this.orgIds,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isAdministrator =>
      role == 'administrator' || role == 'superadmin' || role == 'admin';

  /// Ketua/Wakil Organisasi (PMR, OSIS, MPK, dll)
  bool get isAdminOrg =>
      role == 'organization_admin' || role == 'admin_organisasi' ||
      role == 'organisasi';

  /// Ketua Eskul (Volley, Basket, Futsal, dll)
  bool get isAdminEskul => role == 'admin_eskul' || role == 'eskul';

  /// Guru Pembina Organisasi
  bool get isPembinaOrg => role == 'pembina_organisasi';

  /// Guru Pembina Eskul
  bool get isPembinaEskul => role == 'pembina_eskul';

  /// Any "admin unit" role (organisasi atau eskul). Kept for backward compat.
  bool get isOrganizationAdmin => isAdminOrg || isAdminEskul;

  /// Any pembina role (organisasi atau eskul).
  bool get isPembina => isPembinaOrg || isPembinaEskul;

  /// Any non-siswa staff role that can log in and manage a unit.
  bool get isStaff =>
      isAdministrator || isOrganizationAdmin || isPembina;

  bool get canAccessAdmin => isAdministrator;

  // ── Feature permissions (roleakses.md — PERMISSION MATRIX FINAL) ──

  /// QR Code (Generate/View/Delete): Admin + Admin Org only.
  bool get canManageQr => isAdministrator || isAdminOrg;

  /// Wawancara: Admin + Admin Org + Pembina Org (bukan role eskul).
  bool get canWawancara => isAdministrator || isAdminOrg || isPembinaOrg;

  /// Pengumuman ke Anggota: Admin + Admin Org + Admin Eskul (bukan pembina).
  bool get canPengumumanAnggota =>
      isAdministrator || isAdminOrg || isAdminEskul;

  /// Pengumuman Sistem: Admin only.
  bool get canPengumumanSistem => isAdministrator;

  /// Materi & Jadwal: Admin only.
  bool get canMateriJadwal => isAdministrator;

  /// Manage User: Admin only.
  bool get canManageUser => isAdministrator;

  /// Audit Log: Admin only.
  bool get canAuditLog => isAdministrator;

  /// Export & Import: semua role staff.
  bool get canExportImport => isStaff;

  /// Dokumentasi: Administrator + Admin Org + Admin Eskul + Pembina Org + Pembina Eskul.
  bool get canDokumentasi => isAdministrator || isOrganizationAdmin || isPembina;

  /// Kelola anggota pada organisasi/eskul yang ditugaskan.
  bool get canManageMembers => isAdministrator || isOrganizationAdmin || isPembina;

  String get roleDisplay {
    switch (role) {
      case 'administrator':
      case 'superadmin':
      case 'admin':
        return 'Administrator';
      case 'organization_admin':
      case 'admin_organisasi':
      case 'organisasi':
        return 'Admin Organisasi';
      case 'admin_eskul':
      case 'eskul':
        return 'Admin Eskul';
      case 'pembina_organisasi':
        return 'Pembina Organisasi';
      case 'pembina_eskul':
        return 'Pembina Eskul';
      case 'siswa':
        return 'Siswa';
      default:
        return role;
    }
  }
}
