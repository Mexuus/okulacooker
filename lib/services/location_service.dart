import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../data/regions.dart';
import '../data/zip_states.dart';
import '../models/store.dart';
import 'zip_locator.dart';

/// A raw GPS fix.
class GeoFix {
  final double lat;
  final double lng;
  const GeoFix(this.lat, this.lng);
}

enum LocationFailure {
  serviceDisabled,
  denied,
  deniedForever,
  timeout,
  outsideUs,
  unknown,
}

class LocationException implements Exception {
  final LocationFailure reason;
  final String? detail;
  const LocationException(this.reason, [this.detail]);

  String get message {
    switch (reason) {
      case LocationFailure.serviceDisabled:
        return 'Location services are turned off. Turn them on, or enter your ZIP.';
      case LocationFailure.denied:
        return 'Location permission was declined. You can enter your ZIP instead.';
      case LocationFailure.deniedForever:
        return 'Location access is blocked. Allow it in your browser or device settings, or enter your ZIP.';
      case LocationFailure.timeout:
        return 'Couldn’t get a location fix in time. Try again or enter your ZIP.';
      case LocationFailure.outsideUs:
        return 'You appear to be outside the US. TapCook supports US stores only.';
      case LocationFailure.unknown:
        return 'Couldn’t determine your location${detail == null ? '' : ' ($detail)'}.';
    }
  }

  @override
  String toString() => message;
}

/// Source of GPS fixes. Abstracted so the app can be tested without a device.
abstract class GeoProvider {
  Future<GeoFix> currentFix();
}

/// Device GPS via the geolocator plugin (iOS Core Location / browser
/// Geolocation API). No third-party service or key involved.
class DeviceGeoProvider implements GeoProvider {
  final Duration timeout;
  const DeviceGeoProvider({this.timeout = const Duration(seconds: 15)});

  @override
  Future<GeoFix> currentFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationFailure.serviceDisabled);
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw const LocationException(LocationFailure.denied);
    }
    if (perm == LocationPermission.deniedForever) {
      throw const LocationException(LocationFailure.deniedForever);
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: timeout,
        ),
      );
      return GeoFix(pos.latitude, pos.longitude);
    } on TimeoutException {
      throw const LocationException(LocationFailure.timeout);
    } on LocationServiceDisabledException {
      throw const LocationException(LocationFailure.serviceDisabled);
    } on PermissionDeniedException {
      throw const LocationException(LocationFailure.denied);
    } catch (e) {
      throw LocationException(LocationFailure.unknown, e.toString());
    }
  }
}

/// Everything TapCook knows about a place, derived fully offline.
class PlaceInfo {
  final String zip;
  final double lat;
  final double lng;
  final String? state;
  final Region region;

  const PlaceInfo({
    required this.zip,
    required this.lat,
    required this.lng,
    required this.state,
    required this.region,
  });

  String get stateName => kStateNames[state] ?? state ?? 'Unknown';
}

/// Detects the user's ZIP from GPS and resolves ZIP codes to coordinates.
class LocationService {
  /// Beyond this distance from any US ZIP centroid we treat the user as abroad.
  static const double maxDistanceKm = 80;

  final GeoProvider geo;
  final Future<ZipLocator> Function() _zipLoader;

  LocationService({
    GeoProvider? geo,
    Future<ZipLocator> Function()? zipLoader,
  })  : geo = geo ?? const DeviceGeoProvider(),
        _zipLoader = zipLoader ?? ZipLocator.load;

  PlaceInfo _place(ZipPoint p) => PlaceInfo(
        zip: p.zip,
        lat: p.lat,
        lng: p.lng,
        state: stateForZip(p.zip),
        region: regionForZip(p.zip),
      );

  /// Uses device location to find the nearest US ZIP.
  Future<PlaceInfo> detect() async {
    final fix = await geo.currentFix();
    final zips = await _zipLoader();
    final p = zips.nearest(fix.lat, fix.lng);
    if (p == null ||
        haversineKm(fix.lat, fix.lng, p.lat, p.lng) > maxDistanceKm) {
      throw const LocationException(LocationFailure.outsideUs);
    }
    return _place(p);
  }

  /// Resolves a typed ZIP to its centroid; null if it isn't a known US ZIP.
  Future<PlaceInfo?> resolveZip(String zip) async {
    if (!isValidZip(zip)) return null;
    final zips = await _zipLoader();
    final p = zips.lookup(zip);
    return p == null ? null : _place(p);
  }
}
