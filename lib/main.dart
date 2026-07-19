import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/organization_provider.dart';
import 'providers/cash_provider.dart';
import 'providers/interview_provider.dart';
import 'providers/quest_provider.dart';
import 'providers/theme_provider.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';
import 'services/biometric_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Muat .env — jangan sampai kegagalan memblokir startup (white screen).
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv gagal dimuat: $e');
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Persistence + cache tak terbatas. Repeat reads (buka halaman yang sama,
  // list yang sudah pernah dimuat) diservis dari disk cache — hemat quota
  // Firestore dan bikin UI terasa instan setelah data pertama masuk.
  //
  // Web memakai IndexedDB persistence yang harus di-enable via cara terpisah;
  // untuk mobile/desktop cukup Settings ini. Try/catch supaya kegagalan
  // (mis. dipanggil setelah Firestore terlanjur dipakai) tidak menghentikan app.
  try {
    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  } catch (e) {
    debugPrint('Firestore settings gagal diterapkan: $e');
  }

  // Inisialisasi App Check — gunakan DebugProvider saat development.
  // Dibungkus try/catch agar kegagalan (mis. site key belum diset di web)
  // tidak menghentikan runApp.
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
      webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    );
  } catch (e) {
    debugPrint('App Check gagal diaktifkan: $e');
  }

  // Layer offline SQLite + auto-sync ke Firestore. Di web, SQLite dinonaktifkan
  // (lihat LocalDatabase) sehingga init aman. Tetap dibungkus untuk berjaga.
  try {
    await SyncService.instance.init();
  } catch (e) {
    debugPrint('SyncService gagal diinisialisasi: $e');
  }

  // Notifikasi lokal untuk pesan chat baru. Init duluan supaya kanal Android
  // sudah dibuat sebelum ChatNotifier.start() dipanggil AuthProvider.
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('NotificationService gagal diinisialisasi: $e');
  }

  // Inisialisasi biometrik untuk login cepat.
  try {
    await BiometricService.instance.init();
  } catch (e) {
    debugPrint('BiometricService gagal diinisialisasi: $e');
  }

  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('initializeDateFormatting gagal: $e');
  }

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OrganizationProvider()),
        ChangeNotifierProvider(create: (_) => CashProvider()),
        ChangeNotifierProvider(create: (_) => InterviewProvider()),
        ChangeNotifierProvider(create: (_) => QuestProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: const SISCOApp(),
    ),
  );
}
