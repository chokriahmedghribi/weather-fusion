import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/units.dart';
import '../../models/fused_weather.dart';
import 'common.dart';

class WindCard extends StatelessWidget {
  final FusedWeather weather;
  final S s;
  final WindUnit windUnit;
  const WindCard({super.key, required this.weather, required this.s, required this.windUnit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speed = weather.windSpeedMs;
    final dir = weather.windDirDeg;
    final calm = speed != null && speed < 0.5;

    final String direction;
    if (dir != null) {
      direction = '${s.t('from')} ${s.cardinal(dir)} (${dir.round()}°)';
    } else if (calm) {
      direction = s.t('calm');
    } else if (speed != null && weather.windDirConsistency != null) {
      direction = s.t('variable'); // sources disagree on the direction
    } else {
      direction = s.na;
    }

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 78,
                child: Text(label,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
              Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );

    return SectionCard(
      title: s.t('wind'),
      icon: Icons.air,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 128,
            height: 128,
            child: CustomPaint(
              painter: CompassPainter(
                fromDeg: dir,
                labels: [s.t('dir_N_short'), s.t('dir_E_short'), s.t('dir_S_short'), s.t('dir_W_short')],
                color: theme.colorScheme.onSurface,
                accent: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.wind(speed, windUnit), style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                row(s.t('direction'), direction),
                row(s.t('gusts'), s.wind(weather.windGustMs, windUnit)),
                row(
                  s.t('beaufort'),
                  speed == null
                      ? s.na
                      : '${Units.beaufort(speed)} — ${s.t('bft_${Units.beaufort(speed)}')}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compass dial. The arrow starts on the rim at the bearing the wind comes
/// FROM and points the way the air is moving. Geography is not mirrored in
/// RTL: east is always on the right.
class CompassPainter extends CustomPainter {
  final double? fromDeg;

  /// Labels for N, E, S, W.
  final List<String> labels;
  final Color color;
  final Color accent;

  CompassPainter({
    required this.fromDeg,
    required this.labels,
    required this.color,
    required this.accent,
  });

  Offset _at(Offset c, double radius, double bearingDeg) {
    final rad = bearingDeg * math.pi / 180;
    return c + Offset(math.sin(rad), -math.cos(rad)) * radius;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withAlpha(90);
    canvas.drawCircle(c, r, ring);

    for (var d = 0; d < 360; d += 30) {
      final major = d % 90 == 0;
      canvas.drawLine(_at(c, r, d.toDouble()),
          _at(c, r - (major ? 8 : 4), d.toDouble()), ring);
    }

    for (var i = 0; i < 4; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: i == 0 ? accent : color.withAlpha(180),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = _at(c, r - 18, i * 90.0);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    final from = fromDeg;
    if (from == null) {
      canvas.drawCircle(c, 3, Paint()..color = color.withAlpha(120));
      return;
    }
    final arrow = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final tail = _at(c, r - 30, from);
    final head = _at(c, r - 30, from + 180);
    canvas.drawLine(tail, head, arrow);
    canvas.drawLine(head, _at(head, 12, from + 25), arrow);
    canvas.drawLine(head, _at(head, 12, from - 25), arrow);
    canvas.drawCircle(tail, 4, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(CompassPainter old) =>
      old.fromDeg != fromDeg || old.color != color || old.accent != accent;
}
