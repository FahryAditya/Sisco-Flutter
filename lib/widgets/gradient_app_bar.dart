import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppBar dengan latar gradient berwarna, dipakai lintas halaman agar
/// tampilan konsisten & tidak monoton. Mendukung [actions] dan [bottom]
/// (mis. TabBar) seperti AppBar biasa.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Color> colors;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const GradientAppBar({
    super.key,
    required this.title,
    required this.colors,
    this.actions,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      backgroundColor: Colors.transparent,
      actions: actions,
      bottom: bottom,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}
