import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/organization.dart';
import '../../widgets/character_dialog.dart';
import 'registration_form_page.dart';

class RegistrationLandingPage extends StatefulWidget {
  const RegistrationLandingPage({super.key});

  @override
  State<RegistrationLandingPage> createState() => _RegistrationLandingPageState();
}

class _RegistrationLandingPageState extends State<RegistrationLandingPage> {
  List<Organization> _orgs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrgs();
  }

  Future<void> _loadOrgs() async {
    setState(() => _loading = true);
    try {
      final orgs = await FirestoreService.getOrganizations();
      if (mounted) setState(() { _orgs = orgs; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); await AppDialogs.showError(context, 'Gagal memuat organisasi: $e'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pendaftaran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Daftar Organisasi / Ekstrakurikuler',
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Pilih organisasi yang ingin kamu ikuti',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (_orgs.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Belum ada organisasi tersedia', style: TextStyle(color: AppColors.textSecondary))))
          else
            ..._orgs.map((org) => Card(child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withAlpha(30),
                child: Icon(Icons.business, color: AppColors.primary),
              ),
              title: Text(org.nama, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              subtitle: Text('${org.schoolOrigin} - ${org.status}',
                style: TextStyle(color: AppColors.textSecondary)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(context,
                SmoothPageRoute(builder: (_) => RegistrationFormPage(org: org))),
            ))),
        ],
      ),
    );
  }
}
