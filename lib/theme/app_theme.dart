import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF0057B3);
  static const Color primaryLight = Color(0xFFE8F0FE);
  static const Color secondary = Color(0xFF1ABC9C);
  static const Color accent = Color(0xFFFF6B35);
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1D21);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color danger = Color(0xFFE74C3C);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF3498DB);

  static const Color cardBackground = Colors.white;
  static const Color darkBackground = Color(0xFF000B18);
  static const Color appBarBackground = Colors.white;

  // Role specific
  static const Color adminBadge = Color(0xFFFF6B6B);
  static const Color orgAdminBadge = Color(0xFFFF6B35);
  static const Color eskulAdminBadge = Color(0xFF4A90D9);
  static const Color pembinaOrgBadge = Color(0xFF50C878);
  static const Color pembinaEskulBadge = Color(0xFF9B59B6);

  // Status absensi
  static const Color hadir = Color(0xFF2ECC71);
  static const Color tidakHadir = Color(0xFFE74C3C);
  static const Color izin = Color(0xFF3498DB);
  static const Color sakit = Color(0xFFF39C12);
  static const Color alpha = Color(0xFF8E44AD);
  static const Color kasSaja = Color(0xFF95A5A6);

  static Color roleBadge(String role) {
    switch (role) {
      case 'administrator':
      case 'superadmin':
      case 'admin':
        return adminBadge;
      case 'organization_admin':
      case 'admin_organisasi':
      case 'organisasi':
        return orgAdminBadge;
      case 'admin_eskul':
      case 'eskul':
        return eskulAdminBadge;
      case 'pembina_organisasi':
        return pembinaOrgBadge;
      case 'pembina_eskul':
        return pembinaEskulBadge;
      default:
        return textSecondary;
    }
  }

  static Color absensiColor(String status) {
    switch (status) {
      case 'hadir': return hadir;
      case 'tidak_hadir': return tidakHadir;
      case 'izin': return izin;
      case 'sakit': return sakit;
      case 'alpha': return alpha;
      case 'kas_saja': return kasSaja;
      default: return textSecondary;
    }
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.appBarBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border.withAlpha(80)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.danger),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textHint),
        labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
      ),
      chipTheme: ChipThemeData(
        selectedColor: AppColors.primary,
        secondarySelectedColor: AppColors.primaryLight,
        brightness: Brightness.light,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.border.withAlpha(128),
        thickness: 0.5,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: AppColors.primaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          );
        }),
      ),
    );
  }
}
