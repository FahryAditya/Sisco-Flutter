import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'local_database.dart';
import 'connectivity_service.dart';

/// Ringkasan status sinkronisasi untuk ditampilkan di UI.
@immutable
class SyncStatus {
  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final DateTime? lastSyncedAt;

  const SyncStatus({
    this.isOnline = true,
    this.isSyncing = false,
    this.pendingCount = 0,
    this.lastSyncedAt,
  });

  SyncStatus copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    DateTime? lastSyncedAt,
  }) {
    return SyncStatus(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  bool get hasPending => pendingCount > 0;
}

/// Dokumen hasil baca yang seragam (dari Firestore maupun cache SQLite),
/// sehingga [FirestoreService] bisa memetakannya ke model dengan cara sama.
class SyncDoc {
  final String id;
  final Map<String, dynamic> data;
  const SyncDoc(this.id, this.data);
}

/// Orkestrator offline-first.
///
/// Semua tulisan/bacaan CRUD dari [FirestoreService] dialihkan ke sini:
/// - **Online**  : langsung ke Firestore, lalu cermin ke cache SQLite.
/// - **Offline** : tulis optimistis ke cache + antre di outbox; dibaca dari cache.
///
/// Saat jaringan pulih, [flush] mengirim antrian ke Firestore dengan strategi
/// **last-write-wins** berdasarkan `updatedAt`.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final LocalDatabase _local = LocalDatabase.instance;
  final ConnectivityService _conn = ConnectivityService.instance;
  final Uuid _uuid = const Uuid();

  final ValueNotifier<SyncStatus> status = ValueNotifier(const SyncStatus());

  StreamSubscription<bool>? _sub;
  bool _flushing = false;

  Future<void> init() async {
    await _local.init();
    final online = await _conn.isOnline();
    await _refreshStatus(isOnline: online);

    _sub = _conn.onlineStream.listen((online) async {
      await _refreshStatus(isOnline: online);
      if (online) {
        // Jaringan pulih → coba kirim antrian.
        unawaited(flush());
      }
    });

    if (online) unawaited(flush());
  }

  void dispose() {
    _sub?.cancel();
  }

  // ===================== WRITE =====================

  /// Buat dokumen baru dengan ID stabil (UUID). Mengganti pola `.add()` yang
  /// menghasilkan ID acak dan bisa menimbulkan duplikat saat offline.
  Future<String> addDoc(String collection, Map<String, dynamic> data) async {
    final id = _uuid.v4();
    await setDoc(collection, id, data);
    return id;
  }

  /// Tulis (buat/timpa) dokumen. [merge] true untuk menggabung field.
  Future<void> setDoc(
    String collection,
    String docId,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    final resolved = _resolveServerValues(data);
    await _dispatch(
      op: merge ? 'update' : 'set',
      collection: collection,
      docId: docId,
      payload: resolved,
    );
  }

  /// Perbarui sebagian field dokumen yang sudah ada.
  Future<void> updateDoc(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final resolved = _resolveServerValues(data);
    await _dispatch(
      op: 'update',
      collection: collection,
      docId: docId,
      payload: resolved,
    );
  }

  Future<void> deleteDoc(String collection, String docId) async {
    await _dispatch(
      op: 'delete',
      collection: collection,
      docId: docId,
      payload: null,
    );
  }

  Future<void> _dispatch({
    required String op,
    required String collection,
    required String docId,
    required Map<String, dynamic>? payload,
  }) async {
    // 1) Terapkan optimistis ke cache lokal supaya UI langsung konsisten.
    await _applyToCache(op, collection, docId, payload);

    final updatedAt = _updatedAtMillis(payload);

    // 2) Tentukan tujuan berdasarkan KONEKTIVITAS, bukan exception.
    //    Firestore punya cache offline sendiri: `set()`/`delete()` selesai dari
    //    tulisan lokal dan TIDAK melempar error saat offline, lalu disinkron
    //    otomatis tanpa lewat last-write-wins kita. Karena itu, saat offline
    //    kita SENGAJA tidak menyentuh Firestore — cukup antre di outbox agar
    //    [flush] yang mengendalikan sinkronisasi (dengan LWW) saat online.
    final online = await _conn.isOnline();
    if (!online) {
      await _enqueue(op, collection, docId, payload, updatedAt);
      await _refreshStatus(isOnline: false);
      return;
    }

    try {
      final ref = _fs.collection(collection).doc(docId);
      switch (op) {
        case 'delete':
          await ref.delete();
          break;
        case 'update':
          await ref.set(payload!, SetOptions(merge: true));
          break;
        default: // set
          await ref.set(payload!);
      }
      await _refreshStatus(isOnline: true);
    } on FirebaseException catch (e) {
      // Jaringan putus di tengah operasi → jatuh ke antrian.
      if (_isOfflineError(e)) {
        await _enqueue(op, collection, docId, payload, updatedAt);
        await _refreshStatus(isOnline: false);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _enqueue(
    String op,
    String collection,
    String docId,
    Map<String, dynamic>? payload,
    int updatedAt,
  ) async {
    await _local.enqueue(
      collection: collection,
      docId: docId,
      op: op,
      payload: payload,
      updatedAt: updatedAt,
    );
  }

  Future<void> _applyToCache(
    String op,
    String collection,
    String docId,
    Map<String, dynamic>? payload,
  ) async {
    if (op == 'delete') {
      await _local.deleteCache(collection, docId);
      return;
    }
    if (payload == null) return;
    if (op == 'update') {
      final existing = await _local.readCacheDoc(collection, docId) ?? {};
      await _local.upsertCache(collection, docId, {...existing, ...payload});
    } else {
      await _local.upsertCache(collection, docId, payload);
    }
  }

  // ===================== READ (CACHE-FIRST) =====================
  //
  // Strategi baca:
  //   1. Cek meta `cacheKey`. Kalau pernah dimuat → langsung baca cache lokal,
  //      TIDAK menyentuh Firestore. Ini yang memangkas Reads secara signifikan.
  //   2. Kalau belum pernah (atau [forceRefresh] = true) → fetch Firestore,
  //      REPLACE cache untuk koleksi/subset yang dimaksud, dan tandai meta.
  //   3. Kalau Firestore gagal karena offline → fallback ke cache apa adanya.
  //
  // [cacheKey] mengidentifikasi query secara unik (mis. `members:orgABC`)
  // sehingga dua query berbeda pada koleksi yang sama tidak saling menimpa
  // sinyal "sudah pernah dimuat". Kalau [cacheKey] tidak diisi, perilaku
  // lama (network-first) dipertahankan.

  /// Baca kumpulan dokumen dengan strategi cache-first.
  Future<List<SyncDoc>> getDocs({
    required String collection,
    required Query Function() query,
    bool Function(String id, Map<String, dynamic> data)? cacheFilter,
    int Function(Map<String, dynamic> a, Map<String, dynamic> b)? cacheSort,
    String? cacheKey,
    bool forceRefresh = false,
  }) async {
    // 1) Cache-first: kalau meta ada & tidak dipaksa refresh → dari cache.
    if (cacheKey != null && !forceRefresh) {
      final loadedAt = await _local.getCacheMeta(cacheKey);
      if (loadedAt != null) {
        return _readFromCache(collection, cacheFilter, cacheSort);
      }
    }

    // 2) Belum pernah dimuat atau force-refresh → hit Firestore.
    try {
      final snap = await query().get();
      final docs = <SyncDoc>[];
      final serverIds = <String>{};
      for (final d in snap.docs) {
        final data = (d.data() as Map<String, dynamic>?) ?? {};
        docs.add(SyncDoc(d.id, data));
        serverIds.add(d.id);
        await _local.upsertCache(collection, d.id, data);
      }

      // Kalau ada cacheKey & cacheFilter: buang row cache dari subset ini yang
      // TIDAK ada di server (dokumen sudah dihapus). Tanpa langkah ini,
      // pembacaan cache berikutnya akan menampilkan hantu.
      if (cacheKey != null && cacheFilter != null) {
        final rows = await _local.readCache(collection);
        for (final e in rows) {
          if (cacheFilter(e.key, e.value) && !serverIds.contains(e.key)) {
            await _local.deleteCache(collection, e.key);
          }
        }
      }

      if (cacheKey != null) {
        await _local.setCacheMeta(cacheKey);
      }
      return docs;
    } on FirebaseException catch (e) {
      if (!_isOfflineError(e)) rethrow;
      return _readFromCache(collection, cacheFilter, cacheSort);
    }
  }

  /// Baca satu dokumen dengan strategi cache-first. Kalau cache lokal berisi
  /// dokumennya, kembalikan tanpa hit Firestore.
  Future<SyncDoc?> getDoc(
    String collection,
    String docId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _local.readCacheDoc(collection, docId);
      if (cached != null) return SyncDoc(docId, cached);
    }

    try {
      final d = await _fs.collection(collection).doc(docId).get();
      if (!d.exists) {
        // Cache mungkin masih menyimpan tombstone lama; bersihkan.
        await _local.deleteCache(collection, docId);
        return null;
      }
      final data = d.data() ?? {};
      await _local.upsertCache(collection, docId, data);
      return SyncDoc(docId, data);
    } on FirebaseException catch (e) {
      if (!_isOfflineError(e)) rethrow;
      final cached = await _local.readCacheDoc(collection, docId);
      return cached == null ? null : SyncDoc(docId, cached);
    }
  }

  /// Hapus tanda "sudah dimuat" untuk sebuah [cacheKey]. Bacaan berikutnya
  /// akan menembus ke Firestore. Berguna kalau ada perubahan besar-besaran
  /// dari layar/alur lain di luar CRUD normal.
  Future<void> invalidateCache(String cacheKey) async {
    await _local.deleteCacheMeta(cacheKey);
  }

  Future<List<SyncDoc>> _readFromCache(
    String collection,
    bool Function(String id, Map<String, dynamic> data)? filter,
    int Function(Map<String, dynamic> a, Map<String, dynamic> b)? sort,
  ) async {
    final rows = await _local.readCache(collection);
    var docs = rows.map((e) => SyncDoc(e.key, e.value)).toList();
    if (filter != null) {
      docs = docs.where((d) => filter(d.id, d.data)).toList();
    }
    if (sort != null) {
      docs.sort((a, b) => sort(a.data, b.data));
    }
    return docs;
  }

  // ===================== FLUSH (SYNC) =====================

  /// Kirim seluruh antrian outbox ke Firestore. Aman dipanggil berulang.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    status.value = status.value.copyWith(isSyncing: true);
    try {
      final ops = await _local.pendingOps();
      for (final op in ops) {
        try {
          final applied = await _applyOpToServer(op);
          if (applied) {
            // Segarkan cache dari server agar konsisten pasca-sync.
            if (op.op != 'delete') {
              final fresh =
                  await _fs.collection(op.collection).doc(op.docId).get();
              if (fresh.exists) {
                await _local.upsertCache(op.collection, op.docId,
                    fresh.data() ?? {});
              }
            }
          }
          await _local.markDone(op.id);
        } on FirebaseException catch (e) {
          if (_isOfflineError(e)) {
            // Masih offline → hentikan, sisakan antrian untuk percobaan berikut.
            await _local.markPending(op.id);
            break;
          }
          await _local.markFailed(op.id, e.message ?? e.code);
        } catch (e) {
          await _local.markFailed(op.id, e.toString());
        }
      }
      final remaining = await _local.pendingCount();
      status.value = status.value.copyWith(
        isSyncing: false,
        pendingCount: remaining,
        lastSyncedAt: remaining == 0 ? DateTime.now() : status.value.lastSyncedAt,
      );
    } finally {
      _flushing = false;
      if (status.value.isSyncing) {
        status.value = status.value.copyWith(isSyncing: false);
      }
    }
  }

  /// Terapkan satu operasi ke Firestore dengan last-write-wins.
  /// Return false bila operasi sengaja dilewati (server lebih baru).
  Future<bool> _applyOpToServer(OutboxOp op) async {
    final ref = _fs.collection(op.collection).doc(op.docId);

    if (op.op == 'delete') {
      await ref.delete();
      return true;
    }

    return _fs.runTransaction<bool>((txn) async {
      final snap = await txn.get(ref);
      if (snap.exists) {
        final sv = snap.data()?['updatedAt'];
        final serverMs = sv is Timestamp ? sv.millisecondsSinceEpoch : 0;
        // Server lebih baru → pertahankan versi server (LWW).
        if (serverMs > op.updatedAt) return false;
      }
      // op.op 'update' pakai merge; 'set' menimpa penuh.
      txn.set(ref, op.payload ?? {}, SetOptions(merge: op.op == 'update'));
      return true;
    });
  }

  // ===================== HELPERS =====================

  Future<void> _refreshStatus({bool? isOnline}) async {
    final pending = await _local.pendingCount();
    status.value = status.value.copyWith(
      isOnline: isOnline,
      pendingCount: pending,
    );
  }

  static bool _isOfflineError(FirebaseException e) {
    return e.code == 'unavailable' ||
        e.code == 'deadline-exceeded' ||
        e.code == 'network-request-failed';
  }

  /// Ganti `FieldValue.serverTimestamp()` (satu-satunya FieldValue yang dipakai
  /// di codebase) dengan `Timestamp.now()` agar bisa diserialisasi & dipakai
  /// sebagai dasar last-write-wins secara konsisten online maupun offline.
  static Map<String, dynamic> _resolveServerValues(Map<String, dynamic> data) {
    final now = Timestamp.now();
    dynamic walk(dynamic v) {
      if (v is FieldValue) return now;
      if (v is Map) {
        return v.map((k, val) => MapEntry(k, walk(val)));
      }
      if (v is List) return v.map(walk).toList();
      return v;
    }

    return Map<String, dynamic>.from(walk(data) as Map);
  }

  static int _updatedAtMillis(Map<String, dynamic>? data) {
    if (data == null) return Timestamp.now().millisecondsSinceEpoch;
    final v = data['updatedAt'] ?? data['createdAt'];
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    return Timestamp.now().millisecondsSinceEpoch;
  }
}
