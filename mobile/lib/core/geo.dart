import 'dart:math' as math;

export 'indonesia_regions.dart';

/// Haversine distance in kilometers.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
}

double _rad(double deg) => deg * math.pi / 180;

String formatDistanceKm(double? km) {
  if (km == null) return '—';
  if (km < 1) return '${(km * 1000).round()} m';
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}

/// "Tempat, Kab/Kota, Provinsi" → Provinsi (last comma part).
String eventProvince(String location) {
  final parts = location.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  return parts.last;
}

/// "Tempat, Kab/Kota, Provinsi" → Kab/Kota (second-last), else first part.
String eventCity(String location) {
  final parts = location.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (parts.length >= 2) return parts[parts.length - 2];
  if (parts.length == 1) return parts.first;
  return '';
}
