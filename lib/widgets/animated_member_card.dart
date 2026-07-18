import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Kartu anggota pada halaman Absensi dengan animasi perubahan status:
/// saat status diganti, kartu sedikit mengecil, status lama memudar, muncul
/// loading kecil, lalu status baru & warna kartu bertransisi halus.
class AnimatedMemberCard extends StatefulWidget {
  final String name;
  final String? kelas;
  final int level;
  final String status;
  final String searchQuery;

  /// Daftar status yang bisa dipilih (mis. hadir, izin, sakit, ...).
  final List<String> statuses;

  /// Dipanggil saat pengguna memilih status baru. Harus menyimpan perubahan.
  final Future<void> Function(String newStatus) onStatusChanged;

  const AnimatedMemberCard({
    super.key,
    required this.name,
    required this.kelas,
    required this.level,
    required this.status,
    required this.searchQuery,
    required this.statuses,
    required this.onStatusChanged,
  });

  @override
  State<AnimatedMemberCard> createState() => _AnimatedMemberCardState();
}

class _AnimatedMemberCardState extends State<AnimatedMemberCard> {
  bool _updating = false;
  bool _pressed = false;

  Future<void> _handleChange(String newStatus) async {
    if (newStatus == widget.status) return;
    setState(() {
      _updating = true;
      _pressed = true;
    });
    // Jeda kecil agar animasi "mengecil + loading" terasa (min. 200 ms).
    await Future.wait([
      widget.onStatusChanged(newStatus),
      Future.delayed(const Duration(milliseconds: 220)),
    ]);
    if (mounted) {
      setState(() {
        _updating = false;
        _pressed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.absensiColor(widget.status);
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withAlpha(40),
            child: Text(
              '${widget.level}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          title: _buildHighlightedText(widget.name, widget.searchQuery),
          subtitle: Text(
            widget.kelas ?? '-',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          trailing: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: _updating
                ? SizedBox(
                    key: const ValueKey('loading'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  )
                : _statusDropdown(),
          ),
        ),
      ),
    );
  }

  Widget _statusDropdown() {
    return DropdownButton<String>(
      key: ValueKey('dropdown_${widget.status}'),
      value: widget.status,
      underline: const SizedBox(),
      style: GoogleFonts.plusJakartaSans(
        color: AppColors.absensiColor(widget.status),
        fontWeight: FontWeight.w600,
      ),
      items: widget.statuses.map((s) {
        return DropdownMenuItem(
          value: s,
          child: Text(
            s.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(color: AppColors.absensiColor(s)),
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) _handleChange(v);
      },
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    final base = GoogleFonts.plusJakartaSans(
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
    if (query.isEmpty) return Text(text, style: base);

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);
    if (index == -1) return Text(text, style: base);

    return RichText(
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              backgroundColor: AppColors.primary.withOpacity(0.1),
            ),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }
}
