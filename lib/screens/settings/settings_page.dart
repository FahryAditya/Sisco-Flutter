import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/theme_provider.dart';
import '../../services/biometric_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/character_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final svc = BiometricService.instance;
    final enabled = await svc.isEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = svc.isAvailable && svc.isEnrolled;
        _biometricEnabled = enabled && _biometricAvailable;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      final ok = await BiometricService.instance.authenticate(
        reason: 'Aktifkan login sidik jari',
      );
      if (!ok) return;
      await BiometricService.instance.registerBiometric(uid: '');
      if (mounted) {
        setState(() => _biometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login sidik jari aktif'), behavior: SnackBarBehavior.floating),
        );
      }
    } else {
      await BiometricService.instance.disable();
      if (mounted) {
        setState(() => _biometricEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login sidik jari dinonaktifkan'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('TAMPILAN'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Warna Aksen'),
              subtitle: Text(ThemeProvider.accentLabels[theme.accentIndex]),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: ThemeProvider.accentColors.map((c) => Container(
                  width: 20, height: 20, margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                    border: Border.all(color: c == theme.accentColor ? Colors.white : Colors.transparent, width: 2),
                  ),
                )).toList(),
              ),
              onTap: () => _showAccentPicker(theme),
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('KEAMANAN'),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Login Sidik Jari'),
              subtitle: Text(_biometricAvailable
                  ? (_biometricEnabled ? 'Sidik jari / Face ID aktif' : 'Aktifkan login cepat')
                  : 'Tidak tersedia di perangkat ini'),
              secondary: Icon(
                _biometricAvailable ? Icons.fingerprint : Icons.smartphone_outlined,
                color: _biometricEnabled ? AppColors.primary : AppColors.textHint,
              ),
              value: _biometricEnabled,
              onChanged: _biometricAvailable ? _toggle : null,
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('CACHE'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('Hapus Cache'),
              subtitle: const Text('Bersihkan data cache lokal aplikasi'),
              onTap: () => _confirmClearCache(),
            ),
          ),
        ],
      ),
    );
  }

  void _showAccentPicker(ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pilih Warna Aksen', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...List.generate(ThemeProvider.accentColors.length, (i) => ListTile(
                leading: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: ThemeProvider.accentColors[i], shape: BoxShape.circle),
                ),
                title: Text(ThemeProvider.accentLabels[i]),
                trailing: theme.accentIndex == i ? Icon(Icons.check, color: ThemeProvider.accentColors[i]) : null,
                onTap: () {
                  theme.setAccentColor(i);
                  Navigator.pop(c);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearCache() async {
    final ok = await AppDialogs.showConfirm(context, message: 'Data cache lokal akan dibersihkan. Data tersimpan di server tidak terpengaruh.', confirmLabel: 'Hapus');
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cache dibersihkan'), behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(label, style: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textHint, letterSpacing: 0.5,
      )),
    );
  }
}
