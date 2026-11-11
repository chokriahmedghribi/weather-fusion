import 'package:dio/dio.dart';

import '../../core/env.dart';
import '../../core/weather_condition.dart';
import '../../models/geo.dart';
import '../../models/observation.dart';
import 'weather_source.dart';

/// OpenWeather — optional, enabled only when OPENWEATHER_API_KEY is set.
/// Uses the free "current weather" and "5 day / 3 hour forecast" endpoints,
/// so it contributes to the hourly fusion every third hour only.
class OpenWeatherSource implements WeatherSource {
  final Dio dio;
  final String apiKey;
  OpenWeatherSource(this.dio, {this.apiKey = Env.openWeatherApiKey});

  @override
  String get id => 'open_weather';
  @override
  String get displayName => 'OpenWeather';
  @override
  double get reliability => 0.75;
  @override
  bool get isConfigured => apiKey.isNotEmpty;

  @override
  Future<SourceReading> fetch(GeoPoint point) async {
    if (!isConfigured) throw SourceException(id, 'API key not configured');
    final query = {
      'lat': point.lat,
      'lon': point.lon,
      'appid': apiKey,
      'units': 'metric', // °C and m/s
    };
    try {
      final current = await dio.get<Map<String, dynamic>>(
        'https://api.openweathermap.org/data/2.5/weather',
        queryParameters: query,
      );
      Map<String, dynamic>? forecast;
      try {
        forecast = (await dio.get<Map<String, dynamic>>(
          'https://api.openweathermap.org/data/2.5/forecast',
          queryParameters: {...query, 'cnt': 8},
        ))
            .data;
      } on DioException {
        forecast = null; // Current conditions alone are still useful.
      }
      return parse(current.data!, forecast, point, DateTime.now().toUtc(),
          id: id, name: displayName, reliability: reliability);
    } on DioException catch (e) {
      // Never include e.requestOptions.uri here: it contains the API key.
      final code = e.response?.statusCode;
      throw SourceException(id, code == null ? e.type.name : 'HTTP $code');
    } catch (_) {
      throw SourceException(id, 'Unexpected response');
    }
  }

  static Observation _observation(Map<String, dynamic> j) {
    final main = (j['main'] as Map?) ?? const {};
    final wind = (j['wind'] as Map?) ?? const {};
    final weather = j['weather'] as List?;
    final first = (weather == null || weather.isEmpty) ? null : weather.first as Map;
    final condId = asDouble(first?['id']);
    final icon = first?['icon'] as String?; // e.g. "10d" / "10n"
    final pop = asDouble(j['pop']);
    return Observation(
      time: DateTime.fromMillisecondsSinceEpoch((j['dt'] as num).toInt() * 1000,
          isUtc: true),
      temperatureC: asDouble(main['temp']),
      humidityPct: asDouble(main['humidity']),
      // "sea_level" when present, otherwise "pressure" (also sea-level hPa).
      pressureHpa: asDouble(main['sea_level']) ?? asDouble(main['pressure']),
      windSpeedMs: asDouble(wind['speed']),
      windDirDeg: asDouble(wind['deg']),
      windGustMs: asDouble(wind['gust']),
      visibilityM: asDouble(j['visibility']),
      cloudCoverPct: asDouble((j['clouds'] as Map?)?['all']),
      precipProbPct: pop == null ? null : pop * 100,
      condition: condId == null ? null : conditionFromOpenWeatherId(condId.toInt()),
      isDay: icon == null
          ? null
          : icon.endsWith('d')
              ? true
              : icon.endsWith('n')
                  ? false
                  : null,
    );
  }

  static SourceReading parse(
    Map<String, dynamic> current,
    Map<String, dynamic>? forecast,
    GeoPoint requested,
    DateTime fetchedAt, {
    String id = 'open_weather',
    String name = 'OpenWeather',
    double reliability = 0.75,
  }) {
    final coord = current['coord'] as Map?;
    final grid = GeoPoint(
      asDouble(coord?['lat']) ?? requested.lat,
      asDouble(coord?['lon']) ?? requested.lon,
    );
    return SourceReading(
      sourceId: id,
      sourceName: name,
      fetchedAt: fetchedAt,
      distanceKm: requested.distanceKmTo(grid),
      reliability: reliability,
      current: _observation(current),
      hourly: [
        for (final e in (forecast?['list'] as List?) ?? const [])
          _observation((e as Map).cast<String, dynamic>()),
      ],
    );
  }
}
