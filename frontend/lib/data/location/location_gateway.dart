import 'dart:async';
import 'dart:math' as math;

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

const _earthRadiusMeters = 6371000.0;

/// 두 좌표 사이의 거리(m) — 하버사인.
///
/// 위치 인증의 거리 판정은 **단말 안에서** 끝나야 하므로(좌표 비전송 불변식,
/// docs/specs/050-quest-verification/location-law-review.md) 이 계산이 그 판정의
/// 전부다. 플러그인이 아닌 순수 함수라 위젯 테스트에서도 그대로 검증된다.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  final phi1 = _radians(lat1);
  final phi2 = _radians(lat2);
  final deltaPhi = _radians(lat2 - lat1);
  final deltaLambda = _radians(lng2 - lng1);
  final a =
      math.pow(math.sin(deltaPhi / 2), 2) +
      math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(deltaLambda / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.sqrt(a.toDouble()));
}

double _radians(double degrees) => degrees * math.pi / 180;

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
