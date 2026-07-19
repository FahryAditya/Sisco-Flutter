import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/organization_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../models/documentation.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/character_dialog.dart';

class DokumentasiPage extends StatefulWidget {
  const DokumentasiPage({super.key});

  @override
  State<DokumentasiPage> createState() => _DokumentasiPageState();
}

class _DokumentasiPageState extends State<DokumentasiPage> {
  List<Documentation> _docs = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    context.read<OrganizationProvider>().loadOrgs();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    try {
      final user = context.read<AuthProvider>().user;
      // Admin membaca semua; non-admin dibatasi ke organisasinya sesuai aturan
      // Firestore agar tidak permission-denied.
      _docs = (user?.isAdministrator ?? false)
          ? await FirestoreService.getDocumentations(forceRefresh: forceRefresh)
          : await FirestoreService.getDocumentations(
              orgIds: user?.orgIds ?? [],
              forceRefresh: forceRefresh,
            );
    } catch (e) {
      if (mounted) await AppDialogs.showError(context, 'Gagal memuat dokumentasi: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() => _load(forceRefresh: true);

  Future<void> _showAddDialog() async {
    final user = context.read<AuthProvider>().user;
    final orgs = context.read<OrganizationProvider>().orgs;
    if (user == null) return;
    final titleC = TextEditingController();
    final descC = TextEditingController();
    final categoryC = TextEditingController();
    String? selectedOrgId;
    if (orgs.isNotEmpty) selectedOrgId = orgs.first.id;
    // Foto yang dipilih (belum diunggah). Diunggah ke Cloudinary saat Simpan.
    final List<PlatformFile> photos = [];
    var saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Tambah Dokumentasi'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (orgs.isNotEmpty) ...[
              AppDropdown<String>(
                label: 'Organisasi',
                icon: Icons.business_outlined,
                enabled: !saving,
                value: selectedOrgId,
                items: orgs.map((o) => AppDropdownItem(value: o.id, label: o.nama)).toList(),
                onChanged: (v) => setDialogState(() => selectedOrgId = v),
              ),
              const SizedBox(height: 8),
            ],
            TextField(controller: titleC, enabled: !saving, decoration: const InputDecoration(labelText: 'Judul')),
            const SizedBox(height: 8),
            TextField(controller: descC, enabled: !saving, decoration: const InputDecoration(labelText: 'Deskripsi'), maxLines: 3),
            const SizedBox(height: 8),
            TextField(controller: categoryC, enabled: !saving, decoration: const InputDecoration(labelText: 'Kategori')),
            const SizedBox(height: 12),
            _photoPicker(photos, saving, setDialogState),
          ]),
        ),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: saving ? null : () async {
            if (titleC.text.trim().isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Judul wajib diisi')));
              return;
            }
            if (selectedOrgId == null || selectedOrgId!.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Organisasi wajib dipilih')));
              return;
            }
            setDialogState(() => saving = true);
            try {
              // Unggah tiap foto ke Cloudinary, kumpulkan secure_url-nya.
              final urls = <String>[];
              for (final p in photos) {
                if (p.bytes == null) continue;
                urls.add(await CloudinaryService.uploadBytes(p.bytes!, p.name));
              }
              await FirestoreService.createDocumentation({
                'title': titleC.text.trim(),
                'description': descC.text.trim(),
                'category': categoryC.text.trim(),
                'organizationId': selectedOrgId ?? '',
                'createdBy': user.id,
                'dateTaken': FieldValue.serverTimestamp(),
                'photos': urls,
              });
              await FirestoreService.logAction(userId: user.id, userNama: user.nama, aksi: 'CREATE', tabel: 'documentation', deskripsi: 'Menambah dokumentasi: ${titleC.text.trim()} (${urls.length} foto)');
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) await AppDialogs.showSuccess(context, 'Dokumentasi ditambahkan');
              _load();
            } catch (e) {
              if (ctx.mounted) setDialogState(() => saving = false);
              if (mounted) await AppDialogs.showError(context, 'Gagal menyimpan dokumentasi: $e');
            }
          }, child: saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Simpan')),
        ],
      )),
    );
  }

  /// Pemilih foto (bisa banyak) + pratinjau thumbnail. Foto disimpan sementara
  /// sebagai [PlatformFile] lalu diunggah ke Cloudinary saat Simpan ditekan.
  Widget _photoPicker(List<PlatformFile> photos, bool saving, void Function(void Function()) setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.photo_library_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('Foto', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton.icon(
            onPressed: saving ? null : () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
                allowMultiple: true,
                withData: true,
              );
              if (result != null) {
                setDialogState(() => photos.addAll(
                    result.files.where((f) => f.bytes != null)));
              }
            },
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: const Text('Tambah'),
          ),
        ]),
        if (photos.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Belum ada foto dipilih', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(photos.length, (i) {
              final p = photos[i];
              return Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: p.bytes != null
                      ? Image.memory(p.bytes!, width: 72, height: 72, fit: BoxFit.cover)
                      : Container(width: 72, height: 72, color: AppColors.primary.withAlpha(30)),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: saving ? null : () => setDialogState(() => photos.removeAt(i)),
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ]);
            }),
          ),
      ],
    );
  }

  Future<void> _delete(String id) async {
    final user = context.read<AuthProvider>().user;
    final ok = await AppDialogs.showConfirm(context, message: 'Yakin ingin menghapus?', confirmLabel: 'Hapus', danger: true);
    if (ok == true) {
      if (!mounted) return;
      AppDialogs.showLoading(context, kind: LoadingKind.sinkronasi);
      try {
        await FirestoreService.deleteDocumentation(id);
        await FirestoreService.logAction(userId: user?.id ?? '', userNama: user?.nama ?? '', aksi: 'DELETE', tabel: 'documentation', recordId: id, deskripsi: 'Menghapus dokumentasi');
        if (mounted) AppDialogs.hide(context);
        if (mounted) await AppDialogs.showSuccess(context, 'Dokumentasi dihapus');
        _load();
      } catch (e) {
        if (mounted) { AppDialogs.hide(context); await AppDialogs.showError(context, 'Gagal menghapus dokumentasi: $e'); }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Dokumentasi',
        colors: const [Color(0xFFFF8A50), Color(0xFFE64A19)],
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog)],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _docs.isEmpty
          ? const EmptyState(icon: Icons.photo_library, message: 'Belum ada dokumentasi')
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: _buildAlbumSections(),
              ),
            ),
    );
  }

  /// Kelompokkan album (entri dokumentasi) per tanggal, tiap grup diberi header
  /// tanggal/hari lalu grid 2 kolom berisi kartu album bersampul foto asli.
  List<Widget> _buildAlbumSections() {
    // _docs sudah terurut dateTaken menurun dari FirestoreService.
    final groups = <String, List<Documentation>>{};
    for (final d in _docs) {
      final key = _dateGroupLabel(d.dateTaken);
      groups.putIfAbsent(key, () => []).add(d);
    }

    final widgets = <Widget>[];
    groups.forEach((label, docs) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Row(children: [
          Icon(Icons.event_outlined, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
        ]),
      ));
      widgets.add(GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: docs.length,
        itemBuilder: (_, i) => _albumCard(docs[i]),
      ));
    });
    return widgets;
  }

  /// Label pengelompokan: "Hari ini", "Kemarin", atau tanggal lengkap.
  String _dateGroupLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    return Formatters.formatDate(dt);
  }

  /// Kartu album: sampul foto asli + overlay judul, jumlah foto, dan tanggal.
  Widget _albumCard(Documentation d) {
    return GestureDetector(
      onTap: () => _showGallery(d),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Sampul: foto asli pertama, memenuhi kartu.
            if (d.photos.isNotEmpty)
              Image.network(
                d.photos.first,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _photoPlaceholder(),
                loadingBuilder: (c, child, progress) => progress == null
                    ? child
                    : _photoPlaceholder(loading: true),
              )
            else
              _photoPlaceholder(),
            // Gradient gelap di bawah agar teks terbaca.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
            // Badge jumlah foto.
            if (d.photos.length > 1)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.collections, size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('${d.photos.length}', style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            // Tombol hapus.
            Positioned(
              top: 4,
              left: 4,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                  style: IconButton.styleFrom(backgroundColor: Colors.black38),
                  onPressed: () => _delete(d.id),
                ),
              ),
            ),
            // Judul + tanggal di bawah.
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    d.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.formatDate(d.dateTaken),
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder({bool loading = false}) {
    return Container(
      color: AppColors.primary.withAlpha(30),
      child: loading
          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
          : Icon(Icons.photo, color: AppColors.primary),
    );
  }

  /// Buka album: seluruh foto dalam grid 2 kolom yang bisa di-zoom.
  void _showGallery(Documentation d) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: GradientAppBar(
          title: d.title,
          colors: const [Color(0xFFFF8A50), Color(0xFFE64A19)],
        ),
        body: d.photos.isEmpty
            ? const EmptyState(icon: Icons.photo, message: 'Belum ada foto di album ini')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (d.description != null && d.description!.isNotEmpty) ...[
                    Text(d.description!, style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    '${Formatters.formatDate(d.dateTaken)}  •  ${d.photos.length} foto',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: d.photos.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _showFullPhoto(d.photos, i),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          d.photos[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _photoPlaceholder(),
                          loadingBuilder: (c, child, progress) => progress == null
                              ? child
                              : _photoPlaceholder(loading: true),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    ));
  }

  /// Lihat satu foto layar penuh dengan zoom (pinch/double-tap pan).
  void _showFullPhoto(List<String> photos, int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              maxScale: 4,
              child: Image.network(
                photos[index],
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _photoPlaceholder(),
                loadingBuilder: (c, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    );
  }
}
