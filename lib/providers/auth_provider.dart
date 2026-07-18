import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/directory_service.dart';
import '../services/presence_service.dart';
import '../services/chat_notifier.dart';
class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _loading = true;
  String? _error;

  UserModel? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdministrator ?? false;
  bool get isOrgAdmin => _user?.isOrganizationAdmin ?? false;
  bool get isAdminOrg => _user?.isAdminOrg ?? false;
  bool get isAdminEskul => _user?.isAdminEskul ?? false;
  bool get isPembina => _user?.isPembina ?? false;
  bool get isPembinaOrg => _user?.isPembinaOrg ?? false;
  bool get isPembinaEskul => _user?.isPembinaEskul ?? false;

  // Feature permissions (roleakses.md)
  bool get canManageQr => _user?.canManageQr ?? false;
  bool get canWawancara => _user?.canWawancara ?? false;
  bool get canPengumumanAnggota => _user?.canPengumumanAnggota ?? false;
  bool get canPengumumanSistem => _user?.canPengumumanSistem ?? false;
  bool get canMateriJadwal => _user?.canMateriJadwal ?? false;
  bool get canManageUser => _user?.canManageUser ?? false;
  bool get canAuditLog => _user?.canAuditLog ?? false;
  bool get canExportImport => _user?.canExportImport ?? false;

  /// Perbarui entri buku alamat staff (nama+role) di collection `directory`
  /// agar pengguna ini muncul di daftar kontak chat orang lain. Fire-and-forget;
  /// kegagalan tidak boleh mengganggu alur login.
  void _syncDirectory() {
    final u = _user;
    if (u == null || !u.isStaff) return;
    DirectoryService.upsertSelf(u).catchError((_) {});
    // Mulai lacak presence (online + heartbeat) untuk staff yang login.
    PresenceService.instance.start(u.id);
    // Pantau pesan chat baru → tampilkan notifikasi lokal (WhatsApp-like).
    ChatNotifier.instance.start(u.id);
  }

  /// Called once on app start — fast because it checks auth state first
  Future<void> checkSession() async {
    // If Firebase already has a session, try cached first
    if (AuthService.firebaseUser != null) {
      _user = AuthService.getCachedUser();
      if (_user != null) {
        _loading = false;
        notifyListeners();
        _syncDirectory();
        return;
      }
    }

    // Fetch from Firestore if no cache
    _user = await AuthService.getCurrentUser();
    _loading = false;
    notifyListeners();
    _syncDirectory();
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await AuthService.login(email, password);
      _loading = false;
      if (_user != null && (_user!.role == 'siswa' || _user!.role == 'peserta')) {
        await AuthService.logout();
        _user = null;
        _error = 'Akun siswa tidak memiliki akses login';
        notifyListeners();
        return false;
      }
      notifyListeners();
      _syncDirectory();
      return _user != null;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String nama, String email, String password, String role) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await AuthService.register(nama, email, password, role);
      _user = await AuthService.getCurrentUser();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    PresenceService.instance.stop();
    await ChatNotifier.instance.stop();
    await AuthService.logout();
    _user = null;
    notifyListeners();
  }
}
