import 'package:dio/dio.dart';

import '../../core/env.dart';
import '../../core/weather_condition.dart';
import '../../models/geo.dart';
import '../../models/observation.dart';
import 'weather_source.dart';

/// MET Norway Locationforecast 2.0 — free, no key, but the terms of service
/// require an identifying User-Agent (set MET_NO_USER_AGENT in .env).
/// Does not provide visibility; that field stays null for this source.
class MetNorwaySource implements WeatherSource {
  final Dio dio;
  MetNorwaySource(this.dio);

  @override
  String get id => 'met_norway';
  @override
  String get displayName => 'MET Norway';
  @override
  double get reliability => 0.85;
  @override
  bool get isConfigured => true;

  @override
  Future<SourceReading> fetch(GeoPoint point) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        'https://api.met.no/weatherapi/locationforecast/2.0/complete',
        // MET asks for at most 4 decimals; the app already sends only 2.
        queryParameters: {
          'lat': point.lat.toStringAsFixed(4),
          'lon': point.lon.toStringAsFixed(4),
        },
        options: Options(headers: {'User-Agent': Env.metNoUserAgent}),
      );
      return parse(res.data!, point, DateTime.now().toUtc(),
          id: id, name: displayName, reliability: reliability);
    } on DioException catch (e) {
      throw SourceException(id, e.message ?? e.type.name);
    } catch (e) {
      throw SourceException(id, 'Unexpected response: $e');
    }
  }

  static SourceReading parse(
    Map<String, dynamic> json,
    GeoPoint requested,
    DateTime fetchedAt, {
    String id = 'met_norway',
    String name = 'MET Norway',
    double reliability = 0.85,
  }) {
    var grid = requested;
    final coords = (json['geometry'] as Map?)?['coordinates'] as List?;
    if (coords != null && coords.length >= 2) {
      // GeoJSON order: [lon, lat, altitude]
      grid = GeoPoint(asDouble(coords[1]) ?? requested.lat,
          asDouble(coords[0]) ?? requested.lon);
    }

    final series = ((json['properties'] as Map)['timeseries'] as List);
    final all = <Observation>[];
    for (final raw in series.take(30)) {
      final entry = (raw as Map).cast<String, dynamic>();
      final data = (entry['data'] as Map).cast<String, dynamic>();
      final d = (((data['instant'] as Map?)?['details']) as Map?) ?? const {};
      final next = data['next_1_hours'] as Map?;
      final symbol = (next?['summary'] as Map?)?['symbol_code'] as String?;
      final nextDetails = next?['details'] as Map?;
      all.add(Observation(
        time: DateTime.parse(entry['time'] as String),
        temperatureC: asDouble(d['air_temperature']),
        humidityPct: asDouble(d['relative_humidity']),
        pressureHpa: asDouble(d['air_pressure_at_sea_level']),
        windSpeedMs: asDouble(d['wind_speed']),
        windDirDeg: asDouble(d['wind_from_direction']),
        windGustMs: asDouble(d['wind_speed_of_gust']),
        cloudCoverPct: asDouble(d['cloud_area_fraction']),
        precipProbPct: asDouble(nextDetails?['probability_of_precipitation']),
        condition: symbol == null ? null : conditionFromMetNoSymbol(symbol),
        isDay: symbol == null
            ? null
            : symbol.endsWith('_day')
                ? true
                : symbol.endsWith('_night')
                    ? false
                    : null,
      ));
    }
    final current = nearestTo(all, fetchedAt);
    if (current == null) {
      throw const FormatException('empty timeseries');
    }

    return SourceReading(
      sourceId: id,
      sourceName: name,
      fetchedAt: fetchedAt,
      distanceKm: requested.distanceKmTo(grid),
      reliability: reliability,
      current: current,
      hourly: all,
    );
  }
}
