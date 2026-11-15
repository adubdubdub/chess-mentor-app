import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analysis/analysis.dart';
import '../mentor/profile.dart';
import '../mentor/topic_texts.dart';
import '../mentor/topics.dart';
import 'accuracy_chart.dart';
import 'strings.dart';
import 'topic_info_sheet.dart';

/// Darstellung des Schwächenprofils (reine Anzeige, bekommt fertige Daten).
class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.profile, this.onTopic, this.onGame, this.header});

  final Profile profile;

  /// Antippen eines Themas (Liste der zugehörigen Fehlzüge).
  final void Function(Topic topic)? onTopic;

  /// „Partie öffnen“ im Genauigkeitsdiagramm.
  final void Function(int gameId)? onGame;

  /// Wird über den Kennzahlen angezeigt (z. B. die Fokuskarte); fehlt bei leerem Profil.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final p = profile;
    if (p.games == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            tr.t(
              'Noch keine analysierten Partien. Das Profil entsteht, sobald Partien analysiert sind.',
              'No analysed games yet. The profile appears once games have been analysed.',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Balken nie bis zum Rand: Skala mit Luft nach oben, mindestens 10 je 100 Züge
    final topicScale = barScale(p.topics.fold<double>(0, (a, t) => t.per100 > a ? t.per100 : a));
    final phaseScale = barScale(p.phases.fold<double>(0, (a, x) => x.per100 > a ? x.per100 : a));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (header != null) ...[header!, const SizedBox(height: 16)],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Figure(label: tr.t('Partien', 'Games'), value: '${p.games}'),
            _Figure(
              label: tr.t('Genauigkeit', 'Accuracy'),
              value: p.accuracy == null ? '–' : '${p.accuracy!.round()} %',
            ),
            for (final c in MistakeClass.values.reversed) _Figure(label: tr.mistake(c), value: '${p.counts[c] ?? 0}'),
          ],
        ),
        if (p.accuracySeries.length >= 2) ...[
          const SizedBox(height: 20),
          Text(tr.t('Genauigkeit je Partie', 'Accuracy per game'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          AccuracyChart(series: p.accuracySeries, onOpen: onGame),
        ],
        if (!p.enough) ...[
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                tr.t(
                  'Noch zu wenig Daten für Aussagen: ab $minGames analysierten Partien zeigt der Mentor, wo deine '
                      'Schwächen liegen (jetzt ${p.games}). Die Zahlen unten sind nur eine erste Orientierung.',
                  'Not enough data yet: from $minGames analysed games the mentor shows where your weaknesses are '
                      '(now ${p.games}). The figures below are only a first indication.',
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(tr.t('Schwächen-Themen', 'Weakness topics'), style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          tr.t(
            'Fehlzüge je 100 eigene Züge. Ein Fehlzug kann zu mehreren Themen zählen, die Anteile ergeben deshalb keine Summe.',
            'Mistakes per 100 of your own moves. One mistake can belong to several topics, so the shares do not add up.',
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (p.topics.isEmpty)
          Text(tr.t('Keine Fehlzüge mit erkennbarem Thema.', 'No mistakes with a recognisable topic.'))
        else
          for (final t in p.topics)
            _TopicTile(stat: t, scale: topicScale, onTap: onTopic == null ? null : () => onTopic!(t.topic)),
        if (p.untagged > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              tr.t(
                '${p.untagged} weitere Fehlzüge ohne erkennbares Thema.',
                '${p.untagged} more mistakes without a recognisable topic.',
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (p.phases.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(tr.t('Spielphasen', 'Game phases'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final ph in p.phases)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _BarRow(
                label: tr.phase(ph.phase),
                value: ph.per100,
                max: phaseScale,
                trailing: tr.t(
                  '${ph.mistakes} Fehlzüge bei ${ph.moves} Zügen',
                  '${ph.mistakes} mistakes in ${ph.moves} moves',
                ),
                color: theme.colorScheme.tertiary,
              ),
            ),
        ],
        if (p.openings.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(tr.t('Eröffnungen', 'Openings'), style: theme.textTheme.titleMedium),
          for (final o in p.openings)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(o.name),
              subtitle: Text(
                tr.t(
                  '${o.games} Partien · ${o.mistakes} Fehlzüge${o.accuracy == null ? '' : ' · Genauigkeit ${o.accuracy!.round()} %'}',
                  '${o.games} games · ${o.mistakes} mistakes${o.accuracy == null ? '' : ' · accuracy ${o.accuracy!.round()} %'}',
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),
        Text(
          tr.t(
            'Grundlage: die letzten $profileWindow analysierten Partien. Themen gelten erst ab $minOccurrences '
                'Vorkommen in mindestens $minTopicGames Partien.',
            'Based on the last $profileWindow analysed games. Topics count only from $minOccurrences occurrences in at '
                'least $minTopicGames games.',
          ),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          Text(label, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.stat, required this.scale, this.onTap});

  final TopicStat stat;

  /// Wert, der einem vollen Balken entspricht.
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final t = stat;
    final trend = t.trend;
    final trendText = trend == null
        ? ''
        : trend < -0.3
        ? ' · ↘ ${tr.t('besser', 'better')}'
        : trend > 0.3
        ? ' · ↗ ${tr.t('schlechter', 'worse')}'
        : ' · → ${tr.t('gleich', 'same')}';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Opacity(
        opacity: t.enough ? 1 : 0.6,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BarRow(
                        label: tr.topicName(t.topic),
                        value: t.per100,
                        max: scale,
                        trailing: tr.t('${t.count}× in ${t.games} Partien', '${t.count}× in ${t.games} games'),
                        color: t.enough ? theme.colorScheme.primary : theme.colorScheme.outline,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [
                                tr.t('Ø-Verlust ${t.avgDrop.round()} Punkte', 'avg. loss ${t.avgDrop.round()} points'),
                                if (t.puzzles > 0)
                                  tr.t(
                                    'Puzzles ${t.mastered}/${t.puzzles} gemeistert',
                                    'puzzles ${t.mastered}/${t.puzzles} mastered',
                                  ),
                              ].join(' · ') +
                              trendText,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      if (!t.enough)
                        Text(
                          tr.t(
                            'Noch kein Muster (zu wenige Vorkommen oder Partien).',
                            'No pattern yet (too few occurrences or games).',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: tr.t('Erklärung und Tipps', 'Explanation and tips'),
                  onPressed: () => showTopicInfo(context, t.topic),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.trailing,
    required this.color,
  });

  final String label;
  final double value;
  final double max;
  final String trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text('${value.toStringAsFixed(1)} / 100', style: theme.textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: max == 0 ? 0 : (value / max).clamp(0.0, 1.0),
            minHeight: 8,
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        Text(trailing, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Wert, der einem vollen Balken entspricht: 40 % über dem größten Wert, auf 5 gerundet, mindestens 10.
/// Damit füllt auch der größte Balken nie die ganze Breite.
double barScale(double max) => math.max(10.0, (max * 1.4 / 5).ceil() * 5.0);
