import '../models/geo.dart';
import '../models/observation.dart';
import '../models/weather_bundle.dart';
import '../services/cache_service.dart';
import '../services/sources/weather_source.dart';

class FetchResult {
  final List<SourceReading> readings;

  /// Display names of the sources that were tried and failed.
  final List<String> failed;

  /// How many sources were actually queried.
  final int attempted;

  const FetchResult(this.readings, this.failed, this.attempted);
}

class WeatherRepository {
  final List<WeatherSource> sources;
  final CacheService cache;
  WeatherRepository(this.sources, this.cache);

  /// Queries every enabled + configured source in parallel. One source
  /// failing never fails the whole refresh.
  Future<FetchResult> fetchAll(GeoPoint point, Set<String> enabledIds) async {
    final active = sources
        .where((s) => enabledIds.contains(s.id) && s.isConfigured)
        .toList();
    final failed = <String>[];
    final results = await Future.wait(active.map((s) async {
      try {
        return await s.fetch(point);
      } catch (_) {
        failed.add(s.displayName);
        return null;
      }
    }));
    return FetchResult(
      results.whereType<SourceReading>().toList(),
      failed,
      active.length,
    );
  }

  WeatherBundle? loadCached() => cache.load();
  Future<void> saveCache(WeatherBundle bundle) => cache.save(bundle);
}
