import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';

/// Penyimpanan lokal SQLite untuk mode offline.
///
/// Dua tabel:
/// - `cache`  : cermin dokumen Firestore agar bisa dibaca saat offline.
/// - `outbox` : antrian tulisan (create/update/delete) yang belum tersinkron
///              ke Firestore. Di-flush oleh [SyncService] saat jaringan pulih.
///
/// Nilai Firestore yang tidak bisa langsung di-JSON-kan (mis. [Timestamp])
/// dikodekan lewat [encode]/[decode]. `FieldValue.serverTimestamp()` sudah
/// di-resolve ke [Timestamp] konkret oleh pemanggil sebelum masuk ke sini.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  static const _dbName = 'sisko_offline.db';
  static const _dbVersion = 2;

  Database? _db;

  /// SQLite (`sqflite`) tidak didukung di Flutter Web. Di web seluruh lapisan
  /// cache/outbox dinonaktifkan — app berjalan online-only lewat Firestore
  /// (yang sudah punya offline persistence sendiri via IndexedDB).
  bool get _disabled => kIsWeb;

  Future<Database> get _database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = '$dir/$_dbName';
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache (
            collection TEXT NOT NULL,
            docId      TEXT NOT NULL,
            data       TEXT NOT NULL,
            updatedAt  INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (collection, docId)
          )
        ''');
        await db.execute('''
          CREATE TABLE outbox (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            collection TEXT NOT NULL,
            docId      TEXT NOT NULL,
            op         TEXT NOT NULL,
            payload    TEXT,
            updatedAt  INTEGER NOT NULL DEFAULT 0,
            status     TEXT NOT NULL DEFAULT 'pending',
            retries    INTEGER NOT NULL DEFAULT 0,
            error      TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_outbox_status ON outbox (status, id)',
        );
        await db.execute('''
          CREATE TABLE cache_meta (
            cacheKey  TEXT PRIMARY KEY,
            loadedAt  INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cache_meta (
              cacheKey  TEXT PRIMARY KEY,
              loadedAt  INTEGER NOT NULL
            )
          ''');
        }
      },
    );
  }

  Future<void> init() async {
    if (_disabled) return;
    await _database;
  }

  // ===================== CODEC =====================
  // Firestore <-> JSON string. Tipe khusus dikodekan sebagai objek bertanda:
  //   Timestamp  -> {"__ts__": <millisSinceEpoch>}
  //   GeoPoint   -> {"__geo__": [lat, lng]}
  // Nilai lain (String/num/bool/List/Map/null) lolos apa adanya.

  static dynamic _encodeValue(dynamic v) {
    if (v is Timestamp) {
      return {'__ts__': v.millisecondsSinceEpoch};
    }
    if (v is DateTime) {
      return {'__ts__': v.millisecondsSinceEpoch};
    }
    if (v is GeoPoint) {
      return {
        '__geo__': [v.latitude, v.longitude]
      };
    }
    if (v is Map) {
      return v.map((k, val) => MapEntry(k, _encodeValue(val)));
    }
    if (v is List) {
      return v.map(_encodeValue).toList();
    }
    return v;
  }

  static dynamic _decodeValue(dynamic v) {
    if (v is Map) {
      if (v.containsKey('__ts__')) {
        return Timestamp.fromMillisecondsSinceEpoch(v['__ts__'] as int);
      }
      if (v.containsKey('__geo__')) {
        final g = (v['__geo__'] as List).cast<num>();
        return GeoPoint(g[0].toDouble(), g[1].toDouble());
      }
      return v.map((k, val) => MapEntry(k as String, _decodeValue(val)));
    }
    if (v is List) {
      return v.map(_decodeValue).toList();
    }
    return v;
  }

  /// Serialisasi map Firestore ke string JSON untuk disimpan di SQLite.
  static String encode(Map<String, dynamic> data) =>
      jsonEncode(_encodeValue(data));

  /// Kebalikan [encode]: string JSON -> map dengan tipe Firestore dipulihkan.
  static Map<String, dynamic> decode(String raw) =>
      Map<String, dynamic>.from(_decodeValue(jsonDecode(raw)) as Map);

  // ===================== CACHE =====================

  Future<void> upsertCache(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    if (_disabled) return;
    final db = await _database;
    await db.insert(
      'cache',
      {
        'collection': collection,
        'docId': docId,
        'data': encode(data),
        'updatedAt': _extractUpdatedAt(data),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ganti seluruh isi cache sebuah koleksi dengan [docs] (hasil query online).
  Future<void> replaceCollectionCache(
    String collection,
    Map<String, Map<String, dynamic>> docs,
  ) async {
    if (_disabled) return;
    final db = await _database;
    await db.transaction((txn) async {
      for (final entry in docs.entries) {
        await txn.insert(
          'cache',
          {
            'collection': collection,
            'docId': entry.key,
            'data': encode(entry.value),
            'updatedAt': _extractUpdatedAt(entry.value),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> deleteCache(String collection, String docId) async {
    if (_disabled) return;
    final db = await _database;
    await db.delete(
      'cache',
      where: 'collection = ? AND docId = ?',
      whereArgs: [collection, docId],
    );
  }

  /// Hapus semua baris cache milik satu [collection]. Dipakai saat refresh
  /// list agar dokumen yang sudah dihapus di server tidak "tertinggal" di
  /// cache setelah replace.
  Future<void> clearCollectionCache(String collection) async {
    if (_disabled) return;
    final db = await _database;
    await db.delete(
      'cache',
      where: 'collection = ?',
      whereArgs: [collection],
    );
  }

  // ===================== CACHE META =====================
  // Meta menandai bahwa sebuah [cacheKey] pernah diisi (loadedAt = millis).
  // Tanpa ini kita tidak bisa bedakan "cache kosong karena belum pernah
  // dimuat" (harus fetch Firestore) vs "cache kosong karena data memang
  // tidak ada" (jangan fetch lagi).

  Future<int?> getCacheMeta(String cacheKey) async {
    if (_disabled) return null;
    final db = await _database;
    final rows = await db.query(
      'cache_meta',
      where: 'cacheKey = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['loadedAt'] as int?;
  }

  Future<void> setCacheMeta(String cacheKey, {int? loadedAt}) async {
    if (_disabled) return;
    final db = await _database;
    await db.insert(
      'cache_meta',
      {
        'cacheKey': cacheKey,
        'loadedAt': loadedAt ?? DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCacheMeta(String cacheKey) async {
    if (_disabled) return;
    final db = await _database;
    await db.delete(
      'cache_meta',
      where: 'cacheKey = ?',
      whereArgs: [cacheKey],
    );
  }

  /// Baca semua dokumen cache pada [collection]. Mengembalikan pasangan
  /// (docId, data). Filter/urut dilakukan pemanggil di memori.
  Future<List<MapEntry<String, Map<String, dynamic>>>> readCache(
    String collection,
  ) async {
    if (_disabled) return [];
    final db = await _database;
    final rows = await db.query(
      'cache',
      where: 'collection = ?',
      whereArgs: [collection],
    );
    return rows
        .map((r) => MapEntry(
              r['docId'] as String,
              decode(r['data'] as String),
            ))
        .toList();
  }

  Future<Map<String, dynamic>?> readCacheDoc(
    String collection,
    String docId,
  ) async {
    if (_disabled) return null;
    final db = await _database;
    final rows = await db.query(
      'cache',
      where: 'collection = ? AND docId = ?',
      whereArgs: [collection, docId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return decode(rows.first['data'] as String);
  }

  // ===================== OUTBOX =====================

  /// Antre sebuah operasi tulis. [op] ∈ set|update|delete.
  Future<int> enqueue({
    required String collection,
    required String docId,
    required String op,
    Map<String, dynamic>? payload,
    required int updatedAt,
  }) async {
    if (_disabled) return 0;
    final db = await _database;
    return db.insert('outbox', {
      'collection': collection,
      'docId': docId,
      'op': op,
      'payload': payload == null ? null : encode(payload),
      'updatedAt': updatedAt,
      'status': 'pending',
      'retries': 0,
    });
  }

  /// Semua operasi yang masih perlu dikirim (pending atau failed), urut FIFO.
  Future<List<OutboxOp>> pendingOps() async {
    if (_disabled) return [];
    final db = await _database;
    final rows = await db.query(
      'outbox',
      where: "status IN ('pending','failed')",
      orderBy: 'id ASC',
    );
    return rows.map(OutboxOp.fromRow).toList();
  }

  Future<int> pendingCount() async {
    if (_disabled) return 0;
    final db = await _database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM outbox WHERE status IN ('pending','failed')",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markDone(int id) async {
    if (_disabled) return;
    final db = await _database;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markFailed(int id, String error) async {
    if (_disabled) return;
    final db = await _database;
    await db.rawUpdate(
      'UPDATE outbox SET status = ?, retries = retries + 1, error = ? WHERE id = ?',
      ['failed', error, id],
    );
  }

  /// Kembalikan op ke status pending (mis. saat mau dicoba lagi).
  Future<void> markPending(int id) async {
    if (_disabled) return;
    final db = await _database;
    await db.update(
      'outbox',
      {'status': 'pending'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static int _extractUpdatedAt(Map<String, dynamic> data) {
    final v = data['updatedAt'];
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    if (v is DateTime) return v.millisecondsSinceEpoch;
    final c = data['createdAt'];
    if (c is Timestamp) return c.millisecondsSinceEpoch;
    if (c is DateTime) return c.millisecondsSinceEpoch;
    return 0;
  }
}

/// Satu baris antrian outbox.
class OutboxOp {
  final int id;
  final String collection;
  final String docId;
  final String op; // set | update | delete
  final Map<String, dynamic>? payload;
  final int updatedAt; // millisSinceEpoch, dasar last-write-wins

  OutboxOp({
    required this.id,
    required this.collection,
    required this.docId,
    required this.op,
    required this.payload,
    required this.updatedAt,
  });

  factory OutboxOp.fromRow(Map<String, dynamic> r) {
    final raw = r['payload'] as String?;
    return OutboxOp(
      id: r['id'] as int,
      collection: r['collection'] as String,
      docId: r['docId'] as String,
      op: r['op'] as String,
      payload: raw == null ? null : LocalDatabase.decode(raw),
      updatedAt: (r['updatedAt'] as int?) ?? 0,
    );
  }
}
