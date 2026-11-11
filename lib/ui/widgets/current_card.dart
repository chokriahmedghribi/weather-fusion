import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/units.dart';
import '../../models/fused_weather.dart';
import 'common.dart';

class CurrentCard extends StatelessWidget {
  final FusedWeather weather;
  final S s;
  final TempUnit tempUnit;
  const CurrentCard({super.key, required this.weather, required this.s, required this.tempUnit});

  @override
  Widget build(BuildContext context) {
    final isDay = weather.isDay ?? true;
    const white = Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: conditionGradient(weather.condition, isDay: isDay),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.temp(weather.temperatureC, tempUnit)}${weather.temperatureC == null ? '' : s.tempSuffix(tempUnit)}',
                  style: const TextStyle(
                      color: white, fontSize: 56, fontWeight: FontWeight.w300, height: 1.1),
                ),
                const SizedBox(height: 4),
                Text(s.condition(weather.condition),
                    style: const TextStyle(color: white, fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  '${s.t('feels_like')}: ${s.temp(weather.feelsLikeC, tempUnit)}',
                  style: TextStyle(color: white.withAlpha(220), fontSize: 14),
                ),
              ],
            ),
          ),
          Icon(conditionIcon(weather.condition, isDay: isDay), color: white, size: 72),
        ],
      ),
    );
  }
}
