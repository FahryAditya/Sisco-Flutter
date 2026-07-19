import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
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
            ...cash.expenses.map((ex) {
              final String keperluan = ex.keterangan;
              final String dayDate = DateFormat('EEEE, dd MMMM', 'id').format(ex.tanggal);
              final String timeStr = DateFormat('HH:mm').format(ex.tanggal);
              final String yearStr = DateFormat('yyyy').format(ex.tanggal);
              final String nominalStr = Formatters.formatCurrency(ex.nominal);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'PENGELUARAN',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                                onPressed: () => _delete(ex.id),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          Text(
                            '-$nominalStr',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      _buildInfoRow('Nama Keperluan', keperluan),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: _buildInfoRow('Tanggal Hari', dayDate)),
                          Expanded(child: _buildInfoRow('Jam', timeStr)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: _buildInfoRow('Tahun', yearStr)),
                          Expanded(child: _buildInfoRow('Nominal', nominalStr)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
