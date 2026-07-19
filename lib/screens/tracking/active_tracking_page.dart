import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/character_dialog.dart';

class ActiveTrackingPage extends StatefulWidget {
  final String kegiatanId;
  final String kegiatanTitle;

  const ActiveTrackingPage({
    super.key,
    required this.kegiatanId,
    required this.kegiatanTitle,
  });

  @override
  State<ActiveTrackingPage> createState() => _ActiveTrackingPageState();
}

class _ActiveTrackingPageState extends State<ActiveTrackingPage>
    with WidgetsBindingObserver {
  int _elapsed = 0;
  final MapController _mapController = MapController();
  List<LiveTrackingData> _participants = [];

  static const _defaultCenter = LatLng(-1.249, 116.832);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _elapsed++);
        return true;
      }
      return false;
    });
  }

  String _formatTime(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _stopAndLeave() async {
    final confirmed = await AppDialogs.showConfirm(context, message: 'Lokasi Anda akan berhenti dibagikan. Lanjutkan?', confirmLabel: 'Hentikan', danger: true);

    if (confirmed == true) {
      await LocationService.instance.stopTracking();
      if (mounted) Navigator.pop(context);
    }
  }

  void _fitMapBounds() {
    final coords = _participants.where((p) => p.hasLocation).map((p) => LatLng(p.latitude!, p.longitude!)).toList();
    if (coords.isEmpty) return;
    if (coords.length == 1) {
      _mapController.move(coords.first, 15);
      return;
    }
    double minLat = coords.first.latitude, maxLat = coords.first.latitude;
    double minLng = coords.first.longitude, maxLng = coords.first.longitude;
    for (final c in coords) {
      if (c.latitude < minLat) minLat = c.latitude;
      if (c.latitude > maxLat) maxLat = c.latitude;
      if (c.longitude < minLng) minLng = c.longitude;
      if (c.longitude > maxLng) maxLng = c.longitude;
    }
    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
  }

  @override
  Widget build(BuildContext context) {
    final isTracking = LocationService.instance.isTracking;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kegiatanTitle),
        actions: [
          if (isTracking)
            TextButton.icon(
              onPressed: _stopAndLeave,
              icon: const Icon(Icons.stop, color: AppColors.danger),
              label: Text('Berhenti', style: GoogleFonts.plusJakartaSans(color: AppColors.danger)),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withAlpha(15),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location, size: 28, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatTime(_elapsed),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Lokasi dibagikan secara langsung',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text('${_participants.where((p) => p.hasLocation).length} peserta',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<LiveTrackingData>>(
              stream: LocationService.kegiatanParticipantsStream(widget.kegiatanId),
              builder: (context, snap) {
                _participants = snap.data ?? [];
                final aktif = _participants.where((p) => p.hasLocation).toList();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (aktif.isNotEmpty) _fitMapBounds();
                });

                if (aktif.isEmpty) {
                  return _emptyMap();
                }

                return FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _defaultCenter,
                    initialZoom: 12,
                    minZoom: 3,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.sisko',
                    ),
                    MarkerLayer(
                      markers: aktif.map((p) => Marker(
                        point: LatLng(p.latitude!, p.longitude!),
                        width: 120,
                        height: 50,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p.userName.split(' ').first,
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Icon(Icons.location_on, color: AppColors.danger, size: 30),
                          ],
                        ),
                      )).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: 12,
        minZoom: 3,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.sisko',
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}
