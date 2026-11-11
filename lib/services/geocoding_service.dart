import 'package:dio/dio.dart';

import '../models/geo.dart';

/// City search through the Open-Meteo geocoding API (no key).
class GeocodingService {
  final Dio dio;
  GeocodingService(this.dio);

  Future<List<Place>> search(String query, {String language = 'ar'}) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final res = await dio.get<Map<String, dynamic>>(
      'https://geocoding-api.open-meteo.com/v1/search',
      queryParameters: {'name': q, 'count': 8, 'language': language, 'format': 'json'},
    );
    final results = (res.data?['results'] as List?) ?? const [];
    return [
      for (final r in results.cast<Map>())
        if (r['latitude'] is num && r['longitude'] is num)
          Place(
            point: GeoPoint(
              (r['latitude'] as num).toDouble(),
              (r['longitude'] as num).toDouble(),
            ),
            name: [r['name'], r['admin1'], r['country']]
                .whereType<String>()
                .where((s) => s.isNotEmpty)
                .toSet()
                .join(language == 'ar' ? '، ' : ', '),
          ),
    ];
  }
}
