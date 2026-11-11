import 'package:flutter_test/flutter_test.dart';
import 'package:weather_fusion/core/weather_condition.dart';
import 'package:weather_fusion/models/fused_weather.dart';
import 'package:weather_fusion/models/nowcast.dart';
import 'package:weather_fusion/nowcast/nowcast_engine.dart';
import 'package:weather_fusion/nowcast/pressure_trend.dart';

final t0 = DateTime.utc(2026, 1, 1, 12);

FusedWeather current({
  WeatherCondition cond = WeatherCondition.cloudy,
  double? pressure,
  double? wind,
}) =>
    FusedWeather(
      time: t0,
      condition: cond,
      pressureHpa: pressure,
      windSpeedMs: wind,
      confidence: 0.8,
    );

List<FusedWeather> hours(
  int count, {
  double? pop = 30,
  double? temp = 15,
  WeatherCondition cond = WeatherCondition.cloudy,
  double? Function(int h)? pressure,
  double? Function(int h)? wind,
}) =>
    [
      for (var h = 1; h <= count; h++)
        FusedWeather(
          time: t0.add(Duration(hours: h)),
          condition: cond,
          temperatureC: temp,
          precipProbPct: pop,
          pressureHpa: pressure?.call(h),
          windSpeedMs: wind?.call(h),
          confidence: 0.8,
        ),
    ];

void main() {
  const engine = NowcastEngine();

  group('PressureTrend.fromSamples', () {
    List<PressureSample> ramp(int minutes, double hpaPerHour) => [
          for (var m = minutes; m >= 0; m -= 10)
            PressureSample(t0.subtract(Duration(minutes: m)),
                1010 + hpaPerHour * (minutes - m) / 60),
        ];

    test('steady fall of 1 hPa/h → −3 hPa/3h, "falling"', () {
      final trend = PressureTrend.fromSamples(ramp(60, -1), t0)!;
      expect(trend.hpaPer3h, closeTo(-3, 1e-6));
      expect(trend.tendency, PressureTendency.falling);
      expect(trend.measured, isTrue);
    });

    test('tendency thresholds', () {
      PressureTendency of(double v) => PressureTrend(v, measured: true).tendency;
      expect(of(-4), PressureTendency.fallingFast);
      expect(of(-2), PressureTendency.falling);
      expect(of(0.5), PressureTendency.steady);
      expect(of(2), PressureTendency.rising);
      expect(of(4), PressureTendency.risingFast);
    });

    test('too little history → no trend rather than a noisy one', () {
      expect(PressureTrend.fromSamples(ramp(20, -1), t0), isNull);
      expect(PressureTrend.fromSamples([], t0), isNull);
    });

    test('samples older than 3 hours are ignored', () {
      final old = [
        for (var m = 300; m >= 200; m -= 10)
          PressureSample(t0.subtract(Duration(minutes: m)), 1000),
      ];
      expect(PressureTrend.fromSamples(old, t0), isNull);
    });
  });

  group('NowcastEngine', () {
    test('covers at most 6 hours', () {
      final n = engine.build(current: current(), hourly: hours(10));
      expect(n.steps, hasLength(6));
      expect(n.steps.first.leadHours, 1);
      expect(n.steps.last.leadHours, 6);
    });

    test('no hourly data → unavailable, no invented steps', () {
      final n = engine.build(current: current(), hourly: const []);
      expect(n.steps, isEmpty);
      expect(n.summary, NowcastSummary.unavailable);
    });

    test('measured fast pressure fall raises rain probability, less so later', () {
      final n = engine.build(
        current: current(),
        hourly: hours(6),
        barometerTrend: const PressureTrend(-4, measured: true),
      );
      expect(n.steps[0].precipProbPct, closeTo(55, 1e-9)); // +25
      expect(n.steps[2].precipProbPct, closeTo(55, 1e-9));
      expect(n.steps[3].precipProbPct, closeTo(42.5, 1e-9)); // +12.5 after 3 h
      expect(n.summary, NowcastSummary.rainPossible);
    });

    test('measured pressure rise lowers rain probability, never below 0', () {
      final n = engine.build(
        current: current(),
        hourly: hours(6, pop: 5),
        barometerTrend: const PressureTrend(4, measured: true),
      );
      expect(n.steps[0].precipProbPct, 0);
    });

    test('trend derived from the sources themselves is shown but not re-applied', () {
      final n = engine.build(
        current: current(pressure: 1015),
        hourly: hours(6, pressure: (h) => 1015 - 2.0 * h),
      );
      expect(n.trend, isNotNull);
      expect(n.trend!.measured, isFalse);
      expect(n.trend!.hpaPer3h, closeTo(-6, 1e-9));
      expect(n.steps.every((s) => s.precipProbPct == 30), isTrue);
      expect(n.summary, NowcastSummary.stable);
    });

    test('unknown rain probability stays unknown', () {
      final n = engine.build(
        current: current(),
        hourly: hours(3, pop: null),
        barometerTrend: const PressureTrend(-4, measured: true),
      );
      expect(n.steps.every((s) => s.precipProbPct == null), isTrue);
    });

    test('high probability turns a dry condition into rain, or snow when freezing', () {
      const fall = PressureTrend(-4, measured: true);
      final rain = engine.build(
          current: current(), hourly: hours(3, pop: 40), barometerTrend: fall);
      expect(rain.steps.first.condition, WeatherCondition.rain);
      expect(rain.summary, NowcastSummary.rainLikely);

      final snow = engine.build(
          current: current(), hourly: hours(3, pop: 40, temp: -2), barometerTrend: fall);
      expect(snow.steps.first.condition, WeatherCondition.snow);
    });

    test('confidence shrinks with lead time', () {
      final n = engine.build(current: current(), hourly: hours(6));
      for (var i = 1; i < n.steps.length; i++) {
        expect(n.steps[i].confidence, lessThan(n.steps[i - 1].confidence));
      }
      expect(n.steps.first.confidence, closeTo(0.8 * 0.95, 1e-9));
    });

    test('barometer contradicting the sources lowers confidence', () {
      final plain = engine.build(current: current(), hourly: hours(3));
      final contradicted = engine.build(
        current: current(),
        hourly: hours(3), // sources say 30 % …
        barometerTrend: const PressureTrend(-4, measured: true), // … barometer says rain
      );
      expect(contradicted.steps.first.confidence,
          lessThan(plain.steps.first.confidence));
    });

    test('summary: clearing and strengthening wind', () {
      final clearing = engine.build(
        current: current(cond: WeatherCondition.rain),
        hourly: hours(4, pop: 10),
      );
      expect(clearing.summary, NowcastSummary.clearing);

      final windy = engine.build(
        current: current(wind: 3),
        hourly: hours(4, pop: 0, wind: (h) => 3.0 + 2 * h),
      );
      expect(windy.summary, NowcastSummary.windIncreasing);
    });
  });
}
