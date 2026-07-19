import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Jenis proses yang sedang berjalan, menentukan gambar karakter & teks default
/// pada dialog loading.
enum LoadingKind {
  /// Sedang memuat / mencari data (mis. refresh, ganti filter, muat ulang).
  cariData,

  /// Sedang menyinkronkan data ke server (mis. flush antrian, import, export).
  sinkronasi,
}

/// Kumpulan dialog karakter yang seragam untuk seluruh aplikasi.
///
/// Semua feedback aksi (loading, berhasil, gagal) dipusatkan di sini agar
/// tampilannya konsisten dan mudah dipelihara:
///   • [showLoading] — dialog tak bisa ditutup, menampilkan karakter
///     `mencaridata` / `sinkronasi` selama proses berjalan.
///   • [hide] — menutup dialog loading yang sedang tampil.
///   • [showSuccess] — karakter `berhasil`, menutup otomatis (~2 detik).
///   • [showError] — karakter `eror`, ditutup manual lewat tombol OK.
///   • [runWithLoading] — pembungkus praktis: jalankan tugas async sambil
///     menampilkan loading, lalu munculkan success/error otomatis.
class AppDialogs {
  AppDialogs._();

  static const String _imgCariData = 'assets/images/mencaridata.jpeg';
  static const String _imgSinkronasi = 'assets/images/sinkronasi.jpeg';
  static const String _imgBerhasil = 'assets/images/berhasil.jpeg';
  static const String _imgEror = 'assets/images/eror.jpeg';
  static const String _imgMenentukan = 'assets/images/menentukan.jpeg';

  /// Menandai bahwa sebuah dialog loading sedang tampil, agar [hide] tidak
  /// keliru menutup route lain saat dipanggil ganda.
  static bool _loadingVisible = false;

  /// Tampilkan dialog loading yang tidak bisa ditutup pengguna.
  ///
  /// Pasangkan selalu dengan [hide] di blok `finally`. Untuk alur umum lebih
  /// baik pakai [runWithLoading] yang sudah mengurus buka/tutup otomatis.
  static void showLoading(
    BuildContext context, {
    LoadingKind kind = LoadingKind.cariData,
    String? message,
  }) {
    if (_loadingVisible) return;
    _loadingVisible = true;

    final bool isSync = kind == LoadingKind.sinkronasi;
    final String image = isSync ? _imgSinkronasi : _imgCariData;
    final String text = message ??
        (isSync ? 'Menyinkronkan data...' : 'Mencari data...');
    final Color tint = isSync ? AppColors.info : AppColors.primary;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: _CharacterCard(
          image: image,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    backgroundColor: tint.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(tint),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tutup dialog loading yang sedang tampil (bila ada).
  static void hide(BuildContext context) {
    if (!_loadingVisible) return;
    _loadingVisible = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Tampilkan dialog berhasil dengan karakter `berhasil`. Menutup otomatis
  /// setelah [autoCloseDuration] (default 2 detik).
  static Future<void> showSuccess(
    BuildContext context,
    String message, {
    Duration autoCloseDuration = const Duration(seconds: 2),
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogContext) {
        // Jadwalkan penutupan otomatis.
        Future.delayed(autoCloseDuration, () {
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        });
        return _CharacterCard(
          image: _imgBerhasil,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        );
      },
    );
  }

  /// Tampilkan dialog gagal dengan karakter `eror`. Ditutup manual lewat
  /// tombol OK agar pengguna sempat membaca pesannya.
  static Future<void> showError(
    BuildContext context,
    String message,
  ) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => _CharacterCard(
        image: _imgEror,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'OK',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tampilkan dialog konfirmasi (mis. sebelum aksi berat/berisiko).
  ///
  /// Mengembalikan `true` bila pengguna menekan tombol konfirmasi, selain itu
  /// `false`. Memakai karakter `menentukan` agar seragam dengan dialog lain.
  /// [danger] mengubah warna tombol konfirmasi menjadi merah untuk aksi merusak.
  static Future<bool> showConfirm(
    BuildContext context, {
    required String message,
    String confirmLabel = 'Lanjut',
    String cancelLabel = 'Batal',
    bool danger = false,
  }) async {
    if (!context.mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => _CharacterCard(
        image: _imgMenentukan,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      cancelLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          danger ? AppColors.danger : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  /// Jalankan [task] sambil menampilkan dialog loading, lalu tampilkan dialog
  /// berhasil/gagal secara otomatis.
  ///
  /// - Mengembalikan hasil task bila sukses, atau `null` bila terjadi error.
  /// - [successMessage] yang null berarti tidak menampilkan dialog berhasil
  ///   (berguna bila pemanggil ingin menampilkan feedback sendiri).
  /// - [errorPrefix] diawalkan ke pesan error, mis. 'Gagal menyimpan'.
  static Future<T?> runWithLoading<T>(
    BuildContext context, {
    required Future<T> Function() task,
    LoadingKind kind = LoadingKind.cariData,
    String? loadingMessage,
    String? successMessage,
    String errorPrefix = 'Gagal',
  }) async {
    showLoading(context, kind: kind, message: loadingMessage);
    try {
      final result = await task();
      if (context.mounted) hide(context);
      if (successMessage != null && context.mounted) {
        await showSuccess(context, successMessage);
      }
      return result;
    } catch (e) {
      if (context.mounted) hide(context);
      if (context.mounted) {
        await showError(context, '$errorPrefix: $e');
      }
      return null;
    }
  }
}

/// Kartu dialog dengan gambar karakter di atas dan konten di bawahnya.
class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.image, required this.child});

  final String image;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                image,
                width: 160,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => SizedBox(
                  width: 160,
                  height: 160,
                  child: Icon(Icons.image_not_supported_outlined,
                      size: 48, color: AppColors.textHint),
                ),
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
