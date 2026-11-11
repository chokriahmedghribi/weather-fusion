import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_fusion/core/weather_condition.dart';
import 'package:weather_fusion/fusion/fusion_engine.dart';
import 'package:weather_fusion/models/fused_weather.dart';
import 'package:weather_fusion/models/observation.dart';

final now = DateTime.utc(2026, 1, 1, 12, 20);

SourceReading reading(
  String id, {
  double? temp,
  double? hum,
  double? pres,
  double? ws,
  double? wd,
  double? vis,
  WeatherCondition? cond,
  int ageMin = 0,
  double distKm = 0,
  double reliability = 1,
  List<Observation> hourly = const [],
}) =>
    SourceReading(
      sourceId: id,
      sourceName: id,
      fetchedAt: now,
      distanceKm: distKm,
      reliability: reliability,
      current: Observation(
        time: now.subtract(Duration(minutes: ageMin)),
        temperatureC: temp,
        humidityPct: hum,
        pressureHpa: pres,
        windSpeedMs: ws,
        windDirDeg: wd,
        visibilityM: vis,
        condition: cond,
      ),
      hourly: hourly,
    );

/// Smallest angle between two bearings.
double angleDiff(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

void main() {
  const engine = FusionEngine();

  group('weighted mean', () {
    test('no readings → null', () {
      expect(engine.fuseCurrent([], now), isNull);
    });

    test('equal weights → plain mean', () {
      final f = engine.fuseCurrent(
          [reading('a', temp: 20, pres: 1010), reading('b', temp: 22, pres: 1012)], now)!;
      expect(f.temperatureC, closeTo(21, 1e-9));
      expect(f.pressureHpa, closeTo(1011, 1e-9));
      expect(f.contributions.map((c) => c.weight).reduce((a, b) => a + b),
          closeTo(1, 1e-9));
    });

    test('fresher data weighs more (half-life 60 min)', () {
      final f = engine.fuseCurrent(
          [reading('a', temp: 20), reading('b', temp: 24, ageMin: 60)], now)!;
      // weights 1 and 0.5 → (20 + 12) / 1.5
      expect(f.temperatureC, closeTo(21.3333, 1e-3));
    });

    test('nearer grid point weighs more', () {
      final f = engine.fuseCurrent(
          [reading('a', temp: 20), reading('b', temp: 24, distKm: 50)], now)!;
      final w = math.exp(-1);
      expect(f.temperatureC, closeTo((20 + 24 * w) / (1 + w), 1e-9));
    });

    test('more reliable source weighs more', () {
      final f = engine.fuseCurrent(
          [reading('a', temp: 20, reliability: 0.9), reading('b', temp: 24, reliability: 0.3)],
          now)!;
      expect(f.temperatureC, closeTo(21, 1e-9));
    });

    test('missing values stay null — nothing is invented', () {
      final f = engine.fuseCurrent(
          [reading('a', temp: 20, ws: 3), reading('b', temp: 21, ws: 3)], now)!;
      expect(f.visibilityM, isNull);
      expect(f.humidityPct, isNull);
      expect(f.feelsLikeC, isNull); // needs humidity
      expect(f.windGustMs, isNull);
      expect(f.condition, WeatherCondition.unknown);
    });

    test('a value given by one source only is still used', () {
      final f = engine.fuseCurrent(
          [reading('a', temp: 20, vis: 9000), reading('b', temp: 21)], now)!;
      expect(f.visibilityM, 9000);
    });
  });

  group('outlier rejection', () {
    test('with 3 sources the odd one out is discarded', () {
      final f = engine.fuseCurrent([
        reading('a', temp: 20),
        reading('b', temp: 20.4),
        reading('broken', temp: 35),
      ], now)!;
      expect(f.temperatureC, closeTo(20.2, 1e-9));
      expect(f.rejected, hasLength(1));
      expect(f.rejected.single.sourceName, 'broken');
      expect(f.rejected.single.field, 'temperature');
    });

    test('normal spread is not rejected', () {
      final f = engine.fuseCurrent(
          [reading('a', temp: 19), reading('b', temp: 20), reading('c', temp: 22)], now)!;
      expect(f.rejected, isEmpty);
      expect(f.temperatureC, closeTo(20.3333, 1e-3));
    });

    test('with 2 sources nothing is rejected, confidence drops instead', () {
      final agree = engine.fuseCurrent(
          [reading('a', temp: 20, pres: 1010, ws: 4), reading('b', temp: 20.5, pres: 1010, ws: 4)],
          now)!;
      final disagree = engine.fuseCurrent(
          [reading('a', temp: 20, pres: 1010, ws: 4), reading('b', temp: 31, pres: 1010, ws: 4)],
          now)!;
      expect(disagree.rejected, isEmpty);
      expect(disagree.temperatureC, closeTo(25.5, 1e-9));
      expect(disagree.confidence, lessThan(agree.confidence));
    });
  });

  group('wind', () {
    test('direction is a vector mean: 350° and 10° → north, not 180°', () {
      final f = engine.fuseCurrent(
          [reading('a', ws: 5, wd: 350), reading('b', ws: 5, wd: 10)], now)!;
      expect(angleDiff(f.windDirDeg!, 0), lessThan(1e-6));
      expect(f.windSpeedMs, closeTo(5, 1e-9));
    });

    test('simple quadrants', () {
      for (final d in [0.0, 90.0, 180.0, 270.0, 45.0, 225.0]) {
        final f = engine.fuseCurrent([reading('a', ws: 6, wd: d)], now)!;
        expect(angleDiff(f.windDirDeg!, d), lessThan(1e-6), reason: 'bearing $d');
      }
    });

    test('stronger wind pulls the direction towards itself', () {
      final f = engine.fuseCurrent(
          [reading('a', ws: 9, wd: 0), reading('b', ws: 3, wd: 90)], now)!;
      expect(f.windDirDeg!, greaterThan(0));
      expect(f.windDirDeg!, lessThan(45));
      // Speed is the scalar mean, not the (shorter) vector length.
      expect(f.windSpeedMs, closeTo(6, 1e-9));
    });

    test('opposite winds cancel → no direction is claimed', () {
      final f = engine.fuseCurrent(
          [reading('a', ws: 5, wd: 90), reading('b', ws: 5, wd: 270)], now)!;
      expect(f.windDirDeg, isNull);
      expect(f.windDirConsistency, closeTo(0, 1e-6));
      expect(f.windSpeedMs, closeTo(5, 1e-9));
    });

    test('calm air has no direction', () {
      final f = engine.fuseCurrent(
          [reading('a', ws: 0.2, wd: 90), reading('b', ws: 0.1, wd: 100)], now)!;
      expect(f.windDirDeg, isNull);
    });
  });

  group('condition and confidence', () {
    test('condition is a weighted vote by family', () {
      final f = engine.fuseCurrent([
        reading('a', cond: WeatherCondition.rain),
        reading('b', cond: WeatherCondition.heavyRain),
        reading('c', cond: WeatherCondition.clear),
      ], now)!;
      expect(f.condition.isPrecipitation, isTrue);
    });

    test('single source → low confidence', () {
      final f = engine.fuseCurrent(
          [reading('a', temp: 20, pres: 1010, ws: 4, wd: 90)], now)!;
      expect(f.level, ConfidenceLevel.low);
    });

    test('three fresh agreeing sources → high confidence', () {
      final f = engine.fuseCurrent([
        reading('a', temp: 20, pres: 1010, ws: 4, wd: 90, cond: WeatherCondition.cloudy),
        reading('b', temp: 20.3, pres: 1010.5, ws: 4.2, wd: 95, cond: WeatherCondition.cloudy),
        reading('c', temp: 19.8, pres: 1009.8, ws: 3.9, wd: 85, cond: WeatherCondition.cloudy),
      ], now)!;
      expect(f.level, ConfidenceLevel.high);
      expect(f.confidence, lessThanOrEqualTo(0.98));
    });

    test('stale data lowers confidence', () {
      List<SourceReading> pair(int age) => [
            reading('a', temp: 20, pres: 1010, ageMin: age),
            reading('b', temp: 20, pres: 1010, ageMin: age),
          ];
      expect(engine.fuseCurrent(pair(180), now)!.confidence,
          lessThan(engine.fuseCurrent(pair(0), now)!.confidence));
    });
  });

  group('hourly fusion', () {
    test('aligns sources on the hour and skips hours without data', () {
      Observation at(int hour, double t) =>
          Observation(time: DateTime.utc(2026, 1, 1, hour), temperatureC: t);
      final f = engine.fuseHourly([
        reading('a', temp: 9, hourly: [at(12, 9), at(13, 10), at(14, 11)]),
        reading('b', temp: 9, hourly: [at(13, 12)]),
      ], now);
      expect(f, hasLength(2)); // 13:00 and 14:00 only
      expect(f[0].time, DateTime.utc(2026, 1, 1, 13));
      expect(f[0].temperatureC, closeTo(11, 1e-9));
      expect(f[0].contributions, hasLength(2));
      expect(f[1].temperatureC, closeTo(11, 1e-9));
      expect(f[1].contributions, hasLength(1));
    });
  });
}
