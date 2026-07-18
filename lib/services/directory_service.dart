import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

/// Kontak staff ringkas (tanpa data sensitif) untuk fitur chat.
class StaffContact {
  final String id;
  final String nama;
  final String role;
  final bool online;
  final DateTime? lastSeen;

  StaffContact({
    required this.id,
    required this.nama,
    required this.role,
    this.online = false,
    this.lastSeen,
  });

  factory StaffContact.fromMap(Map<String, dynamic> map, String docId) {
    return StaffContact(
      id: docId,
      nama: map['nama'] as String? ?? '',
      role: map['role'] as String? ?? '',
      online: map['online'] as bool? ?? false,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
    );
  }

  /// True bila dianggap online: flag online DAN heartbeat masih segar (< 90 dtk).
  bool get isOnlineNow {
    if (!online) return false;
    final ls = lastSeen;
    if (ls == null) return false;
    return DateTime.now().difference(ls) < const Duration(seconds: 90);
  }
}

/// Layanan "buku alamat" staff.
///
/// Dokumen `users` menyimpan password plaintext sehingga rule bacanya sengaja
/// admin-only. Agar staff biasa tetap bisa melihat daftar kontak chat tanpa
/// mengekspos data sensitif, kita simpan cermin ringan (nama + role +
/// presence) di collection `directory/{uid}` yang boleh dibaca semua staff.
///
/// Pengisian: tiap staff menulis entri DIRINYA SENDIRI saat login (lihat
/// [upsertSelf]); administrator juga menulisnya saat membuat user baru.
class DirectoryService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static CollectionReference get _dir => _db.collection('directory');

  /// Role yang dianggap staff (bisa login & saling chat). Siswa dikecualikan.
  static const _staffRoles = {
    'administrator', 'superadmin', 'admin',
    'organization_admin', 'admin_organisasi', 'organisasi',
    'admin_eskul', 'eskul',
    'pembina_organisasi', 'pembina_eskul',
  };

  /// Perbarui/isi entri directory milik [user]. Dipanggil saat login.
  /// Hanya untuk staff — siswa tak perlu masuk buku alamat chat.
  static Future<void> upsertSelf(UserModel user) async {
    if (!_staffRoles.contains(user.role)) return;
    await _dir.doc(user.id).set({
      'nama': user.nama,
      'role': user.role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Tulis entri directory untuk user yang baru dibuat administrator, agar
  /// langsung muncul di daftar kontak tanpa menunggu ia login.
  static Future<void> upsertEntry({
    required String uid,
    required String nama,
    required String role,
  }) async {
    if (!_staffRoles.contains(role)) return;
    await _dir.doc(uid).set({
      'nama': nama,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Perbarui status kehadiran (online + heartbeat). Dipanggil oleh
  /// PresenceService saat app aktif/tidak aktif.
  static Future<void> setPresence({
    required String uid,
    required bool online,
  }) async {
    try {
      await _dir.doc(uid).set({
        'online': online,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {/* non-kritis */}
  }

  /// Ambil semua kontak staff kecuali [excludeId] (biasanya diri sendiri).
  static Future<List<StaffContact>> getStaffContacts(String excludeId) async {
    final snap = await _dir.get();
    final list = snap.docs
        .map((d) =>
            StaffContact.fromMap(d.data() as Map<String, dynamic>, d.id))
        .where((c) => c.id != excludeId && _staffRoles.contains(c.role))
        .toList()
      ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    return list;
  }

  /// Stream realtime satu kontak (untuk presence di header ruang chat).
  static Stream<StaffContact?> contactStream(String uid) {
    return _dir.doc(uid).snapshots().map((d) {
      if (!d.exists) return null;
      return StaffContact.fromMap(d.data() as Map<String, dynamic>, d.id);
    });
  }

  /// Hapus entri directory (dipanggil saat user dihapus administrator).
  static Future<void> remove(String uid) async {
    await _dir.doc(uid).delete();
  }
}
