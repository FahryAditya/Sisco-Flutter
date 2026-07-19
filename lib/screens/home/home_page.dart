import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/organization_provider.dart';
import '../../providers/quest_provider.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/social_media_popup.dart';
import '../../widgets/sync_status_banner.dart';
import '../dashboard/dashboard_page.dart';
import '../absensi/absensi_page.dart';
import '../kas/kas_page.dart';
import '../pengeluaran/pengeluaran_page.dart';
import '../wawancara/wawancara_page.dart';
import '../admin/admin_page.dart';
import '../organisasi/organisasi_page.dart';
import '../leaderboard/leaderboard_page.dart';
import '../jadwal/jadwal_page.dart';
import '../admin_org/admin_org_home.dart';
import '../anggota/anggota_page.dart';
import '../profile/profile_page.dart';
import '../materi/materi_page.dart';
import '../laporan/laporan_page.dart';
import '../rekap_absensi/rekap_absensi_page.dart';
import '../dokumentasi/dokumentasi_page.dart';
import '../log_aktivitas/log_aktivitas_page.dart';
import '../pencapaian/pencapaian_page.dart';
import '../../widgets/character_dialog.dart';
import '../export/export_page.dart';
import '../import/import_page.dart';
import '../chat/chat_list_page.dart';
import '../quest/quest_page.dart';
import '../backup/backup_page.dart';
import '../settings/settings_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const AbsensiPage(),
    const KasPage(),
    const PengeluaranPage(),
    const WawancaraPage(),
    const JadwalPage(),
    const LeaderboardPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OrganizationProvider>().loadOrgs();
      final user = context.read<AuthProvider>().user;
      if (user != null && user.isOrganizationAdmin && user.orgIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anda belum ditugaskan ke organisasi manapun')),
        );
      }
      // Popup Instagram SISCO — hanya untuk admin / admin org / pembina, dan
      // hanya sekali (opsi "Jangan tampilkan lagi" disimpan per-user).
      if (user != null &&
          (user.isAdministrator ||
              user.isOrganizationAdmin ||
              user.isPembina)) {
        SocialMediaPopup.maybeShow(context, user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.nama ?? 'SISCO'),
        actions: [
          if (user?.isStaff ?? false)
            _ChatIconButton(uid: user!.id),
          if (user?.isAdministrator ?? false)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => Navigator.push(
                context,
                SmoothPageRoute(builder: (_) => const AdminPage()),
              ),
            ),
        ],
      ),
      drawer: _buildDrawer(context, user),
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex < 3 ? _currentIndex : 0,
        onDestinationSelected: (i) {
          if (i == 3) {
            Navigator.push(context, SmoothPageRoute(builder: (_) => const ProfilePage()));
            return;
          }
          setState(() => _currentIndex = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_outlined), label: 'Absensi'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Kas'),
          NavigationDestination(icon: Icon(Icons.person_outlined), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, UserModel? user) {
    final isAdmin = user?.isAdministrator ?? false;
    final isOrgAdmin = user?.isOrganizationAdmin ?? false;
    final isStaff = user?.isStaff ?? false;
    final canWawancara = user?.canWawancara ?? false;
    final canMateriJadwal = user?.canMateriJadwal ?? false;
    final canAuditLog = user?.canAuditLog ?? false;
    final canExportImport = user?.canExportImport ?? false;
    final canDokumentasi = user?.canDokumentasi ?? false;
    final canManageMembers = user?.canManageMembers ?? false;
    final canSeeQuest = context.watch<QuestProvider>().canSeeQuestMenu(user);

    return Drawer(
      child: Column(
        children: [
          _drawerHeader(user),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _sectionLabel('UTAMA'),
                _drawerItem(Icons.dashboard_outlined, 'Dashboard', AppColors.primary, () => _navigate(0)),
                _drawerItem(Icons.qr_code_scanner_outlined, 'Absensi', Colors.blue, () => _navigate(1)),
                _drawerItem(Icons.leaderboard_outlined, 'Leaderboard', Colors.amber, () => _navigate(6)),
                if (isStaff)
                  _drawerItem(Icons.chat_bubble_outline, 'Pesan', Colors.blueAccent, () => _push(const ChatListPage())),

                _sectionLabel('KEUANGAN'),
                _drawerItem(Icons.account_balance_wallet_outlined, 'Kas', Colors.green, () => _navigate(2)),
                _drawerItem(Icons.money_off_outlined, 'Pengeluaran', Colors.red, () => _navigate(3)),
                _drawerItem(Icons.bar_chart_outlined, 'Laporan', Colors.indigo, () => _push(const LaporanPage())),

                _sectionLabel('KEGIATAN'),
                if (canManageMembers)
                  _drawerItem(Icons.group_add_outlined, 'Anggota', Colors.green, () => _push(const AnggotaPage())),
                _drawerItem(Icons.groups_outlined, 'Organisasi', Colors.orange, () => _push(const OrganisasiPage())),
                if (canWawancara)
                  _drawerItem(Icons.record_voice_over_outlined, 'Wawancara', Colors.purple, () => _navigate(4)),
                if (canMateriJadwal)
                  _drawerItem(Icons.calendar_month_outlined, 'Jadwal', Colors.teal, () => _navigate(5)),
                if (canMateriJadwal)
                  _drawerItem(Icons.menu_book_outlined, 'Materi', Colors.brown, () => _push(const MateriPage())),
                _drawerItem(Icons.summarize_outlined, 'Rekap Absensi', Colors.cyan, () => _push(const RekapAbsensiPage())),
                if (canDokumentasi)
                  _drawerItem(Icons.photo_library_outlined, 'Dokumentasi', Colors.deepOrange, () => _push(const DokumentasiPage())),
                _drawerItem(Icons.emoji_events_outlined, 'Pencapaian', Colors.amber, () => _push(const PencapaianPage())),
                if (canSeeQuest)
                  _drawerItem(Icons.qr_code_2, 'Airlangga QR Quest', Colors.deepPurple, () => _push(const QuestPage())),

                if (isAdmin || isOrgAdmin) ...[
                  _sectionLabel('ADMIN'),
                  _drawerItem(Icons.business_outlined, 'Org / Eskul Saya', Colors.teal, () => _push(const AdminOrgHomePage())),
                  if (isAdmin)
                    _drawerItem(Icons.admin_panel_settings_outlined, 'Admin Panel', Colors.red, () => _push(const AdminPage())),
                  if (canAuditLog)
                    _drawerItem(Icons.history_outlined, 'Log Aktivitas', Colors.grey, () => _push(const LogAktivitasPage())),
                ],

                if (canExportImport) ...[
                  _sectionLabel('DATA'),
                  _drawerItem(Icons.file_download_outlined, 'Export', Colors.teal, () => _push(const ExportPage())),
                  _drawerItem(Icons.file_upload_outlined, 'Import', Colors.indigo, () => _push(const ImportPage())),
                ],
                if (isAdmin || isOrgAdmin)
                  _drawerItem(Icons.cloud_upload_outlined, 'Backup Cloud', Colors.deepPurple, () => _push(const BackupPage())),

                _sectionLabel('TAMPILAN'),
                _drawerItem(Icons.settings_outlined, 'Pengaturan', Colors.blueGrey, () => _push(const SettingsPage())),

                _sectionLabel('AKUN'),
                _drawerItem(Icons.person_outlined, 'Profile', Colors.pink, () => _navigate(7)),
                _drawerItem(
                  Icons.camera_alt_outlined,
                  'Media Sosial',
                  const Color(0xFFDD2A7B),
                  () {
                    Navigator.pop(context);
                    SocialMedia.openInstagram();
                  },
                ),
                _drawerItem(Icons.logout, 'Keluar', AppColors.danger, () => _confirmLogout(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerHeader(UserModel? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0057B3), Color(0xFF1ABC9C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(90), width: 2),
                ),
                child: const CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, size: 30, color: Colors.white),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            user?.nama ?? 'User',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user?.roleDisplay ?? '',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textHint,
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await AppDialogs.showConfirm(context, message: 'Yakin ingin keluar?', confirmLabel: 'Keluar', danger: true);
    if (ok == true) {
      if (context.mounted) context.read<OrganizationProvider>().clear();
      if (context.mounted) context.read<AuthProvider>().logout();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil keluar')));
    }
  }

  Widget _drawerItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withAlpha(28),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigate(int index) {
    Navigator.pop(context);
    setState(() => _currentIndex = index);
  }

  void _push(Widget page) {
    Navigator.pop(context);
    Navigator.push(context, SmoothPageRoute(builder: (_) => page));
  }
}

/// Ikon Pesan di app bar dengan badge jumlah pesan belum dibaca (realtime).
class _ChatIconButton extends StatelessWidget {
  final String uid;
  const _ChatIconButton({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: ChatService.totalUnreadStream(uid),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Pesan',
              onPressed: () => Navigator.push(
                context,
                SmoothPageRoute(builder: (_) => const ChatListPage()),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
