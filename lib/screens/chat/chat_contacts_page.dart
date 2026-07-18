import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../services/directory_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/empty_state.dart';
import 'chat_room_page.dart';

/// Daftar staff yang bisa diajak chat. Semua staff bisa saling berkirim pesan
/// (administrator, admin org/eskul, pembina org/eskul) — kecuali diri sendiri
/// dan akun siswa.
class ChatContactsPage extends StatefulWidget {
  const ChatContactsPage({super.key});

  @override
  State<ChatContactsPage> createState() => _ChatContactsPageState();
}

class _ChatContactsPageState extends State<ChatContactsPage> {
  List<StaffContact> _staff = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Ambil user SEBELUM await agar tidak menyentuh context lintas async gap.
    final me = context.read<AuthProvider>().user;
    try {
      final staff = await DirectoryService.getStaffContacts(me?.id ?? '');
      if (mounted) {
        setState(() {
          _staff = staff;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat kontak: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  List<StaffContact> get _filtered {
    if (_query.isEmpty) return _staff;
    final q = _query.toLowerCase();
    return _staff
        .where((u) =>
            u.nama.toLowerCase().contains(q) ||
            _roleDisplay(u.role).toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pesan Baru')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Cari nama atau role...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        message: 'Tidak ada kontak',
                        subtitle: 'Belum ada staff lain yang bisa dihubungi.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) => _tile(_filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tile(StaffContact u) {
    final color = AppColors.roleBadge(u.role);
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: color.withAlpha(40),
            child: Text(
              _initials(u.nama),
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (u.isOnlineNow)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2.5),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        u.nama,
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(u.isOnlineNow ? 'Online' : _roleDisplay(u.role)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: () {
        Navigator.pushReplacement(
          context,
          SmoothPageRoute(
            builder: (_) => ChatRoomPage(
              recipientId: u.id,
              recipientName: u.nama,
              recipientRole: u.role,
            ),
          ),
        );
      },
    );
  }

  static String _roleDisplay(String role) {
    switch (role) {
      case 'administrator':
      case 'superadmin':
      case 'admin':
        return 'Administrator';
      case 'organization_admin':
      case 'admin_organisasi':
      case 'organisasi':
        return 'Admin Organisasi';
      case 'admin_eskul':
      case 'eskul':
        return 'Admin Eskul';
      case 'pembina_organisasi':
        return 'Pembina Organisasi';
      case 'pembina_eskul':
        return 'Pembina Eskul';
      default:
        return role;
    }
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
