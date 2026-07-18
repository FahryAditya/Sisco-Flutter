import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/login/login_page.dart';
import 'screens/home/home_page.dart';
import 'screens/chat/chat_room_page.dart';
import 'services/notification_service.dart';

class SISCOApp extends StatefulWidget {
  const SISCOApp({super.key});

  @override
  State<SISCOApp> createState() => _SISCOAppState();
}

class _SISCOAppState extends State<SISCOApp> {
  @override
  void initState() {
    super.initState();
    // Handler saat user menekan notifikasi chat: buka ruang percakapan.
    // Memakai NavigatorState global (di-set via navigatorKey di MaterialApp)
    // supaya bisa push dari luar konteks widget.
    NotificationService.instance.onChatTap = (payload) {
      final nav = NotificationService.navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            recipientId: payload.recipientId,
            recipientName: payload.recipientName,
            recipientRole: payload.recipientRole,
          ),
        ),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SISCO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: NotificationService.navigatorKey,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.loading) return const SplashScreen();
        if (auth.isLoggedIn) return const HomePage();
        return const LoginPage();
      },
    );
  }
}
