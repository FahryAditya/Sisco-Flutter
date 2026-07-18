import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/organization_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/member.dart';
import '../../models/attendance.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/formatters.dart';
import '../../utils/exp_helper.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/app_dropdown.dart';

class OrganisasiPage extends StatefulWidget {
  const OrganisasiPage({super.key});

  @override
  State<OrganisasiPage> createState() => _OrganisasiPageState();
}

class _OrganisasiPageState extends State<OrganisasiPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedOrgId;
  List<Member> _members = [];
  Map<String, Attendance> _attendanceMap = {};
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<OrganizationProvider>().loadOrgs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers({bool forceRefresh = false}) async {
    if (_selectedOrgId == null) return;
    try {
      _members = await FirestoreService.getMembers(_selectedOrgId!, forceRefresh: forceRefresh);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat anggota: $e')));
    }
    setState(() {});
  }

  Future<void> _refreshMembers() => _loadMembers(forceRefresh: true);

  Future<void> _loadAttendance() async {
    if (_selectedOrgId == null) return;
    try {
      final list = await FirestoreService.getAttendanceByDate(_selectedOrgId!, _selectedDate);
      _attendanceMap = {for (final a in list) a.memberId: a};
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat absensi: $e')));
    }
    setState(() {});
  }

  Future<void> _setStatus(String memberId, String status) async {
    try {
      final user = context.read<AuthProvider>().user;
      await FirestoreService.upsertAttendance({
        'organizationId': _selectedOrgId!,
        'memberId': memberId,
        'date': Timestamp.fromDate(_selectedDate),
        'status': status,
        'cashAmount': 0,
        'notes': null,
      }, _selectedDate, memberId);
      final member = _members.where((m) => m.id == memberId).firstOrNull;
      await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'UPDATE', tabel: 'attendance', recordId: memberId, deskripsi: 'Mengubah status absensi ${member?.name ?? memberId} menjadi $status');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${member?.name ?? memberId}: $status')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan absensi: $e')));
    }
    _loadAttendance();
  }

  @override
  Widget build(BuildContext context) {
    final orgs = context.watch<OrganizationProvider>().orgs;
    return Scaffold(appBar: GradientAppBar(title: 'Organisasi', colors: const [Color(0xFFFF9068), Color(0xFFFF6B35)], bottom: TabBar(
      controller: _tabController, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.white70, tabs: const [Tab(text: 'Anggota'), Tab(text: 'Absensi & Kas')],
    )), body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: AppDropdown<String>(label: 'Organisasi', icon: Icons.business_outlined, value: _selectedOrgId,
        items: orgs.map((o) => AppDropdownItem(value: o.id, label: o.nama)).toList(),
        onChanged: (v) { setState(() => _selectedOrgId = v); _loadMembers(); _loadAttendance(); },
      )),
      Expanded(child: TabBarView(controller: _tabController, children: [
        _buildMembersTab(),
        _buildAbsensiTab(),
      ])),
    ]));
  }

  Widget _buildMembersTab() {
    if (_selectedOrgId == null) return const SizedBox();
    return RefreshIndicator(onRefresh: _refreshMembers, child: ListView.builder(
      itemCount: _members.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return Padding(padding: const EdgeInsets.all(16), child: Text('${_members.length} anggota', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)));
        final m = _members[i - 1];
        return Card(child: ListTile(
          leading: CircleAvatar(child: Text('${m.level}')),
          title: Text(m.name), subtitle: Text('${m.kelas ?? "-"} - Level ${m.level} (${ExpHelper.getLevelBadge(m.level)})'),
          trailing: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(Formatters.formatCurrency(m.exp), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text('XP', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ));
      },
    ));
  }

  Widget _buildAbsensiTab() {
    if (_selectedOrgId == null) return const SizedBox();
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
          if (picked != null) { setState(() => _selectedDate = picked); _loadAttendance(); }
        },
        child: InputDecorator(decoration: const InputDecoration(labelText: 'Tanggal'), child: Text(Formatters.formatDate(_selectedDate))),
      )),
      Expanded(child: _members.isEmpty ? const Center(child: Text('Pilih organisasi dulu')) : ListView.builder(
        itemCount: _members.length, itemBuilder: (_, i) {
          final m = _members[i];
          final att = _attendanceMap[m.id];
          final status = att?.status ?? 'hadir';
          return Card(child: ListTile(
            title: Text(m.name), subtitle: Text(m.kelas ?? '-'),
            trailing: DropdownButton<String>(value: status, underline: const SizedBox(),
              style: TextStyle(color: AppColors.absensiColor(status), fontWeight: FontWeight.w600),
              items: ['hadir', 'tidak_hadir', 'izin', 'sakit', 'alpha', 'kas_saja'].map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: AppColors.absensiColor(s))))).toList(),
              onChanged: (v) { if (v != null) _setStatus(m.id, v); },
            ),
          ));
        },
      )),
    ]);
  }
}




