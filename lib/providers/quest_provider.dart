import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/quest_feature.dart';
import '../models/user.dart';
import '../services/firestore_service.dart';

/// Menyediakan konfigurasi aktivasi "Airlangga QR Quest" secara real-time.
///
/// Mendengarkan dokumen `app_features/airlangga_qr_quest` dan memberi tahu UI
/// saat administrator/admin org mengubah status aktif atau daftar pemegang akses.
class QuestProvider extends ChangeNotifier {
  QuestFeatureConfig _config = QuestFeatureConfig.empty;
  bool _loaded = false;

  QuestFeatureConfig get config => _config;
  bool get loaded => _loaded;
  bool get enabled => _config.enabled;

  StreamSubscription<QuestFeatureConfig>? _sub;

  QuestProvider() {
    _listen();
  }

  void _listen() {
    _sub = FirestoreService.questConfigStream().listen(
      (config) {
        _config = config;
        _loaded = true;
        notifyListeners();
      },
      onError: (_) {
        // Jangan biarkan error stream mengganggu app; anggap fitur nonaktif.
        _loaded = true;
        notifyListeners();
      },
    );
  }

  /// Apakah [user] boleh melihat menu Airlangga QR Quest.
  /// Administrator selalu melihat menu; user lain harus jadi pemegang akses.
  bool canSeeQuestMenu(UserModel? user) {
    if (user == null) return false;
    if (user.isAdministrator) return true;
    return _config.hasAccess(user.id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
