import '../core/weather_condition.dart';
import '../nowcast/pressure_trend.dart';
import 'fused_weather.dart';

class NowcastStep {
  final DateTime time;
  final int leadHours;
  final WeatherCondition condition;
  final double? temperatureC;
  final double? precipProbPct;
  final double? windSpeedMs;
  final double? windDirDeg;
  final double confidence;

  const NowcastStep({
    required this.time,
    required this.leadHours,
    required this.condition,
    this.temperatureC,
    this.precipProbPct,
    this.windSpeedMs,
    this.windDirDeg,
    required this.confidence,
  });

  ConfidenceLevel get level => confidenceLevel(confidence);
}

enum NowcastSummary { stable, rainLikely, rainPossible, clearing, windIncreasing, unavailable }

class Nowcast {
  final List<NowcastStep> steps;

  /// Pressure tendency used (measured by the phone barometer, or derived
  /// from the sources' own forecasts when no barometer history exists).
  final PressureTrend? trend;
  final NowcastSummary summary;

  const Nowcast({required this.steps, this.trend, required this.summary});
}
