import 'dart:math' as math;

import '../core/units.dart';
import '../core/weather_condition.dart';
import '../models/fused_weather.dart';
import '../models/observation.dart';

class FusionConfig {
  /// A reading loses half of its weight every [recencyHalfLifeMin] minutes.
  final double recencyHalfLifeMin;

  /// Weight falls by 1/e every [distanceScaleKm] km from the requested point.
  final double distanceScaleKm;

  const FusionConfig({this.recencyHalfLifeMin = 60, this.distanceScaleKm = 50});
}

/// Per-variable settings: [outlierFloor] is the smallest deviation from the
/// median that can ever be called an outlier; [tolerance] is the average
/// disagreement at which the agreement score for that variable reaches zero.
class _Field {
  final String name;
  final double outlierFloor;
  final double tolerance;
  const _Field(this.name, this.outlierFloor, this.tolerance);

  static const temperature = _Field('temperature', 4, 3);
  static const humidity = _Field('humidity', 20, 15);
  static const pressure = _Field('pressure', 4, 3);
  static const windSpeed = _Field('windSpeed', 4, 3);
  static const windGust = _Field('windGust', 6, 5);
  static const cloudCover = _Field('cloudCover', 50, 40);
  static const precipProb = _Field('precipProb', 40, 30);
  // Visibility varies too much between models to reject or score.
  static const visibility = _Field('visibility', double.infinity, double.infinity);
}

class _Input {
  final Observation obs;
  final double weight;
  final double recency;
  final SourceReading source;
  const _Input(this.obs, this.weight, this.recency, this.source);
}

class _Sample {
  final double value;
  final _Input input;
  const _Sample(this.value, this.input);
}

/// Pure-Dart data fusion: no Flutter, no I/O, fully unit-testable.
class FusionEngine {
  final FusionConfig config;
  const FusionEngine({this.config = const FusionConfig()});

  double recencyOf(SourceReading r, DateTime now) {
    final ageMin = now.difference(r.current.time).inSeconds.abs() / 60;
    return math.pow(0.5, ageMin / config.recencyHalfLifeMin).toDouble();
  }

  /// weight = reliability × recency × proximity
  double weightOf(SourceReading r, DateTime now) {
    final proximity = math.exp(-r.distanceKm / config.distanceScaleKm);
    return math.max(1e-6, r.reliability * recencyOf(r, now) * proximity);
  }

  /// Fuses the "current" observation of every source. Null if no readings.
  FusedWeather? fuseCurrent(List<SourceReading> readings, DateTime now) {
    if (readings.isEmpty) return null;
    return _fuse(now.toUtc(), [
      for (final r in readings)
        _Input(r.current, weightOf(r, now), recencyOf(r, now), r),
    ], now);
  }

  /// Fuses the hourly forecasts for the next [hours] full hours.
  /// Hours for which no source has data are skipped (never invented).
  List<FusedWeather> fuseHourly(List<SourceReading> readings, DateTime now,
      {int hours = 12}) {
    final utc = now.toUtc();
    final base = DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
    final out = <FusedWeather>[];
    for (var h = 1; h <= hours; h++) {
      final target = base.add(Duration(hours: h));
      final inputs = <_Input>[];
      for (final r in readings) {
        for (final o in r.hourly) {
          if (o.time.difference(target).inMinutes.abs() <= 30) {
            inputs.add(_Input(o, weightOf(r, now), recencyOf(r, now), r));
            break;
          }
        }
      }
      if (inputs.isNotEmpty) out.add(_fuse(target, inputs, now));
    }
    return out;
  }

