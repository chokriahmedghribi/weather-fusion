import 'package:flutter_test/flutter_test.dart';
import 'package:weather_fusion/core/weather_condition.dart';
import 'package:weather_fusion/models/geo.dart';
import 'package:weather_fusion/models/observation.dart';
import 'package:weather_fusion/models/weather_bundle.dart';
import 'package:weather_fusion/services/sources/met_norway_source.dart';
import 'package:weather_fusion/services/sources/open_meteo_source.dart';
import 'package:weather_fusion/services/sources/open_weather_source.dart';

/// These check that every provider is normalized to the same units
/// (°C, m/s, hPa, metres, %, UTC) before fusion.
void main() {
  const here = GeoPoint(36.80, 10.18);
  final fetched = DateTime.utc(2026, 1, 1, 12, 10);
  final noon = DateTime.utc(2026, 1, 1, 12).millisecondsSinceEpoch ~/ 1000;

  test('Open-Meteo', () {
    final r = OpenMeteoSource.parse({
      'latitude': 36.75,
      'longitude': 10.25,
      'current': {
        'time': noon,
        'temperature_2m': 18.4,
        'relative_humidity_2m': 62,
        'is_day': 1,
        'weather_code': 61,
        'cloud_cover': 80,
        'pressure_msl': 1013.2,
        'wind_speed_10m': 4.5,
        'wind_direction_10m': 310,
        'wind_gusts_10m': 8.1,
      },
      'hourly': {
        'time': [noon, noon + 3600],
        'temperature_2m': [18.4, 18.9],
        'precipitation_probability': [45, null],
        'visibility': [24000, 22000],
        'weather_code': [61, 3],
      },
    }, here, fetched);

    expect(r.current.time, DateTime.utc(2026, 1, 1, 12));
    expect(r.current.temperatureC, 18.4);
    expect(r.current.windSpeedMs, 4.5);
    expect(r.current.windDirDeg, 310);
    expect(r.current.pressureHpa, 1013.2);
    expect(r.current.condition, WeatherCondition.rain);
    expect(r.current.isDay, isTrue);
    // Taken from the nearest hourly slot.
    expect(r.current.visibilityM, 24000);
    expect(r.current.precipProbPct, 45);
    expect(r.hourly, hasLength(2));
    expect(r.hourly[1].precipProbPct, isNull);
    expect(r.hourly[1].humidityPct, isNull); // column absent → null, not 0
    expect(r.distanceKm, greaterThan(1));
    expect(r.distanceKm, lessThan(15));
  });

  test('MET Norway', () {
    final r = MetNorwaySource.parse({
      'geometry': {
        'coordinates': [10.18, 36.8, 12]
      },
      'properties': {
        'timeseries': [
          {
            'time': '2026-01-01T12:00:00Z',
            'data': {
              'instant': {
                'details': {
                  'air_temperature': 17.9,
                  'relative_humidity': 65.0,
                  'air_pressure_at_sea_level': 1012.8,
                  'cloud_area_fraction': 75.0,
                  'wind_speed': 5.1,
                  'wind_from_direction': 300.0,
                  'wind_speed_of_gust': 9.0,
                }
              },
              'next_1_hours': {
                'summary': {'symbol_code': 'lightrain_day'},
                'details': {'probability_of_precipitation': 55.0},
              },
            },
          },
          {
            'time': '2026-01-01T13:00:00Z',
            'data': {
              'instant': {
                'details': {'air_temperature': 18.2}
              },
            },
          },
        ],
      },
    }, here, fetched);

    expect(r.current.time, DateTime.utc(2026, 1, 1, 12));
    expect(r.current.temperatureC, 17.9);
    expect(r.current.windSpeedMs, 5.1);
    expect(r.current.windGustMs, 9.0);
    expect(r.current.precipProbPct, 55);
    expect(r.current.condition, WeatherCondition.rain);
    expect(r.current.isDay, isTrue);
    expect(r.current.visibilityM, isNull); // MET does not provide it
    expect(r.hourly[1].condition, isNull);
    expect(r.distanceKm, closeTo(0, 1e-6));
  });

  test('OpenWeather', () {
    final r = OpenWeatherSource.parse({
      'coord': {'lat': 36.8, 'lon': 10.18},
      'dt': noon,
      'main': {'temp': 18.0, 'humidity': 60, 'pressure': 1013},
      'wind': {'speed': 4.0, 'deg': 320},
      'visibility': 10000,
      'clouds': {'all': 90},
      'weather': [
        {'id': 500, 'icon': '10d'}
      ],
    }, {
      'list': [
        {
          'dt': noon + 3 * 3600,
          'main': {'temp': 17.0, 'sea_level': 1011, 'pressure': 1012},
          'pop': 0.4,
        },
      ],
    }, here, fetched);

    expect(r.current.temperatureC, 18.0);
    expect(r.current.pressureHpa, 1013);
    expect(r.current.windGustMs, isNull);
    expect(r.current.condition, WeatherCondition.rain);
    expect(r.current.isDay, isTrue);
    expect(r.hourly.single.precipProbPct, closeTo(40, 1e-9)); // 0..1 → %
    expect(r.hourly.single.pressureHpa, 1011);
    expect(r.hourly.single.time, DateTime.utc(2026, 1, 1, 15));
  });

  test('cache round-trip keeps every value, including nulls', () {
    final reading = SourceReading(
      sourceId: 'x',
      sourceName: 'X',
      fetchedAt: fetched,
      distanceKm: 3.5,
      reliability: 0.8,
      current: Observation(
        time: fetched,
        temperatureC: 12.5,
        condition: WeatherCondition.fog,
        isDay: false,
      ),
    );
    final bundle = WeatherBundle(
      place: const Place(point: here, name: 'Tunis'),
      readings: [reading],
      fetchedAt: fetched,
      failedSources: const ['Y'],
      barometerTrendHpa3h: -1.2,
    );
    final copy = WeatherBundle.fromJson(bundle.toJson());
    expect(copy.place.name, 'Tunis');
    expect(copy.fetchedAt, fetched);
    expect(copy.failedSources, ['Y']);
    expect(copy.barometerTrendHpa3h, -1.2);
    expect(copy.stationPressureHpa, isNull);
    final c = copy.readings.single.current;
    expect(c.temperatureC, 12.5);
    expect(c.windSpeedMs, isNull);
    expect(c.condition, WeatherCondition.fog);
    expect(c.isDay, isFalse);
  });

  test('coordinates are coarsened to ~1 km before leaving the device', () {
    final p = const GeoPoint(36.806495, 10.181532, altitudeM: 40).rounded(2);
    expect(p.lat, 36.81);
    expect(p.lon, 10.18);
    expect(p.altitudeM, isNull);
  });
}
