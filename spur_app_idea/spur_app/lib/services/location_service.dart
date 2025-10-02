import '../models/geo.dart';

class LocationService {
  // In production, replace with geolocator/geocoding. For now, mock or use stored profile.
  LatLng? _last;

  Future<LatLng> getCurrentPosition({LatLng? fallback}) async {
    // Simulate a GPS fetch with a small delay
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _last ?? fallback ?? const LatLng(-33.9249, 18.4241); // default to Cape Town
  }

  void setMockPosition(LatLng pos) {
    _last = pos;
  }

  int estimateEtaMinutes(double distanceKm) {
    // naive: base 10 min + 3 min per km, capped 60
    final est = 10 + (distanceKm * 3).round();
    return est.clamp(5, 60);
  }
}

