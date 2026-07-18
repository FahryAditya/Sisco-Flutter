import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/organization.dart';
import '../../services/firestore_service.dart';
import '../../widgets/character_dialog.dart';
import '../quest/quest_activation.dart';
import 'org_workspace_page.dart';

class AdminOrgHomePage extends StatefulWidget {
  const AdminOrgHomePage({super.key});

  @override
  State<AdminOrgHomePage> createState() => _AdminOrgHomePageState();
}

class _AdminOrgHomePageState extends State<AdminOrgHomePage> {
  List<Organization> _orgs = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      if (user.isAdministrator) {
        _orgs = await FirestoreService.getOrganizations();
      } else {
        _orgs = await FirestoreService.getOrganizationsByIds(user.orgIds);
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) await AppDialogs.showError(context, 'Gagal memuat organisasi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final canActivateQuest =
        (user?.isAdministrator ?? false) || (user?.isAdminOrg ?? false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organisasi / Eskul'),
        actions: [
          if (canActivateQuest)
            IconButton(
              icon: const Icon(Icons.qr_code_2),
              tooltip: 'Airlangga QR Quest',
              onPressed: () => QuestActivation.show(context),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orgs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business_outlined, size: 64, color: AppColors.border),
                        const SizedBox(height: 16),
                        Text('Tidak ada organisasi', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
                        if (!user!.isAdministrator)
                          Text('Anda belum ditugaskan ke organisasi manapun', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textHint)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orgs.length,
                  itemBuilder: (_, i) {
                    final org = _orgs[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withAlpha(30),
                          child: Icon(Icons.business, color: AppColors.primary),
                        ),
                        title: Text(org.nama, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                        subtitle: Text('${org.category} - ${org.schoolOrigin}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          SmoothPageRoute(builder: (_) => OrgWorkspacePage(org: org)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
