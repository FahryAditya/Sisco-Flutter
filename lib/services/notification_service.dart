import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Layanan notifikasi lokal (in-app). Menampilkan gelembung notifikasi saat
/// pesan chat baru masuk selagi aplikasi berjalan (foreground / background
/// running). Untuk notifikasi saat app benar-benar mati, perlu FCM + Cloud
/// Functions yang meng-emit push berdasarkan write ke `messages`.
///
/// Semua kegagalan (permission ditolak, plugin belum init, dsb.) dibungkus
/// try/catch agar tidak pernah menghentikan alur chat.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Callback yang dipanggil saat user menekan sebuah notifikasi chat.
  void Function(ChatNotifPayload payload)? onChatTap;

  /// Navigator global — di-set dari `MaterialApp.navigatorKey` supaya tap
  /// notifikasi bisa push route dari mana saja (di luar BuildContext widget).
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  bool _inited = false;

  /// Kanal notifikasi khusus chat. Nama & ID di sini di-cache Android saat
  /// pertama kali app menampilkan notifikasi; ubah [_chatChannelId] hanya
  /// bila mengganti perilaku (suara/prioritas) supaya kanal lama tidak sisa.
  static const _chatChannelId = 'chat_messages';
  static const _chatChannelName = 'Pesan Chat';
  static const _chatChannelDesc = 'Notifikasi pesan chat baru dari staff lain.';

  Future<void> init() async {
    if (_inited) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onTap,
      );

      // Buat kanal Android secara eksplisit — kalau tidak, prioritas default
      // "low" bikin notifikasi tidak muncul sebagai heads-up di Android 8+.
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _chatChannelId,
          _chatChannelName,
          description: _chatChannelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Android 13+ butuh runtime permission POST_NOTIFICATIONS.
      await android?.requestNotificationsPermission();

      _inited = true;
    } catch (e) {
      debugPrint('NotificationService init gagal: $e');
    }
  }

  /// Tampilkan notifikasi pesan chat baru. [conversationId] dipakai sebagai
  /// notification id (hash) — pesan berikutnya dari percakapan yang sama akan
  /// MEMPERBARUI gelembung, bukan menumpuk (perilaku ala WhatsApp).
  Future<void> showChatMessage({
    required String conversationId,
    required String recipientId,
    required String senderName,
    required String senderRole,
    required String text,
  }) async {
    if (!_inited) await init();
    try {
      final payload = ChatNotifPayload(
        conversationId: conversationId,
        recipientId: recipientId,
        recipientName: senderName,
        recipientRole: senderRole,
      );
      final notifId = conversationId.hashCode & 0x7fffffff;
      await _plugin.show(
        notifId,
        senderName,
        text,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _chatChannelId,
            _chatChannelName,
            channelDescription: _chatChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
            styleInformation: BigTextStyleInformation(text),
            ticker: 'Pesan baru dari $senderName',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(payload.toMap()),
      );
    } catch (e) {
      debugPrint('showChatMessage gagal: $e');
    }
  }

  /// Bersihkan notifikasi milik satu percakapan (dipanggil saat user membuka
  /// ruang chat-nya, supaya badge tidak menyisa).
  Future<void> clearForConversation(String conversationId) async {
    try {
      final notifId = conversationId.hashCode & 0x7fffffff;
      await _plugin.cancel(notifId);
    } catch (_) {/* non-kritis */}
  }

  /// Hapus semua notifikasi (mis. saat logout).
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {/* non-kritis */}
  }

  void _onTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      onChatTap?.call(ChatNotifPayload.fromMap(map));
    } catch (e) {
      debugPrint('onTap notification payload rusak: $e');
    }
  }
}

/// Payload notifikasi chat — cukup untuk membuka `ChatRoomPage` langsung.
class ChatNotifPayload {
  final String conversationId;
  final String recipientId;
  final String recipientName;
  final String recipientRole;

  ChatNotifPayload({
    required this.conversationId,
    required this.recipientId,
    required this.recipientName,
    required this.recipientRole,
  });

  Map<String, dynamic> toMap() => {
        'cid': conversationId,
        'rid': recipientId,
        'rname': recipientName,
        'rrole': recipientRole,
      };

  factory ChatNotifPayload.fromMap(Map<String, dynamic> m) => ChatNotifPayload(
        conversationId: m['cid'] as String? ?? '',
        recipientId: m['rid'] as String? ?? '',
        recipientName: m['rname'] as String? ?? '',
        recipientRole: m['rrole'] as String? ?? '',
      );
}
