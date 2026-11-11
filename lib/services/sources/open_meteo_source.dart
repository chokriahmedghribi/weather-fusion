import 'package:dio/dio.dart';

import '../../core/weather_condition.dart';
import '../../models/geo.dart';
import '../../models/observation.dart';
import 'weather_source.dart';

/// Open-Meteo — free, no API key. Default source.
class OpenMeteoSource implements WeatherSource {
  final Dio dio;
  OpenMeteoSource(this.dio);

  @override
  String get id => 'open_meteo';
  @override
  String get displayName => 'Open-Meteo';
  @override
  double get reliability => 0.85;
  @override
  bool get isConfigured => true;

  static const _hourlyVars = 'temperature_2m,relative_humidity_2m,'
      'precipitation_probability,weather_code,cloud_cover,pressure_msl,'
      'visibility,wind_speed_10m,wind_direction_10m,wind_gusts_10m';
  static const _currentVars = 'temperature_2m,relative_humidity_2m,is_day,'
      'weather_code,cloud_cover,pressure_msl,wind_speed_10m,'
      'wind_direction_10m,wind_gusts_10m';

  @override
  Future<SourceReading> fetch(GeoPoint point) async {
    try {
      final res = await dio.get<Map<String, dynamic>>(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': point.lat,
          'longitude': point.lon,
          'current': _currentVars,
          'hourly': _hourlyVars,
          'wind_speed_unit': 'ms',
          'timeformat': 'unixtime',
          'timezone': 'UTC',
          'forecast_hours': 24,
        },
      );
      return parse(res.data!, point, DateTime.now().toUtc(),
          id: id, name: displayName, reliability: reliability);
    } on DioException catch (e) {
      throw SourceException(id, e.message ?? e.type.name);
    } catch (e) {
      throw SourceException(id, 'Unexpected response: $e');
    }
  }

  static DateTime _time(Object? unixSeconds) =>
      DateTime.fromMillisecondsSinceEpoch((unixSeconds as num).toInt() * 1000,
          isUtc: true);

  /// Separated from [fetch] so it can be unit-tested with a JSON fixture.
  static SourceReading parse(
    Map<String, dynamic> json,
    GeoPoint requested,
    DateTime fetchedAt, {
    String id = 'open_meteo',
    String name = 'Open-Meteo',
    double reliability = 0.85,
  }) {
    final grid = GeoPoint(
      asDouble(json['latitude']) ?? requested.lat,
      asDouble(json['longitude']) ?? requested.lon,
    );

    final h = (json['hourly'] as Map?)?.cast<String, dynamic>() ?? const {};
    final times = (h['time'] as List?) ?? const [];
    double? at(String key, int i) {
      final list = h[key] as List?;
      return (list == null || i >= list.length) ? null : asDouble(list[i]);
    }

    final hourly = <Observation>[
      for (var i = 0; i < times.length; i++)
        Observation(
          time: _time(times[i]),
          temperatureC: at('temperature_2m', i),
          humidityPct: at('relative_humidity_2m', i),
          pressureHpa: at('pressure_msl', i),
          windSpeedMs: at('wind_speed_10m', i),
          windDirDeg: at('wind_direction_10m', i),
          windGustMs: at('wind_gusts_10m', i),
          visibilityM: at('visibility', i),
          cloudCoverPct: at('cloud_cover', i),
          precipProbPct: at('precipitation_probability', i),
          condition: at('weather_code', i) == null
              ? null
              : conditionFromWmo(at('weather_code', i)!.toInt()),
        ),
    ];

    final c = (json['current'] as Map).cast<String, dynamic>();
    final currentTime = _time(c['time']);
    // Visibility and rain probability only exist in the hourly block.
    final near = nearestTo(hourly, currentTime);
    final code = asDouble(c['weather_code']);
    final isDay = asDouble(c['is_day']);

    return SourceReading(
      sourceId: id,
      sourceName: name,
      fetchedAt: fetchedAt,
      distanceKm: requested.distanceKmTo(grid),
      reliability: reliability,
      current: Observation(
        time: currentTime,
        temperatureC: asDouble(c['temperature_2m']),
        humidityPct: asDouble(c['relative_humidity_2m']),
        pressureHpa: asDouble(c['pressure_msl']),
        windSpeedMs: asDouble(c['wind_speed_10m']),
        windDirDeg: asDouble(c['wind_direction_10m']),
        windGustMs: asDouble(c['wind_gusts_10m']),
        visibilityM: near?.visibilityM,
        cloudCoverPct: asDouble(c['cloud_cover']),
        precipProbPct: near?.precipProbPct,
        condition: code == null ? null : conditionFromWmo(code.toInt()),
        isDay: isDay == null ? null : isDay == 1,
      ),
      hourly: hourly,
    );
  }
}
