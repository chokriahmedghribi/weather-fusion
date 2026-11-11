import '../../models/geo.dart';
import '../../models/observation.dart';

/// Contract every weather provider implements. To add a provider:
/// implement this class, convert everything to canonical units
/// (°C, m/s, hPa MSL, metres, %, UTC), and register it in
/// `weatherSourcesProvider` (lib/state/providers.dart).
abstract class WeatherSource {
  String get id;
  String get displayName;

  /// Prior trust in this provider, 0..1. Used as a fusion weight factor.
  double get reliability;

  /// False when the provider needs an API key that is not configured.
  bool get isConfigured;

  Future<SourceReading> fetch(GeoPoint point);
}

class SourceException implements Exception {
  final String sourceId;
  final String message;
  const SourceException(this.sourceId, this.message);

  @override
  String toString() => 'SourceException($sourceId): $message';
}

double? asDouble(Object? v) => v is num ? v.toDouble() : null;

/// The observation closest in time to [t], or null if the list is empty.
Observation? nearestTo(List<Observation> list, DateTime t) {
  Observation? best;
  for (final o in list) {
    if (best == null ||
        o.time.difference(t).abs() < best.time.difference(t).abs()) {
      best = o;
    }
  }
  return best;
}
