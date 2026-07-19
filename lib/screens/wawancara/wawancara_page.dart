import 'package:flutter/material.dart';
import '../../utils/page_transitions.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/organization_provider.dart';
import '../../providers/interview_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/interview.dart';
import '../../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/formatters.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/character_dialog.dart';

class WawancaraPage extends StatefulWidget {
  const WawancaraPage({super.key});

  @override
  State<WawancaraPage> createState() => _WawancaraPageState();
}

class _WawancaraPageState extends State<WawancaraPage> {
  String? _selectedOrgId;

  @override
  void initState() {
    super.initState();
    context.read<OrganizationProvider>().loadOrgs();
  }

  void _subscribeSessions() {
    if (_selectedOrgId == null) return;
    context.read<InterviewProvider>().subscribeSessions(_selectedOrgId!);
  }

  Future<void> _createSession() async {
    if (_selectedOrgId == null) return;
    final user = context.read<AuthProvider>().user;
    final now = DateTime.now();
    AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
    try {
      final newId = await FirestoreService.createSession({
        'organizationId': _selectedOrgId!,
        'status': 'SCHEDULED',
        'jadwalMulai': Timestamp.fromDate(now),
        'jadwalSelesai': Timestamp.fromDate(now.add(const Duration(hours: 7))),
        'createdBy': user?.id ?? '',
      });
      await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'CREATE', tabel: 'interview_sessions', recordId: newId, deskripsi: 'Membuat sesi wawancara baru');
      if (mounted) AppDialogs.hide(context);
      if (mounted) await AppDialogs.showSuccess(context, 'Sesi wawancara dibuat');
    } catch (e) {
      if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal membuat sesi: $e'); }
    }
  }

  Future<void> _activateSession(String sesiId) async {
    final user = context.read<AuthProvider>().user;
    AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
    try {
      await FirestoreService.updateSession(sesiId, {'status': 'ACTIVE'});
      await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'UPDATE', tabel: 'interview_sessions', recordId: sesiId, deskripsi: 'Mengaktifkan sesi wawancara');
      if (mounted) AppDialogs.hide(context);
      if (mounted) await AppDialogs.showSuccess(context, 'Sesi wawancara aktif');
    } catch (e) {
      if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal mengaktifkan sesi: $e'); }
    }
  }

  Future<void> _finishSession(String sesiId) async {
    final user = context.read<AuthProvider>().user;
    AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
    try {
      await FirestoreService.updateSession(sesiId, {
        'status': 'SELESAI',
        'finalizedAt': FieldValue.serverTimestamp(),
      });
      await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'UPDATE', tabel: 'interview_sessions', recordId: sesiId, deskripsi: 'Menyelesaikan sesi wawancara');
      if (mounted) AppDialogs.hide(context);
      if (mounted) await AppDialogs.showSuccess(context, 'Sesi wawancara selesai');
    } catch (e) {
      if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal menyelesaikan sesi: $e'); }
    }
  }

  void _showSessionDetail(InterviewSession session) {
    Navigator.push(
      context,
      SmoothPageRoute(builder: (_) => _SessionDetailPage(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null || !user.canWawancara) {
      return Scaffold(
        appBar: GradientAppBar(
          title: 'Wawancara',
          colors: const [Color(0xFFA88BEB), Color(0xFF8E44AD)],
        ),
        body: const EmptyState(
          icon: Icons.lock_outline,
          message: 'Akses ditolak',
          subtitle: 'Wawancara hanya untuk Admin, Admin Organisasi, dan Pembina Organisasi',
        ),
      );
    }
    final orgs = context.watch<OrganizationProvider>().orgs;
    final inter = context.watch<InterviewProvider>();

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Wawancara',
        colors: const [Color(0xFFA88BEB), Color(0xFF8E44AD)],
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createSession,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppDropdown<String>(label: 'Organisasi', icon: Icons.business_outlined, value: _selectedOrgId,
            items: orgs.map((o) => AppDropdownItem(value: o.id, label: o.nama)).toList(),
            onChanged: (v) {
              setState(() => _selectedOrgId = v);
              if (v == null) {
                context.read<InterviewProvider>().clear();
              } else {
                _subscribeSessions();
              }
            },
          ),
          const SizedBox(height: 16),
          if (inter.sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(icon: Icons.record_voice_over, message: 'Belum ada sesi wawancara', subtitle: 'Tekan + untuk membuat sesi baru'),
            )
          else
            ...inter.sessions.map((s) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _statusColor(s.status).withAlpha(30),
                      child: Icon(_statusIcon(s.status), color: _statusColor(s.status)),
                    ),
                    title: Text('Sesi ${Formatters.formatDate(s.createdAt)}'),
                    subtitle: Text(s.statusDisplay),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'activate') _activateSession(s.id);
                        if (v == 'finish') _finishSession(s.id);
                        if (v == 'detail') _showSessionDetail(s);
                      },
                      itemBuilder: (_) => [
                        if (s.isScheduled)
                          const PopupMenuItem(value: 'activate', child: Text('Mulai Sesi')),
                        if (s.isActive)
                          const PopupMenuItem(value: 'finish', child: Text('Akhiri Sesi')),
                        const PopupMenuItem(value: 'detail', child: Text('Detail')),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE': return AppColors.success;
      case 'SCHEDULED': return AppColors.info;
      case 'SELESAI': return AppColors.textSecondary;
      case 'DIBATALKAN': return AppColors.danger;
      default: return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'ACTIVE': return Icons.play_circle;
      case 'SCHEDULED': return Icons.schedule;
      case 'SELESAI': return Icons.check_circle;
      case 'DIBATALKAN': return Icons.cancel;
      default: return Icons.help;
    }
  }
}

