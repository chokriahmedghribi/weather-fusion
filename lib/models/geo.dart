import 'dart:math' as math;

class GeoPoint {
  final double lat;
  final double lon;
  final double? altitudeM;

  const GeoPoint(this.lat, this.lon, {this.altitudeM});

  /// Coarsens the coordinates (2 decimals ≈ 1.1 km) before they leave the device.
  GeoPoint rounded(int decimals) {
    final f = math.pow(10, decimals).toDouble();
    return GeoPoint((lat * f).round() / f, (lon * f).round() / f);
  }

  /// Great-circle (haversine) distance in kilometres.
  double distanceKmTo(GeoPoint o) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(o.lat - lat);
    final dLon = rad(o.lon - lon);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat)) * math.cos(rad(o.lat)) * math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon, 'alt': altitudeM};

  factory GeoPoint.fromJson(Map<String, dynamic> j) => GeoPoint(
        (j['lat'] as num).toDouble(),
        (j['lon'] as num).toDouble(),
        altitudeM: (j['alt'] as num?)?.toDouble(),
      );
}

class Place {
  final GeoPoint point;

  /// City name for manual places; null for the GPS position.
  final String? name;
  final bool fromGps;

  const Place({required this.point, this.name, this.fromGps = false});

  Map<String, dynamic> toJson() =>
      {'point': point.toJson(), 'name': name, 'gps': fromGps};

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        point: GeoPoint.fromJson((j['point'] as Map).cast<String, dynamic>()),
        name: j['name'] as String?,
        fromGps: j['gps'] as bool? ?? false,
      );
}
