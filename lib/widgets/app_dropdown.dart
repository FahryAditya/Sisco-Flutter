import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Dropdown bergaya modern & seragam untuk seluruh aplikasi.
///
/// Pembungkus tipis di atas [DropdownButtonFormField] sehingga migrasi dari
/// dropdown lama nyaris drop-in: cukup ganti nama widget dan (opsional) tambah
/// [icon]. Semua penyeragaman visual dipusatkan di sini:
///   • sudut membulat 12, isian lembut, border tipis yang menguat saat fokus,
///   • popup menu membulat dengan sudut 16 dan elevasi halus,
///   • chevron animasi-friendly + ikon prefix opsional,
///   • label & teks memakai Plus Jakarta Sans agar serasi dengan tema.
///
/// Contoh:
/// ```dart
/// AppDropdown<String>(
///   label: 'Organisasi',
///   icon: Icons.business_outlined,
///   value: _selectedOrgId,
///   items: orgs
///       .map((o) => AppDropdownItem(value: o.id, label: o.nama))
///       .toList(),
///   onChanged: (v) => setState(() => _selectedOrgId = v),
/// )
/// ```
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.hint,
    this.icon,
    this.validator,
    this.isExpanded = true,
    this.enabled = true,
  });

  final T? value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;

  /// Ikon prefix opsional untuk memberi konteks visual (mis. Icons.business).
  final IconData? icon;
  final String? Function(T?)? validator;
  final bool isExpanded;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Jaga agar value tetap valid; kalau tidak ada di daftar item, jangan paksa
    // supaya tidak memicu assertion "value not in items".
    final hasValue = value != null && items.any((e) => e.value == value);

    return DropdownButtonFormField<T>(
      initialValue: hasValue ? value : null,
      isExpanded: isExpanded,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.textSecondary),
      iconSize: 24,
      borderRadius: BorderRadius.circular(16),
      dropdownColor: AppColors.surface,
      elevation: 3,
      style: GoogleFonts.plusJakartaSans(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      hint: hint == null
          ? null
          : Text(hint!,
              style: GoogleFonts.plusJakartaSans(color: AppColors.textHint)),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? AppColors.surface : AppColors.background,
        prefixIcon: icon == null
            ? null
            : Icon(icon, size: 20, color: AppColors.primary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.primary, width: 1.6),
        errorBorder: _border(AppColors.danger),
        focusedErrorBorder: _border(AppColors.danger, width: 1.6),
        labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
      ),
      items: items
          .map((e) => DropdownMenuItem<T>(
                value: e.value,
                child: e.child ??
                    Row(
                      children: [
                        if (e.icon != null) ...[
                          Icon(e.icon,
                              size: 18, color: e.iconColor ?? AppColors.primary),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            e.label ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
              ))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Deskriptor satu opsi pada [AppDropdown].
///
/// Gunakan [label] untuk teks sederhana (paling umum), atau [child] bila butuh
/// tata letak kustom. [icon] menampilkan ikon kecil di depan label.
class AppDropdownItem<T> {
  const AppDropdownItem({
    required this.value,
    this.label,
    this.icon,
    this.iconColor,
    this.child,
  }) : assert(label != null || child != null,
            'AppDropdownItem butuh label atau child');

  final T value;
  final String? label;
  final IconData? icon;
  final Color? iconColor;
  final Widget? child;
}
