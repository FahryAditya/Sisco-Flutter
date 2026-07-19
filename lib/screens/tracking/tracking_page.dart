import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/page_transitions.dart';
import 'active_tracking_page.dart';

class TrackingPage extends StatefulWidget {
  final String kegiatanId;
  final String kegiatanTitle;
  final String? organizationId;

  const TrackingPage({
    super.key,
    required this.kegiatanId,
    required this.kegiatanTitle,
    this.organizationId,
  });

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _isTracking = LocationService.instance.isTracking;
  }

  Future<void> _startTracking() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final permitted = await LocationService.instance.requestPermission();
    if (!permitted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin lokasi diperlukan untuk tracking'), backgroundColor: AppColors.danger),
        );
      }
      return;
    }

    await LocationService.instance.startTracking(
      userId: user.id,
      userName: user.nama,
      kegiatanId: widget.kegiatanId,
      kegiatanTitle: widget.kegiatanTitle,
      organizationId: widget.organizationId,
    );

    if (mounted) {
      setState(() => _isTracking = true);
      Navigator.push(context, SmoothPageRoute(builder: (_) => ActiveTrackingPage(
        kegiatanId: widget.kegiatanId,
        kegiatanTitle: widget.kegiatanTitle,
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.kegiatanTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on, size: 64, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Live Tracking Kegiatan',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22, fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bagikan lokasi real-time Anda selama kegiatan berlangsung.\nAnggota lain dapat melihat posisi Anda di peta.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: AppColors.textSecondary, height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              icon: Icon(_isTracking ? Icons.my_location : Icons.play_arrow),
              label: Text(_isTracking ? 'Sedang Melacak...' : 'Mulai Tracking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTracking ? AppColors.success : AppColors.primary,
                foregroundColor: Colors.white,
                textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              onPressed: _isTracking ? null : _startTracking,
            ),
          ),
          const SizedBox(height: 32),
          if (_isTracking) _participantsList(),
        ],
      ),
    );
  }

  Widget _participantsList() {
    return StreamBuilder<List<LiveTrackingData>>(
      stream: LocationService.kegiatanParticipantsStream(widget.kegiatanId),
      builder: (context, snap) {
        final participants = snap.data ?? [];
        if (participants.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Peserta Aktif (${participants.length})',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...participants.map((p) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withAlpha(30),
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                title: Text(p.userName),
                subtitle: Text(p.hasLocation
                    ? '${p.latitude!.toStringAsFixed(4)}, ${p.longitude!.toStringAsFixed(4)}'
                    : 'Menunggu lokasi...'),
                trailing: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                ),
              ),
            )),
          ],
        );
      },
    );
  }
}
