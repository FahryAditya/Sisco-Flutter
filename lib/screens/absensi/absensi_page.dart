import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/organization_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/member.dart';
import '../../models/attendance.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../utils/exp_helper.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/animations.dart';
import '../../widgets/animated_stats.dart';
import '../../widgets/animated_member_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/app_dropdown.dart';

class AbsensiPage extends StatefulWidget {
  const AbsensiPage({super.key});

  @override
  State<AbsensiPage> createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedOrgId;
  List<Member> _members = [];
  List<Member> _filteredMembers = [];
  Map<String, Attendance> _attendanceMap = {};
  bool _loading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name';
  StreamSubscription? _membersSub;
  StreamSubscription? _attSub;

  @override
  void initState() {
    super.initState();
    _loadOrgs();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _membersSub?.cancel();
    _attSub?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterMembers();
    });
  }

  void _filterMembers() {
    if (_searchQuery.isEmpty) {
      _filteredMembers = List.from(_members);
    } else {
      _filteredMembers = _members.where((member) {
        return member.name.toLowerCase().contains(_searchQuery) ||
               (member.kelas?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }
    _sortMembers();
  }

  void _sortMembers() {
    switch (_sortBy) {
      case 'name':
        _filteredMembers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'level':
        _filteredMembers.sort((a, b) => b.level.compareTo(a.level));
        break;
      case 'status':
        _filteredMembers.sort((a, b) {
          final statusA = _attendanceMap[a.id]?.status ?? 'hadir';
          final statusB = _attendanceMap[b.id]?.status ?? 'hadir';
          return statusA.compareTo(statusB);
        });
        break;
    }
  }

  Future<void> _loadOrgs() async {
    final orgProvider = context.read<OrganizationProvider>();
    await orgProvider.loadOrgs();
    if (mounted && _selectedOrgId == null && orgProvider.orgs.isNotEmpty) {
      _selectedOrgId = orgProvider.orgs.first.id;
      _subscribeStreams(_selectedOrgId!);
    }
  }

  void _subscribeStreams(String orgId) {
    _membersSub?.cancel();
    _attSub?.cancel();

    // Tampilkan shimmer/progress bar hanya di bagian yang berubah, bukan layar
    // penuh, saat menunggu data organisasi baru.
    _loading = true;
    setState(() {});

    _membersSub = FirestoreService.membersStream(orgId).listen((list) {
      if (!mounted || _selectedOrgId != orgId) return;
      _members = list;
      _filterMembers();
      _loading = false;
      setState(() {});
    }, onError: (_) {
      _members = [];
      _loading = false;
      setState(() {});
    });

    _attSub = FirestoreService.attendanceStream(orgId, _selectedDate).listen((list) {
      if (!mounted || _selectedOrgId != orgId) return;
      _attendanceMap = {for (final a in list) a.memberId: a};
      _filterMembers();
      _loading = false;
      setState(() {});
    }, onError: (_) {
      _attendanceMap = {};
      _loading = false;
      setState(() {});
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
      if (_selectedOrgId != null) _subscribeStreams(_selectedOrgId!);
    }
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
      if (status == 'hadir') await _addExp(memberId);
      await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'UPDATE', tabel: 'attendance', recordId: memberId, deskripsi: 'Mengubah status absensi ${member?.name ?? memberId} menjadi $status');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${member?.name ?? memberId}: $status')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan absensi: $e')));
    }
  }

  Future<void> _setAllStatus(String status) async {
    try {
      final user = context.read<AuthProvider>().user;
      await Future.wait(_filteredMembers.map((m) async {
        await FirestoreService.upsertAttendance({
          'organizationId': _selectedOrgId!,
          'memberId': m.id,
          'date': Timestamp.fromDate(_selectedDate),
          'status': status,
          'cashAmount': 0,
          'notes': null,
        }, _selectedDate, m.id);
        if (status == 'hadir') await _addExp(m.id);
      }));
      await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'UPDATE', tabel: 'attendance', deskripsi: 'Mengubah absensi massal ${_filteredMembers.length} anggota menjadi $status');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_filteredMembers.length} anggota: $status')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan absensi massal: $e')));
    }
  }

  Future<void> _addExp(String memberId) async {
    final member = _members.where((m) => m.id == memberId).firstOrNull;
    if (member == null) return;
    final result = ExpHelper.calculateLevelUp(member.exp, member.level, ExpHelper.expPerAbsen);
    await FirestoreService.updateMemberExp(memberId, result.exp, result.level);
  }

  @override
  Widget build(BuildContext context) {
    final orgs = context.read<OrganizationProvider>().orgs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi'),
        actions: [
          // Search action button
          IconButton(
            onPressed: () {
              FocusScope.of(context).requestFocus(FocusNode());
              Future.delayed(const Duration(milliseconds: 100), () {
                _searchController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _searchController.text.length,
                );
              });
            },
            icon: const Icon(Icons.search),
            tooltip: 'Fokus ke pencarian',
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar tipis di atas layar saat data sedang disinkronkan.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _loading
                ? const LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: AppColors.primaryLight,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  )
                : const SizedBox(height: 3, width: double.infinity),
          ),
          // Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppDropdown<String>(label: 'Organisasi', icon: Icons.business_outlined, value: _selectedOrgId,
                  items: orgs.map((o) => AppDropdownItem(value: o.id, label: o.nama)).toList(),
                  onChanged: (v) {
                    setState(() => _selectedOrgId = v);
                    if (v != null) _subscribeStreams(v);
                  },
                ).animateEntrance(index: 1, baseDelay: const Duration(milliseconds: 100)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 12),
                        Text(
                          Formatters.formatDate(_selectedDate),
                          style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ).animateEntrance(index: 2, baseDelay: const Duration(milliseconds: 100)),
                const SizedBox(height: 8),
                // Search Field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Cari nama anggota',
                    hintText: 'Masukkan nama atau kelas...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
                ).animateEntrance(index: 3, baseDelay: const Duration(milliseconds: 100)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ditemukan: ${_filteredMembers.length} dari ${_members.length} anggota',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        // Sort dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortBy,
                              isDense: true,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'name', child: Text('Nama')),
                                DropdownMenuItem(value: 'level', child: Text('Level')),
                                DropdownMenuItem(value: 'status', child: Text('Status')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _sortBy = value;
                                    _sortMembers();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                            },
                            child: Text(
                              'Reset',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Statistics Card
                if (_filteredMembers.isNotEmpty)
                  _buildStatisticsCard().animateEntrance(
                    index: 4,
                    baseDelay: const Duration(milliseconds: 100),
                  ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _quickAction('Hadir', AppColors.hadir, () => _setAllStatus('hadir'))
                          .animatePop(index: 0),
                      const SizedBox(width: 8),
                      _quickAction('Izin', AppColors.izin, () => _setAllStatus('izin'))
                          .animatePop(index: 1),
                      const SizedBox(width: 8),
                      _quickAction('Sakit', AppColors.sakit, () => _setAllStatus('sakit'))
                          .animatePop(index: 2),
                      const SizedBox(width: 8),
                      _quickAction('Alpha', AppColors.alpha, () => _setAllStatus('alpha'))
                          .animatePop(index: 3),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const SkeletonList(items: 7)
                : _filteredMembers.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        // Key berganti tiap query berubah agar item cocok
                        // beranimasi masuk kembali saat hasil pencarian berubah.
                        key: ValueKey('list_$_searchQuery'),
                        itemCount: _filteredMembers.length,
                        itemBuilder: (_, i) {
                          final m = _filteredMembers[i];
                          final att = _attendanceMap[m.id];
                          final status = att?.status ?? 'hadir';
                          return AnimatedMemberCard(
                            key: ValueKey(m.id),
                            name: m.name,
                            kelas: m.kelas,
                            level: m.level,
                            status: status,
                            searchQuery: _searchQuery,
                            statuses: const [
                              'hadir',
                              'tidak_hadir',
                              'izin',
                              'sakit',
                              'alpha',
                              'kas_saja',
                            ],
                            onStatusChanged: (s) => _setStatus(m.id, s),
                          ).animateEntrance(
                            index: i < 12 ? i : 0,
                            baseDelay: const Duration(milliseconds: 100),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _filteredMembers.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (context) => _buildQuickActionsSheet(),
                );
              },
              icon: const Icon(Icons.bolt),
              label: const Text('Aksi Cepat'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildStatisticsCard() {
    final stats = <String, int>{
      'hadir': 0,
      'tidak_hadir': 0,
      'izin': 0,
      'sakit': 0,
      'alpha': 0,
      'kas_saja': 0,
    };

    for (final member in _filteredMembers) {
      final status = _attendanceMap[member.id]?.status ?? 'hadir';
      stats[status] = (stats[status] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistik Absensi ${_searchQuery.isNotEmpty ? '(Hasil Pencarian)' : ''}',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: stats.entries.where((e) => e.value > 0).map((entry) {
              return AnimatedStatChip(
                key: ValueKey('stat_${entry.key}'),
                label: entry.key.replaceAll('_', ' ').toUpperCase(),
                value: entry.value,
                color: AppColors.absensiColor(entry.key),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final searching = _searchQuery.isNotEmpty;
    return Center(
      key: ValueKey('empty_$searching'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            searching ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(
                begin: 0,
                end: -6,
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 16),
          Text(
            searching ? 'Tidak ada anggota ditemukan' : 'Tidak ada anggota',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (searching) ...[
            const SizedBox(height: 6),
            Text(
              'Coba kata kunci lain',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _searchController.clear(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset Pencarian'),
            ),
          ],
        ],
      ).animateEntrance(),
    );
  }

  Widget _quickAction(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: _filteredMembers.isEmpty ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withAlpha(30),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        disabledBackgroundColor: AppColors.border.withOpacity(0.3),
        disabledForegroundColor: AppColors.textSecondary,
      ),
      child: Text(label),
    );
  }

  Widget _buildQuickActionsSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aksi Cepat',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Untuk ${_filteredMembers.length} anggota ${_searchQuery.isNotEmpty ? '(Hasil Pencarian)' : ''}',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _quickActionButton('Semua Hadir', AppColors.hadir, Icons.check_circle, 0, () {
                Navigator.pop(context);
                _setAllStatus('hadir');
              }),
              const SizedBox(width: 8),
              _quickActionButton('Semua Izin', AppColors.izin, Icons.event_busy, 1, () {
                Navigator.pop(context);
                _setAllStatus('izin');
              }),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _quickActionButton('Semua Sakit', AppColors.sakit, Icons.local_hospital, 2, () {
                Navigator.pop(context);
                _setAllStatus('sakit');
              }),
              const SizedBox(width: 8),
              _quickActionButton('Semua Alpha', AppColors.alpha, Icons.cancel, 3, () {
                Navigator.pop(context);
                _setAllStatus('alpha');
              }),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _quickActionButton(String label, Color color, IconData icon, int index, VoidCallback onPressed) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: color.withOpacity(0.3)),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ).animatePop(index: index),
    );
  }
}


