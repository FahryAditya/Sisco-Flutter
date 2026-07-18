import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/organization.dart';
import '../models/member.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class OrganizationProvider extends ChangeNotifier {
  List<Organization> _orgs = [];
  Organization? _selectedOrg;
  List<Member> _members = [];
  bool _loading = false;

  // Cache flag: sekali orgs berhasil dimuat, buka-tutup halaman tidak akan
  // memicu fetch ulang ke Firestore. Panggil refresh() untuk paksa reload
  // (mis. pull-to-refresh atau setelah CRUD dari layar lain).
  bool _orgsLoaded = false;
  String? _membersOrgId; // orgId yang saat ini di-cache di _members

  List<Organization> get orgs => _orgs;
  Organization? get selectedOrg => _selectedOrg;
  List<Member> get members => _members;
  bool get loading => _loading;
  bool get orgsLoaded => _orgsLoaded;

  /// Memberi tahu listener dengan aman. Bila dipanggil saat frame sedang di-build
  /// (mis. `loadOrgs()` dipanggil sinkron dari `initState`), notifikasi ditunda
  /// hingga frame selesai untuk menghindari error
  /// "setState() or markNeedsBuild() called during build".
  void _safeNotify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  /// Muat daftar organisasi yang boleh diakses pengguna saat ini.
  ///
  /// Hanya Administrator yang melihat SEMUA organisasi. Role lain (admin_eskul,
  /// admin_organisasi, pembina_eskul, pembina_organisasi) hanya melihat
  /// organisasi/eskul yang secara eksplisit di-sign kepadanya oleh Administrator
  /// (field `orgIds` pada dokumen user). Ini mencegah mereka melihat data org
  /// lain (mis. admin_eskul Programming tidak boleh melihat MPK/OSIS).
  Future<void> loadOrgs({bool force = false}) async {
    if (_loading) return;
    if (_orgsLoaded && !force) return; // sudah ada di memory, skip fetch
    _loading = true;
    _safeNotify();
    try {
      final user = AuthService.getCachedUser() ?? await AuthService.getCurrentUser();
      if (user == null) {
        _orgs = [];
      } else if (user.isAdministrator) {
        _orgs = await FirestoreService.getOrganizations(forceRefresh: force);
      } else {
        _orgs = await FirestoreService.getOrganizationsByIds(
          user.orgIds,
          forceRefresh: force,
        );
      }
      _orgsLoaded = true;
    } catch (_) {
      _orgs = [];
    }
    _loading = false;
    _safeNotify();
  }

  /// Paksa reload dari Firestore. Panggil dari pull-to-refresh atau setelah
  /// CRUD org (create/update/delete organization) di layar lain.
  Future<void> refresh() => loadOrgs(force: true);

  Future<void> selectOrg(String orgId, {bool force = false}) async {
    // Kalau org yang sama dan members sudah di-cache, lewati fetch.
    if (!force && _selectedOrg?.id == orgId && _membersOrgId == orgId) {
      return;
    }
    _selectedOrg = await FirestoreService.getOrganization(orgId, forceRefresh: force);
    _members = await FirestoreService.getMembers(orgId, forceRefresh: force);
    _membersOrgId = orgId;
    _safeNotify();
  }

  void setSelectedOrg(Organization org) {
    _selectedOrg = org;
    _safeNotify();
  }

  /// Tambah anggota ke list lokal setelah write ke Firestore berhasil.
  /// Menghindari full-reload getMembers() setelah CRUD.
  void addMemberLocal(Member m) {
    _members = [..._members, m];
    _safeNotify();
  }

  void updateMemberLocal(Member m) {
    _members = [
      for (final e in _members) if (e.id == m.id) m else e,
    ];
    _safeNotify();
  }

  void removeMemberLocal(String memberId) {
    _members = _members.where((e) => e.id != memberId).toList();
    _safeNotify();
  }

  /// Tambah/update/hapus organisasi di list lokal setelah write ke Firestore
  /// berhasil. Menghindari refetch seluruh list.
  void addOrgLocal(Organization o) {
    _orgs = [..._orgs, o];
    _safeNotify();
  }

  void updateOrgLocal(Organization o) {
    _orgs = [
      for (final e in _orgs) if (e.id == o.id) o else e,
    ];
    if (_selectedOrg?.id == o.id) _selectedOrg = o;
    _safeNotify();
  }

  void removeOrgLocal(String orgId) {
    _orgs = _orgs.where((e) => e.id != orgId).toList();
    if (_selectedOrg?.id == orgId) {
      _selectedOrg = null;
      _members = [];
      _membersOrgId = null;
    }
    _safeNotify();
  }

  /// Bersihkan cache saat logout supaya user berikutnya tidak melihat data lama.
  void clear() {
    _orgs = [];
    _selectedOrg = null;
    _members = [];
    _orgsLoaded = false;
    _membersOrgId = null;
    _safeNotify();
  }
}