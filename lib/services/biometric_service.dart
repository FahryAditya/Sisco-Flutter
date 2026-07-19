import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:io' show Platform;

enum BiometricState {
  notRegistered,
  registering,
  registered,
  verifying,
  success,
  failed,
  disabled,
}

class BiometricService {
  static final BiometricService instance = BiometricService._();
  BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _prefsEnabled = 'biometric_enabled';
  static const _prefsState = 'biometric_state';
  static const _prefsDeviceId = 'biometric_device_id';

  bool _available = false;
  bool get isAvailable => _available;

  bool _enrolled = false;
  bool get isEnrolled => _enrolled;

  String? _deviceId;

  String get _uid => _deviceId ??= const Uuid().v4();

  final ValueNotifier<BiometricState> stateNotifier =
      ValueNotifier(BiometricState.notRegistered);

  Future<void> init() async {
    try {
      _available =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (_available) {
        final biometrik = await _auth.getAvailableBiometrics();
        _enrolled = biometrik.isNotEmpty;
      }
    } catch (_) {
      _available = false;
      _enrolled = false;
    }

    _deviceId = await _loadDeviceId();
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getString(_prefsState);
    if (savedState == 'registered') {
      stateNotifier.value = BiometricState.registered;
    }
  }

  Future<String> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefsDeviceId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_prefsDeviceId, id);
    }
    return id;
  }

  String _deviceName() {
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      return 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  Future<bool> registerBiometric({required String uid}) async {
    stateNotifier.value = BiometricState.registering;
    final ok = await authenticate(reason: 'Daftarkan sidik jari');
    if (ok) {
      stateNotifier.value = BiometricState.registered;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsState, 'registered');
      await prefs.setBool(_prefsEnabled, true);
      await _syncToFirestore(uid, true);
      return true;
    }
    stateNotifier.value = BiometricState.failed;
    return false;
  }

  Future<bool> verifyAndLogin() async {
    stateNotifier.value = BiometricState.verifying;
    final ok = await authenticate(reason: 'Masuk ke SISCO');
    if (ok) {
      stateNotifier.value = BiometricState.success;
      return true;
    }
    stateNotifier.value = BiometricState.failed;
    return false;
  }

  Future<bool> authenticate({String reason = 'Verifikasi identitas'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      debugPrint('BiometricService: Error autentikasi — $e');
      return false;
    }
  }

  Future<void> disable({String? uid}) async {
    stateNotifier.value = BiometricState.disabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsState);
    await prefs.setBool(_prefsEnabled, false);
    if (uid != null) await _syncToFirestore(uid, false);
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsEnabled) ?? false;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsEnabled);
    await prefs.remove(_prefsState);
    await prefs.remove(_prefsDeviceId);
    stateNotifier.value = BiometricState.notRegistered;
  }

  Future<void> _syncToFirestore(String uid, bool enabled) async {
    try {
      await _db.collection('users').doc(uid).collection('devices').doc(_uid).set({
        'biometricEnabled': enabled,
        'registeredAt': FieldValue.serverTimestamp(),
        'deviceName': _deviceName(),
        'status': enabled ? 'active' : 'inactive',
      });
    } catch (e) {
      debugPrint('BiometricService: Gagal sinkron ke Firestore — $e');
    }
  }
}
