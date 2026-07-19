import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/member.dart';
import '../../models/organization.dart';
import '../../providers/auth_provider.dart';
import '../../providers/organization_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/kelas_helper.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/empty_state.dart';

class AnggotaPage extends StatefulWidget {
  const AnggotaPage({super.key});

  @override
  State<AnggotaPage> createState() => _AnggotaPageState();
}

class _AnggotaPageState extends State<AnggotaPage> {
  String? _selectedOrgId;
  List<Member> _members = [];
  bool _loading = false;
  StreamSubscription<List<Member>>? _membersSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final orgProvider = context.read<OrganizationProvider>();
      await orgProvider.loadOrgs();
      if (!mounted || _selectedOrgId != null || orgProvider.orgs.isEmpty) {
        return;
      }
      _selectOrg(orgProvider.orgs.first.id);
    });
  }

  @override
  void dispose() {
    _membersSub?.cancel();
    super.dispose();
  }

  void _selectOrg(String? orgId) {
    _membersSub?.cancel();
    setState(() {
      _selectedOrgId = orgId;
      _members = [];
      _loading = orgId != null;
    });
    if (orgId == null) return;

    _membersSub = FirestoreService.membersStream(orgId).listen((list) {
      if (!mounted || _selectedOrgId != orgId) return;
      setState(() {
        _members = list;
        _loading = false;
      });
    }, onError: (e) {
      if (!mounted || _selectedOrgId != orgId) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat anggota: $e')),
      );
    });
  }

  Future<void> _showMemberForm({Member? member}) async {
    final orgs = context.read<OrganizationProvider>().orgs;
    if (orgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada organisasi yang bisa dikelola')),
      );
      return;
    }

    final result = await showModalBottomSheet<_MemberFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MemberFormSheet(
        member: member,
        initialOrgId: member?.organizationId ?? _selectedOrgId ?? orgs.first.id,
        orgs: orgs,
      ),
    );
    if (result == null) return;

    try {
      final user = context.read<AuthProvider>().user;
      final data = <String, dynamic>{
        'organizationId': result.orgId,
        'name': result.nama,
        'kelas': result.kelas,
        'nis': result.nis,
        'email': result.email,
        'jabatan': result.jabatan,
        'status': member?.status ?? 'ACTIVE',
      };

      if (member == null) {
        data.addAll({
          'level': 1,
          'exp': 0,
          'progress': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        final id = await FirestoreService.createMember(data);
        await FirestoreService.logAction(
          userId: user?.id ?? '',
          userNama: user?.nama ?? '',
          aksi: 'CREATE',
          tabel: 'members',
          recordId: id,
          deskripsi: 'Menambah anggota ${result.nama}',
        );
      } else {
        await FirestoreService.updateMember(member.id, data);
        await FirestoreService.logAction(
          userId: user?.id ?? '',
          userNama: user?.nama ?? '',
          aksi: 'UPDATE',
          tabel: 'members',
          recordId: member.id,
          deskripsi: 'Memperbarui anggota ${result.nama}',
        );
      }

      if (mounted && _selectedOrgId != result.orgId) _selectOrg(result.orgId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              member == null
                  ? 'Anggota berhasil ditambahkan'
                  : 'Anggota berhasil diperbarui',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan anggota: $e')),
        );
      }
    }
  }

  Future<void> _deleteMember(Member member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Anggota'),
        content: Text('Hapus ${member.name} dari daftar anggota?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final user = context.read<AuthProvider>().user;
      await FirestoreService.deleteMember(member.id);
      await FirestoreService.logAction(
        userId: user?.id ?? '',
        userNama: user?.nama ?? '',
        aksi: 'DELETE',
        tabel: 'members',
        recordId: member.id,
        deskripsi: 'Menghapus anggota ${member.name}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anggota berhasil dihapus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus anggota: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final orgs = context.watch<OrganizationProvider>().orgs;

    if (!(user?.canManageMembers ?? false)) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.lock_outline,
          message: 'Akses ditolak',
          subtitle: 'Anda tidak memiliki akses mengelola anggota',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Anggota')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppDropdown<String>(
              label: 'Organisasi / Eskul',
              icon: Icons.business_outlined,
              value: _selectedOrgId,
              items: orgs
                  .map((o) => AppDropdownItem(value: o.id, label: o.nama))
                  .toList(),
              onChanged: _selectOrg,
            ),
          ),
          Expanded(child: _buildBody(orgs.isEmpty)),
        ],
      ),
      floatingActionButton: orgs.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showMemberForm(),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Tambah'),
            ),
    );
  }

  Widget _buildBody(bool noOrgs) {
    if (noOrgs) {
      return const EmptyState(
        icon: Icons.business_outlined,
        message: 'Belum ada organisasi',
        subtitle: 'Administrator perlu menugaskan organisasi/eskul terlebih dahulu',
      );
    }
    if (_selectedOrgId == null) {
      return const EmptyState(
        icon: Icons.people_outline,
        message: 'Pilih organisasi',
        subtitle: 'Pilih organisasi/eskul untuk mengelola anggotanya',
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_members.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        message: 'Belum ada anggota',
        subtitle: 'Tekan Tambah untuk membuat anggota baru',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: _members.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_members.length} anggota',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        final member = _members[i - 1];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withAlpha(30),
              child: Text(
                member.name.isEmpty ? '?' : member.name[0].toUpperCase(),
                style: TextStyle(color: AppColors.primary),
              ),
            ),
            title: Text(member.name),
            subtitle: Text(
              [
                member.kelas,
                member.nis,
                member.email,
                member.jabatan,
              ].whereType<String>().where((e) => e.trim().isNotEmpty).join(' - '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: () => _showMemberForm(member: member),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.danger,
                  tooltip: 'Hapus',
                  onPressed: () => _deleteMember(member),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MemberFormResult {
  const _MemberFormResult({
    required this.orgId,
    required this.nama,
    required this.kelas,
    this.nis,
    this.email,
    required this.jabatan,
  });

  final String orgId;
  final String nama;
  final String kelas;
  final String? nis;
  final String? email;
  final String jabatan;
}

class _MemberFormSheet extends StatefulWidget {
  const _MemberFormSheet({
    required this.orgs,
    required this.initialOrgId,
    this.member,
  });

  final List<Organization> orgs;
  final String initialOrgId;
  final Member? member;

  @override
  State<_MemberFormSheet> createState() => _MemberFormSheetState();
}

class _MemberFormSheetState extends State<_MemberFormSheet> {
  late String? _orgId;
  late final TextEditingController _namaC;
  late final TextEditingController _kelasC;
  late final TextEditingController _nisC;
  late final TextEditingController _emailC;
  late final TextEditingController _jabatanC;
  String? _kelasError;

  @override
  void initState() {
    super.initState();
    _orgId = widget.initialOrgId;
    final m = widget.member;
    _namaC = TextEditingController(text: m?.name ?? '');
    _kelasC = TextEditingController(text: m?.kelas ?? '');
    _nisC = TextEditingController(text: m?.nis ?? '');
    _emailC = TextEditingController(text: m?.email ?? '');
    _jabatanC = TextEditingController(text: m?.jabatan ?? 'Anggota');
  }

  @override
  void dispose() {
    _namaC.dispose();
    _kelasC.dispose();
    _nisC.dispose();
    _emailC.dispose();
    _jabatanC.dispose();
    super.dispose();
  }

  void _submit() {
    final nama = _namaC.text.trim();
    final kelasRaw = _kelasC.text.trim();
    final normalizedKelas = KelasHelper.normalize(kelasRaw);

    if (_orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organisasi wajib dipilih')),
      );
      return;
    }
    if (nama.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama minimal 3 karakter')),
      );
      return;
    }
    if (normalizedKelas == null) {
      final saran = KelasHelper.suggest(kelasRaw);
      setState(() {
        _kelasError = saran == null
            ? 'Kelas tidak valid. Contoh: ${KelasHelper.contohKelas}'
            : 'Kelas tidak valid. Saran: $saran';
      });
      return;
    }

    Navigator.pop(
      context,
      _MemberFormResult(
        orgId: _orgId!,
        nama: nama,
        kelas: normalizedKelas,
        nis: _nullIfEmpty(_nisC.text),
        email: _nullIfEmpty(_emailC.text),
        jabatan: _nullIfEmpty(_jabatanC.text) ?? 'Anggota',
      ),
    );
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.member == null ? 'Tambah Anggota' : 'Edit Anggota',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppDropdown<String>(
              label: 'Organisasi / Eskul',
              icon: Icons.business_outlined,
              value: _orgId,
              items: widget.orgs
                  .map((o) => AppDropdownItem<String>(
                        value: o.id,
                        label: o.nama,
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _orgId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _namaC,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kelasC,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Kelas',
                helperText: 'Contoh: X AKL, XI AKL, XII AKL',
                errorText: _kelasError,
              ),
              onChanged: (_) {
                if (_kelasError != null) setState(() => _kelasError = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nisC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'NIS (Opsional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailC,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (Opsional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _jabatanC,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Jabatan (Opsional)'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
