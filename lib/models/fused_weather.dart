import '../core/weather_condition.dart';

enum ConfidenceLevel { low, medium, high }

ConfidenceLevel confidenceLevel(double c) => c >= 0.75
    ? ConfidenceLevel.high
    : c >= 0.55
        ? ConfidenceLevel.medium
        : ConfidenceLevel.low;

class SourceContribution {
  final String sourceId;
  final String sourceName;

  /// Share of the total weight, 0..1 (all contributions sum to 1).
  final double weight;
  final int ageMinutes;
  final double distanceKm;

  const SourceContribution({
    required this.sourceId,
    required this.sourceName,
    required this.weight,
    required this.ageMinutes,
    required this.distanceKm,
  });
}

class RejectedValue {
  final String sourceName;
  final String field;
  final double value;
  const RejectedValue(this.sourceName, this.field, this.value);
}

/// Result of fusing several sources for one instant.
class FusedWeather {
  final DateTime time;
  final double? temperatureC;
  final double? feelsLikeC;
  final double? humidityPct;
  final double? pressureHpa;
  final double? visibilityM;
  final double? cloudCoverPct;
  final double? precipProbPct;
  final double? windSpeedMs;
  final double? windDirDeg;
  final double? windGustMs;

  /// 0..1 — how well the sources agree on wind direction (1 = identical).
  final double? windDirConsistency;
  final WeatherCondition condition;
  final bool? isDay;

  /// 0..1 overall confidence.
  final double confidence;
  final List<SourceContribution> contributions;
  final List<RejectedValue> rejected;

  const FusedWeather({
    required this.time,
    this.temperatureC,
    this.feelsLikeC,
    this.humidityPct,
    this.pressureHpa,
    this.visibilityM,
    this.cloudCoverPct,
    this.precipProbPct,
    this.windSpeedMs,
    this.windDirDeg,
    this.windGustMs,
    this.windDirConsistency,
    this.condition = WeatherCondition.unknown,
    this.isDay,
    this.confidence = 0,
    this.contributions = const [],
    this.rejected = const [],
  });

  ConfidenceLevel get level => confidenceLevel(confidence);
}
