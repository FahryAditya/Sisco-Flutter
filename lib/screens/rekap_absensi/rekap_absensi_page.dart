import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/attendance.dart';
import '../../models/member.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/app_dropdown.dart';


class RekapAbsensiPage extends StatefulWidget {
  const RekapAbsensiPage({super.key});

  @override
  State<RekapAbsensiPage> createState() => _RekapAbsensiPageState();
}

class _RekapAbsensiPageState extends State<RekapAbsensiPage> {
  String? _selectedOrgId;
  List<Attendance> _attendances = [];
  List<Member> _members = [];
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
      _members = await FirestoreService.getMembers(_selectedOrgId!);
      _attendances = await FirestoreService.getAttendanceByDate(_selectedOrgId!, DateTime.now());
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat rekap: $e')));
    }
  }

  Map<String, int> get _summary {
    final s = <String, int>{'hadir': 0, 'tidak_hadir': 0, 'izin': 0, 'sakit': 0, 'kas_saja': 0};
    for (final a in _attendances) {
      s[a.status] = (s[a.status] ?? 0) + 1;
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final orgs = context.watch<OrganizationProvider>().orgs;
    return Scaffold(
      appBar: const GradientAppBar(title: 'Rekap Absensi', colors: [Color(0xFF4DD0E1), Color(0xFF0097A7)]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppDropdown<String>(
          label: 'Organisasi',
          icon: Icons.business_outlined,
          value: _selectedOrgId,
          items: orgs.map((o) => AppDropdownItem(value: o.id, label: o.nama)).toList(),
          onChanged: (v) => setState(() => _selectedOrgId = v),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.search),
          label: const Text('Lihat Rekap Hari Ini'),
          onPressed: _load,
        ),
        const SizedBox(height: 16),
        if (_loading) const Center(child: CircularProgressIndicator())
        else if (_members.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Belum ada anggota', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary))))
        else ...[
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Text('Ringkasan', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ..._summary.entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.absensiColor(e.key), shape: BoxShape.circle)), const SizedBox(width: 8), Text(e.key.replaceAll('_', ' '))]),
              Text('${e.value}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            ]))),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
              Text('${_members.length} anggota', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            ]),
          ]))),
          const SizedBox(height: 16),
          Text('Detail Anggota', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ..._members.map((m) {
            final att = _attendances.where((a) => a.memberId == m.id).firstOrNull;
            return Card(child: ListTile(
              leading: CircleAvatar(
                backgroundColor: att != null ? AppColors.absensiColor(att.status).withAlpha(30) : AppColors.border,
                child: Icon(Icons.person, color: att != null ? AppColors.absensiColor(att.status) : AppColors.textSecondary),
              ),
              title: Text(m.name),
              subtitle: Text(m.kelas ?? ''),
              trailing: att != null
                ? Chip(label: Text(att.statusDisplay, style: const TextStyle(fontSize: 11, color: Colors.white)), backgroundColor: AppColors.absensiColor(att.status))
                : Chip(label: const Text('Belum', style: TextStyle(fontSize: 11)), backgroundColor: AppColors.border),
            ));
          }),
        ],
      ]),
    );
  }
}
