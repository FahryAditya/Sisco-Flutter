import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/member.dart';
import '../../models/organization.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/directory_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/exp_helper.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/character_dialog.dart';
import '../kas/kas_page.dart';
import '../materi/materi_page.dart';
import '../export/export_page.dart';
import '../import/import_page.dart';
import '../backup/backup_page.dart';
import '../registration/approval_page.dart';
import '../quest/quest_activation.dart';

const _roles = ['administrator', 'admin_organisasi', 'admin_eskul', 'pembina_organisasi', 'pembina_eskul', 'siswa'];
const _statuses = ['aktif', 'tidak'];
const _orgCategories = ['OSIS', 'MPK', 'Eskul', 'Organisasi'];
const _attendanceStatuses = ['Hadir', 'Izin', 'Sakit', 'Alfa'];
const _cashTypes = ['Pemasukan', 'Pengeluaran'];
const _cashCategories = [
  'Iuran',
  'Donasi',
  'Operasional',
  'Kegiatan',
  'Lainnya',
];
const _docCategories = [
  'Kegiatan',
  'Rapat',
  'Prestasi',
  'Dokumentasi',
  'Lainnya',
];
const _announcementTypes = ['info', 'warning', 'penting'];
const _grades = ['X', 'XI', 'XII'];
const _majors = ['PPLG', 'DKV', 'AKL', 'TJKT', 'MPLB', 'AKC', 'TLM', 'FARMASI'];
final _classes = _grades.expand((g) => _majors.expand((m) => [for (var i = 1; i <= 4; i++) '$g $m $i'])).toList();
const _positions = [
  'Ketua',
  'Wakil',
  'Sekretaris',
  'Bendahara',
  'Koordinator',
  'Anggota',
];

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<UserModel> _users = [];
  List<Organization> _orgs = [];
  List<Member> _members = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    try {
      // Satu query menggantikan N (satu per organisasi). Menghemat ratusan
      // Firestore reads untuk instalasi dengan banyak organisasi/eskul.
      final results = await Future.wait([
        FirestoreService.getUsers(),
        FirestoreService.getOrganizations(forceRefresh: forceRefresh),
        FirestoreService.getAllMembers(forceRefresh: forceRefresh),
      ]);
      _users = results[0] as List<UserModel>;
      _orgs = results[1] as List<Organization>;
      _members = results[2] as List<Member>;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() => _load(forceRefresh: true);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administrator')),
        body: Center(
          child: Text(
            'Akses khusus Administrator',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Administrator'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _summary(),
                  const SizedBox(height: 16),
                  ..._features.map(_featureCard),
                  const SizedBox(height: 24),
                  _recentUsers(),
                ],
              ),
            ),
    );
  }

  Widget _summary() {
    return Row(
      children: [
        Expanded(
          child: _metric('User', _users.length.toString(), Icons.people),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metric('Organisasi', _orgs.length.toString(), Icons.business),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metric('Anggota', _members.length.toString(), Icons.groups),
        ),
      ],
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
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
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureCard(_AdminFeature feature) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(28),
          child: Icon(feature.icon, color: AppColors.primary),
        ),
        title: Text(
          feature.title,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          feature.fields,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: feature.onTap,
      ),
    );
  }

  Widget _recentUsers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Terbaru',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ..._users
            .take(5)
            .map(
              (u) => Card(
                child: ListTile(
                  title: Text(u.nama),
                  subtitle: Text('${u.email} - ${u.roleDisplay}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.key),
                        tooltip: 'Lihat Password',
                        onPressed: () => _showStoredPasswordDialog(u),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit',
                        onPressed: () => _showUserForm(user: u),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  List<_AdminFeature> get _features => [
    _AdminFeature(
      'Airlangga QR Quest',
      'Aktifkan fitur, pilih pemegang akses & organisasi peserta',
      Icons.qr_code_2,
      () => QuestActivation.show(context),
    ),
    _AdminFeature(
      'Tambah/Edit User',
      'Nama, email, password, role, status',
      Icons.person_add,
      () => _showUserForm(),
    ),
    _AdminFeature(
      'Kelola User & Password',
      'Lihat semua user, lihat password, edit',
      Icons.manage_accounts,
      _showUserManager,
    ),
    _AdminFeature(
      'Tambah/Edit Organisasi',
      'Nama, slug, kategori, deskripsi, logo, status',
      Icons.add_business,
      () => _showOrganizationForm(),
    ),
    _AdminFeature(
      'Tambah/Edit Anggota',
      'NIS/NIP, nama, kelas, jabatan, status',
      Icons.group_add,
      () => _showMemberForm(),
    ),
    _AdminFeature(
      'Absensi per Organisasi',
      'Tanggal dan status per anggota',
      Icons.fact_check,
      _showBulkAttendanceForm,
    ),
    _AdminFeature(
      'Tambah Transaksi Kas',
      'Tanggal, jenis, jumlah, keterangan, kategori',
      Icons.account_balance_wallet,
      _showCashTransactionForm,
    ),
    _AdminFeature(
      'Tambah Pengeluaran',
      'Tanggal, jumlah, kategori, keterangan, bukti',
      Icons.receipt_long,
      _showExpenseForm,
    ),
    _AdminFeature(
      'Kirim Email',
      'Penerima, subjek, pesan, lampiran',
      Icons.mail,
      _showEmailForm,
    ),
    _AdminFeature(
      'Atur EXP Anggota',
      'Anggota, jumlah EXP, alasan',
      Icons.trending_up,
      _showExpForm,
    ),
    _AdminFeature(
      'Tambah Dokumentasi',
      'Judul, deskripsi, foto, kategori, organisasi',
      Icons.photo_library,
      _showDocumentationForm,
    ),
    _AdminFeature(
      'Import Anggota via Excel',
      'File Excel dan organisasi tujuan',
      Icons.upload_file,
      _showImportMembersForm,
    ),
    _AdminFeature(
      'Update Sistem / Pengumuman',
      'Judul, konten, tipe',
      Icons.campaign,
      _showAnnouncementForm,
    ),
    _AdminFeature(
      'Pengaturan Organisasi',
      'Nama, slug, deskripsi, logo, status',
      Icons.settings,
      _showOrganizationSettingsForm,
    ),
    _AdminFeature('Login', 'Email dan password', Icons.login, _showLoginInfo),
    _AdminFeature(
      'Persetujuan Pendaftaran',
      'Terima/tolak pendaftaran anggota baru',
      Icons.approval,
      () => _push(const ApprovalPage()),
    ),
    _AdminFeature(
      'Data Siswa',
      'NIS, nama, kelas, jurusan, poin EXP',
      Icons.school,
      _showStudentForm,
    ),
    _AdminFeature(
      'Materi Kegiatan',
      'Judul, deskripsi, lokasi, notulen',
      Icons.menu_book,
      () => _push(const MateriPage()),
    ),
    _AdminFeature(
      'Kas (Setor/Tarik)',
      'Setor: anggota, jumlah. Tarik: jumlah',
      Icons.account_balance_wallet,
      () => _push(const KasPage()),
    ),
    _AdminFeature(
      'Export Data',
      'Anggota, absensi, kas ke CSV',
      Icons.file_download,
      () => _push(const ExportPage()),
    ),
    _AdminFeature(
      'Import Data Anggota',
      'Excel/CSV dengan preview table',
      Icons.file_upload,
      () => _push(const ImportPage()),
    ),
    _AdminFeature(
      'Backup Data',
      'Anggota, foto, EXP, absensi, kas, penghargaan ke JSON',
      Icons.backup,
      () => _push(const BackupPage()),
    ),
  ];

  Future<void> _showUserForm({UserModel? user}) async {
    final namaC = TextEditingController(text: user?.nama ?? '');
    final emailC = TextEditingController(text: user?.email ?? '');
    final passC = TextEditingController();
    var role = _roles.contains(user?.role) ? user!.role : 'admin';
    var status = user?.status ?? 'aktif';
    var obscurePassword = true;
    final assignedOrgIds = <String>{...?user?.orgIds};
    final saved = await _dialog(
      title: user == null ? 'Tambah User' : 'Edit User',
      successMessage: user == null ? 'User berhasil ditambahkan' : 'User berhasil diperbarui',
      builder: (setDialogState) => [
        _text(namaC, 'Nama'),
        _text(
          emailC,
          'Email',
          keyboardType: TextInputType.emailAddress,
          enabled: user == null,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: passC,
            obscureText: obscurePassword,
            maxLines: 1,
            decoration: InputDecoration(
              labelText: user == null ? 'Password' : 'Password baru',
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
              ),
            ),
          ),
        ),
        _select('Role', role, _roles, (v) => setDialogState(() => role = v)),
        _select(
          'Status',
          status,
          _statuses,
          (v) => setDialogState(() => status = v),
        ),
        if (_needsAssignment(role)) _assignOrgsTile(assignedOrgIds, setDialogState),
      ],
      onSave: () async {
        if (namaC.text.trim().isEmpty || emailC.text.trim().isEmpty) {
          throw Exception('Nama dan email wajib diisi');
        }
        if (_needsAssignment(role) && assignedOrgIds.isEmpty) {
          throw Exception('Tugaskan minimal satu organisasi/eskul untuk role ini');
        }
        if (user == null) {
          if (passC.text.length < 6) {
            throw Exception('Password minimal 6 karakter');
          }
          final taken = await FirestoreService.isEmailTaken(emailC.text.trim());
          if (taken) throw Exception('Email sudah digunakan');
          final id = await AuthService.createUserByAdmin(
            nama: namaC.text.trim(),
            email: emailC.text.trim(),
            password: passC.text,
            role: role,
            orgIds: assignedOrgIds.toList(),
          );
          await FirestoreService.updateUser(id, {'status': status});
          // Cerminkan ke buku alamat chat agar user baru langsung bisa dihubungi.
          await DirectoryService.upsertEntry(
            uid: id,
            nama: namaC.text.trim(),
            role: role,
          );
        } else {
          await FirestoreService.updateUser(user.id, {
            'nama': namaC.text.trim(),
            'role': role,
            'status': status,
            'orgIds': assignedOrgIds.toList(),
          });
          // Sinkronkan perubahan nama/role ke buku alamat chat.
          await DirectoryService.upsertEntry(
            uid: user.id,
            nama: namaC.text.trim(),
            role: role,
          );
          if (passC.text.isNotEmpty) {
            try {
              await AuthService.sendPasswordResetEmail(user.email);
              await FirestoreService.updateUser(user.id, {
                'passwordResetRequested': true,
              });
            } catch (e) {
              throw Exception('Gagal mengirim email reset password: $e');
            }
          }
        }
      },
      onDelete: user == null
          ? null
          : () async {
              final current = context.read<AuthProvider>().user;
              if (current != null && current.id == user.id) {
                throw Exception('Anda tidak bisa menghapus akun Anda sendiri');
              }
              await FirestoreService.deleteUser(user.id, email: user.email);
              await DirectoryService.remove(user.id);
              await FirestoreService.logAction(
                userId: current?.id ?? '',
                userNama: current?.nama ?? '',
                aksi: 'DELETE',
                tabel: 'users',
                recordId: user.id,
                deskripsi: 'Menghapus user: ${user.nama} (${user.email}, ${user.roleDisplay})',
              );
            },
      deleteMessage:
          'Hapus user "${user?.nama}" (${user?.roleDisplay})?\n\nData user akan dihapus dari database. Catatan: akun login (Firebase Auth) mungkin masih ada dan perlu dihapus manual dari Firebase Console.',
    );
    if (saved && user == null && mounted) {
      _showCredentialDialog(
        nama: namaC.text.trim(),
        email: emailC.text.trim(),
        password: passC.text,
      );
    }
  }

  Future<void> _showOrganizationForm({Organization? org}) async {
    final namaC = TextEditingController(text: org?.nama ?? '');
    final slugC = TextEditingController(text: org?.slug ?? '');
    final descC = TextEditingController(text: org?.deskripsi ?? '');
    var category = _orgCategories.contains(org?.category)
        ? org!.category
        : 'Eskul';
    var active = (org?.status.toLowerCase() ?? 'aktif') == 'aktif';
    PlatformFile? logo;
    await _dialog(
      title: org == null ? 'Tambah Organisasi' : 'Edit Organisasi',
      successMessage: org == null ? 'Organisasi berhasil ditambahkan' : 'Organisasi berhasil diperbarui',
      builder: (setDialogState) => [
        _text(namaC, 'Nama'),
        _text(slugC, 'Slug'),
        _select(
          'Kategori',
          category,
          _orgCategories,
          (v) => setDialogState(() => category = v),
        ),
        _text(descC, 'Deskripsi', maxLines: 3),
        _fileTile(
          'Logo',
          logo,
          () async {
            final picked = await _pickFile(FileType.image);
            setDialogState(() => logo = picked);
          },
        ),
        SwitchListTile(
          value: active,
          title: const Text('Status aktif'),
          onChanged: (v) => setDialogState(() => active = v),
        ),
      ],
      onSave: () async {
        if (namaC.text.trim().isEmpty) {
          throw Exception('Nama organisasi wajib diisi');
        }
        final slug = slugC.text.trim().isEmpty
            ? _slugify(namaC.text)
            : slugC.text.trim();
        final logoUrl = logo == null
            ? null
            : await CloudinaryService.uploadBytes(
                logo!.bytes!, logo!.name);
        final data = <String, dynamic>{
          'nama': namaC.text.trim(),
          'slug': slug,
          'category': category,
          'deskripsi': descC.text.trim(),
          'status': active ? 'aktif' : 'tidak',
          'logoUrl': logoUrl,
        };
        if (org == null) {
          await FirestoreService.createOrganization(data);
        } else {
          await FirestoreService.updateOrganization(org.id, data);
        }
      },
      onDelete: org == null
          ? null
          : () async {
              final user = context.read<AuthProvider>().user;
              await FirestoreService.deleteOrganization(org.id);
              await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'DELETE', tabel: 'organizations', recordId: org.id, deskripsi: 'Menghapus organisasi: ${org.nama}');
            },
      deleteMessage: 'Hapus organisasi "${org?.nama}"? Semua data terkait akan dihapus.',
    );
  }

  Future<void> _showMemberForm({Member? member}) async {
    var orgId =
        member?.organizationId ?? (_orgs.isNotEmpty ? _orgs.first.id : null);
    final nisC = TextEditingController(text: member?.nis ?? '');
    final namaC = TextEditingController(text: member?.name ?? '');
    var kelas = member?.kelas ?? _classes.first;
    var jabatan = member?.jabatan ?? 'Anggota';
    var status = (member?.status.toLowerCase() == 'tidak') ? 'tidak' : 'aktif';
    await _dialog(
      title: member == null ? 'Tambah Anggota' : 'Edit Anggota',
      successMessage: member == null ? 'Anggota berhasil ditambahkan' : 'Anggota berhasil diperbarui',
      builder: (setDialogState) => [
        _orgSelect(orgId, (v) => setDialogState(() => orgId = v)),
        _text(nisC, 'NIS/NIP'),
        _text(namaC, 'Nama'),
        _select(
          'Kelas',
          kelas,
          _classes,
          (v) => setDialogState(() => kelas = v),
        ),
        _select(
          'Jabatan',
          jabatan,
          _positions,
          (v) => setDialogState(() => jabatan = v),
        ),
        _select(
          'Status',
          status,
          _statuses,
          (v) => setDialogState(() => status = v),
        ),
      ],
      onSave: () async {
        if (orgId == null) throw Exception('Organisasi wajib dipilih');
        if (namaC.text.trim().isEmpty) {
          throw Exception('Nama anggota wajib diisi');
        }
        final data = {
          'organizationId': orgId,
          'nis': nisC.text.trim(),
          'name': namaC.text.trim(),
          'kelas': kelas,
          'jabatan': jabatan,
          'status': status,
          'exp': member?.exp ?? 0,
          'level': member?.level ?? 1,
        };
        if (member == null) {
          await FirestoreService.createMember(data);
        } else {
          await FirestoreService.updateMember(member.id, data);
        }
      },
    );
  }

  Future<void> _showBulkAttendanceForm() async {
    var orgId = _orgs.isNotEmpty ? _orgs.first.id : null;
    var date = DateTime.now();
    var members = orgId == null
        ? <Member>[]
        : await FirestoreService.getMembers(orgId);
    final statuses = <String, String>{for (final m in members) m.id: 'Hadir'};
    await _dialog(
      title: 'Absensi per Organisasi',
      successMessage: 'Absensi berhasil disimpan untuk ${members.length} anggota',
      builder: (setDialogState) => [
        _orgSelect(orgId, (v) async {
          orgId = v;
          members = v == null
              ? <Member>[]
              : await FirestoreService.getMembers(v);
          statuses
            ..clear()
            ..addAll({for (final m in members) m.id: 'Hadir'});
          setDialogState(() {});
        }),
        _dateTile('Tanggal', date, () async {
          final picked = await _pickDate(date);
          if (picked != null) setDialogState(() => date = picked);
        }),
        ...members.map(
          (m) => _select(
            m.name,
            statuses[m.id] ?? 'Hadir',
            _attendanceStatuses,
            (v) => setDialogState(() => statuses[m.id] = v),
          ),
        ),
      ],
      onSave: () async {
        if (orgId == null) throw Exception('Organisasi wajib dipilih');
        for (final m in members) {
          await FirestoreService.upsertAttendance(
            {
              'organizationId': orgId,
              'memberId': m.id,
              'date': Timestamp.fromDate(date),
              'status': (statuses[m.id] ?? 'Hadir').toLowerCase(),
            },
            date,
            m.id,
          );
        }
      },
    );
  }

  Future<void> _showCashTransactionForm() async {
    var orgId = _orgs.isNotEmpty ? _orgs.first.id : null;
    var date = DateTime.now();
    var type = 'Pemasukan';
    var category = _cashCategories.first;
    final amountC = TextEditingController();
    final descC = TextEditingController();
    await _dialog(
      title: 'Tambah Transaksi Kas',
      successMessage: 'Transaksi kas berhasil ditambahkan',
      builder: (setDialogState) => [
        _orgSelect(orgId, (v) => setDialogState(() => orgId = v)),
        _dateTile('Tanggal', date, () async {
          final picked = await _pickDate(date);
          if (picked != null) setDialogState(() => date = picked);
        }),
        _select(
          'Jenis',
          type,
          _cashTypes,
          (v) => setDialogState(() => type = v),
        ),
        _text(amountC, 'Jumlah', keyboardType: TextInputType.number),
        _text(descC, 'Keterangan'),
        _select(
          'Kategori',
          category,
          _cashCategories,
          (v) => setDialogState(() => category = v),
        ),
      ],
      onSave: () async {
        if (orgId == null) throw Exception('Organisasi wajib dipilih');
        final amount = int.tryParse(amountC.text.replaceAll(RegExp(r'[^0-9]'), ''));
        if (amount == null || amount <= 0) {
          throw Exception('Jumlah harus berupa angka lebih dari 0');
        }
        await FirestoreService.createCashTransaction({
          'organizationId': orgId,
          'memberId': '',
          'amount': type == 'Pengeluaran' ? -amount : amount,
          'description': descC.text.trim(),
          'category': category,
          'type': type,
          'tanggal': Timestamp.fromDate(date),
        });
      },
    );
  }

  Future<void> _showExpenseForm() async {
    var orgId = _orgs.isNotEmpty ? _orgs.first.id : null;
    var date = DateTime.now();
    var category = _cashCategories.first;
    final amountC = TextEditingController();
    final descC = TextEditingController();
    PlatformFile? proof;
    await _dialog(
      title: 'Tambah Pengeluaran',
      successMessage: 'Pengeluaran berhasil dicatat',
      builder: (setDialogState) => [
        _orgSelect(orgId, (v) => setDialogState(() => orgId = v)),
        _dateTile('Tanggal', date, () async {
          final picked = await _pickDate(date);
          if (picked != null) setDialogState(() => date = picked);
        }),
        _text(amountC, 'Jumlah', keyboardType: TextInputType.number),
        _select(
          'Kategori',
          category,
          _cashCategories,
          (v) => setDialogState(() => category = v),
        ),
        _text(descC, 'Keterangan', maxLines: 3),
        _fileTile(
          'Bukti',
          proof,
          () async {
            final picked = await _pickFile(FileType.any);
            setDialogState(() => proof = picked);
          },
        ),
      ],
      onSave: () async {
        if (orgId == null) throw Exception('Organisasi wajib dipilih');
        final userId = context.read<AuthProvider>().user?.id ?? '';
        final nominal = int.tryParse(amountC.text.replaceAll(RegExp(r'[^0-9]'), ''));
        if (nominal == null || nominal <= 0) {
          throw Exception('Jumlah harus berupa angka lebih dari 0');
        }
        final proofUrl = proof == null
            ? null
            : await _uploadFile(proof!, 'expense_proofs');
        await FirestoreService.createExpense({
          'organizationId': orgId,
          'nominal': nominal,
          'kategori': category,
          'keterangan': descC.text.trim(),
          'tanggal': Timestamp.fromDate(date),
          'createdBy': userId,
          'buktiUrl': proofUrl,
        });
      },
    );
  }

  Future<void> _showEmailForm() async {
    var recipient = 'semua';
    final subjectC = TextEditingController();
    final messageC = TextEditingController();
    PlatformFile? attachment;
    await _dialog(
      title: 'Kirim Email',
      successMessage: 'Email berhasil dikirimkan',
      builder: (setDialogState) => [
        _select('Penerima', recipient, [
          'semua',
          'admin',
          'anggota',
          'siswa',
        ], (v) => setDialogState(() => recipient = v)),
        _text(subjectC, 'Subjek'),
        _text(messageC, 'Pesan', maxLines: 5),
        _fileTile(
          'Lampiran',
          attachment,
          () async {
            final picked = await _pickFile(FileType.any);
            setDialogState(() => attachment = picked);
          },
        ),
      ],
      onSave: () async {
        if (subjectC.text.trim().isEmpty) {
          throw Exception('Subjek email wajib diisi');
        }
        if (messageC.text.trim().isEmpty) {
          throw Exception('Pesan email wajib diisi');
        }
        final attachmentUrl = attachment == null
            ? null
            : await _uploadFile(attachment!, 'email_attachments');
        await FirestoreService.createEmailRequest({
          'recipient': recipient,
          'subject': subjectC.text.trim(),
          'message': messageC.text.trim(),
          'attachmentUrl': attachmentUrl,
          'status': 'pending',
        });
      },
    );
  }

  Future<void> _showExpForm() async {
    var memberId = _members.isNotEmpty ? _members.first.id : null;
    final expC = TextEditingController();
    final reasonC = TextEditingController();
    await _dialog(
      title: 'Atur EXP Anggota',
      successMessage: 'EXP anggota berhasil diperbarui',
      builder: (setDialogState) => [
        _memberSelect(memberId, (v) => setDialogState(() => memberId = v)),
        _text(expC, 'Jumlah EXP', keyboardType: TextInputType.number),
        _text(reasonC, 'Alasan', maxLines: 3),
      ],
      onSave: () async {
        final member = _memberById(memberId);
        if (member == null) throw Exception('Anggota wajib dipilih');
        final amount = int.tryParse(expC.text.replaceAll(RegExp(r'[^0-9]'), ''));
        if (amount == null || amount <= 0) {
          throw Exception('Jumlah EXP harus berupa angka lebih dari 0');
        }
        final result = ExpHelper.calculateLevelUp(
          member.exp,
          member.level,
          amount,
        );
        await FirestoreService.updateMemberExp(
          member.id,
          result.exp,
          result.level,
        );
        await FirestoreService.createExpLog({
          'memberId': member.id,
          'amount': amount,
          'reason': reasonC.text.trim(),
        });
      },
    );
  }

  Future<void> _showDocumentationForm() async {
    var orgId = _orgs.isNotEmpty ? _orgs.first.id : null;
    var category = _docCategories.first;
    final titleC = TextEditingController();
    final descC = TextEditingController();
    PlatformFile? photo;
    await _dialog(
      title: 'Tambah Dokumentasi',
      successMessage: 'Dokumentasi berhasil ditambahkan',
      builder: (setDialogState) => [
        _text(titleC, 'Judul'),
        _text(descC, 'Deskripsi', maxLines: 3),
        _fileTile(
          'Foto',
          photo,
          () async {
            final picked = await _pickFile(FileType.image);
            setDialogState(() => photo = picked);
          },
        ),
        _select(
          'Kategori',
          category,
          _docCategories,
          (v) => setDialogState(() => category = v),
        ),
        _orgSelect(orgId, (v) => setDialogState(() => orgId = v)),
      ],
      onSave: () async {
        if (orgId == null) throw Exception('Organisasi wajib dipilih');
        if (titleC.text.trim().isEmpty) {
          throw Exception('Judul dokumentasi wajib diisi');
        }
        final userId = context.read<AuthProvider>().user?.id ?? '';
        final photoUrl = photo == null
            ? null
            : await _uploadFile(photo!, 'documentation');
        await FirestoreService.createDocumentation({
          'title': titleC.text.trim(),
          'description': descC.text.trim(),
          'category': category,
          'organizationId': orgId,
          'createdBy': userId,
          'dateTaken': FieldValue.serverTimestamp(),
          'photos': photoUrl == null ? <String>[] : [photoUrl],
        });
      },
    );
  }

  Future<void> _showImportMembersForm() async {
    var orgId = _orgs.isNotEmpty ? _orgs.first.id : null;
    PlatformFile? excelFile;
    await _dialog(
      title: 'Import Anggota via Excel',
      successMessage: 'Anggota berhasil diimport dari Excel',
      builder: (setDialogState) => [
        _orgSelect(orgId, (v) => setDialogState(() => orgId = v)),
        _fileTile(
          'File Excel',
          excelFile,
          () async {
            final picked = await _pickFile(FileType.custom, ['xlsx', 'xls']);
            setDialogState(() => excelFile = picked);
          },
        ),
      ],
      onSave: () async {
        if (orgId == null || excelFile?.bytes == null) {
          throw Exception('File Excel dan organisasi wajib diisi');
        }
        final excel = Excel.decodeBytes(excelFile!.bytes!);
        if (excel.tables.isEmpty) throw Exception('File Excel kosong');
        final sheet = excel.tables.values.first;
        for (final row in sheet.rows.skip(1)) {
          final nis = row.isNotEmpty ? _getCellValueString(row[0]?.value).trim() : '';
          final name = row.length > 1 ? _getCellValueString(row[1]?.value).trim() : '';
          final kelas = row.length > 2 ? _getCellValueString(row[2]?.value).trim() : '';
          if (name.isEmpty) continue;
          await FirestoreService.createMember({
            'organizationId': orgId,
            'nis': nis.isEmpty ? null : nis,
            'name': name,
            'kelas': kelas,
            'status': 'aktif',
            'exp': 0,
            'level': 1,
          });
        }
      },
    );
  }

  Future<void> _showAnnouncementForm() async {
    final titleC = TextEditingController();
    final contentC = TextEditingController();
    var type = 'info';
    await _dialog(
      title: 'Update Sistem / Pengumuman',
      successMessage: 'Pengumuman berhasil dipublikasikan',
      builder: (setDialogState) => [
        _text(titleC, 'Judul'),
        _text(contentC, 'Konten', maxLines: 5),
        _select(
          'Tipe',
          type,
          _announcementTypes,
          (v) => setDialogState(() => type = v),
        ),
      ],
      onSave: () async {
        if (titleC.text.trim().isEmpty) {
          throw Exception('Judul pengumuman wajib diisi');
        }
        if (contentC.text.trim().isEmpty) {
          throw Exception('Konten pengumuman wajib diisi');
        }
        await FirestoreService.createAnnouncement({
          'title': titleC.text.trim(),
          'content': contentC.text.trim(),
          'type': type,
        });
      },
    );
  }

  Future<void> _showOrganizationSettingsForm() async {
    var orgId = _orgs.isNotEmpty ? _orgs.first.id : null;
    await _dialog(
      title: 'Pilih Organisasi',
      builder: (setDialogState) => [
        _orgSelect(orgId, (v) => setDialogState(() => orgId = v)),
      ],
      onSave: () async {
        final org = _orgById(orgId);
        if (org == null) throw Exception('Organisasi wajib dipilih');
        await _showOrganizationForm(org: org);
      },
    );
  }

  Future<void> _showUserManager() async {
    await Navigator.of(context).push(
      SmoothPageRoute(
        builder: (_) => _UserManagerPage(
          users: _users,
          onViewPassword: _showStoredPasswordDialog,
          onEdit: (u) async {
            await _showUserForm(user: u);
          },
        ),
      ),
    );
    // Muat ulang agar perubahan (mis. user baru) tercermin.
    await _load();
  }

  Future<void> _showLoginInfo() async {
    final emailC = TextEditingController();
    final passC = TextEditingController();
    await _dialog(
      title: 'Login',
      builder: (_) => [
        _text(emailC, 'Email', keyboardType: TextInputType.emailAddress),
        _text(passC, 'Password', obscure: true),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Form login utama aplikasi sudah tersedia di halaman Login. Dialog ini hanya memastikan field login sesuai spesifikasi.',
          ),
        ),
      ],
      onSave: () async {},
    );
  }

  Future<void> _showStudentForm() async {
    final nisC = TextEditingController();
    final nameC = TextEditingController();
    final expC = TextEditingController(text: '0');
    var kelas = _classes.first;
    var major = _majors.first;
    await _dialog(
      title: 'Data Siswa',
      successMessage: 'Data siswa berhasil ditambahkan',
      builder: (setDialogState) => [
        _text(nisC, 'NIS'),
        _text(nameC, 'Nama'),
        _select(
          'Kelas',
          kelas,
          _classes,
          (v) => setDialogState(() => kelas = v),
        ),
        _select(
          'Jurusan',
          major,
          _majors,
          (v) => setDialogState(() => major = v),
        ),
        _text(expC, 'Poin EXP', keyboardType: TextInputType.number),
      ],
      onSave: () async {
        if (nisC.text.trim().isEmpty) {
          throw Exception('NIS siswa wajib diisi');
        }
        if (nameC.text.trim().isEmpty) {
          throw Exception('Nama siswa wajib diisi');
        }
        await FirestoreService.createStudent({
          'nis': nisC.text.trim(),
          'nama': nameC.text.trim(),
          'kelas': kelas,
          'jurusan': major,
          'exp': int.tryParse(expC.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        });
      },
    );
  }

  Future<bool> _dialog({
    required String title,
    required List<Widget> Function(StateSetter setDialogState) builder,
    required Future<void> Function() onSave,
    String successMessage = 'Data berhasil disimpan',
    Future<void> Function()? onDelete,
    String deleteMessage = 'Yakin ingin menghapus?',
  }) async {
    var saved = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        var saving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(title),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              // Lebar definit (double.maxFinite -> di-clamp ke maxWidth di atas)
              // agar AlertDialog tidak menghitung intrinsic width konten. Tanpa ini,
              // ListView(shrinkWrap) di dalam dialog (mis. daftar "Tugaskan")
              // memicu: "RenderShrinkWrappingViewport does not support returning
              // intrinsic dimensions".
              child: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: builder(setDialogState),
                  ),
                ),
              ),
            ),
            actions: [
              if (onDelete != null)
                TextButton(
                  onPressed: saving ? null : () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        title: const Text('Hapus'),
                        content: Text(deleteMessage),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                          ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Hapus', style: TextStyle(color: Colors.white))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      setDialogState(() => saving = true);
                      try {
                        await onDelete().timeout(const Duration(seconds: 120));
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                        if (mounted) await AppDialogs.showSuccess(context, 'Data berhasil dihapus');
                      } catch (e) {
                        if (ctx.mounted) await AppDialogs.showError(ctx, 'Gagal menghapus: $e');
                      } finally {
                        if (ctx.mounted) setDialogState(() => saving = false);
                      }
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  child: const Text('Hapus'),
                ),
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          await onSave().timeout(const Duration(seconds: 120));
                          saved = true;
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _load();
                          if (mounted) await AppDialogs.showSuccess(context, successMessage);
                        } catch (e) {
                          if (ctx.mounted) await AppDialogs.showError(ctx, 'Gagal menyimpan: $e');
                        } finally {
                          if (ctx.mounted) setDialogState(() => saving = false);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan'),
              ),
            ],
          ),
        );
      },
    );
    return saved;
  }

  Widget _text(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscure,
        maxLines: obscure ? 1 : maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _select(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppDropdown<String>(
        label: label,
        icon: Icons.tune_outlined,
        value: items.contains(value) ? value : items.first,
        items: items
            .map((e) => AppDropdownItem(value: e, label: e))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  /// Role yang perlu di-assign ke unit (organisasi/eskul). Administrator melihat
  /// semua unit dan Siswa tidak punya akses, jadi keduanya tidak perlu assignment.
  bool _needsAssignment(String role) {
    const noAssign = {'administrator', 'admin', 'superadmin', 'siswa', 'peserta'};
    return !noAssign.contains(role);
  }

  /// Multi-select "Tugaskan" — mengatur `orgIds` user ke organisasi/eskul yang
  /// dibuat administrator. Membedakan Org vs Eskul lewat kategori.
  Widget _assignOrgsTile(Set<String> selected, StateSetter setDialogState) {
    if (_orgs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Belum ada organisasi/eskul. Buat dulu di menu Organisasi.',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.assignment_ind_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Tugaskan ke Organisasi / Eskul (${selected.length})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              shrinkWrap: true,
              children: _orgs.map((o) {
                return CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selected.contains(o.id),
                  title: Text(o.nama, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(o.category, style: const TextStyle(fontSize: 11)),
                  onChanged: (v) => setDialogState(() {
                    if (v == true) {
                      selected.add(o.id);
                    } else {
                      selected.remove(o.id);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orgSelect(String? value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppDropdown<String>(
        label: 'Organisasi',
        icon: Icons.business_outlined,
        value: _orgs.any((o) => o.id == value)
            ? value
            : (_orgs.isEmpty ? null : _orgs.first.id),
        items: _orgs
            .map((o) => AppDropdownItem(value: o.id, label: o.nama))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _memberSelect(String? value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppDropdown<String>(
        label: 'Anggota',
        icon: Icons.person_outline,
        value: _members.any((m) => m.id == value)
            ? value
            : (_members.isEmpty ? null : _members.first.id),
        items: _members
            .map((m) => AppDropdownItem(value: m.id, label: m.name))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _dateTile(String label, DateTime value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(label),
        subtitle: Text('${value.day}/${value.month}/${value.year}'),
        trailing: const Icon(Icons.calendar_month),
        onTap: onTap,
      ),
    );
  }

  Widget _fileTile(String label, PlatformFile? file, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text(label),
        subtitle: Text(file?.name ?? 'Pilih file'),
        trailing: const Icon(Icons.attach_file),
        onTap: onTap,
      ),
    );
  }

  Future<DateTime?> _pickDate(DateTime current) {
    return showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
  }

  Future<PlatformFile?> _pickFile(
    FileType type, [
    List<String>? extensions,
  ]) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: extensions,
      withData: true,
    );
    return result?.files.single;
  }

  Future<String?> _uploadFile(PlatformFile file, String folder) async {
    if (file.bytes == null) return null;
    if (file.size > 5 * 1024 * 1024) {
      throw Exception('File terlalu besar (maks 5MB)');
    }
    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ref = FirebaseStorage.instance.ref(
      '$folder/${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );
    final snapshot = await ref.putData(file.bytes!).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Upload timeout (30 detik)'),
    );
    return snapshot.ref.getDownloadURL();
  }

  String _slugify(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  String _getCellValueString(CellValue? cellValue) {
    if (cellValue == null) return '';
    return switch (cellValue) {
      TextCellValue(value: final v) => v.toString(),
      IntCellValue(value: final v) => v.toString(),
      DoubleCellValue(value: final v) => v.toString(),
      BoolCellValue(value: final v) => v.toString(),
      FormulaCellValue(formula: final f) => f.toString(),
      _ => cellValue.toString(),
    };
  }

  Organization? _orgById(String? id) {
    for (final org in _orgs) {
      if (org.id == id) return org;
    }
    return null;
  }

  Member? _memberById(String? id) {
    for (final member in _members) {
      if (member.id == id) return member;
    }
    return null;
  }

  void _showCredentialDialog({
    required String nama,
    required String email,
    required String password,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.key, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Akun Berhasil Dibuat'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Simpan kredensial berikut untuk diberikan ke $nama:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _credentialRow('Email', email, Icons.email),
                  const SizedBox(height: 8),
                  _credentialRow('Password', password, Icons.lock),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Password tidak bisa dilihat lagi setelah dialog ini ditutup.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Saya sudah catat'),
          ),
        ],
      ),
    );
  }

  Widget _credentialRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ],
    );
  }

  /// Menampilkan password awal user yang tersimpan (khusus administrator).
  void _showStoredPasswordDialog(UserModel user) {
    final password = user.password;
    final hasPassword = password != null && password.isNotEmpty;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.key, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text('Password ${user.nama}')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _credentialRow('Email', user.email, Icons.email),
                  const SizedBox(height: 8),
                  hasPassword
                      ? _credentialRow('Password', password, Icons.lock)
                      : Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Password tidak tersimpan untuk akun ini.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasPassword
                  ? 'Ini adalah password awal yang dibuat administrator. Bila user pernah mengganti password sendiri, nilai ini mungkin sudah tidak berlaku.'
                  : 'Akun ini dibuat sebelum fitur simpan password aktif, atau dibuat lewat cara lain. Gunakan menu Edit User untuk kirim reset password.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(
      SmoothPageRoute(builder: (_) => page),
    );
  }
}

class _AdminFeature {
  final String title;
  final String fields;
  final IconData icon;
  final VoidCallback onTap;

  _AdminFeature(this.title, this.fields, this.icon, this.onTap);
}

/// Halaman kelola user: cari user, lihat password tersimpan, dan edit.
/// Hanya diakses dari Dashboard Administrator (sudah dibatasi role admin).
class _UserManagerPage extends StatefulWidget {
  final List<UserModel> users;
  final void Function(UserModel) onViewPassword;
  final Future<void> Function(UserModel) onEdit;

  const _UserManagerPage({
    required this.users,
    required this.onViewPassword,
    required this.onEdit,
  });

  @override
  State<_UserManagerPage> createState() => _UserManagerPageState();
}

class _UserManagerPageState extends State<_UserManagerPage> {
  final _searchC = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  List<UserModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.users;
    return widget.users.where((u) {
      return u.nama.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.roleDisplay.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola User & Password')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchC,
              decoration: InputDecoration(
                hintText: 'Cari nama, email, atau role...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchC.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada user ditemukan',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final u = list[i];
                      final hasPassword =
                          u.password != null && u.password!.isNotEmpty;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.roleBadge(u.role).withAlpha(40),
                            child: Text(
                              u.nama.isEmpty ? '?' : u.nama[0].toUpperCase(),
                              style: TextStyle(color: AppColors.roleBadge(u.role)),
                            ),
                          ),
                          title: Text(u.nama),
                          subtitle: Text(
                            '${u.email}\n${u.roleDisplay}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.key,
                                  color: hasPassword ? AppColors.primary : AppColors.textHint,
                                ),
                                tooltip: hasPassword ? 'Lihat Password' : 'Password tidak tersimpan',
                                onPressed: () => widget.onViewPassword(u),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Edit',
                                onPressed: () => widget.onEdit(u),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
