import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/organization_provider.dart';
import '../../providers/cash_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/member.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_dropdown.dart';


class KasPage extends StatefulWidget {
  const KasPage({super.key});

  @override
  State<KasPage> createState() => _KasPageState();
}

class _KasPageState extends State<KasPage> {
  String? _selectedOrgId;

  @override
  void initState() {
    super.initState();
    context.read<OrganizationProvider>().loadOrgs();
  }

  void _showSetorDialog() async {
    if (_selectedOrgId == null) return;
    final members = await FirestoreService.getMembers(_selectedOrgId!);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SetorKasSheet(
        orgId: _selectedOrgId!,
        members: members,
      ),
    );
  }

  void _showTarikDialog() async {
    if (_selectedOrgId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _TarikKasSheet(
        orgId: _selectedOrgId!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgs = context.watch<OrganizationProvider>().orgs;
    final cashState = context.watch<CashProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Kas')),
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

          // Saldo Card
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text('Saldo Kas', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    cashState.loading
                        ? 'Memuat...'
                        : Formatters.formatCurrency(cashState.balance),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showSetorDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Setor'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withAlpha(30),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _showTarikDialog,
                        icon: const Icon(Icons.remove, size: 18),
                        label: const Text('Tarik'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withAlpha(30),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Transactions
          Text(
            'Riwayat Transaksi',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (cashState.transactions.isEmpty && cashState.expenses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Belum ada transaksi',
                    style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
              ),
            )
          else ...[
            ...cashState.transactions.map((tx) => ListTile(
                  title: Text(tx.description),
                  subtitle: Text(Formatters.formatDateTime(tx.createdAt)),
                  trailing: Text(
                    '+${Formatters.formatCurrency(tx.amount)}',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )),
            ...cashState.expenses.map((ex) => ListTile(
                  title: Text(ex.keterangan),
                  subtitle: Text(Formatters.formatDateTime(ex.tanggal)),
                  trailing: Text(
                    '-${Formatters.formatCurrency(ex.nominal)}',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// Setor Kas Sheet
class _SetorKasSheet extends StatefulWidget {
  final String orgId;
  final List<Member> members;

  const _SetorKasSheet({
    required this.orgId,
    required this.members,
  });

  @override
  State<_SetorKasSheet> createState() => _SetorKasSheetState();
}

class _SetorKasSheetState extends State<_SetorKasSheet> {
  Member? _selectedMember;
  final _amountC = TextEditingController();
  final _descC = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amountC.dispose();
    _descC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedMember == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih anggota terlebih dahulu')));
      return;
    }
    final amount = int.tryParse(_amountC.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (amount == null || amount <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jumlah tidak valid')));
      return;
    }

    setState(() => _saving = true);
    try {
      final user = context.read<AuthProvider>().user;
      await FirestoreService.createCashTransaction({
        'organizationId': widget.orgId,
        'memberId': _selectedMember!.id,
        'amount': amount,
        'description': _descC.text.trim().isEmpty ? 'Setor kas' : _descC.text.trim(),
      });
      await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'CREATE', tabel: 'cash_transactions', deskripsi: 'Setor kas ${_selectedMember!.name}: $amount');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Setor kas berhasil')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyetor kas: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Setor Kas', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          AppDropdown<Member>(
            label: 'Anggota',
            icon: Icons.person_outline,
            value: _selectedMember,
            items: widget.members.map((m) => AppDropdownItem(value: m, label: m.name)).toList(),
            onChanged: (v) => setState(() => _selectedMember = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descC,
            decoration: const InputDecoration(labelText: 'Keterangan (opsional)'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

// Tarik Kas Sheet
class _TarikKasSheet extends StatefulWidget {
  final String orgId;

  const _TarikKasSheet({required this.orgId});

  @override
  State<_TarikKasSheet> createState() => _TarikKasSheetState();
}

class _TarikKasSheetState extends State<_TarikKasSheet> {
  final _amountC = TextEditingController();
  final _descC = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amountC.dispose();
    _descC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountC.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (amount == null || amount <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jumlah tidak valid')));
      return;
    }

    setState(() => _saving = true);
    try {
      final user = context.read<AuthProvider>().user;
      await FirestoreService.createExpense({
        'organizationId': widget.orgId,
        'nominal': amount,
        'keterangan': _descC.text.trim(),
        'tanggal': FieldValue.serverTimestamp(),
        'createdBy': user?.id ?? '',
      });
      await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'CREATE', tabel: 'cash_expenses', deskripsi: 'Tarik kas: $amount untuk ${_descC.text.trim()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarik kas berhasil')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menarik kas: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tarik Kas', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _amountC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descC,
            decoration: const InputDecoration(labelText: 'Keterangan'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

