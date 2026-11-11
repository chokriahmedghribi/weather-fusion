import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/geo.dart';
import '../state/providers.dart';

/// Manual location: search a city by name, or switch back to GPS.
class CitySearchScreen extends ConsumerStatefulWidget {
  /// When shown from onboarding there is no previous route to pop to.
  final bool popOnDone;
  const CitySearchScreen({super.key, this.popOnDone = true});

  @override
  ConsumerState<CitySearchScreen> createState() => _CitySearchScreenState();
}

class _CitySearchScreenState extends ConsumerState<CitySearchScreen> {
  final _controller = TextEditingController();
  List<Place>? _results;
  bool _loading = false;
  bool _failed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final language = ref.read(settingsProvider).localeCode;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final r = await ref
          .read(geocodingServiceProvider)
          .search(_controller.text, language: language);
      if (!mounted) return;
      setState(() => _results = r);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _done() {
    if (widget.popOnDone && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('choose_city'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ListTile(
            leading: const Icon(Icons.my_location),
            title: Text(s.t('use_gps')),
            subtitle: Text(s.t('use_gps_hint')),
            onTap: () {
              ref.read(settingsProvider.notifier).useGps();
              _done();
            },
          ),
          const Divider(),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: s.t('city_name'),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: s.t('search'),
                icon: const Icon(Icons.search),
                onPressed: _search,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_failed) Text(s.t('search_failed')),
          if (!_loading && !_failed && results != null && results.isEmpty)
            Text(s.t('no_results')),
          if (results != null)
            for (final p in results)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(p.name ?? ''),
                onTap: () {
                  ref.read(settingsProvider.notifier).useManualPlace(p);
                  _done();
                },
              ),
        ],
      ),
    );
  }
}
