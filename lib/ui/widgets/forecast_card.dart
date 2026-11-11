import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/units.dart';
import '../../models/fused_weather.dart';
import '../../models/nowcast.dart';
import 'common.dart';

/// Next hours: nowcast summary, pressure tendency, 1–6 h steps with
/// confidence, and a temperature chart for the fused hourly forecast.
class ForecastCard extends StatelessWidget {
  final Nowcast nowcast;
  final List<FusedWeather> hourly;
  final S s;
  final TempUnit tempUnit;
  final bool isDay;

  const ForecastCard({
    super.key,
    required this.nowcast,
    required this.hourly,
    required this.s,
    required this.tempUnit,
    this.isDay = true,
  });

  String _trendText() {
    final t = nowcast.trend;
    if (t == null) return '${s.t('pressure_trend')}: ${s.na}';
    final sign = t.hpaPer3h >= 0 ? '+' : '−';
    final label = s.t('trend_${t.tendency.name}');
    final origin = s.t(t.measured ? 'trend_measured' : 'trend_model');
    return '${s.t('pressure_trend')}: $label '
        '($sign${t.hpaPer3h.abs().toStringAsFixed(1)} hPa/3h) · $origin';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return SectionCard(
      title: s.t('next_hours'),
      icon: Icons.schedule,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('nowcast_${nowcast.summary.name}'), style: theme.textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text(_trendText(), style: small),
          const SizedBox(height: 12),
          if (nowcast.steps.isEmpty)
            Text(s.na)
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: nowcast.steps.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _StepTile(
                    step: nowcast.steps[i], s: s, tempUnit: tempUnit, isDay: isDay),
              ),
            ),
          const SizedBox(height: 6),
          Text(s.t('nowcast_note'), style: small),
          const SizedBox(height: 16),
          Text(s.t('temp_chart'), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          _TempChart(hourly: hourly, s: s, tempUnit: tempUnit),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final NowcastStep step;
  final S s;
  final TempUnit tempUnit;
  final bool isDay;
  const _StepTile({required this.step, required this.s, required this.tempUnit, required this.isDay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(s.clock(step.time), style: theme.textTheme.labelMedium),
          Icon(conditionIcon(step.condition, isDay: isDay), size: 24),
          Text(s.temp(step.temperatureC, tempUnit), style: theme.textTheme.titleSmall),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.water_drop_outlined, size: 12),
            const SizedBox(width: 2),
            // Rounded to 5 %: the method does not justify finer steps.
            Text(s.percent(step.precipProbPct, step: 5), style: theme.textTheme.labelSmall),
          ]),
          Tooltip(
            message: '${s.t('confidence')}: ${s.confidence(step.level)}',
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: confidenceColor(step.level), shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(s.confidenceShort(step.level),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TempChart extends StatelessWidget {
  final List<FusedWeather> hourly;
  final S s;
  final TempUnit tempUnit;
  const _TempChart({required this.hourly, required this.s, required this.tempUnit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = hourly.where((h) => h.temperatureC != null).toList();
    if (points.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(s.na),
      );
    }
    final values = [for (final p in points) Units.temp(p.temperatureC!, tempUnit)];
    final minY = values.reduce(math.min).floorToDouble() - 1;
    final maxY = values.reduce(math.max).ceilToDouble() + 1;
    final color = theme.colorScheme.primary;
    final labelStyle = theme.textTheme.labelSmall;
    final step = points.length > 8 ? 3 : 2;

    // Time always runs left → right, also in RTL.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: 160,
        child: LineChart(LineChartData(
          minY: minY,
          maxY: maxY,
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (value, meta) => value == value.roundToDouble()
                    ? Text('${value.round()}°', style: labelStyle)
                    : const SizedBox.shrink(),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (value != i.toDouble() || i < 0 || i >= points.length || i % step != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(s.clock(points[i].time), style: labelStyle),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              barWidth: 3,
              color: color,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: color.withAlpha(40)),
            ),
          ],
        )),
      ),
    );
  }
}
