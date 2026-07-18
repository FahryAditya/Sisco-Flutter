import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/organization_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/daily_material.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/character_dialog.dart';

class MateriPage extends StatefulWidget {
  const MateriPage({super.key});

  @override
  State<MateriPage> createState() => _MateriPageState();
}

class _MateriPageState extends State<MateriPage> {
  String? _selectedOrgId;
  List<DailyMaterial> _materials = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    context.read<OrganizationProvider>().loadOrgs();
  }

  Future<void> _load() async {
    if (_selectedOrgId == null) return;
    setState(() => _loading = true);
    try {
      _materials = await FirestoreService.getMaterials(_selectedOrgId!);
    } catch (e) {
      if (mounted) await AppDialogs.showError(context, 'Gagal memuat materi: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showForm([DailyMaterial? existing]) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final judulC = TextEditingController(text: existing?.judul ?? '');
    final deskripsiC = TextEditingController(text: existing?.deskripsi ?? '');
    final lokasiC = TextEditingController(text: existing?.lokasi ?? '');
    final notulenC = TextEditingController(text: existing?.notulen ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? 'Edit Materi' : 'Tambah Materi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: judulC, decoration: const InputDecoration(labelText: 'Judul')),
              const SizedBox(height: 8),
              TextField(controller: deskripsiC, decoration: const InputDecoration(labelText: 'Deskripsi'), maxLines: 3),
              const SizedBox(height: 8),
              TextField(controller: lokasiC, decoration: const InputDecoration(labelText: 'Lokasi')),
              const SizedBox(height: 8),
              TextField(controller: notulenC, decoration: const InputDecoration(labelText: 'Notulen'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () async {
            if (judulC.text.trim().isEmpty) return;
            AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
            try {
              final data = {
                'judul': judulC.text.trim(),
                'deskripsi': deskripsiC.text.trim(),
                'tanggal': FieldValue.serverTimestamp(),
                'organizationId': _selectedOrgId,
                'lokasi': lokasiC.text.trim(),
                'notulen': notulenC.text.trim(),
                'createdBy': user.id,
              };
              if (existing != null) {
                await FirestoreService.updateMaterial(existing.id, data);
                await FirestoreService.logAction(userId: user.id, userNama: user.nama, aksi: 'UPDATE', tabel: 'daily_materials', recordId: existing.id, deskripsi: 'Mengupdate materi: ${judulC.text.trim()}');
              } else {
                await FirestoreService.createMaterial(data);
                await FirestoreService.logAction(userId: user.id, userNama: user.nama, aksi: 'CREATE', tabel: 'daily_materials', deskripsi: 'Membuat materi baru: ${judulC.text.trim()}');
              }
              if (mounted) AppDialogs.hide(context);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) await AppDialogs.showSuccess(context, existing != null ? 'Materi diperbarui' : 'Materi ditambahkan');
            } catch (e) {
              if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal menyimpan materi: $e'); }
            }
            _load();
          }, child: Text(existing != null ? 'Simpan' : 'Tambah')),
        ],
      ),
    );
  }

  Future<void> _delete(String id) async {
    final user = context.read<AuthProvider>().user;
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Hapus Materi'),
      content: const Text('Yakin ingin menghapus?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Hapus', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok == true) {
      if (!mounted) return;
      AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
      try {
        await FirestoreService.deleteMaterial(id);
        await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'DELETE', tabel: 'daily_materials', recordId: id, deskripsi: 'Menghapus materi');
        if (mounted) AppDialogs.hide(context);
        if (mounted) await AppDialogs.showSuccess(context, 'Materi dihapus');
        _load();
      } catch (e) {
        if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal menghapus materi: $e'); }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgs = context.watch<OrganizationProvider>().orgs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materi Hari Ini'),
        actions: [
          if (_selectedOrgId != null)
            IconButton(icon: const Icon(Icons.add), onPressed: () => _showForm()),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppDropdown<String>(
          label: 'Organisasi',
          icon: Icons.business_outlined,
          value: _selectedOrgId,
          items: orgs.map((o) => AppDropdownItem(value: o.id, label: o.nama)).toList(),
          onChanged: (v) { setState(() => _selectedOrgId = v); _load(); },
        ),
        const SizedBox(height: 16),
        if (_loading) const Center(child: CircularProgressIndicator())
        else if (_materials.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Belum ada materi', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary))))
        else ..._materials.map((m) => Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(Icons.menu_book, color: AppColors.primary)),
            title: Text(m.judul, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.deskripsi, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(Formatters.formatDate(m.tanggal), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (m.lokasi != null && m.lokasi!.isNotEmpty)
                  Row(children: [Icon(Icons.location_on, size: 14, color: AppColors.textSecondary), Text(m.lokasi!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))]),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _showForm(m);
                if (v == 'delete') _delete(m.id);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
          ),
        )),
      ]),
    );
  }
}
