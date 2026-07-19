import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/animations.dart';
import '../../widgets/shimmer_loading.dart';
import '../../services/firestore_service.dart';
import '../absensi/absensi_page.dart';
import '../kas/kas_page.dart';
import '../pengeluaran/pengeluaran_page.dart';
import '../leaderboard/leaderboard_page.dart';
import '../jadwal/jadwal_page.dart';
import '../admin_org/admin_org_home.dart';
import '../profile/profile_page.dart';
import '../wawancara/wawancara_page.dart';
import '../organisasi/organisasi_page.dart';
import '../anggota/anggota_page.dart';
import '../admin/admin_page.dart';
import '../materi/materi_page.dart';
import '../laporan/laporan_page.dart';
import '../rekap_absensi/rekap_absensi_page.dart';
import '../dokumentasi/dokumentasi_page.dart';
import '../log_aktivitas/log_aktivitas_page.dart';
import '../pencapaian/pencapaian_page.dart';
import '../export/export_page.dart';
import '../import/import_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  int totalHadir = 0;
  int totalAnggota = 0;
  int totalKas = 0;
  Timer? _refreshTimer;
  StreamSubscription? _orgSub;
  StreamSubscription? _attSub;
  StreamSubscription? _cashSub;
  List<String> _orgIds = [];

  @override
  void initState() {
    super.initState();
    context.read<OrganizationProvider>().loadOrgs();
    _subscribeOrgs();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _orgSub?.cancel();
    _attSub?.cancel();
    _cashSub?.cancel();
    super.dispose();
  }

  void _subscribeOrgs() {
    _orgSub?.cancel();
    _orgSub = FirestoreService.orgsRef.snapshots().listen((snap) {
      _orgIds = snap.docs.map((d) => d.id).toList();
      totalAnggota = _orgIds.length;
      if (mounted) {
        final orgProvider = context.read<OrganizationProvider>();
        final currentIds = orgProvider.orgs.map((o) => o.id).toSet();
        final serverIds = _orgIds.toSet();
        if (currentIds.length != serverIds.length ||
            !currentIds.containsAll(serverIds)) {
          unawaited(orgProvider.refresh());
        }
      }
      if (_orgIds.isEmpty) {
        _attSub?.cancel();
        _cashSub?.cancel();
        _refreshTimer?.cancel();
        totalHadir = 0;
        totalKas = 0;
      } else {
        _subscribeAllData();
      }
      if (mounted) setState(() => _loading = false);
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  void _subscribeAllData() {
    _attSub?.cancel();
    _cashSub?.cancel();

    _attSub = FirestoreService.attendanceRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)))
        .where('date', isLessThan: Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).add(const Duration(days: 1))))
        .snapshots()
        .listen((snap) {
      int hadir = 0;
      for (final d in snap.docs) {
        final s = d.data() as Map<String, dynamic>?;
        if (s?['status'] == 'hadir') hadir++;
      }
      if (mounted) setState(() => totalHadir = hadir);
    }, onError: (_) {});

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshCash());
    _refreshCash();
  }

  Future<void> _refreshCash() async {
    int total = 0;
    for (final id in _orgIds) {
      total += await FirestoreService.getCashBalance(id);
    }
    if (mounted) setState(() => totalKas = total);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _subscribeOrgs();
          if (_orgIds.isNotEmpty) _subscribeAllData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Halo, ${user?.nama ?? 'User'}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              Formatters.formatDateLong(DateTime.now()),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            if (_loading) const SkeletonStatGrid(rows: 2),
            if (!_loading) ...[
            Row(
              children: [
                Expanded(child: _statCard('Total Anggota', '$totalAnggota', Icons.groups, AppColors.primary).animateEntrance(index: 0)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Hadir Hari Ini', '$totalHadir', Icons.check_circle, AppColors.success).animateEntrance(index: 1)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statCard('Organisasi', '${context.read<OrganizationProvider>().orgs.length}', Icons.business, AppColors.info).animateEntrance(index: 2)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Saldo Kas', Formatters.formatCurrency(totalKas), Icons.account_balance_wallet, AppColors.warning).animateEntrance(index: 3)),
              ],
            ),
            const SizedBox(height: 24),
            ],

            Text(
              'Menu Cepat',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 152,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                clipBehavior: Clip.none,
                children: _buildHeroCards(user),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Lainnya',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.82,
              children: _buildOtherCards(user)
                  .asMap()
                  .entries
                  .map((e) => e.value.animatePop(index: e.key))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(IconData icon, String label, String subtitle, List<Color> gradient, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withAlpha(75),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const Spacer(),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: Colors.white.withAlpha(210),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridCard(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHeroCards(UserModel? user) {
    final cards = [
      _heroCard(Icons.qr_code_scanner, 'Absensi', 'Scan kehadiran',
          const [Color(0xFF4A90E2), Color(0xFF0057B3)], () => _push(const AbsensiPage())),
      _heroCard(Icons.account_balance_wallet, 'Kas', 'Saldo & iuran',
          const [Color(0xFF2ECC71), Color(0xFF16A085)], () => _push(const KasPage())),
      _heroCard(Icons.money_off, 'Pengeluaran', 'Catat keluar',
          const [Color(0xFFFF6B6B), Color(0xFFE74C3C)], () => _push(const PengeluaranPage())),
      _heroCard(Icons.leaderboard, 'Leaderboard', 'Peringkat aktif',
          const [Color(0xFFF7B733), Color(0xFFF39C12)], () => _push(const LeaderboardPage())),
      _heroCard(Icons.groups, 'Organisasi', 'Anggota & data',
          const [Color(0xFFFF9068), Color(0xFFFF6B35)], () => _push(const OrganisasiPage())),
    ];
    return cards
        .asMap()
        .entries
        .map((e) => e.value.animateEntrance(index: e.key, slide: 0.0))
        .toList();
  }

  List<Widget> _buildOtherCards(UserModel? user) {
    final isAdmin = user?.isAdministrator ?? false;
    final isOrgAdmin = user?.isOrganizationAdmin ?? false;
    final canWawancara = user?.canWawancara ?? false;
    final canMateriJadwal = user?.canMateriJadwal ?? false;
    final canAuditLog = user?.canAuditLog ?? false;
    final canExportImport = user?.canExportImport ?? false;
    final canDokumentasi = user?.canDokumentasi ?? false;
    final canManageMembers = user?.canManageMembers ?? false;

    return [
      if (canManageMembers)
        _gridCard(Icons.group_add, 'Anggota', Colors.green, () => _push(const AnggotaPage())),
      if (canWawancara)
        _gridCard(Icons.record_voice_over, 'Wawancara', Colors.purple, () => _push(const WawancaraPage())),
      if (isAdmin || isOrgAdmin)
        _gridCard(Icons.business, 'Org Saya', Colors.teal, () => _push(const AdminOrgHomePage())),
      if (isAdmin)
        _gridCard(Icons.admin_panel_settings, 'Admin', Colors.red, () => _push(const AdminPage())),
      if (canMateriJadwal)
        _gridCard(Icons.calendar_month, 'Jadwal', Colors.teal, () => _push(const JadwalPage())),
      if (canMateriJadwal)
        _gridCard(Icons.menu_book, 'Materi', Colors.brown, () => _push(const MateriPage())),
      _gridCard(Icons.bar_chart, 'Laporan', Colors.indigo, () => _push(const LaporanPage())),
      _gridCard(Icons.summarize, 'Rekap Absensi', Colors.cyan, () => _push(const RekapAbsensiPage())),
      if (canDokumentasi)
        _gridCard(Icons.photo_library, 'Dokumentasi', Colors.deepOrange, () => _push(const DokumentasiPage())),
      _gridCard(Icons.emoji_events, 'Pencapaian', Colors.amber, () => _push(const PencapaianPage())),
      if (canAuditLog)
        _gridCard(Icons.history, 'Log', Colors.grey, () => _push(const LogAktivitasPage())),
      if (canExportImport)
        _gridCard(Icons.file_download, 'Export', Colors.teal, () => _push(const ExportPage())),
      if (canExportImport)
        _gridCard(Icons.file_upload, 'Import', Colors.indigo, () => _push(const ImportPage())),
      _gridCard(Icons.person, 'Profile', Colors.pink, () => _push(const ProfilePage())),
    ];
  }

  void _push(Widget page) {
    Navigator.push(context, SmoothPageRoute(builder: (_) => page));
  }
}
