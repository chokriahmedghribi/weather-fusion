import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../state/providers.dart';
import 'common.dart';

/// "Why this result?" — sources, their weights, freshness and confidence.
class ConfidenceCard extends StatelessWidget {
  final WeatherView view;
  final S s;
  final DateTime now;
  const ConfidenceCard({super.key, required this.view, required this.s, required this.now});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = view.current;
    final small = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final color = confidenceColor(w.level);
    final age = now.toUtc().difference(view.bundle.fetchedAt);

    return SectionCard(
      title: s.t('why_title'),
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                // Rounded to 5 %: finer digits would be false precision.
                '${s.confidence(w.level)} · ${s.percent(w.confidence * 100, step: 5)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: w.confidence,
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withAlpha(40),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text('${s.t('last_update')}: ${s.clock(view.bundle.fetchedAt)} (${s.ago(age)})'),
          const SizedBox(height: 10),
          Text(s.t('sources_used'), style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          for (final c in w.contributions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(child: Text(c.sourceName)),
                Text(
                  '${s.t('weight')} ${s.percent(c.weight * 100)} · '
                  '${s.t('data_age')} ${s.minutes(c.ageMinutes)}',
                  style: small,
                ),
              ]),
            ),
          if (w.contributions.length == 1) ...[
            const SizedBox(height: 6),
            Text(s.t('single_source_note'), style: small),
          ],
          if (view.bundle.failedSources.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${s.t('failed_sources')}: ${view.bundle.failedSources.join(', ')}',
                style: small?.copyWith(color: theme.colorScheme.error)),
          ],
          if (w.rejected.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${s.t('rejected_values')}: '
              '${w.rejected.map((r) => '${s.t('field_${r.field}')} ${r.value.toStringAsFixed(1)} (${r.sourceName})').join(', ')}',
              style: small,
            ),
          ],
          const SizedBox(height: 10),
          Text(s.t('why_text'), style: small),
        ],
      ),
    );
  }
}
