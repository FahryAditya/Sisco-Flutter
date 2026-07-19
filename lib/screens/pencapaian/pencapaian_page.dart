import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/organization_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/achievement.dart';
import '../../models/member.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/character_dialog.dart';

class PencapaianPage extends StatefulWidget {
  const PencapaianPage({super.key});

  @override
  State<PencapaianPage> createState() => _PencapaianPageState();
}

class _PencapaianPageState extends State<PencapaianPage> with SingleTickerProviderStateMixin {
  String? _selectedOrgId;
  late TabController _tabC;
  List<Achievement> _achievements = [];
  List<Member> _members = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabC = TabController(length: 2, vsync: this);
    _tabC.addListener(() {
      if (!_tabC.indexIsChanging) setState(() {});
    });
    context.read<OrganizationProvider>().loadOrgs();
  }

  @override
  void dispose() {
    _tabC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_selectedOrgId == null) return;
    setState(() => _loading = true);
    try {
      _achievements = await FirestoreService.getAchievements(_selectedOrgId!);
      _members = await FirestoreService.getMembers(_selectedOrgId!);
    } catch (e) {
      if (mounted) await AppDialogs.showError(context, 'Gagal memuat data: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showAddAchievement() async {
    final namaC = TextEditingController();
    final deskripsiC = TextEditingController();
    final expC = TextEditingController();
    await showDialog(
      context: context, builder: (ctx) => AlertDialog(
        title: const Text('Tambah Pencapaian'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: namaC, decoration: const InputDecoration(labelText: 'Nama Pencapaian')),
          const SizedBox(height: 8),
          TextField(controller: deskripsiC, decoration: const InputDecoration(labelText: 'Deskripsi'), maxLines: 3),
          const SizedBox(height: 8),
          TextField(controller: expC, decoration: const InputDecoration(labelText: 'EXP Reward', helperText: 'Maksimal 999 EXP'), keyboardType: TextInputType.number),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () async {
            if (namaC.text.trim().isEmpty) {
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Nama pencapaian wajib diisi')));
              return;
            }
            AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
            try {
              final expReward = (int.tryParse(expC.text) ?? 0).clamp(0, 999);
              final user = context.read<AuthProvider>().user;
              await FirestoreService.createAchievement({
                'icon': 'emoji_events',
                'nama': namaC.text.trim(),
                'deskripsi': deskripsiC.text.trim(),
                'expReward': expReward,
                'organizationId': _selectedOrgId,
              });
              await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'CREATE', tabel: 'achievements', deskripsi: 'Membuat pencapaian: ${namaC.text.trim()} ($expReward EXP)');
              if (mounted) AppDialogs.hide(context);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) await AppDialogs.showSuccess(context, 'Pencapaian ditambahkan');
              _load();
            } catch (e) {
              if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal menyimpan pencapaian: $e'); }
            }
          }, child: const Text('Simpan')),
        ],
      ),
    );
  }

  Future<void> _showGiveAchievement(Achievement a) async {
    String? selectedMemberId;
    await showDialog(
      context: context, builder: (ctx) => AlertDialog(
        title: Text('Berikan: ${a.nama}'),
        content: _members.isEmpty
          ? const Text('Tidak ada anggota')
          : AppDropdown<String>(
              label: 'Anggota',
              icon: Icons.person_outline,
              value: selectedMemberId,
              items: _members.map((m) => AppDropdownItem(value: m.id, label: m.name)).toList(),
              onChanged: (v) => selectedMemberId = v,
            ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () async {
            if (selectedMemberId == null) {
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Pilih anggota terlebih dahulu')));
              return;
            }
            AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
            try {
              final user = context.read<AuthProvider>().user;
              await FirestoreService.giveAchievementToMember(selectedMemberId!, {
                'achievementId': a.id,
                'memberId': selectedMemberId,
                'tanggal': FieldValue.serverTimestamp(),
              });
              final member = _members.where((m) => m.id == selectedMemberId).firstOrNull;
              await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'CREATE', tabel: 'member_achievements', deskripsi: 'Memberikan pencapaian ${a.nama} ke ${member?.name ?? selectedMemberId}');
              if (mounted) AppDialogs.hide(context);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) await AppDialogs.showSuccess(context, 'Pencapaian diberikan ke ${member?.name}');
            } catch (e) {
              if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal memberikan pencapaian: $e'); }
            }
          }, child: const Text('Berikan')),
        ],
      ),
    );
  }

  Future<void> _deleteAchievement(String id) async {
    final user = context.read<AuthProvider>().user;
    final ok = await AppDialogs.showConfirm(context, message: 'Yakin?', confirmLabel: 'Hapus', danger: true);
    if (ok == true) {
      if (!mounted) return;
      AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
      try {
        await FirestoreService.deleteAchievement(id);
        await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'DELETE', tabel: 'achievements', recordId: id, deskripsi: 'Menghapus pencapaian');
        if (mounted) AppDialogs.hide(context);
        if (mounted) await AppDialogs.showSuccess(context, 'Pencapaian dihapus');
        _load();
      } catch (e) {
        if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal menghapus pencapaian: $e'); }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgs = context.watch<OrganizationProvider>().orgs;
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Pencapaian',
        colors: const [Color(0xFFF7B733), Color(0xFFF39C12)],
        bottom: TabBar(controller: _tabC, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70, tabs: const [Tab(text: 'Daftar'), Tab(text: 'Anggota')]),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddAchievement)],
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
        else if (_selectedOrgId == null) Center(child: Text('Pilih organisasi terlebih dahulu', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)))
        else SizedBox(
          height: 400,
          child: TabBarView(controller: _tabC, children: [
            _achievementsTab(),
            _membersTab(),
          ]),
        ),
      ]),
    );
  }

  Widget _achievementsTab() {
    if (_achievements.isEmpty) return Center(child: Text('Belum ada pencapaian', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)));
    return ListView(children: _achievements.map((a) {
      return Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: AppColors.warning.withAlpha(30), child: const Icon(Icons.emoji_events, color: AppColors.warning)),
        title: Text(a.nama, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        subtitle: Text(a.deskripsi, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (a.expReward > 0) Chip(label: Text('${a.expReward} EXP', style: TextStyle(fontSize: 10, color: AppColors.warning)), backgroundColor: AppColors.warning.withAlpha(20)),
          const SizedBox(width: 4),
          IconButton(icon: const Icon(Icons.person_add, size: 20), onPressed: () => _showGiveAchievement(a)),
          IconButton(icon: Icon(Icons.delete_outline, size: 20, color: AppColors.danger), onPressed: () => _deleteAchievement(a.id)),
        ]),
      ));
    }).toList());
  }

  Widget _membersTab() {
    if (_members.isEmpty) return Center(child: Text('Belum ada anggota', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)));
    return ListView(children: _members.map((m) => Card(child: ListTile(
      leading: CircleAvatar(backgroundColor: AppColors.primary.withAlpha(30), child: Text(m.name[0])),
      title: Text(m.name),
      subtitle: Text('Level ${m.level} - ${m.exp} XP'),
    ))).toList());
  }
}
