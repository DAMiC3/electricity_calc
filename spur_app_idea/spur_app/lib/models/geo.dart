import 'dart:math' as math;

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

double haversineKm(LatLng a, LatLng b) {
  const R = 6371.0; // km
  final dLat = _deg2rad(b.lat - a.lat);
  final dLng = _deg2rad(b.lng - a.lng);
  final aa = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(a.lat)) * math.cos(_deg2rad(b.lat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
  return R * c;
}

double _deg2rad(double deg) => deg * (math.pi / 180.0);

