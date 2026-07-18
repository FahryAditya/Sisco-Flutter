import 'package:flutter/material.dart';

/// Route transisi halaman yang halus (fade + slide lembut ke atas).
///
/// Pengganti [MaterialPageRoute] agar perpindahan antar halaman terasa mulus
/// dan konsisten di seluruh aplikasi. Cara pakai:
///
/// ```dart
/// Navigator.push(context, SmoothPageRoute(builder: (_) => const ProfilePage()));
/// ```
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  SmoothPageRoute({
    required WidgetBuilder builder,
    super.settings,
    this.duration = const Duration(milliseconds: 320),
    this.reverseDuration = const Duration(milliseconds: 260),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Kurva easing yang lembut untuk masuk & keluar.
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            // Slide lembut dari bawah (8% tinggi layar) sekaligus fade in.
            final offset = Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved);

            return FadeTransition(
              opacity: curved,
              child: SlideTransition(position: offset, child: child),
            );
          },
        );

  final Duration duration;
  final Duration reverseDuration;
}
