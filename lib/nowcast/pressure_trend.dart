class PressureSample {
  final DateTime time;
  final double hpa;

  PressureSample(DateTime time, this.hpa) : time = time.toUtc();

  Map<String, dynamic> toJson() => {'t': time.millisecondsSinceEpoch, 'p': hpa};

  factory PressureSample.fromJson(Map<String, dynamic> j) => PressureSample(
        DateTime.fromMillisecondsSinceEpoch(j['t'] as int, isUtc: true),
        (j['p'] as num).toDouble(),
      );
}

enum PressureTendency { fallingFast, falling, steady, rising, risingFast }

class PressureTrend {
  /// Change in hPa per 3 hours (negative = falling).
  final double hpaPer3h;

  /// True when measured by the phone barometer; false when derived from
  /// the sources' own pressure forecasts.
  final bool measured;

  const PressureTrend(this.hpaPer3h, {required this.measured});

  PressureTendency get tendency {
    if (hpaPer3h <= -3.5) return PressureTendency.fallingFast;
    if (hpaPer3h <= -1.6) return PressureTendency.falling;
    if (hpaPer3h >= 3.5) return PressureTendency.risingFast;
    if (hpaPer3h >= 1.6) return PressureTendency.rising;
    return PressureTendency.steady;
  }

  /// Least-squares slope of the barometer samples from the last 3 hours.
  /// Returns null unless the samples span at least [minSpan] — a trend from
  /// a few minutes of data would be noise presented as signal.
  static PressureTrend? fromSamples(
    List<PressureSample> samples,
    DateTime now, {
    Duration minSpan = const Duration(minutes: 30),
  }) {
    final from = now.toUtc().subtract(const Duration(hours: 3));
    final s = samples.where((e) => !e.time.isBefore(from)).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (s.length < 3 || s.last.time.difference(s.first.time) < minSpan) {
      return null;
    }
    final t0 = s.first.time;
    final xs = [for (final e in s) e.time.difference(t0).inSeconds / 3600.0];
    final ys = [for (final e in s) e.hpa];
    final n = s.length;
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    var cov = 0.0, den = 0.0;
    for (var i = 0; i < n; i++) {
      cov += (xs[i] - mx) * (ys[i] - my);
      den += (xs[i] - mx) * (xs[i] - mx);
    }
    if (den == 0) return null;
    return PressureTrend(cov / den * 3, measured: true);
  }
}
