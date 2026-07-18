import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Deteksi ketersediaan jaringan sebagai pemicu auto-sync.
///
/// Catatan: `connectivity_plus` hanya melaporkan status *interface* (ada
/// Wi-Fi/seluler), bukan konektivitas internet nyata ke Firestore. Karena itu
/// [SyncService] tetap menganggap kegagalan tulis `unavailable` sebagai
/// "offline" dan menyimpan operasi ke antrian untuk dicoba lagi.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  static bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// True bila minimal satu interface jaringan aktif.
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _hasConnection(results);
  }

  /// Stream boolean online/offline (terdistinct agar tidak spam listener).
  Stream<bool> get onlineStream {
    bool? last;
    return _connectivity.onConnectivityChanged
        .map(_hasConnection)
        .where((online) {
      if (online == last) return false;
      last = online;
      return true;
    });
  }
}