  FusedWeather _fuse(DateTime time, List<_Input> inputs, DateTime now) {
    final rejected = <RejectedValue>[];
    final agreementScores = <double>[];

    double? scalar(_Field f, double? Function(Observation o) get,
        {bool score = true}) {
      final samples = <_Sample>[
        for (final i in inputs)
          if (get(i.obs) != null && get(i.obs)!.isFinite) _Sample(get(i.obs)!, i),
      ];
      if (samples.isEmpty) return null;
      final kept = _rejectOutliers(samples, f, rejected);
      final mean = _weightedMean(kept);
      if (score && kept.length >= 2 && f.tolerance.isFinite) {
        final wSum = kept.fold<double>(0, (s, e) => s + e.input.weight);
        final mad = kept.fold<double>(
                0, (s, e) => s + e.input.weight * (e.value - mean).abs()) /
            wSum;
        agreementScores.add(1 - (mad / f.tolerance).clamp(0.0, 1.0).toDouble());
      }
      return mean;
    }

    final temp = scalar(_Field.temperature, (o) => o.temperatureC);
    final hum = scalar(_Field.humidity, (o) => o.humidityPct);
    final pres = scalar(_Field.pressure, (o) => o.pressureHpa);
    final vis = scalar(_Field.visibility, (o) => o.visibilityM, score: false);
    final cloud = scalar(_Field.cloudCover, (o) => o.cloudCoverPct, score: false);
    final pop = scalar(_Field.precipProb, (o) => o.precipProbPct, score: false);
    final gust = scalar(_Field.windGust, (o) => o.windGustMs, score: false);

    // ---- Wind: speed is a weighted scalar mean; direction is a VECTOR mean.
    final windSamples = <_Sample>[
      for (final i in inputs)
        if (i.obs.windSpeedMs != null && i.obs.windSpeedMs!.isFinite)
          _Sample(i.obs.windSpeedMs!, i),
    ];
    double? windSpeed, windDir, dirConsistency;
    if (windSamples.isNotEmpty) {
      final kept = _rejectOutliers(windSamples, _Field.windSpeed, rejected);
      final speed = _weightedMean(kept);
      windSpeed = speed;
      if (kept.length >= 2) {
        final wSum = kept.fold<double>(0, (s, e) => s + e.input.weight);
        final mad = kept.fold<double>(
                0, (s, e) => s + e.input.weight * (e.value - speed).abs()) /
            wSum;
        agreementScores.add(
            1 - (mad / _Field.windSpeed.tolerance).clamp(0.0, 1.0).toDouble());
      }
      var u = 0.0, v = 0.0, w = 0.0, speedW = 0.0;
      var dirCount = 0;
      for (final s in kept) {
        final dir = s.input.obs.windDirDeg;
        if (dir == null || !dir.isFinite || s.value <= 0) continue;
        final rad = dir * math.pi / 180;
        // Meteorological convention: direction is where the wind comes FROM.
        u += s.input.weight * (-s.value * math.sin(rad));
        v += s.input.weight * (-s.value * math.cos(rad));
        speedW += s.input.weight * s.value;
        w += s.input.weight;
        dirCount++;
      }
      if (w > 0) {
        final uMean = u / w, vMean = v / w;
        final magnitude = math.sqrt(uMean * uMean + vMean * vMean);
        final consistency =
            (magnitude / (speedW / w)).clamp(0.0, 1.0).toDouble();
        dirConsistency = consistency;
        // Calm air or sources cancelling each other: direction is meaningless.
        if (speed >= 0.5 && magnitude > 1e-6 && consistency >= 0.2) {
          windDir = Units.normalizeDeg(
              math.atan2(-uMean, -vMean) * 180 / math.pi);
        }
        if (dirCount >= 2 && speed >= 1.5) {
          agreementScores.add(consistency);
        }
      }
    }

    // ---- Condition: weighted vote, first by family, then inside the family.
    final groupVotes = <ConditionGroup, double>{};
    final condVotes = <WeatherCondition, double>{};
    var voteTotal = 0.0;
    var voters = 0;
    for (final i in inputs) {
      final c = i.obs.condition;
      if (c == null || c == WeatherCondition.unknown) continue;
      groupVotes[c.group] = (groupVotes[c.group] ?? 0) + i.weight;
      condVotes[c] = (condVotes[c] ?? 0) + i.weight;
      voteTotal += i.weight;
      voters++;
    }
    var condition = WeatherCondition.unknown;
    if (voteTotal > 0) {
      final topGroup =
          groupVotes.entries.reduce((a, b) => b.value > a.value ? b : a);
      condition = condVotes.entries
          .where((e) => e.key.group == topGroup.key)
          .reduce((a, b) => b.value > a.value ? b : a)
          .key;
      if (voters >= 2) agreementScores.add(topGroup.value / voteTotal);
    } else if (cloud != null) {
      // No source gave a condition: derive a sky state from cloud cover only.
      condition = cloud < 20
          ? WeatherCondition.clear
          : cloud < 70
              ? WeatherCondition.partlyCloudy
              : WeatherCondition.cloudy;
    }

    // ---- Confidence
    final totalWeight = inputs.fold<double>(0, (s, i) => s + i.weight);
    final freshness =
        inputs.fold<double>(0, (s, i) => s + i.weight * i.recency) / totalWeight;
    final n = inputs.length;
    final countFactor = n >= 3 ? 1.0 : (n == 2 ? 0.8 : 0.3);
    // With a single source nothing can be cross-checked: agreement is unknown.
    var agreement = agreementScores.isEmpty
        ? 0.4
        : agreementScores.reduce((a, b) => a + b) / agreementScores.length;
    agreement = math.max(0.0, agreement - 0.05 * rejected.length);
    final confidence =
        (0.35 * countFactor + 0.40 * agreement + 0.25 * freshness)
            .clamp(0.05, 0.98);

    bool? isDay;
    for (final i in inputs) {
      if (i.obs.isDay != null) {
        isDay = i.obs.isDay;
        break;
      }
    }

    return FusedWeather(
      time: time,
      temperatureC: temp,
      feelsLikeC: (temp != null && hum != null && windSpeed != null)
          ? Units.apparentTemperature(temp, hum, windSpeed)
          : null,
      humidityPct: hum,
      pressureHpa: pres,
      visibilityM: vis,
      cloudCoverPct: cloud,
      precipProbPct: pop,
      windSpeedMs: windSpeed,
      windDirDeg: windDir,
      windGustMs: gust,
      windDirConsistency: dirConsistency,
      condition: condition,
      isDay: isDay,
      confidence: confidence.toDouble(),
      contributions: [
        for (final i in inputs)
          SourceContribution(
            sourceId: i.source.sourceId,
            sourceName: i.source.sourceName,
            weight: i.weight / totalWeight,
            ageMinutes: now.difference(i.source.current.time).inMinutes.abs(),
            distanceKm: i.source.distanceKm,
          ),
      ],
      rejected: rejected,
    );
  }

