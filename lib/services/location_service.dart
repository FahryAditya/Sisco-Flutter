import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
  String? _trackingId;

  static const _trackingCollection = 'live_tracking';
  static const _heartbeatSeconds = 10;

  bool get isTracking => _trackingId != null;

  Stream<Position> get positionStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    ),
  );

  Future<bool> requestPermission() async {
    final status = await Geolocator.requestPermission();
    return status == LocationPermission.always || status == LocationPermission.whileInUse;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      debugPrint('Get position error: $e');
      return null;
    }
  }

  Future<String> startTracking({
    required String userId,
    required String userName,
    required String kegiatanId,
    required String kegiatanTitle,
    String? organizationId,
  }) async {
    _trackingId = '${kegiatanId}_$userId';

    final doc = _db.collection(_trackingCollection).doc(_trackingId);
    await doc.set({
      'userId': userId,
      'userName': userName,
      'kegiatanId': kegiatanId,
      'kegiatanTitle': kegiatanTitle,
      'organizationId': organizationId ?? '',
      'isActive': true,
      'startedAt': FieldValue.serverTimestamp(),
      'lastUpdate': FieldValue.serverTimestamp(),
    });

    final pos = await getCurrentPosition();
    if (pos != null) {
      await _updatePosition(pos);
    }

    _positionSub = positionStream.listen(_updatePosition);

    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeatSeconds),
      (_) => _heartbeat(),
    );

    return _trackingId!;
  }

  Future<void> _updatePosition(Position pos) async {
    if (_trackingId == null) return;
    try {
      await _db.collection(_trackingCollection).doc(_trackingId).update({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy': pos.accuracy,
        'speed': pos.speed,
        'lastUpdate': FieldValue.serverTimestamp(),
        'isActive': true,
      });
    } catch (e) {
      debugPrint('Update position error: $e');
    }
  }

  Future<void> _heartbeat() async {
    if (_trackingId == null) return;
    try {
      await _db.collection(_trackingCollection).doc(_trackingId).update({
        'lastUpdate': FieldValue.serverTimestamp(),
        'isActive': true,
      });
    } catch (_) {}
  }

  Future<void> stopTracking() async {
    _positionSub?.cancel();
    _positionSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_trackingId != null) {
      try {
        await _db.collection(_trackingCollection).doc(_trackingId).update({
          'isActive': false,
          'endedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    _trackingId = null;
  }

  static Stream<List<LiveTrackingData>> kegiatanParticipantsStream(String kegiatanId) {
    return FirebaseFirestore.instance
        .collection(_trackingCollection)
        .where('kegiatanId', isEqualTo: kegiatanId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LiveTrackingData.fromMap(d.data(), d.id))
            .toList());
  }

  static Stream<LiveTrackingData?> userTrackingStream(String userId) {
    return FirebaseFirestore.instance
        .collection(_trackingCollection)
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.isNotEmpty
            ? LiveTrackingData.fromMap(snap.docs.first.data(), snap.docs.first.id)
            : null);
  }

  Future<List<LiveTrackingData>> getActiveTrackings(String kegiatanId) async {
    final snap = await _db
        .collection(_trackingCollection)
        .where('kegiatanId', isEqualTo: kegiatanId)
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs
        .map((d) => LiveTrackingData.fromMap(d.data(), d.id))
        .toList();
  }

  void dispose() {
    _positionSub?.cancel();
    _heartbeatTimer?.cancel();
  }
}

class LiveTrackingData {
  final String id;
  final String userId;
  final String userName;
  final String kegiatanId;
  final String kegiatanTitle;
  final String? organizationId;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final double? speed;
  final bool isActive;
  final DateTime? startedAt;
  final DateTime? lastUpdate;
  final DateTime? endedAt;

  LiveTrackingData({
    required this.id,
    required this.userId,
    required this.userName,
    required this.kegiatanId,
    required this.kegiatanTitle,
    this.organizationId,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.speed,
    required this.isActive,
    this.startedAt,
    this.lastUpdate,
    this.endedAt,
  });

  factory LiveTrackingData.fromMap(Map<String, dynamic> map, String docId) {
    return LiveTrackingData(
      id: docId,
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      kegiatanId: map['kegiatanId'] as String? ?? '',
      kegiatanTitle: map['kegiatanTitle'] as String? ?? '',
      organizationId: map['organizationId'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      isActive: map['isActive'] as bool? ?? false,
      startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
      lastUpdate: (map['lastUpdate'] as Timestamp?)?.toDate(),
      endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get hasLocation => latitude != null && longitude != null;
}
