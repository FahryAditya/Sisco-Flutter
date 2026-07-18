import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// Data akun Instagram resmi SISCO + helper untuk membukanya.
class SocialMedia {
  static const String instagramHandle = 'sisco_skarla';
  static const String instagramUrl =
      'https://www.instagram.com/sisco_skarla?igsh=bDJ4MTE0ZTI2dXRh';

  static Future<void> openInstagram() async {
    final uri = Uri.parse(instagramUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }
}

/// Popup yang muncul pertama kali admin/pembina login. Preferensi
/// "Jangan tampilkan lagi" disimpan per-user di SharedPreferences.
class SocialMediaPopup {
  static const String _prefsPrefix = 'social_popup_dismissed_';
  static String _keyFor(String userId) => '$_prefsPrefix$userId';

  static Future<void> maybeShow(BuildContext context, String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyFor(userId)) == true) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _SocialMediaDialog(userId: userId),
    );
  }
}

class _SocialMediaDialog extends StatefulWidget {
  final String userId;
  const _SocialMediaDialog({required this.userId});

  @override
  State<_SocialMediaDialog> createState() => _SocialMediaDialogState();
}

class _SocialMediaDialogState extends State<_SocialMediaDialog> {
  bool _dontShowAgain = false;
  bool _busy = false;

  Future<void> _persist() async {
    if (!_dontShowAgain) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SocialMediaPopup._keyFor(widget.userId), true);
  }

  Future<void> _close() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _persist();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _follow() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _persist();
    await SocialMedia.openInstagram();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Ikuti kami di Instagram',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Dapatkan info kegiatan, dokumentasi, dan pengumuman '
                        'terbaru dari SISCO langsung di feed kamu.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _handleChip(),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _follow,
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: Text(
                            'Ikuti @${SocialMedia.instagramHandle}',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy ? null : _close,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                        ),
                        child: Text(
                          'Nanti saja',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Divider(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _busy
                            ? null
                            : () => setState(
                                () => _dontShowAgain = !_dontShowAgain),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _dontShowAgain,
                                  onChanged: _busy
                                      ? null
                                      : (v) => setState(() =>
                                          _dontShowAgain = v ?? false),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Jangan tampilkan lagi',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 110,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF58529),
            Color(0xFFDD2A7B),
            Color(0xFF8134AF),
            Color(0xFF515BD4),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Tutup',
              onPressed: _busy ? null : _close,
            ),
          ),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withAlpha(120), width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _handleChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alternate_email,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              SocialMedia.instagramHandle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
