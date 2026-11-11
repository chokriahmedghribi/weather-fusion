import '../core/weather_condition.dart';

/// One normalized set of values for one instant, in canonical units
/// (°C, m/s, hPa at sea level, metres, %, UTC). Every field is nullable:
/// a source that does not provide a value leaves it null — never a guess.
class Observation {
  final DateTime time;
  final double? temperatureC;
  final double? humidityPct;
  final double? pressureHpa;
  final double? windSpeedMs;

  /// Direction the wind blows FROM, degrees clockwise from north.
  final double? windDirDeg;
  final double? windGustMs;
  final double? visibilityM;
  final double? cloudCoverPct;
  final double? precipProbPct;
  final WeatherCondition? condition;
  final bool? isDay;

  Observation({
    required DateTime time,
    this.temperatureC,
    this.humidityPct,
    this.pressureHpa,
    this.windSpeedMs,
    this.windDirDeg,
    this.windGustMs,
    this.visibilityM,
    this.cloudCoverPct,
    this.precipProbPct,
    this.condition,
    this.isDay,
  }) : time = time.toUtc();

  Map<String, dynamic> toJson() => {
        't': time.millisecondsSinceEpoch,
        'temp': temperatureC,
        'hum': humidityPct,
        'pres': pressureHpa,
        'ws': windSpeedMs,
        'wd': windDirDeg,
        'wg': windGustMs,
        'vis': visibilityM,
        'cloud': cloudCoverPct,
        'pop': precipProbPct,
        'cond': condition?.name,
        'day': isDay,
      };

  factory Observation.fromJson(Map<String, dynamic> j) {
    double? d(String k) => (j[k] as num?)?.toDouble();
    final cond = j['cond'] as String?;
    return Observation(
      time: DateTime.fromMillisecondsSinceEpoch(j['t'] as int, isUtc: true),
      temperatureC: d('temp'),
      humidityPct: d('hum'),
      pressureHpa: d('pres'),
      windSpeedMs: d('ws'),
      windDirDeg: d('wd'),
      windGustMs: d('wg'),
      visibilityM: d('vis'),
      cloudCoverPct: d('cloud'),
      precipProbPct: d('pop'),
      condition: cond == null
          ? null
          : WeatherCondition.values.asNameMap()[cond] ?? WeatherCondition.unknown,
      isDay: j['day'] as bool?,
    );
  }
}

/// Everything one source returned for one location.
class SourceReading {
  final String sourceId;
  final String sourceName;
  final DateTime fetchedAt;

  /// Distance between the requested point and the grid point / station
  /// the source actually answered for.
  final double distanceKm;

  /// Prior trust in the source, 0..1.
  final double reliability;
  final Observation current;
  final List<Observation> hourly;

  SourceReading({
    required this.sourceId,
    required this.sourceName,
    required DateTime fetchedAt,
    required this.distanceKm,
    required this.reliability,
    required this.current,
    this.hourly = const [],
  }) : fetchedAt = fetchedAt.toUtc();

  Map<String, dynamic> toJson() => {
        'id': sourceId,
        'name': sourceName,
        'fetched': fetchedAt.millisecondsSinceEpoch,
        'dist': distanceKm,
        'rel': reliability,
        'current': current.toJson(),
        'hourly': hourly.map((o) => o.toJson()).toList(),
      };

  factory SourceReading.fromJson(Map<String, dynamic> j) => SourceReading(
        sourceId: j['id'] as String,
        sourceName: j['name'] as String,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(j['fetched'] as int, isUtc: true),
        distanceKm: (j['dist'] as num).toDouble(),
        reliability: (j['rel'] as num).toDouble(),
        current: Observation.fromJson((j['current'] as Map).cast<String, dynamic>()),
        hourly: (j['hourly'] as List? ?? [])
            .map((e) => Observation.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
