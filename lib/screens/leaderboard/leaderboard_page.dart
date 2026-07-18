import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/member.dart';
import '../../utils/exp_helper.dart';
import '../../utils/animations.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/app_dropdown.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  String? _selectedOrgId;
  List<Member> _members = [];
  bool _loading = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    context.read<OrganizationProvider>().loadOrgs();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _subscribe(String orgId) {
    _sub?.cancel();
    setState(() => _loading = true);
    _sub = FirestoreService.leaderboardStream(orgId).listen((list) {
      if (!mounted) return;
      setState(() { _members = list; _loading = false; });
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat leaderboard: $e')));
    });
  }

  @override
  Widget build(BuildContext context) {
    final orgs = context.watch<OrganizationProvider>().orgs;
    return Scaffold(appBar: AppBar(title: const Text('Leaderboard')), body: ListView(padding: const EdgeInsets.all(16), children: [
      AppDropdown<String>(label: 'Organisasi', icon: Icons.business_outlined, value: _selectedOrgId,
        items: orgs.map((o) => AppDropdownItem(value: o.id, label: o.nama)).toList(),
        onChanged: (v) { setState(() => _selectedOrgId = v); if (v != null) _subscribe(v); },
      ),
      const SizedBox(height: 16),
      if (_loading) const SkeletonList(items: 6, padding: EdgeInsets.zero)
      else if (_members.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Belum ada data', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary))))
      else ...List.generate(_members.length, (i) {
        final m = _members[i];
        return Card(child: ListTile(
          leading: CircleAvatar(
            backgroundColor: i < 3 ? AppColors.warning.withAlpha(40) : AppColors.primary.withAlpha(20),
            child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: i < 3 ? AppColors.warning : AppColors.primary)),
          ),
          title: Text(m.name),
          subtitle: Text('Level ${m.level} - ${ExpHelper.getLevelBadge(m.level)}'),
          trailing: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${m.exp}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('XP', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ]),
        )).animateEntrance(index: i);
      }),
    ]));
  }
}