// Session Detail Page
class _SessionDetailPage extends StatefulWidget {
  final InterviewSession session;
  const _SessionDetailPage({required this.session});

  @override
  State<_SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<_SessionDetailPage> {
  List<InterviewQueue> _queues = [];
  final _namaC = TextEditingController();
  final _kelasC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadQueues();
  }

  @override
  void dispose() {
    _namaC.dispose();
    _kelasC.dispose();
    super.dispose();
  }

  Future<void> _loadQueues() async {
    try {
      _queues = await FirestoreService.getQueues(widget.session.id);
    } catch (e) {
      if (mounted) await AppDialogs.showError(context, 'Gagal memuat antrian: $e');
    }
    setState(() {});
  }

  Future<void> _addParticipant() async {
    final user = context.read<AuthProvider>().user;
    final nama = _namaC.text.trim();
    final kelas = _kelasC.text.trim();
    if (nama.isEmpty || kelas.isEmpty) return;
    AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
    try {
      await FirestoreService.addQueue(widget.session.id, {
        'sesiId': widget.session.id,
        'nama': nama,
        'kelas': kelas,
        'nomorAntrian': _queues.length + 1,
        'status': 'MENUNGGU',
      });
      await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'CREATE', tabel: 'interview_queues', deskripsi: 'Menambah peserta wawancara: $nama ($kelas)');
      _namaC.clear();
      _kelasC.clear();
      if (mounted) AppDialogs.hide(context);
      if (mounted) await AppDialogs.showSuccess(context, 'Peserta ditambahkan');
    } catch (e) {
      if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal menambah peserta: $e'); }
    }
    _loadQueues();
  }

  Future<void> _deleteQueue(String queueId) async {
    final user = context.read<AuthProvider>().user;
    AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
    try {
      await FirestoreService.deleteQueue(widget.session.id, queueId);
      await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'DELETE', tabel: 'interview_queues', recordId: queueId, deskripsi: 'Menghapus peserta wawancara');
      if (mounted) AppDialogs.hide(context);
      if (mounted) await AppDialogs.showSuccess(context, 'Peserta dihapus');
    } catch (e) {
      if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal menghapus peserta: $e'); }
    }
    _loadQueues();
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Peserta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _namaC,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _kelasC,
              decoration: const InputDecoration(labelText: 'Kelas'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () async {
            await _addParticipant();
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text('Tambah')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Sesi ${Formatters.formatDate(widget.session.createdAt)}',
        colors: const [Color(0xFFA88BEB), Color(0xFF8E44AD)],
        actions: [
          IconButton(icon: const Icon(Icons.person_add), onPressed: _showAddDialog),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${widget.session.statusDisplay}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.session.isActive ? AppColors.success : AppColors.textSecondary,
                      )),
                  const SizedBox(height: 4),
                  Text('Peserta: ${_queues.length} orang'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Antrian',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_queues.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Belum ada peserta'),
              ),
            )
          else
                ..._queues.map((q) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withAlpha(30),
                      child: Text('${q.nomorAntrian}'),
                    ),
                    title: Text(q.nama),
                    subtitle: Text('${q.kelas} - ${q.statusDisplay}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.rate_review, color: AppColors.info),
                        onPressed: () => _showHasilDialog(q),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: () => _deleteQueue(q.id),
                      ),
                    ]),
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _showHasilDialog(InterviewQueue q) async {
    final hasil = ['DITERIMA', 'DITOLAK', 'DIPERTIMBANGKAN'];
    String selectedHasil = hasil.first;
    final persenC = TextEditingController(text: '50');
    final catatanC = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        title: Text('Hasil Wawancara - ${q.nama}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          AppDropdown<String>(
            label: 'Hasil',
            value: selectedHasil,
            items: hasil.map((h) => AppDropdownItem(value: h, label: h)).toList(),
            onChanged: (v) => setDialogState(() => selectedHasil = v ?? hasil.first),
          ),
          const SizedBox(height: 8),
          TextField(controller: persenC, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Persentase (%)')),
          const SizedBox(height: 8),
          TextField(controller: catatanC, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Catatan')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () async {
            AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
            try {
              final user = context.read<AuthProvider>().user;
              final persen = double.tryParse(persenC.text) ?? 0;
              await FirestoreService.createResult({
                'antrianId': q.id,
                'interviewerId': user?.id ?? '',
                'keterangan': 'AKTIF',
                'hasil': selectedHasil,
                'persentase': persen,
                'catatan': catatanC.text.trim().isEmpty ? null : catatanC.text.trim(),
              });
              await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'CREATE', tabel: 'interview_results', deskripsi: 'Menyimpan hasil wawancara ${q.nama}: $selectedHasil');
              if (mounted) AppDialogs.hide(context);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) await AppDialogs.showSuccess(context, 'Hasil wawancara disimpan');
            } catch (e) {
              if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal menyimpan hasil: $e'); }
            }
          }, child: const Text('Simpan Hasil')),
        ],
      )),
    );
  }
}



