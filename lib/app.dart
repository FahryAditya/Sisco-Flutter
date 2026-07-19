import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/biometric_gate.dart';
import 'screens/login/login_page.dart';
import 'screens/home/home_page.dart';
import 'screens/chat/chat_room_page.dart';
import 'services/biometric_service.dart';
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
    final theme = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'SISCO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(accentColor: theme.accentColor),
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
  bool _biometricChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkSession();
    });
  }

  Future<void> _checkBiometricGate() async {
    final enabled = await BiometricService.instance.isEnabled();
    if (!mounted || !enabled) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BiometricGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.loading) return const SplashScreen();
        if (!auth.isLoggedIn) return const LoginPage();

        if (!_biometricChecked) {
          _biometricChecked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkBiometricGate();
          });
        }

        return const HomePage();
      },
    );
  }
}
