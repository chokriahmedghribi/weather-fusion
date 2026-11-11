import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../models/fused_weather.dart';
import 'common.dart';

class DetailsCard extends StatelessWidget {
  final FusedWeather weather;

  /// Raw phone-barometer reading (station pressure), null if no sensor.
  final double? stationPressureHpa;
  final S s;
  const DetailsCard({super.key, required this.weather, this.stationPressureHpa, required this.s});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <(IconData, String, String)>[
      (Icons.opacity, s.t('humidity'), s.percent(weather.humidityPct)),
      (Icons.speed, s.t('pressure'), s.pressure(weather.pressureHpa)),
      (Icons.visibility_outlined, s.t('visibility'), s.visibility(weather.visibilityM)),
      (Icons.umbrella_outlined, s.t('precip_prob'), s.percent(weather.precipProbPct, step: 5)),
      (Icons.cloud_outlined, s.t('cloud_cover'), s.percent(weather.cloudCoverPct)),
      (Icons.sensors, s.t('phone_barometer'), s.pressure(stationPressureHpa)),
    ];
    return SectionCard(
      title: s.t('details'),
      icon: Icons.list_alt,
      child: Column(
        children: [
          for (final (icon, label, value) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: Text(label)),
                Text(value, style: theme.textTheme.titleSmall),
              ]),
            ),
        ],
      ),
    );
  }
}
