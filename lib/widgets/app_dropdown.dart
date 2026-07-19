import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

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
  final IconData? icon;
  final String? Function(T?)? validator;
  final bool isExpanded;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && items.any((e) => e.value == value);
    final effectiveEnabled = enabled && items.isNotEmpty;

    if (value != null && !hasValue && onChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) onChanged!(null);
      });
    }

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: effectiveEnabled ? AppColors.surface : AppColors.background,
        prefixIcon: icon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _border(AppColors.border),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.primary, width: 1.6),
        errorBorder: _border(AppColors.danger),
        focusedErrorBorder: _border(AppColors.danger, width: 1.6),
        labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: hasValue ? value : null,
          isExpanded: isExpanded,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
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
          hint: hint != null || items.isEmpty
              ? Text(
                  hint ?? 'Belum ada data',
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textHint),
                )
              : null,
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
          onChanged: effectiveEnabled ? onChanged : null,
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
}

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
