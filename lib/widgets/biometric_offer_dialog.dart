import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';

Future<bool?> showBiometricOffer(BuildContext context, {required String uid}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => _BiometricOfferDialog(uid: uid),
  );
}

class _BiometricOfferDialog extends StatefulWidget {
  final String uid;
  const _BiometricOfferDialog({required this.uid});

  @override
  State<_BiometricOfferDialog> createState() => _BiometricOfferDialogState();
}

class _BiometricOfferDialogState extends State<_BiometricOfferDialog> {
  bool _loading = false;
  bool _deviceReady = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkDevice();
  }

  Future<void> _checkDevice() async {
    final svc = BiometricService.instance;
    final tersedia = svc.isAvailable;
    final enrolled = svc.isEnrolled;
    if (mounted) {
      setState(() {
        _deviceReady = tersedia && enrolled;
        _checking = false;
      });
    }
  }

  Future<void> _activate() async {
    if (!_deviceReady) return;
    setState(() => _loading = true);
    final ok = await BiometricService.instance.registerBiometric(uid: widget.uid);
    if (mounted) {
      setState(() => _loading = false);
      if (ok) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.fingerprint, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Text(
            'Login Lebih Cepat',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: _buildContent(),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    if (_checking) {
      return const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (!_deviceReady) {
      return Text(
        'Silakan aktifkan keamanan biometrik (sidik jari / Face ID) '
        'di pengaturan perangkat terlebih dahulu.',
        style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Gunakan biometrik perangkat untuk login lebih cepat dan aman.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5),
        ),
        if (_loading) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(height: 8),
          Text(
            'Tempelkan jari ke sensor...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildActions() {
    if (_checking) return [];

    return [
      if (!_loading)
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Nanti',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
          ),
        ),
      if (_deviceReady && !_loading)
        ElevatedButton.icon(
          icon: const Icon(Icons.fingerprint, size: 20),
          label: const Text('Aktifkan'),
          onPressed: _activate,
        ),
    ];
  }
}
