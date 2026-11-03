import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../api/models.dart';

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

/// Source des positions, remplaçable dans les tests.
abstract class PositionSource {
  Future<LocationAccess> ensureAccess();
  Future<GeoPoint?> current();
  Stream<GeoPoint> watch({
    required Duration interval,
    required String notificationTitle,
    required String notificationText,
  });
}

/// Positions du téléphone (geolocator). Pendant que le livreur est en ligne, Android garde
/// une notification permanente (service au premier plan) : les positions continuent quand
/// l'app est en arrière-plan, sans autorisation « toujours ».
class DevicePositionSource implements PositionSource {
  @override
  Future<LocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceDisabled;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    return switch (permission) {
      LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  @override
  Future<GeoPoint?> current() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: Duration(seconds: 10)),
      );
      return _toPoint(position);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      return last == null ? null : _toPoint(last);
    }
  }

  @override
  Stream<GeoPoint> watch({
    required Duration interval,
    required String notificationTitle,
    required String notificationText,
  }) {
    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            intervalDuration: interval,
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: notificationTitle,
              notificationText: notificationText,
              notificationIcon: const AndroidResource(name: 'ic_launcher_monochrome', defType: 'drawable'),
              setOngoing: true,
            ),
          )
        : AppleSettings(
            activityType: ActivityType.otherNavigation,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
          );
    return Geolocator.getPositionStream(locationSettings: settings).map(_toPoint);
  }

  static GeoPoint _toPoint(Position position) => GeoPoint(
    latitude: position.latitude,
    longitude: position.longitude,
    recordedAt: position.timestamp,
    heading: position.heading >= 0 ? position.heading : null,
    speed: position.speed >= 0 ? position.speed : null,
    accuracy: position.accuracy,
    mocked: position.isMocked,
  );
}
