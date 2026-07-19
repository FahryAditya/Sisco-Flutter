import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _prefsAccent = 'accent_color_index';

  int _accentIndex = 0;

  static const List<Color> accentColors = [
    Color(0xFF0057B3),
    Color(0xFF1ABC9C),
    Color(0xFFFF6B35),
    Color(0xFF9B59B6),
    Color(0xFFE74C3C),
    Color(0xFF2ECC71),
  ];

  static const List<String> accentLabels = [
    'Biru (Default)',
    'Teal',
    'Oranye',
    'Ungu',
    'Merah',
    'Hijau',
  ];

  int get accentIndex => _accentIndex;
  Color get accentColor => accentColors[_accentIndex];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accentIndex = prefs.getInt(_prefsAccent) ?? 0;
    notifyListeners();
  }

  Future<void> setAccentColor(int index) async {
    if (index < 0 || index >= accentColors.length) return;
    _accentIndex = index;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsAccent, index);
  }
}
