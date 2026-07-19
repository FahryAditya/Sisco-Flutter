import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/organization_provider.dart';
import '../../providers/cash_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/character_dialog.dart';

class PengeluaranPage extends StatefulWidget {
  const PengeluaranPage({super.key});

  @override
  State<PengeluaranPage> createState() => _PengeluaranPageState();
}

class _PengeluaranPageState extends State<PengeluaranPage> {
  String? _selectedOrgId;

  @override
  void initState() {
    super.initState();
    context.read<OrganizationProvider>().loadOrgs();
  }

  Future<void> _delete(String id) async {
    final confirm = await AppDialogs.showConfirm(context, message: 'Hapus pengeluaran?', confirmLabel: 'Hapus', danger: true);
    if (confirm == true) {
      if (!mounted) return;
      AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
      try {
        await FirestoreService.deleteExpense(id);
        if (mounted) AppDialogs.hide(context);
        if (mounted) await AppDialogs.showSuccess(context, 'Pengeluaran dihapus');
      } catch (e) {
        if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal menghapus pengeluaran: $e'); }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgs = context.watch<OrganizationProvider>().orgs;
    final cash = context.watch<CashProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pengeluaran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppDropdown<String>(
            label: 'Organisasi',
            icon: Icons.business_outlined,
            value: _selectedOrgId,
            items: orgs.map((o) => AppDropdownItem(value: o.id, label: o.nama)).toList(),
            onChanged: (v) {
              setState(() => _selectedOrgId = v);
              if (v == null) {
                context.read<CashProvider>().clear();
              } else {
                context.read<CashProvider>().subscribe(v);
              }
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEF4444)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saldo Kas', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                    cash.loading
                        ? 'Memuat...'
                        : Formatters.formatCurrency(cash.balance),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Riwayat Pengeluaran',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (cash.expenses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Belum ada pengeluaran',
                    style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
              ),
            )
          else
            ...cash.expenses.map((ex) => Card(
                  child: ListTile(
                    title: Text(ex.keterangan),
                    subtitle: Text(Formatters.formatDate(ex.tanggal)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '-${Formatters.formatCurrency(ex.nominal)}',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                          onPressed: () => _delete(ex.id),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
