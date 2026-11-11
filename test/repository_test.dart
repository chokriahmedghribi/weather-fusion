import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_fusion/models/geo.dart';
import 'package:weather_fusion/models/observation.dart';
import 'package:weather_fusion/models/weather_bundle.dart';
import 'package:weather_fusion/repositories/weather_repository.dart';
import 'package:weather_fusion/services/cache_service.dart';
import 'package:weather_fusion/services/sources/weather_source.dart';

class FakeSource implements WeatherSource {
  @override
  final String id;
  final bool fails;
  @override
  final bool isConfigured;
  FakeSource(this.id, {this.fails = false, this.isConfigured = true});

  @override
  String get displayName => id.toUpperCase();
  @override
  double get reliability => 1;

  @override
  Future<SourceReading> fetch(GeoPoint point) async {
    if (fails) throw SourceException(id, 'boom');
    return SourceReading(
      sourceId: id,
      sourceName: displayName,
      fetchedAt: DateTime.utc(2026),
      distanceKm: 0,
      reliability: reliability,
      current: Observation(time: DateTime.utc(2026), temperatureC: 20),
    );
  }
}

void main() {
  const point = GeoPoint(36.8, 10.18);

  Future<WeatherRepository> repo(List<WeatherSource> sources) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return WeatherRepository(sources, CacheService(prefs));
  }

  test('one failing source does not stop the others', () async {
    final r = await repo([FakeSource('a'), FakeSource('b', fails: true), FakeSource('c')]);
    final result = await r.fetchAll(point, {'a', 'b', 'c'});
    expect(result.readings.map((e) => e.sourceId), ['a', 'c']);
    expect(result.failed, ['B']);
    expect(result.attempted, 3);
  });

  test('disabled and unconfigured sources are never called', () async {
    final r = await repo([
      FakeSource('a'),
      FakeSource('b'),
      FakeSource('needs_key', isConfigured: false),
    ]);
    final result = await r.fetchAll(point, {'a', 'needs_key'});
    expect(result.readings.single.sourceId, 'a');
    expect(result.attempted, 1);
    expect(result.failed, isEmpty);
  });

  test('all sources failing yields an empty result, not an exception', () async {
    final r = await repo([FakeSource('a', fails: true)]);
    final result = await r.fetchAll(point, {'a'});
    expect(result.readings, isEmpty);
    expect(result.failed, ['A']);
  });

  test('offline: the last bundle is restored from local storage', () async {
    final r = await repo([FakeSource('a')]);
    expect(r.loadCached(), isNull);
    final result = await r.fetchAll(point, {'a'});
    await r.saveCache(WeatherBundle(
      place: const Place(point: point, name: 'Tunis'),
      readings: result.readings,
      fetchedAt: DateTime.utc(2026, 1, 1, 12),
    ));
    final cached = r.loadCached()!;
    expect(cached.place.name, 'Tunis');
    expect(cached.readings.single.current.temperatureC, 20);
    expect(cached.fetchedAt, DateTime.utc(2026, 1, 1, 12));
  });
}
