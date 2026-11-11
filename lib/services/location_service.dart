import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/geo.dart';

enum LocationFailureKind { serviceDisabled, denied, deniedForever, timeout, unknown }

class LocationFailure implements Exception {
  final LocationFailureKind kind;
  const LocationFailure(this.kind);
}

class LocationService {
  /// Asks for permission only when called (never at app start) and returns
  /// the current position. Throws [LocationFailure] with a precise reason.
  Future<GeoPoint> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationFailure(LocationFailureKind.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const LocationFailure(LocationFailureKind.denied);
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationFailure(LocationFailureKind.deniedForever);
      }
      // City-level accuracy is enough for weather and uses less battery.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return GeoPoint(pos.latitude, pos.longitude, altitudeM: pos.altitude);
    } on LocationFailure {
      rethrow;
    } on TimeoutException {
      throw const LocationFailure(LocationFailureKind.timeout);
    } on LocationServiceDisabledException {
      throw const LocationFailure(LocationFailureKind.serviceDisabled);
    } catch (_) {
      throw const LocationFailure(LocationFailureKind.unknown);
    }
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
