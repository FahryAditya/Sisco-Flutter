import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/quest_slot.dart';
import '../../theme/app_theme.dart';
import '../../widgets/character_dialog.dart';
import 'quest_constants.dart';

/// Menampilkan QR untuk satu SLOT. QR memuat URL slot (token stabil); saat
/// dipindai, peserta membuka halaman web yang menampilkan soal yang sedang
/// ditugaskan ke slot itu. Isi soal bisa diacak tanpa mengganti QR ini.
class QuestQrPage extends StatefulWidget {
  final QuestSlot slot;

  const QuestQrPage({super.key, required this.slot});

  @override
  State<QuestQrPage> createState() => _QuestQrPageState();
}

class _QuestQrPageState extends State<QuestQrPage> {
  final _boundaryKey = GlobalKey();
  bool _busy = false;

  String get _url => QuestConstants.slotUrl(widget.slot.id);

  /// Ambil gambar QR (beserta label) dari RepaintBoundary sebagai PNG bytes.
  Future<Uint8List?> _capturePng() async {
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _shareQr() async {
    setState(() => _busy = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) throw Exception('Gagal membuat gambar QR');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qr_$_safeName.png');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: 'qr_$_safeName.png')],
        subject: 'QR ${widget.slot.label}',
        text: 'Airlangga QR Quest — ${widget.slot.label}',
      );
    } catch (e) {
      if (mounted) await AppDialogs.showError(context, 'Gagal membagikan QR: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _safeName => widget.slot.label.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');

  /// Simpan gambar QR ke galeri foto HP.
  Future<void> _saveToGallery() async {
    setState(() => _busy = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) throw Exception('Gagal membuat gambar QR');
      // gal minta izin galeri sendiri; cek dulu agar bisa beri pesan jelas.
      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (mounted) {
            await AppDialogs.showError(
                context, 'Izin galeri ditolak. Aktifkan di pengaturan HP.');
          }
          return;
        }
      }
      await Gal.putImageBytes(bytes, name: 'qr_$_safeName');
      if (mounted) {
        await AppDialogs.showSuccess(context, 'QR disimpan ke galeri');
      }
    } on GalException catch (e) {
      if (mounted) {
        await AppDialogs.showError(context, 'Gagal menyimpan: ${e.type.message}');
      }
    } catch (e) {
      if (mounted) await AppDialogs.showError(context, 'Gagal menyimpan QR: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Cetak QR lewat dialog print sistem (printer fisik / simpan sebagai PDF).
  Future<void> _printQr() async {
    setState(() => _busy = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) throw Exception('Gagal membuat gambar QR');
      final image = pw.MemoryImage(bytes);
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Image(image, width: 360, fit: pw.BoxFit.contain),
          ),
        ),
      );
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'QR ${widget.slot.label}',
      );
    } catch (e) {
      if (mounted) await AppDialogs.showError(context, 'Gagal mencetak QR: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyUrl() async {
    await Clipboard.setData(ClipboardData(text: _url));
    if (mounted) {
      await AppDialogs.showSuccess(context, 'Link slot disalin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    return Scaffold(
      appBar: AppBar(title: Text('QR ${slot.label}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        slot.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Airlangga QR Quest',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: _url,
                        version: QrVersions.auto,
                        size: 240,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Info penting: QR ini stabil, isi soalnya bisa diacak.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'QR ini permanen. Bila isinya bocor, acak ulang soal dari '
                      'halaman daftar slot — QR tidak perlu dicetak ulang.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              _url,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _busy ? null : _printQr,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_outlined),
              label: const Text('Cetak QR'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _saveToGallery,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Simpan ke Galeri'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _shareQr,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Bagikan'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _copyUrl,
              icon: const Icon(Icons.link_outlined),
              label: const Text('Salin Link'),
            ),
          ],
        ),
      ),
    );
  }
}
