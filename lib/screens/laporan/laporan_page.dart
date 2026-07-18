import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../widgets/animated_stats.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/character_dialog.dart';

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> with SingleTickerProviderStateMixin {
  String? _selectedOrgId;
  late TabController _tabC;
  Map<String, int> _summary = {};
  int _balance = 0;
  int _totalIncome = 0;
  int _totalExpense = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabC = TabController(length: 2, vsync: this);
    context.read<OrganizationProvider>().loadOrgs();
  }

  @override
  void dispose() {
    _tabC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_selectedOrgId == null) return;
    setState(() => _loading = true);
    try {
      _summary = await FirestoreService.getAttendanceSummary(_selectedOrgId!);
      _balance = await FirestoreService.getCashBalance(_selectedOrgId!);
      final tx = await FirestoreService.getCashTransactions(_selectedOrgId!);
      _totalIncome = tx.fold(0, (sum, t) => sum + t.amount);
      final ex = await FirestoreService.getExpenses(_selectedOrgId!);
      _totalExpense = ex.fold(0, (sum, e) => sum + e.nominal);
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) await AppDialogs.showError(context, 'Gagal memuat laporan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgs = context.watch<OrganizationProvider>().orgs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Statistik'),
        bottom: TabBar(
          controller: _tabC,
          tabs: const [Tab(text: 'Absensi'), Tab(text: 'Keuangan')],
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppDropdown<String>(
          label: 'Organisasi',
          icon: Icons.business_outlined,
          value: _selectedOrgId,
          items: orgs.map((o) => AppDropdownItem(value: o.id, label: o.nama)).toList(),
          onChanged: (v) { setState(() => _selectedOrgId = v); _load(); },
        ),
        const SizedBox(height: 16),
        if (_loading) const Center(child: CircularProgressIndicator())
        else SizedBox(
          height: 400,
          child: TabBarView(
            controller: _tabC,
            children: [
              _attendanceReport(),
              _cashReport(),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _attendanceReport() {
    final total = _summary.values.fold(0, (sum, v) => sum + v);
    final hadir = _summary['hadir'] ?? 0;
    final tidakHadir = _summary['tidak_hadir'] ?? 0;
    final izin = _summary['izin'] ?? 0;
    final sakit = _summary['sakit'] ?? 0;
    final kasSaja = _summary['kas_saja'] ?? 0;
    return Column(children: [
      if (total > 0) ...[
        SizedBox(
          height: 200,
          // Animasikan segmen donut menggambar dari 0 → nilai penuh.
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, t, __) => PieChart(PieChartData(
              sections: [
                PieChartSectionData(value: hadir.toDouble() * t, color: AppColors.hadir, title: 'Hadir\n', titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
                PieChartSectionData(value: tidakHadir.toDouble() * t, color: AppColors.tidakHadir, title: 'Tidak\n', titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
                PieChartSectionData(value: izin.toDouble() * t, color: AppColors.izin, title: 'Izin\n', titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
                PieChartSectionData(value: sakit.toDouble() * t, color: AppColors.sakit, title: 'Sakit\n', titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
                PieChartSectionData(value: kasSaja.toDouble() * t, color: AppColors.kasSaja, title: 'Kas\n', titleStyle: const TextStyle(fontSize: 10, color: Colors.white)),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            )),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Total: ', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            AnimatedCountText(
              value: total,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            Text(' anggota', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ],
        ),
      ] else
        Center(child: Text('Belum ada data absensi', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary))),
    ]);
  }

  Widget _cashReport() {
    return Column(children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _cashStat('Pemasukan', _totalIncome, AppColors.success),
        _cashStat('Pengeluaran', _totalExpense, AppColors.danger),
        _cashStat('Saldo', _balance, AppColors.primary),
      ]))),
      const SizedBox(height: 16),
      if (_totalIncome + _totalExpense > 0)
        SizedBox(
          height: 200,
          // Bar tumbuh dari bawah (0 → tinggi penuh) saat pertama tampil.
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, t, __) => BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (_totalIncome > _totalExpense ? _totalIncome : _totalExpense).toDouble() * 1.2,
              barGroups: [
                BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: _totalIncome.toDouble() * t, color: AppColors.success, width: 24)]),
                BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: _totalExpense.toDouble() * t, color: AppColors.danger, width: 24)]),
              ],
              titlesData: FlTitlesData(show: true, bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                if (v == 0) return Text('Pemasukan', style: GoogleFonts.plusJakartaSans(fontSize: 10));
                if (v == 1) return Text('Pengeluaran', style: GoogleFonts.plusJakartaSans(fontSize: 10));
                return const Text('');
              }))),
            )),
          ),
        )
      else
        Center(child: Text('Belum ada transaksi', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary))),
    ]);
  }

  Widget _cashStat(String label, int amount, Color color) {
    return Column(children: [
      AnimatedCurrencyText(value: amount, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }
}
