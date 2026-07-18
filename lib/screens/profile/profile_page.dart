import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(appBar: AppBar(title: const Text('Profile')), body: ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: Column(children: [
        CircleAvatar(radius: 50, backgroundColor: AppColors.primary.withAlpha(40), child: Icon(Icons.person, size: 50, color: AppColors.primary)),
        const SizedBox(height: 16),
        Text(user?.nama ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(user?.email ?? '', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Chip(label: Text(user?.roleDisplay ?? '')),
      ])),
      const SizedBox(height: 32),
      Card(child: ListTile(leading: Icon(Icons.logout, color: AppColors.danger), title: const Text('Keluar'), onTap: () async {
        final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
          title: const Text('Keluar'), content: const Text('Yakin ingin keluar?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Keluar')),
          ],
        ));
          if (ok == true && context.mounted) {
            context.read<OrganizationProvider>().clear();
            context.read<AuthProvider>().logout();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil keluar')));
        }
      })),
    ]));
  }
}
