import 'dart:async';

import 'package:geolocator/geolocator.dart';

class CurrentLocation {
  const CurrentLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

enum LocationFailureReason {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unavailable,
}

class LocationFailure implements Exception {
  const LocationFailure(this.reason);

  final LocationFailureReason reason;
}

abstract class LocationGateway {
  Future<CurrentLocation> current();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class GeolocatorLocationGateway implements LocationGateway {
  const GeolocatorLocationGateway();

  @override
  Future<CurrentLocation> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(LocationFailureReason.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure(LocationFailureReason.permissionDenied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        LocationFailureReason.permissionDeniedForever,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return CurrentLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      throw const LocationFailure(LocationFailureReason.timeout);
    } on LocationServiceDisabledException {
      throw const LocationFailure(LocationFailureReason.serviceDisabled);
    } on Object {
      throw const LocationFailure(LocationFailureReason.unavailable);
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
