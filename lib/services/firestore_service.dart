import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'sync_service.dart';
import '../models/user.dart';
import '../models/organization.dart';
import '../models/member.dart';
import '../models/attendance.dart';
import '../models/cash_transaction.dart';
import '../models/interview.dart';
import '../models/activity_log.dart';
import '../models/daily_material.dart';
import '../models/documentation.dart';
import '../models/achievement.dart';
import '../models/registration.dart';
import '../models/quest_feature.dart';
import '../models/quest_question.dart';
import '../models/quest_slot.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Bandingkan dua nilai `Timestamp` (untuk sort cache offline). Nilai null
  /// dianggap paling kecil. Kembalikan negatif/0/positif seperti Comparator.
  static int _tsCompare(dynamic a, dynamic b) {
    final ma = a is Timestamp ? a.millisecondsSinceEpoch : 0;
    final mb = b is Timestamp ? b.millisecondsSinceEpoch : 0;
    return ma.compareTo(mb);
  }

  static CollectionReference get usersRef => _db.collection('users');
  static CollectionReference get orgsRef => _db.collection('organizations');
  static CollectionReference get membersRef => _db.collection('members');
  static CollectionReference get attendanceRef => _db.collection('attendance');
  static CollectionReference get cashRef => _db.collection('cash_transactions');
  static CollectionReference get expensesRef => _db.collection('cash_expenses');
  static CollectionReference get sessionsRef => _db.collection('interview_sessions');
  static CollectionReference get resultsRef => _db.collection('interview_results');
  static CollectionReference get logsRef => _db.collection('activity_logs');

  // ====== USERS ======
  // PERINGATAN: JANGAN pakai ini untuk membuat akun user.
  // usersRef.add() menghasilkan dokumen ber-ID ACAK yang tidak terikat ke
  // Firebase Auth UID, sehingga menjadi "dokumen yatim" yang tak bisa login
  // dan mudah menimbulkan DUPLIKAT (email sama, ID beda) yang sulit dihapus.
  // Buat user lewat AuthService.createUserByAdmin() atau AuthService.register()
  // yang memakai .doc(uid).set() sehingga ID dokumen = Auth UID.
  @Deprecated('Gunakan AuthService.createUserByAdmin(); membuat doc ID acak yang menimbulkan duplikat.')
  static Future<String> createUser(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    final ref = await usersRef.add(data);
    return ref.id;
  }

  static Future<void> updateUser(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await SyncService.instance.updateDoc('users', id, data);
  }

  // CATATAN: deleteUser sengaja TIDAK dibuat offline. Ia memverifikasi ke SERVER
  // bahwa dokumen (dan duplikatnya) benar-benar terhapus; jaminan itu mustahil
  // saat offline. Memanggilnya offline akan melempar error 'unavailable' yang
  // eksplisit — perilaku yang diinginkan.
  static Future<void> deleteUser(String id, {String? email}) async {
    // 1) Hapus dokumen utama (by ID).
    await usersRef.doc(id).delete();

    // 2) Sapu dokumen DUPLIKAT dengan email yang sama.
    //    Sebelumnya user bisa memiliki >1 dokumen di koleksi `users`
    //    (mis. dokumen legacy ber-ID acak dari usersRef.add(), atau dibuat
    //    lewat jalur berbeda). Menghapus by-ID saja menyisakan kembaran yang
    //    tetap muncul di daftar & di Firestore Console. Kita query ke SERVER
    //    lalu hapus semua sisa yang emailnya sama (kecuali id yang sudah dihapus).
    final normalizedEmail = email?.trim();
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      try {
        final dupes = await usersRef
            .where('email', isEqualTo: normalizedEmail)
            .get(const GetOptions(source: Source.server));
        for (final d in dupes.docs) {
          if (d.id != id) {
            await d.reference.delete();
          }
        }
      } on FirebaseException catch (e) {
        // Offline: tak bisa menjamin sapu-bersih; lanjut ke verifikasi di bawah
        // yang akan melempar error bila memang belum tersimpan ke server.
        if (e.code != 'unavailable') rethrow;
      }
    }

    // 3) Verifikasi ke SERVER (bukan cache) bahwa dokumen benar-benar terhapus.
    // Firestore mobile memakai cache offline: .delete() menyelesaikan Future
    // segera setelah write lokal, sehingga penghapusan yang ditolak server
    // (mis. aturan keamanan) atau kondisi offline bisa tampak "berhasil".
    try {
      final check =
          await usersRef.doc(id).get(const GetOptions(source: Source.server));
      if (check.exists) {
        throw Exception(
          'Server menolak penghapusan. Periksa aturan keamanan (users) '
          'atau hak akses administrator Anda.',
        );
      }
      // Pastikan tidak ada sisa dokumen ber-email sama di server.
      if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
        final remaining = await usersRef
            .where('email', isEqualTo: normalizedEmail)
            .get(const GetOptions(source: Source.server));
        if (remaining.docs.isNotEmpty) {
          throw Exception(
            'Masih ada ${remaining.docs.length} dokumen user dengan email '
            '"$normalizedEmail" yang tidak terhapus. Periksa aturan keamanan '
            'atau hapus manual dari Firebase Console.',
          );
        }
      }
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        throw Exception(
          'Tidak dapat memverifikasi penghapusan: perangkat sedang offline. '
          'Penghapusan belum tentu tersimpan ke server.',
        );
      }
      rethrow;
    }
  }

  static Future<UserModel?> getUser(String id) async {
    final doc = await usersRef.doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
  }

  static Future<List<UserModel>> getUsers() async {
    final snap = await usersRef.get();
    return snap.docs
        .map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  // ====== VALIDATION ======
  static Future<bool> isSlugTaken(String slug, {String? excludeId}) async {
    final snap = await orgsRef.where('slug', isEqualTo: slug).get();
    if (excludeId != null) {
      return snap.docs.any((d) => d.id != excludeId);
    }
    return snap.docs.isNotEmpty;
  }

  static Future<bool> isEmailTaken(String email, {String? excludeId}) async {
    final snap = await usersRef.where('email', isEqualTo: email).get();
    if (excludeId != null) {
      return snap.docs.any((d) => d.id != excludeId);
    }
    return snap.docs.isNotEmpty;
  }

  // ====== ORGANIZATIONS ======
  static Future<List<Organization>> getOrganizations({bool forceRefresh = false}) async {
    final docs = await SyncService.instance.getDocs(
      collection: 'organizations',
      cacheKey: 'organizations:all',
      forceRefresh: forceRefresh,
      query: () => orgsRef.orderBy('nama'),
      cacheSort: (a, b) =>
          (a['nama'] as String? ?? '').compareTo(b['nama'] as String? ?? ''),
    );
    return docs.map((d) => Organization.fromMap(d.data, d.id)).toList();
  }

  static Future<List<Organization>> getOrganizationsByIds(
    List<String> ids, {
    bool forceRefresh = false,
  }) async {
    if (ids.isEmpty) return [];
    // Firestore membatasi whereIn ke 30 nilai. Kunci cache dibuat stabil dari
    // himpunan id (bukan urutan pemanggilan) supaya dua panggilan yang sama
    // berbagi cache yang sama.
    final sorted = [...ids]..sort();
    final cacheKey = 'organizations:byIds:${sorted.join(',')}';
    final docs = await SyncService.instance.getDocs(
      collection: 'organizations',
      cacheKey: cacheKey,
      forceRefresh: forceRefresh,
      query: () => orgsRef.where(FieldPath.documentId, whereIn: sorted),
      cacheFilter: (id, _) => sorted.contains(id),
      cacheSort: (a, b) =>
          (a['nama'] as String? ?? '').compareTo(b['nama'] as String? ?? ''),
    );
    return docs.map((d) => Organization.fromMap(d.data, d.id)).toList();
  }

  static Future<Organization?> getOrganization(String id, {bool forceRefresh = false}) async {
    final doc = await SyncService.instance.getDoc(
      'organizations',
      id,
      forceRefresh: forceRefresh,
    );
    if (doc == null) return null;
    return Organization.fromMap(doc.data, doc.id);
  }

  static Future<String> createOrganization(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    return SyncService.instance.addDoc('organizations', data);
  }

  static Future<void> updateOrganization(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await SyncService.instance.updateDoc('organizations', id, data);
  }

  static Future<void> deleteOrganization(String id) async {
    await SyncService.instance.deleteDoc('organizations', id);
  }

  static CollectionReference get schedulesRef => _db.collection('schedules');

  static Future<Map<String, int>> getAttendanceSummary(String orgId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    final snap = await attendanceRef.where('organizationId', isEqualTo: orgId).where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start)).where('date', isLessThan: Timestamp.fromDate(end)).get();
    final summary = <String, int>{'hadir': 0, 'tidak_hadir': 0, 'izin': 0, 'sakit': 0, 'alpha': 0, 'kas_saja': 0};
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      final s = (data?['status'] as String?) ?? 'hadir';
      summary[s] = (summary[s] ?? 0) + 1;
    }
    return summary;
  }

  // ====== MEMBERS ======
  static Future<List<Member>> getMembers(String orgId, {bool forceRefresh = false}) async {
    final docs = await SyncService.instance.getDocs(
      collection: 'members',
      cacheKey: 'members:$orgId',
      forceRefresh: forceRefresh,
      query: () => membersRef
          .where('organizationId', isEqualTo: orgId)
          .orderBy('name'),
      cacheFilter: (id, data) => data['organizationId'] == orgId,
      cacheSort: (a, b) =>
          (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''),
    );
    return docs.map((d) => Member.fromMap(d.data, d.id)).toList();
  }

  static Future<Member?> getMember(String id, {bool forceRefresh = false}) async {
    final doc = await SyncService.instance.getDoc(
      'members',
      id,
      forceRefresh: forceRefresh,
    );
    if (doc == null) return null;
    return Member.fromMap(doc.data, doc.id);
  }

  /// Ambil semua anggota lintas organisasi dalam satu query.
  /// Untuk dashboard Administrator agar tidak melakukan N query
  /// (satu getMembers per organisasi) yang memicu ratusan Firestore reads.
  static Future<List<Member>> getAllMembers({bool forceRefresh = false}) async {
    final docs = await SyncService.instance.getDocs(
      collection: 'members',
      cacheKey: 'members:all',
      forceRefresh: forceRefresh,
      query: () => membersRef.orderBy('name'),
      cacheSort: (a, b) =>
          (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''),
    );
    return docs.map((d) => Member.fromMap(d.data, d.id)).toList();
  }

  static Future<String> createMember(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    // Offline-aware: online → Firestore; offline → SQLite + outbox.
    return SyncService.instance.addDoc('members', data);
  }

  static Future<void> updateMember(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await SyncService.instance.updateDoc('members', id, data);
  }

  static Future<void> deleteMember(String id) async {
    await SyncService.instance.deleteDoc('members', id);
  }

  static Future<void> updateMemberExp(String id, int exp, int level) async {
    await SyncService.instance.updateDoc('members', id, {
      'exp': exp,
      'level': level,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<Member>> leaderboardStream(String orgId, {int limit = 20}) {
    return membersRef
        .where('organizationId', isEqualTo: orgId)
        .where('status', isEqualTo: 'ACTIVE')
        .orderBy('exp', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Member.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  static Future<List<Member>> getLeaderboard(String orgId, {int limit = 10}) async {
    final snap = await membersRef
        .where('organizationId', isEqualTo: orgId)
        .where('status', isEqualTo: 'ACTIVE')
        .orderBy('exp', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => Member.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  // ====== ATTENDANCE ======
  static Future<List<Attendance>> getAttendanceByDate(String orgId, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final ymd = '${start.year.toString().padLeft(4, '0')}'
        '${start.month.toString().padLeft(2, '0')}'
        '${start.day.toString().padLeft(2, '0')}';
    final docs = await SyncService.instance.getDocs(
      collection: 'attendance',
      cacheKey: 'attendance:$orgId:$ymd',
      query: () => attendanceRef
          .where('organizationId', isEqualTo: orgId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end)),
      cacheFilter: (id, data) {
        if (data['organizationId'] != orgId) return false;
        final d = data['date'];
        final ms = d is Timestamp ? d.millisecondsSinceEpoch : -1;
        return ms >= startMs && ms < endMs;
      },
    );
    return docs.map((d) => Attendance.fromMap(d.data, d.id)).toList();
  }

  /// Upsert absensi seorang anggota untuk sebuah tanggal.
  ///
  /// Online: coba temukan dokumen yang sudah ada (agar tidak menduplikasi doc
  /// lama ber-ID acak). Offline / gagal query: pakai docId deterministik
  /// `"${memberId}_yyyyMMdd"` sehingga upsert tetap idempotent tanpa query.
  static Future<void> upsertAttendance(Map<String, dynamic> data, DateTime date, String memberId) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final ymd = '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
    String docId = '${memberId}_$ymd';

    try {
      final existing = await attendanceRef
          .where('memberId', isEqualTo: memberId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .limit(1)
          .get(const GetOptions(source: Source.server));
      if (existing.docs.isNotEmpty) docId = existing.docs.first.id;
    } on FirebaseException catch (_) {
      // Offline: tak bisa query server → pakai docId deterministik di atas.
    }

    data['updatedAt'] = FieldValue.serverTimestamp();
    data['createdAt'] ??= FieldValue.serverTimestamp();
    await SyncService.instance.setDoc('attendance', docId, data, merge: true);
  }

  // ====== CASH ======
  static Stream<List<CashTransaction>> cashTransactionsStream(String orgId) {
    return cashRef
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => CashTransaction.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  static Future<List<CashTransaction>> getCashTransactions(String orgId, {bool forceRefresh = false}) async {
    final docs = await SyncService.instance.getDocs(
      collection: 'cash_transactions',
      cacheKey: 'cash_transactions:$orgId',
      forceRefresh: forceRefresh,
      query: () => cashRef
          .where('organizationId', isEqualTo: orgId)
          .orderBy('createdAt', descending: true),
      cacheFilter: (id, data) => data['organizationId'] == orgId,
      cacheSort: (a, b) => _tsCompare(b['createdAt'], a['createdAt']),
    );
    return docs.map((d) => CashTransaction.fromMap(d.data, d.id)).toList();
  }

  static Future<int> getCashBalance(String orgId) async {
    final tx = await cashRef.where('organizationId', isEqualTo: orgId).get();
    int total = 0;
    for (final d in tx.docs) {
      final m = d.data() as Map<String, dynamic>?;
      total += (m?['amount'] as int?) ?? 0;
    }
    final ex = await expensesRef.where('organizationId', isEqualTo: orgId).get();
    for (final d in ex.docs) {
      final m = d.data() as Map<String, dynamic>?;
      total -= (m?['nominal'] as int?) ?? 0;
    }
    return total;
  }

  static Future<void> createCashTransaction(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await SyncService.instance.addDoc('cash_transactions', data);
  }

  static Stream<List<CashExpense>> expensesStream(String orgId) {
    return expensesRef
        .where('organizationId', isEqualTo: orgId)
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => CashExpense.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  static Future<List<CashExpense>> getExpenses(String orgId, {bool forceRefresh = false}) async {
    final docs = await SyncService.instance.getDocs(
      collection: 'cash_expenses',
      cacheKey: 'cash_expenses:$orgId',
      forceRefresh: forceRefresh,
      query: () => expensesRef
          .where('organizationId', isEqualTo: orgId)
          .orderBy('tanggal', descending: true),
      cacheFilter: (id, data) => data['organizationId'] == orgId,
      cacheSort: (a, b) => _tsCompare(b['tanggal'], a['tanggal']),
    );
    return docs.map((d) => CashExpense.fromMap(d.data, d.id)).toList();
  }

  static Future<void> createExpense(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await SyncService.instance.addDoc('cash_expenses', data);
  }

  static Future<void> deleteExpense(String id) async {
    await SyncService.instance.deleteDoc('cash_expenses', id);
  }

  // ====== INTERVIEW ======
  static Stream<List<InterviewSession>> sessionsStream(String orgId) {
    return sessionsRef
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => InterviewSession.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  static Future<List<InterviewSession>> getSessions(String orgId) async {
    final snap = await sessionsRef
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => InterviewSession.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  static Future<String> createSession(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    final ref = await sessionsRef.add(data);
    return ref.id;
  }

  static Future<void> updateSession(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await sessionsRef.doc(id).update(data);
  }

  static CollectionReference queuesRef(String sesiId) =>
      sessionsRef.doc(sesiId).collection('queues');
  static CollectionReference chatsRef(String sesiId) =>
      sessionsRef.doc(sesiId).collection('chats');
  static CollectionReference qrRef(String sesiId) =>
      sessionsRef.doc(sesiId).collection('qr_tokens');

  static Stream<List<InterviewQueue>> queuesStream(String sesiId) {
    return queuesRef(sesiId).orderBy('nomorAntrian').snapshots().map((s) => s.docs
        .map((d) => InterviewQueue.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList());
  }

  static Future<List<InterviewQueue>> getQueues(String sesiId) async {
    final snap = await queuesRef(sesiId).orderBy('nomorAntrian').get();
    return snap.docs
        .map((d) => InterviewQueue.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  static Future<void> addQueue(String sesiId, Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await queuesRef(sesiId).add(data);
  }

  static Future<void> updateQueue(String sesiId, String queueId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await queuesRef(sesiId).doc(queueId).update(data);
  }

  static Future<void> deleteQueue(String sesiId, String queueId) async {
    await queuesRef(sesiId).doc(queueId).delete();
  }

  static Future<void> sendChat(String sesiId, Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await chatsRef(sesiId).add(data);
  }

  static Future<List<InterviewChat>> getChats(String sesiId) async {
    final snap = await chatsRef(sesiId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snap.docs
        .map((d) => InterviewChat.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  static Future<void> createResult(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await resultsRef.add(data);
  }

  // ====== STREAMS ======
  static Stream<List<Attendance>> attendanceStream(String orgId, DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return attendanceRef
        .where('organizationId', isEqualTo: orgId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((s) => s.docs
            .map((d) => Attendance.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  static Stream<List<Member>> membersStream(String orgId) {
    return membersRef
        .where('organizationId', isEqualTo: orgId)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs
            .map((d) => Member.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  // ====== DAILY MATERIALS ======
  static CollectionReference get materialsRef => _db.collection('daily_materials');

  static Future<List<DailyMaterial>> getMaterials(String orgId, {bool forceRefresh = false}) async {
    final docs = await SyncService.instance.getDocs(
      collection: 'daily_materials',
      cacheKey: 'daily_materials:$orgId',
      forceRefresh: forceRefresh,
      query: () => materialsRef
          .where('organizationId', isEqualTo: orgId)
          .orderBy('tanggal', descending: true),
      cacheFilter: (id, data) => data['organizationId'] == orgId,
      cacheSort: (a, b) => _tsCompare(b['tanggal'], a['tanggal']),
    );
    return docs.map((d) => DailyMaterial.fromMap(d.data, d.id)).toList();
  }

  static Future<void> createMaterial(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await SyncService.instance.addDoc('daily_materials', data);
  }

  static Future<void> updateMaterial(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await SyncService.instance.updateDoc('daily_materials', id, data);
  }

  static Future<void> deleteMaterial(String id) async {
    await SyncService.instance.deleteDoc('daily_materials', id);
  }

  // ====== DOCUMENTATION ======
  static CollectionReference get docsRef => _db.collection('documentation');

  /// Ambil dokumentasi.
  /// - [orgId] : batasi ke satu organisasi.
  /// - [orgIds]: batasi ke beberapa organisasi (dipakai non-admin sesuai izin).
  ///   Aturan Firestore hanya membolehkan non-admin membaca dokumen milik
  ///   organisasinya, jadi query WAJIB difilter agar tidak permission-denied.
  static Future<List<Documentation>> getDocumentations({
    String? orgId,
    List<String>? orgIds,
    bool forceRefresh = false,
  }) async {
    // whereIn dibatasi 30 nilai; ambil yang unik & tak kosong.
    final ids = (orgIds ?? (orgId != null ? [orgId] : []))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    // Non-admin tanpa organisasi: tidak ada yang boleh dibaca.
    if (orgIds != null && ids.isEmpty) return [];

    // Kunci cache stabil: himpunan id yang di-sort agar dua panggilan dengan
    // parameter berbeda-urutan tetap berbagi cache yang sama. `all` untuk
    // pemanggilan tanpa filter (Administrator).
    final sortedIds = [...ids]..sort();
    final cacheKey = 'documentation:${sortedIds.isEmpty ? 'all' : sortedIds.join(',')}';

    final docs = await SyncService.instance.getDocs(
      collection: 'documentation',
      cacheKey: cacheKey,
      forceRefresh: forceRefresh,
      query: () {
        Query q = docsRef.orderBy('dateTaken', descending: true);
        if (ids.length == 1) {
          q = q.where('organizationId', isEqualTo: ids.first);
        } else if (ids.isNotEmpty) {
          q = q.where('organizationId', whereIn: ids.take(30).toList());
        }
        return q;
      },
      cacheFilter: (id, data) =>
          ids.isEmpty || ids.contains(data['organizationId']),
      cacheSort: (a, b) => _tsCompare(b['dateTaken'], a['dateTaken']),
    );
    return docs.map((d) => Documentation.fromMap(d.data, d.id)).toList();
  }

  static Future<void> createDocumentation(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await SyncService.instance.addDoc('documentation', data);
  }

  static Future<void> deleteDocumentation(String id) async {
    await SyncService.instance.deleteDoc('documentation', id);
  }

  // ====== ACHIEVEMENTS ======
  static CollectionReference get achievementsRef => _db.collection('achievements');
  static CollectionReference memberAchievementsRef(String memberId) =>
      _db.collection('members').doc(memberId).collection('achievements');

  static Future<List<Achievement>> getAchievements(String orgId, {bool forceRefresh = false}) async {
    final docs = await SyncService.instance.getDocs(
      collection: 'achievements',
      cacheKey: 'achievements:$orgId',
      forceRefresh: forceRefresh,
      query: () => achievementsRef
          .where('organizationId', isEqualTo: orgId)
          .orderBy('nama'),
      cacheFilter: (id, data) => data['organizationId'] == orgId,
      cacheSort: (a, b) =>
          (a['nama'] as String? ?? '').compareTo(b['nama'] as String? ?? ''),
    );
    return docs.map((d) => Achievement.fromMap(d.data, d.id)).toList();
  }

  static Future<void> createAchievement(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await SyncService.instance.addDoc('achievements', data);
  }

  static Future<void> deleteAchievement(String id) async {
    await SyncService.instance.deleteDoc('achievements', id);
  }

  static Future<void> giveAchievementToMember(String memberId, Map<String, dynamic> data) async {
    await memberAchievementsRef(memberId).add(data);
  }

  static Future<List<MemberAchievement>> getMemberAchievements(String memberId) async {
    final snap = await memberAchievementsRef(memberId)
        .orderBy('tanggal', descending: true)
        .get();
    return snap.docs
        .map((d) => MemberAchievement.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  // ====== REGISTRATION ======
  static CollectionReference get registrationsRef => _db.collection('registrations');

  static Future<List<Registration>> getRegistrations({
    String? orgId,
    bool forceRefresh = false,
  }) async {
    final docs = await SyncService.instance.getDocs(
      collection: 'registrations',
      cacheKey: 'registrations:${orgId ?? 'all'}',
      forceRefresh: forceRefresh,
      query: () {
        Query q = registrationsRef.orderBy('createdAt', descending: true);
        if (orgId != null) q = q.where('organizationId', isEqualTo: orgId);
        return q;
      },
      cacheFilter: (id, data) =>
          orgId == null || data['organizationId'] == orgId,
      cacheSort: (a, b) => _tsCompare(b['createdAt'], a['createdAt']),
    );
    return docs.map((d) => Registration.fromMap(d.data, d.id)).toList();
  }

  static Future<void> createRegistration(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await SyncService.instance.addDoc('registrations', data);
  }

  static Future<void> updateRegistration(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await SyncService.instance.updateDoc('registrations', id, data);
  }

  static Future<void> deleteRegistration(String id) async {
    await SyncService.instance.deleteDoc('registrations', id);
  }

  // ====== LOGS ======
  static Future<void> createLog(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await SyncService.instance.addDoc('activity_logs', data);
  }

  static Future<List<ActivityLog>> getLogs({int limit = 50, DocumentSnapshot? startAfter}) async {
    Query query = logsRef.orderBy('createdAt', descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.get();
    return snap.docs
        .map((d) => ActivityLog.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  static Future<DocumentSnapshot?> getLastLogDoc({int limit = 50, DocumentSnapshot? startAfter}) async {
    Query query = logsRef.orderBy('createdAt', descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.last;
  }

  // ====== EMAIL REQUESTS ======
  static CollectionReference get emailRequestsRef => _db.collection('email_requests');

  static Future<void> createEmailRequest(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await emailRequestsRef.add(data);
  }

  // ====== EXP LOGS ======
  static CollectionReference get expLogsRef => _db.collection('exp_logs');

  static Future<void> createExpLog(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await expLogsRef.add(data);
  }

  // ====== ANNOUNCEMENTS ======
  static CollectionReference get announcementsRef => _db.collection('announcements');

  static Future<void> createAnnouncement(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await announcementsRef.add(data);
  }

  // ====== STUDENTS ======
  static CollectionReference get studentsRef => _db.collection('students');

  static Future<List<Map<String, dynamic>>> getStudents() async {
    final snap = await studentsRef.get();
    return snap.docs.map((d) {
      final m = d.data() as Map<String, dynamic>;
      m['id'] = d.id;
      return m;
    }).toList();
  }

  static Future<void> createStudent(Map<String, dynamic> data) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    await studentsRef.add(data);
  }

  // ====== APP FEATURES (Airlangga QR Quest) ======
  static CollectionReference get appFeaturesRef =>
      _db.collection('app_features');

  /// Stream konfigurasi aktivasi Airlangga QR Quest (dokumen tunggal).
  /// Emit [QuestFeatureConfig.empty] bila dokumen belum ada.
  static Stream<QuestFeatureConfig> questConfigStream() {
    return appFeaturesRef.doc(QuestFeatureConfig.docId).snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return QuestFeatureConfig.empty;
      return QuestFeatureConfig.fromMap(data);
    });
  }

  /// Ambil konfigurasi quest sekali (non-stream).
  static Future<QuestFeatureConfig> getQuestConfig() async {
    final doc = await appFeaturesRef.doc(QuestFeatureConfig.docId).get();
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return QuestFeatureConfig.empty;
    return QuestFeatureConfig.fromMap(data);
  }

  /// Simpan konfigurasi aktivasi. Memakai `set(merge:true)` sehingga field
  /// server timestamp untuk `activatedAt` hanya ditulis saat pertama aktif.
  static Future<void> saveQuestConfig(Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await appFeaturesRef
        .doc(QuestFeatureConfig.docId)
        .set(data, SetOptions(merge: true));
  }

  // ====== QUEST QUESTIONS (soal esai) ======
  static CollectionReference get questQuestionsRef =>
      _db.collection('quest_questions');

  /// Stream semua soal, terurut: soal utama dulu (isBackup=false) lalu urutan.
  static Stream<List<QuestQuestion>> questQuestionsStream() {
    return questQuestionsRef.orderBy('urutan').snapshots().map((snap) {
      final list = snap.docs
          .map((d) =>
              QuestQuestion.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      // Soal cadangan (SB) selalu di bawah soal utama (SL).
      list.sort((a, b) {
        if (a.isBackup != b.isBackup) return a.isBackup ? 1 : -1;
        return a.urutan.compareTo(b.urutan);
      });
      return list;
    });
  }

  /// Ambil semua soal sekali (untuk pengacakan slot & pemilihan soal).
  static Future<List<QuestQuestion>> getQuestQuestions() async {
    final snap = await questQuestionsRef.orderBy('urutan').get();
    final list = snap.docs
        .map((d) => QuestQuestion.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
    list.sort((a, b) {
      if (a.isBackup != b.isBackup) return a.isBackup ? 1 : -1;
      return a.urutan.compareTo(b.urutan);
    });
    return list;
  }

  /// Ambil satu soal (dipakai halaman web via export data, bukan langsung).
  static Future<QuestQuestion?> getQuestQuestion(String id) async {
    final doc = await questQuestionsRef.doc(id).get();
    if (!doc.exists) return null;
    return QuestQuestion.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Buat soal baru; mengembalikan id dokumen.
  static Future<String> createQuestQuestion(QuestQuestion q) async {
    final data = q.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    final ref = await questQuestionsRef.add(data);
    return ref.id;
  }

  /// Perbarui soal yang ada.
  static Future<void> updateQuestQuestion(String id, QuestQuestion q) async {
    final data = q.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data.remove('createdAt');
    await questQuestionsRef.doc(id).update(data);
  }

  static Future<void> deleteQuestQuestion(String id) async {
    await questQuestionsRef.doc(id).delete();
  }

  /// Impor banyak soal sekaligus dalam satu batch tulis.
  /// Mengembalikan jumlah soal yang berhasil ditulis.
  static Future<int> importQuestQuestions(List<QuestQuestion> questions) async {
    if (questions.isEmpty) return 0;
    // Firestore batch dibatasi 500 operasi; pecah bila perlu.
    const chunkSize = 400;
    var written = 0;
    for (var i = 0; i < questions.length; i += chunkSize) {
      final end = (i + chunkSize < questions.length)
          ? i + chunkSize
          : questions.length;
      final batch = _db.batch();
      for (final q in questions.sublist(i, end)) {
        final data = q.toMap();
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(questQuestionsRef.doc(), data);
      }
      await batch.commit();
      written += end - i;
    }
    return written;
  }

  // ====== QUEST SLOTS (token QR yang isinya bisa diacak) ======
  // Slot = token stabil di dalam QR. Kumpulan soal (questionIds) bisa diubah
  // tanpa mengganti QR fisik. Bila isi QR bocor, cukup acak ulang penugasan.
  static CollectionReference get questSlotsRef => _db.collection('quest_slots');

  static Stream<List<QuestSlot>> questSlotsStream() {
    return questSlotsRef.orderBy('urutan').snapshots().map((snap) => snap.docs
        .map((d) => QuestSlot.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList());
  }

  static Future<List<QuestSlot>> getQuestSlots() async {
    final snap = await questSlotsRef.orderBy('urutan').get();
    return snap.docs
        .map((d) => QuestSlot.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  /// Buat satu slot baru; id dokumen (token QR) dibuat otomatis oleh Firestore.
  static Future<String> createQuestSlot(String label, {int urutan = 0}) async {
    final ref = questSlotsRef.doc();
    await ref.set({
      'label': label,
      'questionIds': <String>[],
      'urutan': urutan,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Tetapkan kumpulan soal yang dimiliki sebuah slot (kosong = tanpa soal).
  static Future<void> setQuestSlotQuestions(
      String slotId, List<String> questionIds) async {
    await questSlotsRef.doc(slotId).update({
      'questionIds': questionIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteQuestSlot(String slotId) async {
    await questSlotsRef.doc(slotId).delete();
  }

  /// Acak ulang penugasan soal antar SEMUA slot tanpa menyentuh token QR.
  /// Dipakai saat isi sebuah QR bocor: kumpulan soal seluruh slot diaduk lalu
  /// dibagikan ulang, sehingga tiap QR berganti isi sekaligus dan informasi
  /// yang bocor jadi tak berguna.
  ///
  /// Seluruh soal yang saat ini tertugas di semua slot dikumpulkan, diacak,
  /// lalu dibagikan kembali dengan mempertahankan JUMLAH soal tiap slot. Soal
  /// tidak diduplikasi antar slot. Slot tanpa soal tetap kosong.
  ///
  /// Mengembalikan jumlah slot yang menerima setidaknya satu soal.
  static Future<int> shuffleQuestSlots() async {
    final slots = await getQuestSlots();
    if (slots.isEmpty) return 0;

    // Kumpulkan seluruh soal unik yang sedang tertugas, lalu acak.
    final pool = <String>{for (final s in slots) ...s.questionIds}.toList()
      ..shuffle(Random.secure());

    final batch = _db.batch();
    var assigned = 0;
    var cursor = 0;
    for (final slot in slots) {
      final take = slot.questionIds.length;
      final newIds = <String>[];
      for (var i = 0; i < take && cursor < pool.length; i++) {
        newIds.add(pool[cursor++]);
      }
      batch.update(questSlotsRef.doc(slot.id), {
        'questionIds': newIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (newIds.isNotEmpty) assigned++;
    }
    await batch.commit();
    return assigned;
  }

  /// Helper: log an action to activity_logs with minimal boilerplate.
  /// Call this after a successful Firestore write.
  static Future<void> logAction({
    required String userId,
    required String userNama,
    required String aksi,
    required String tabel,
    String? recordId,
    required String deskripsi,
  }) async {
    try {
      await createLog({
        'userId': userId,
        'userNama': userNama,
        'aksi': aksi,
        'tabel': tabel,
        'recordId': recordId,
        'deskripsi': deskripsi,
      });
    } catch (_) {
      // log silently – don't break the main flow
    }
  }
}



