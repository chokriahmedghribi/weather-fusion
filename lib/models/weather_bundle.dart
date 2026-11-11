import 'geo.dart';
import 'observation.dart';

/// The raw, cacheable result of one refresh. Fusion and nowcast are pure
/// functions of this bundle, so the offline view is re-derived from it.
class WeatherBundle {
  final Place place;
  final List<SourceReading> readings;
  final DateTime fetchedAt;

  /// Names of sources that failed during this refresh.
  final List<String> failedSources;

  /// Raw station pressure from the phone barometer (not sea-level), if any.
  final double? stationPressureHpa;

  /// Barometer tendency in hPa per 3 hours, if enough history exists.
  final double? barometerTrendHpa3h;

  WeatherBundle({
    required this.place,
    required this.readings,
    required DateTime fetchedAt,
    this.failedSources = const [],
    this.stationPressureHpa,
    this.barometerTrendHpa3h,
  }) : fetchedAt = fetchedAt.toUtc();

  Map<String, dynamic> toJson() => {
        'place': place.toJson(),
        'readings': readings.map((r) => r.toJson()).toList(),
        'fetched': fetchedAt.millisecondsSinceEpoch,
        'failed': failedSources,
        'station': stationPressureHpa,
        'trend': barometerTrendHpa3h,
      };

  factory WeatherBundle.fromJson(Map<String, dynamic> j) => WeatherBundle(
        place: Place.fromJson((j['place'] as Map).cast<String, dynamic>()),
        readings: (j['readings'] as List)
            .map((e) => SourceReading.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(j['fetched'] as int, isUtc: true),
        failedSources: (j['failed'] as List? ?? []).cast<String>(),
        stationPressureHpa: (j['station'] as num?)?.toDouble(),
        barometerTrendHpa3h: (j['trend'] as num?)?.toDouble(),
      );
}
