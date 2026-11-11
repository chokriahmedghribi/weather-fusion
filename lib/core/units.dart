import 'dart:math' as math;

enum TempUnit { celsius, fahrenheit }

enum WindUnit { kmh, ms, mph }

/// Internal canonical units everywhere in the app:
/// temperature °C, wind m/s, pressure hPa (mean sea level), visibility m,
/// percentages 0..100, timestamps UTC. Convert only at the UI edge.
class Units {
  static double cToF(double c) => c * 9 / 5 + 32;
  static double fToC(double f) => (f - 32) * 5 / 9;
  static double kToC(double k) => k - 273.15;

  static double msToKmh(double v) => v * 3.6;
  static double kmhToMs(double v) => v / 3.6;
  static double msToMph(double v) => v * 2.2369362921;
  static double mphToMs(double v) => v / 2.2369362921;

  static double temp(double celsius, TempUnit u) =>
      u == TempUnit.celsius ? celsius : cToF(celsius);

  static double wind(double ms, WindUnit u) => switch (u) {
        WindUnit.ms => ms,
        WindUnit.kmh => msToKmh(ms),
        WindUnit.mph => msToMph(ms),
      };

  static const _beaufortLowerBounds = [
    0.3, 1.6, 3.4, 5.5, 8.0, 10.8, 13.9, 17.2, 20.8, 24.5, 28.5, 32.7,
  ];

  /// Beaufort number (0..12) from wind speed in m/s.
  static int beaufort(double ms) {
    var b = 0;
    for (final lower in _beaufortLowerBounds) {
      if (ms >= lower) b++;
    }
    return b;
  }

  /// Wraps any bearing into [0, 360).
  static double normalizeDeg(double d) {
    final r = d % 360; // Dart's % is never negative for a positive divisor.
    return r >= 360 ? 0 : r; // guards the -1e-17 % 360 == 360.0 rounding case
  }

  static const _cardinals = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

  /// 8-point compass key (N, NE, ...) for a bearing in degrees.
  static String cardinal(double deg) =>
      _cardinals[((normalizeDeg(deg) + 22.5) ~/ 45) % 8];

  /// Apparent ("feels like") temperature, Steadman / Australian BoM formula.
  /// Uses air temperature (°C), relative humidity (%) and wind (m/s).
  static double apparentTemperature(double tempC, double humidityPct, double windMs) {
    final e = humidityPct / 100 * 6.105 * math.exp(17.27 * tempC / (237.7 + tempC));
    return tempC + 0.33 * e - 0.70 * windMs - 4.0;
  }
}