  double _weightedMean(List<_Sample> s) {
    var sum = 0.0, w = 0.0;
    for (final e in s) {
      sum += e.value * e.input.weight;
      w += e.input.weight;
    }
    return sum / w;
  }

  /// Robust outlier rejection (median ± 3 scaled MAD, never tighter than the
  /// field's floor). Needs at least 3 values: with 2 there is no way to know
  /// which one is wrong, so both are kept and confidence drops instead.
  List<_Sample> _rejectOutliers(
      List<_Sample> samples, _Field f, List<RejectedValue> rejected) {
    if (samples.length < 3 || !f.outlierFloor.isFinite) return samples;
    final med = _median(samples.map((s) => s.value).toList());
    final mad = _median(samples.map((s) => (s.value - med).abs()).toList());
    final limit = math.max(3 * 1.4826 * mad, f.outlierFloor);
    final kept = <_Sample>[];
    for (final s in samples) {
      if ((s.value - med).abs() > limit) {
        rejected.add(RejectedValue(s.input.source.sourceName, f.name, s.value));
      } else {
        kept.add(s);
      }
    }
    return kept;
  }

  double _median(List<double> v) {
    v.sort();
    final m = v.length ~/ 2;
    return v.length.isOdd ? v[m] : (v[m - 1] + v[m]) / 2;
  }
}
