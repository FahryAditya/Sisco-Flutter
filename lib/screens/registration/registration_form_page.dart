import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/organization.dart';
import '../../utils/kelas_helper.dart';
import '../../widgets/character_dialog.dart';

class RegistrationFormPage extends StatefulWidget {
  final Organization org;
  const RegistrationFormPage({super.key, required this.org});

  @override
  State<RegistrationFormPage> createState() => _RegistrationFormPageState();
}

class _RegistrationFormPageState extends State<RegistrationFormPage> {
  final _namaC = TextEditingController();
  final _kelasC = TextEditingController();
  final _emailC = TextEditingController();
  final _nisnC = TextEditingController();
  bool _loading = false;
  bool _success = false;

  @override
  void dispose() {
    _namaC.dispose();
    _kelasC.dispose();
    _emailC.dispose();
    _nisnC.dispose();
    super.dispose();
  }

  String get _kejuruan => KelasHelper.jurusanOf(_kelasC.text) ?? '';

  Future<void> _submit() async {
    final nama = _namaC.text.trim();
    final kelas = _kelasC.text.trim();
    final email = _emailC.text.trim();
    final nisn = _nisnC.text.trim();

    if (nama.isEmpty || kelas.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama, kelas, dan email wajib diisi')));
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format email tidak valid')));
      return;
    }
    if (!KelasHelper.isValid(kelas)) {
      final saran = KelasHelper.suggest(kelas);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saran != null
            ? 'Kelas tidak valid. Maksud Anda "$saran"?'
            : 'Kelas tidak valid (contoh: ${KelasHelper.contohKelas})'),
      ));
      return;
    }
    final kelasNorm = KelasHelper.normalize(kelas)!;

    setState(() => _loading = true);
    AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi, message: 'Mengirim pendaftaran...');
    try {
      await FirestoreService.createRegistration({
        'organizationId': widget.org.id,
        'namaPeserta': nama,
        'kelas': kelasNorm,
        'kejuruan': _kejuruan,
        'emailGmail': email,
        'nisn': nisn.isEmpty ? null : nisn,
        'status': 'MENUNGGU',
      });
      await FirestoreService.logAction(userId: '', userNama: nama, aksi: 'CREATE', tabel: 'registrations', deskripsi: 'Pendaftaran online: $nama ke ${widget.org.nama}');
      if (mounted) AppDialogs.hide(context);
      setState(() => _success = true);
    } catch (e) {
      if (mounted) {
        AppDialogs.hide(context);
        await AppDialogs.showError(context, 'Gagal mendaftar: $e');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pendaftaran Berhasil')),
        body: Center(child: Padding(padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle, size: 80, color: AppColors.success),
            const SizedBox(height: 16),
            Text('Pendaftaran Berhasil!', style: GoogleFonts.plusJakartaSans(
              fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Pendaftaran kamu ke ${widget.org.nama} sedang diproses.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('Kembali')),
          ]))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Daftar ${widget.org.nama}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: AppColors.primaryLight,
          child: Padding(padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.info, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Text('${widget.org.nama}\n${widget.org.schoolOrigin}',
                style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.w500))),
            ])),
        ),
        const SizedBox(height: 20),
        TextField(controller: _namaC, decoration: const InputDecoration(
          labelText: 'Nama Lengkap', prefixIcon: Icon(Icons.person))),
        const SizedBox(height: 12),
        TextField(controller: _kelasC, decoration: const InputDecoration(
          labelText: 'Kelas (contoh: X PPLG atau XI TJKT 2)', prefixIcon: Icon(Icons.school))),
        const SizedBox(height: 12),
        TextField(controller: _emailC, keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Gmail', prefixIcon: Icon(Icons.email))),
        const SizedBox(height: 12),
        TextField(controller: _nisnC, decoration: const InputDecoration(
          labelText: 'NISN (opsional)', prefixIcon: Icon(Icons.badge))),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _loading ? null : _submit,
          child: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Daftar')),
      ]),
    );
  }
}
