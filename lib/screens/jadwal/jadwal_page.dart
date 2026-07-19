import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/schedule.dart';
import '../../utils/formatters.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/app_dropdown.dart';

class JadwalPage extends StatefulWidget {
  const JadwalPage({super.key});

  @override
  State<JadwalPage> createState() => _JadwalPageState();
}

class _JadwalPageState extends State<JadwalPage> {
  String? _selectedOrgId;
  List<Schedule> _schedules = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    context.read<OrganizationProvider>().loadOrgs();
  }

  Future<void> _load() async {
    if (_selectedOrgId == null) {
      setState(() {
        _schedules = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final snap = await FirestoreService.schedulesRef.where('organizationId', isEqualTo: _selectedOrgId).orderBy('tanggal', descending: true).get();
      _schedules = snap.docs.map((d) => Schedule.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat jadwal: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final orgs = context.watch<OrganizationProvider>().orgs;
    return Scaffold(appBar: const GradientAppBar(title: 'Jadwal', colors: [Color(0xFF26C6DA), Color(0xFF00838F)]), body: ListView(padding: const EdgeInsets.all(16), children: [
      AppDropdown<String>(label: 'Organisasi', icon: Icons.business_outlined, value: _selectedOrgId,
        items: orgs.map((o) => AppDropdownItem(value: o.id, label: o.nama)).toList(),
        onChanged: (v) { setState(() => _selectedOrgId = v); _load(); },
      ),
      const SizedBox(height: 16),
      if (_loading) const Center(child: CircularProgressIndicator())
      else if (_schedules.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Belum ada jadwal', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary))))
      else ..._schedules.map((s) => Card(child: ListTile(
        leading: CircleAvatar(child: Icon(Icons.event, color: AppColors.primary)),
        title: Text(s.judul),
        subtitle: Text('${Formatters.formatDate(s.tanggal)} ${s.waktu ?? ""}'),
        trailing: s.wajibHadir ? const Icon(Icons.star, color: AppColors.warning, size: 20) : null,
      ))),
    ]));
  }
}
