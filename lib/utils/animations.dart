import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Preset animasi *entrance* yang konsisten di seluruh aplikasi, dibangun di
/// atas paket `flutter_animate`. Tujuannya agar setiap halaman memakai durasi
/// & kurva yang sama sehingga terasa satu kesatuan.
///
/// Contoh:
/// ```dart
/// // Item ke-i dalam sebuah daftar/grid (muncul berurutan):
/// myWidget.animateEntrance(index: i)
///
/// // Elemen tunggal (mis. judul):
/// myTitle.animateEntrance()
/// ```
extension EntranceAnimation on Widget {
  /// Fade + slide lembut ke atas. [index] membuat efek *staggered* (tiap item
  /// tampil sedikit lebih lambat dari sebelumnya).
  Widget animateEntrance({
    int index = 0,
    Duration duration = const Duration(milliseconds: 380),
    double slide = 0.12,
    Duration stagger = const Duration(milliseconds: 55),
    Duration baseDelay = Duration.zero,
  }) {
    final delay = baseDelay + stagger * index;
    return animate()
        .fadeIn(duration: duration, delay: delay, curve: Curves.easeOut)
        .slideY(
          begin: slide,
          end: 0,
          duration: duration,
          delay: delay,
          curve: Curves.easeOutCubic,
        );
  }

  /// Muncul dengan efek skala kecil → penuh (cocok untuk kartu/badge/bubble).
  Widget animatePop({
    int index = 0,
    Duration duration = const Duration(milliseconds: 340),
    Duration stagger = const Duration(milliseconds: 45),
  }) {
    final delay = stagger * index;
    return animate()
        .fadeIn(duration: duration, delay: delay)
        .scaleXY(begin: 0.92, end: 1, duration: duration, delay: delay, curve: Curves.easeOutBack);
  }
}
