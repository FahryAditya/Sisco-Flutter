import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Membangun cadangan (backup) data inti organisasi sebagai satu objek JSON.
///
/// Cakupan sengaja dibatasi pada data yang penting untuk arsip:
///   • members  — daftar anggota, termasuk `fotoUrl` (URL foto) dan `exp`,
///                beserta subkoleksi penghargaan yang diraih tiap anggota.
///   • attendance      — absensi anggota.
///   • cash_transactions + cash_expenses — uang kas (masuk & keluar).
///   • achievements    — definisi penghargaan.
///
/// Data lain (user, log, chat, wawancara, dll.) TIDAK diikutkan.
///
/// Layanan ini hanya membaca & menyusun struktur; penyimpanan ke perangkat
/// ditangani pemanggil (lihat BackupPage) agar bebas dependensi platform/UI.
///
/// Nilai khusus Firestore diubah agar aman untuk `jsonEncode`:
/// - Timestamp   -> string ISO-8601
/// - GeoPoint    -> {latitude, longitude}
/// - DocumentRef -> path dokumen
/// - Blob        -> base64
class BackupService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Koleksi tingkat-atas yang dibackup apa adanya.
  /// `members` ditangani terpisah karena punya subkoleksi `achievements`.
  static const List<String> _topLevel = [
    'attendance',
    'cash_transactions',
    'cash_expenses',
    'achievements',
  ];

  /// Hasil backup: struktur JSON + jumlah dokumen per koleksi (untuk ringkasan).
  static Future<BackupResult> buildBackup({String? exportedBy}) async {
    final collections = <String, dynamic>{};
    final counts = <String, int>{};

    for (final name in _topLevel) {
      final snap = await _db.collection(name).get();
      collections[name] = snap.docs.map(_docToJson).toList();
      counts[name] = snap.docs.length;
    }

    // members + subkoleksi achievements (penghargaan yang diraih) per anggota.
    // fotoUrl & exp sudah termasuk sebagai field dokumen anggota.
    final memberSnap = await _db.collection('members').get();
    final members = <Map<String, dynamic>>[];
    for (final doc in memberSnap.docs) {
      final m = _docToJson(doc);
      final ach = await doc.reference.collection('achievements').get();
      if (ach.docs.isNotEmpty) {
        m['_achievements'] = ach.docs.map(_docToJson).toList();
      }
      members.add(m);
    }
    collections['members'] = members;
    counts['members'] = members.length;

    final total = counts.values.fold<int>(0, (acc, n) => acc + n);

    final data = <String, dynamic>{
      'app': 'sisko',
      'schema': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'exportedBy': exportedBy ?? '',
      'totalDocuments': total,
      'collections': collections,
    };

    return BackupResult(
      json: const JsonEncoder.withIndent('  ').convert(data),
      counts: counts,
      total: total,
    );
  }

  /// Ubah satu dokumen menjadi Map JSON-aman, dengan `_id` = ID dokumen.
  static Map<String, dynamic> _docToJson(DocumentSnapshot doc) {
    final raw = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    final out = <String, dynamic>{'_id': doc.id};
    raw.forEach((k, v) => out[k] = _sanitize(v));
    return out;
  }

  /// Rekursif: ubah nilai Firestore menjadi tipe yang bisa di-`jsonEncode`.
  static dynamic _sanitize(dynamic value) {
    if (value == null || value is String || value is bool) return value;
    if (value is num) {
      // JSON tak mengenal NaN/Infinity — simpan sebagai string agar tidak gagal.
      if (value is double && (value.isNaN || value.isInfinite)) {
        return value.toString();
      }
      return value;
    }
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is GeoPoint) {
      return {'latitude': value.latitude, 'longitude': value.longitude};
    }
    if (value is DocumentReference) return value.path;
    if (value is Blob) return base64Encode(value.bytes);
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitize(v)));
    }
    if (value is Iterable) return value.map(_sanitize).toList();
    return value.toString();
  }
}

/// Hasil backup siap simpan.
class BackupResult {
  final String json;
  final Map<String, int> counts;
  final int total;

  const BackupResult({
    required this.json,
    required this.counts,
    required this.total,
  });
}
