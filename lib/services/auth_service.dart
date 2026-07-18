import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../models/user.dart';

class AuthService {
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  // In-memory cache
  static UserModel? _cachedUser;

  static String? get currentUserId => _auth.currentUser?.uid;
  static bool get isLoggedIn => _auth.currentUser != null;
  static auth.User? get firebaseUser => _auth.currentUser;
  static Stream<auth.User?> get onAuthStateChanged => _auth.authStateChanges();

  static Future<UserModel?> login(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _fetchAndCache(result.user!.uid);
  }

  static Future<void> register(
    String nama,
    String email,
    String password,
    String role,
  ) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await FirebaseFirestore.instance
        .collection('users')
        .doc(result.user!.uid)
        .set({
          'nama': nama.trim(),
          'email': email.trim(),
          'role': role,
          'orgIds': [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  static Future<String> createUserByAdmin({
    required String nama,
    required String email,
    required String password,
    required String role,
    List<String> orgIds = const [],
  }) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'admin-user-creation',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        secondaryApp = Firebase.app('admin-user-creation');
      } else {
        rethrow;
      }
    }

    final secondaryAuth = auth.FirebaseAuth.instanceFor(app: secondaryApp);
    final result = await secondaryAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await secondaryAuth.signOut();

    final uid = result.user!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'nama': nama.trim(),
      'email': email.trim(),
      'role': role,
      'orgIds': orgIds,
      // Password awal disimpan agar administrator bisa melihatnya kembali.
      // CATATAN KEAMANAN: ini disimpan sebagai teks biasa dan hanya terlindungi
      // oleh Firestore rules (dokumen users hanya dapat dibaca admin/pemilik).
      // Nilai ini bisa menjadi usang bila user mengganti passwordnya sendiri.
      'password': password,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return uid;
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  static Future<void> logout() async {
    _cachedUser = null;
    await _auth.signOut();
  }

  /// Fast check: return cached or fetch from Firestore
  static Future<UserModel?> getCurrentUser() async {
    if (_cachedUser != null) return _cachedUser;
    final user = _auth.currentUser;
    if (user == null) return null;
    return _fetchAndCache(user.uid);
  }

  /// Quick sync check without Firestore — for instant redirect
  static UserModel? getCachedUser() => _cachedUser;

  static void setCachedUser(UserModel user) {
    _cachedUser = user;
  }

  static Future<UserModel?> _fetchAndCache(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    _cachedUser = UserModel.fromMap(doc.data()!, doc.id);
    return _cachedUser;
  }
}
