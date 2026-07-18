import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/organization_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/registration.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/character_dialog.dart';

class ApprovalPage extends StatefulWidget {
  const ApprovalPage({super.key});

  @override
  State<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage> {
  String? _selectedOrgId;
  List<Registration> _registrations = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    context.read<OrganizationProvider>().loadOrgs();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await FirestoreService.getRegistrations(orgId: _selectedOrgId);
      if (mounted) setState(() { _registrations = list; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); await AppDialogs.showError(context, 'Gagal memuat pendaftaran: $e'); }
    }
  }

  Future<void> _approve(Registration r, {String? reason}) async {
    final user = context.read<AuthProvider>().user;
    AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
    try {
      await FirestoreService.updateRegistration(r.id, {
        'status': 'DITERIMA',
        'acceptReason': reason,
      });
      await FirestoreService.createMember({
        'organizationId': r.organizationId,
        'name': r.namaPeserta,
        'kelas': r.kelas,
        'email': r.emailGmail,
        'nis': r.nisn,
        'jabatan': 'Anggota',
        'status': 'ACTIVE',
        'level': 1,
        'exp': 0,
      });
      await FirestoreService.logAction(
        userId: user?.id ?? '', userNama: user?.nama ?? '',
        aksi: 'UPDATE', tabel: 'registrations', recordId: r.id,
        deskripsi: 'Menyetujui pendaftaran: ${r.namaPeserta} ke organisasi',
      );
      if (mounted) AppDialogs.hide(context);
      if (mounted) await AppDialogs.showSuccess(context, '${r.namaPeserta} diterima');
      _load();
    } catch (e) {
      if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal approve: $e'); }
    }
  }

  Future<void> _reject(Registration r, {String? reason}) async {
    final user = context.read<AuthProvider>().user;
    AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
    try {
      await FirestoreService.updateRegistration(r.id, {
        'status': 'DITOLAK',
        'rejectReason': reason,
      });
      await FirestoreService.logAction(
        userId: user?.id ?? '', userNama: user?.nama ?? '',
        aksi: 'UPDATE', tabel: 'registrations', recordId: r.id,
        deskripsi: 'Menolak pendaftaran: ${r.namaPeserta}',
      );
      if (mounted) AppDialogs.hide(context);
      if (mounted) await AppDialogs.showSuccess(context, '${r.namaPeserta} ditolak');
      _load();
    } catch (e) {
      if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal menolak: $e'); }
    }
  }

  Future<void> _showActionDialog(Registration r) async {
    final reasonC = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(r.namaPeserta),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _detailRow('Kelas', r.kelas),
        _detailRow('Jurusan', r.kejuruan),
        _detailRow('Email', r.emailGmail),
        if (r.nisn != null) _detailRow('NISN', r.nisn!),
        _detailRow('Status', r.statusDisplay),
        const Divider(),
        TextField(controller: reasonC, decoration: const InputDecoration(labelText: 'Catatan (opsional)', hintText: 'Alasan diterima/ditolak'), maxLines: 3),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        if (r.status == 'MENUNGGU') ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Terima', style: TextStyle(color: Colors.white)),
            onPressed: () { Navigator.pop(ctx); _approve(r, reason: reasonC.text.trim().isEmpty ? null : reasonC.text.trim()); },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            icon: const Icon(Icons.close, color: Colors.white),
            label: const Text('Tolak', style: TextStyle(color: Colors.white)),
            onPressed: () { Navigator.pop(ctx); _reject(r, reason: reasonC.text.trim().isEmpty ? null : reasonC.text.trim()); },
          ),
        ],
      ],
    ));
  }

  Widget _detailRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(label, style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 13))),
        Expanded(child: Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500))),
      ],
    ));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'DITERIMA': return AppColors.success;
      case 'DITOLAK': return AppColors.danger;
      default: return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgs = context.watch<OrganizationProvider>().orgs;
    return Scaffold(
      appBar: AppBar(title: const Text('Persetujuan Pendaftaran')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppDropdown<String>(
          label: 'Organisasi',
          icon: Icons.business_outlined,
          value: _selectedOrgId,
          items: orgs.map((o) => AppDropdownItem(value: o.id, label: o.nama)).toList(),
          onChanged: (v) { setState(() => _selectedOrgId = v); _load(); },
        ),
        const SizedBox(height: 16),
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (_registrations.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(32),
            child: Column(children: [
              Icon(Icons.person_off_outlined, size: 64, color: AppColors.textSecondary.withAlpha(80)),
              const SizedBox(height: 12),
              Text('Belum ada pendaftaran', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 16)),
            ])))
        else
          ..._registrations.map((r) => Card(child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(r.status).withAlpha(30),
              child: Icon(Icons.person, color: _statusColor(r.status)),
            ),
            title: Text(r.namaPeserta, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            subtitle: Text('${r.kelas} - ${r.emailGmail}', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Chip(
              label: Text(r.statusDisplay, style: TextStyle(fontSize: 11, color: Colors.white)),
              backgroundColor: _statusColor(r.status),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            onTap: () => _showActionDialog(r),
          ))),
      ]),
    );
  }
}
