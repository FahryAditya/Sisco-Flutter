import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/organization.dart';
import '../../models/member.dart';
import '../../models/attendance.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';

class OrgWorkspacePage extends StatefulWidget {
  final Organization org;
  const OrgWorkspacePage({super.key, required this.org});

  @override
  State<OrgWorkspacePage> createState() => _OrgWorkspacePageState();
}

class _OrgWorkspacePageState extends State<OrgWorkspacePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Member> _members = [];
  List<Attendance> _attendances = [];
  int _cashBalance = 0;
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;
  StreamSubscription? _membersSub;
  StreamSubscription? _attSub;
  StreamSubscription? _txSub;
  StreamSubscription? _exSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _subscribeAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _membersSub?.cancel();
    _attSub?.cancel();
    _txSub?.cancel();
    _exSub?.cancel();
    super.dispose();
  }

  void _subscribeAll() {
    _membersSub?.cancel();
    _attSub?.cancel();
    _txSub?.cancel();
    _exSub?.cancel();
    setState(() => _loading = true);

    _membersSub = FirestoreService.membersStream(widget.org.id).listen((list) {
      if (!mounted) return;
      setState(() { _members = list; _loading = false; });
    }, onError: (_) { if (mounted) setState(() => _loading = false); });

    _attSub = FirestoreService.attendanceStream(widget.org.id, _selectedDate).listen((list) {
      if (!mounted) return;
      setState(() { _attendances = list; _loading = false; });
    }, onError: (_) { if (mounted) setState(() => _loading = false); });

    _txSub = FirestoreService.cashTransactionsStream(widget.org.id).listen((list) {
      if (!mounted) return;
      _recalcCash();
    }, onError: (_) {});

    _exSub = FirestoreService.expensesStream(widget.org.id).listen((list) {
      if (!mounted) return;
      _recalcCash();
    }, onError: (_) {});
  }

  void _recalcCash() {
    FirestoreService.getCashBalance(widget.org.id).then((b) {
      if (mounted) setState(() => _cashBalance = b);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _subscribeAll();
    }
  }

  Future<void> _setStatus(String memberId, String status) async {
    try {
      await FirestoreService.upsertAttendance({
        'organizationId': widget.org.id,
        'memberId': memberId,
        'date': Timestamp.fromDate(_selectedDate),
        'status': status,
        'cashAmount': 0,
        'notes': null,
      }, _selectedDate, memberId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status: $status')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan absensi: $e')));
    }
  }

  Future<void> _setAllHadir() async {
    for (final m in _members) {
      await _setStatus(m.id, 'hadir');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.org.nama),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Anggota', icon: Icon(Icons.people, size: 18)),
            Tab(text: 'Absensi', icon: Icon(Icons.qr_code_scanner, size: 18)),
            Tab(text: 'Kas', icon: Icon(Icons.account_balance_wallet, size: 18)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabController, children: [
              _buildMembersTab(),
              _buildAttendanceTab(),
              _buildCashTab(),
            ]),
    );
  }

  Widget _buildMembersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('${_members.length} anggota', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          );
        }
        final m = _members[i - 1];
        return Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: AppColors.primary.withAlpha(30), child: Text('${m.level}', style: const TextStyle(fontSize: 12))),
          title: Text(m.name),
          subtitle: Text('${m.kelas ?? '-'} - Level ${m.level}'),
          trailing: Text('${m.exp} XP', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ));
      },
    );
  }

  Widget _buildAttendanceTab() {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Expanded(child: InkWell(onTap: _pickDate, child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Tanggal', isDense: true),
          child: Text(Formatters.formatDate(_selectedDate)),
        ))),
        const SizedBox(width: 8),
        ElevatedButton.icon(onPressed: _setAllHadir, icon: const Icon(Icons.check, size: 16),
          label: const Text('Hadir Semua'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success.withAlpha(30), foregroundColor: AppColors.success)),
      ])),
      Expanded(child: _members.isEmpty
          ? const Center(child: Text('Tidak ada anggota'))
          : ListView.builder(itemCount: _members.length, itemBuilder: (_, i) {
        final m = _members[i];
        final att = _attendances.where((a) => a.memberId == m.id).firstOrNull;
        final status = att?.status ?? 'hadir';
        return Card(child: ListTile(
          title: Text(m.name),
          subtitle: Text(m.kelas ?? '-'),
          trailing: DropdownButton<String>(value: status, underline: const SizedBox(),
            style: TextStyle(color: AppColors.absensiColor(status), fontWeight: FontWeight.w600),
            items: ['hadir', 'tidak_hadir', 'izin', 'sakit', 'alpha', 'kas_saja'].map((s) => DropdownMenuItem(
              value: s, child: Text(s.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: AppColors.absensiColor(s))),
            )).toList(),
            onChanged: (v) { if (v != null) _setStatus(m.id, v); },
          ),
        ));
      })),
    ]);
  }

  Widget _buildCashTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          const Text('Saldo Kas', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(Formatters.formatCurrency(_cashBalance), style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        ]),
      )),
    ]);
  }
}
