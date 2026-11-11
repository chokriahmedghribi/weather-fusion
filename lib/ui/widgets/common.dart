import 'package:flutter/material.dart';

import '../../core/weather_condition.dart';
import '../../models/fused_weather.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  const SectionCard({super.key, required this.title, this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

IconData conditionIcon(WeatherCondition c, {bool isDay = true}) => switch (c) {
      WeatherCondition.clear => isDay ? Icons.wb_sunny : Icons.nightlight_round,
      WeatherCondition.partlyCloudy => Icons.cloud_queue,
      WeatherCondition.cloudy => Icons.cloud,
      WeatherCondition.fog => Icons.foggy,
      WeatherCondition.drizzle => Icons.grain,
      WeatherCondition.rain => Icons.water_drop,
      WeatherCondition.heavyRain => Icons.umbrella,
      WeatherCondition.snow => Icons.ac_unit,
      WeatherCondition.thunderstorm => Icons.thunderstorm,
      WeatherCondition.unknown => Icons.help_outline,
    };

/// Background gradient chosen from the condition and day/night.
List<Color> conditionGradient(WeatherCondition c, {bool isDay = true}) {
  if (!isDay) return const [Color(0xFF0F1B3D), Color(0xFF2B3A67)];
  return switch (c) {
    WeatherCondition.clear => const [Color(0xFF1E88E5), Color(0xFF64B5F6)],
    WeatherCondition.partlyCloudy => const [Color(0xFF3F7FBF), Color(0xFF8FB8DE)],
    WeatherCondition.cloudy ||
    WeatherCondition.fog ||
    WeatherCondition.unknown =>
      const [Color(0xFF5C6B7A), Color(0xFF8E9BA8)],
    WeatherCondition.drizzle ||
    WeatherCondition.rain ||
    WeatherCondition.heavyRain =>
      const [Color(0xFF37506B), Color(0xFF5F7C99)],
    WeatherCondition.snow => const [Color(0xFF6E8CA8), Color(0xFFAFC3D6)],
    WeatherCondition.thunderstorm => const [Color(0xFF2E2A4F), Color(0xFF55507E)],
  };
}

Color confidenceColor(ConfidenceLevel l) => switch (l) {
      ConfidenceLevel.high => const Color(0xFF2E9E5B),
      ConfidenceLevel.medium => const Color(0xFFE0A100),
      ConfidenceLevel.low => const Color(0xFFD64545),
    };
