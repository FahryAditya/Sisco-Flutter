import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../utils/exp_helper.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/images/logo.png', width: 100, height: 100, fit: BoxFit.cover),
            ),
            const SizedBox(height: 24),
            Text(
              'SISCO',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sistem Absensi Organisasi',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
            Text(
              AppVersion.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
