import 'dart:async';
import 'package:flutter/widgets.dart';
import 'directory_service.dart';

/// Melacak kehadiran (presence) pengguna saat ini dan menuliskannya ke
/// `directory/{uid}` lewat [DirectoryService.setPresence].
///
/// - Menandai `online: true` + heartbeat berkala selama app di foreground.
/// - Menandai `online: false` saat app ke background / ditutup.
///
/// Heartbeat perlu karena app bisa mati tanpa sempat menulis offline; kontak
/// lain menganggap "online" hanya bila heartbeat masih segar (lihat
/// [StaffContact.isOnlineNow]).
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  String? _uid;
  Timer? _heartbeat;
  bool _started = false;

  static const _interval = Duration(seconds: 45);

  /// Mulai melacak presence untuk [uid]. Aman dipanggil berulang (mis. setiap
  /// login) — akan mengganti uid dan mereset heartbeat.
  void start(String uid) {
    if (_started && _uid == uid) return;
    stop(markOffline: false);
    _uid = uid;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _goOnline();
    _heartbeat = Timer.periodic(_interval, (_) => _goOnline());
  }

  /// Hentikan pelacakan (mis. saat logout). Menandai offline bila diminta.
  void stop({bool markOffline = true}) {
    _heartbeat?.cancel();
    _heartbeat = null;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _started = false;
    }
    final uid = _uid;
    if (markOffline && uid != null) {
      DirectoryService.setPresence(uid: uid, online: false);
    }
    _uid = null;
  }

  void _goOnline() {
    final uid = _uid;
    if (uid != null) DirectoryService.setPresence(uid: uid, online: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = _uid;
    if (uid == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _goOnline();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        DirectoryService.setPresence(uid: uid, online: false);
        break;
    }
  }
}
