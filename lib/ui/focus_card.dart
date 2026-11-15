import 'package:flutter/material.dart';

import '../mentor/focus.dart';
import '../mentor/focus_keeper.dart';
import '../mentor/profile.dart';
import '../mentor/topic_texts.dart';
import 'strings.dart';

/// Die Karte „Wochenfokus“ oben auf der Mentor-Seite: Vorschlag mit Wahl, laufender Fokus mit Stand, Ergebnis.
class FocusCard extends StatelessWidget {
  const FocusCard({
    super.key,
    required this.state,
    required this.suggestions,
    required this.profile,
    this.duePuzzles = 0,
    this.onStart,
    this.onCancel,
    this.onPractice,
  });

  final FocusState state;
  final List<FocusSuggestion> suggestions;
  final Profile profile;

  /// Heute fällige Puzzles zum Fokusthema.
  final int duePuzzles;
  final void Function(FocusSuggestion suggestion)? onStart;
  final VoidCallback? onCancel;
  final VoidCallback? onPractice;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final active = state.active;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: active != null ? _active(context, tr, theme, active) : _idle(context, tr, theme),
      ),
    );
  }

  String _goal(Tr tr, int target, int games, int baselineCount, int baselineGames) {
    final usual = baselineGames == 0 ? 0 : baselineCount / baselineGames;
    final usualText = tr.t('bisher ca. ${usual.toStringAsFixed(1)} je Partie', 'so far about ${usual.toStringAsFixed(1)} per game');
    return target == 0
        ? tr.t('Ziel: in den nächsten $games Partien kein solcher Fehlzug ($usualText).', 'Goal: no such mistake in the next $games games ($usualText).')
        : tr.t(
            'Ziel: in den nächsten $games Partien höchstens $target solche Fehlzüge ($usualText).',
            'Goal: at most $target such mistakes in the next $games games ($usualText).',
          );
  }

  Widget _active(BuildContext context, Tr tr, ThemeData theme, FocusEntry f) {
    final p = state.progress;
    final games = p?.games ?? 0, occ = p?.occurrences ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🎯 ${tr.t('Wochenfokus', 'Weekly focus')}: ${tr.topicName(f.topic)}', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(tr.topicRule(f.topic)),
        const SizedBox(height: 8),
        Text('❓ ${tr.t('Vor jedem Zug', 'Before every move')}: ${tr.topicCheck(f.topic)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Text(_goal(tr, f.target, f.goalGames, f.baselineCount, f.baselineGames)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: f.goalGames == 0 ? 0 : (games / f.goalGames).clamp(0.0, 1.0), minHeight: 8),
        const SizedBox(height: 4),
        Text(
          tr.t(
            'Stand: $games von ${f.goalGames} Partien, $occ Fehlzüge (erlaubt ${f.target}) · noch ${p?.daysLeft ?? 0} Tage',
            'So far: $games of ${f.goalGames} games, $occ mistakes (allowed ${f.target}) · ${p?.daysLeft ?? 0} days left',
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (duePuzzles > 0)
              FilledButton.icon(
                onPressed: onPractice,
                icon: const Icon(Icons.extension),
                label: Text(tr.t('$duePuzzles Fokus-Puzzles üben', 'Practise $duePuzzles focus puzzles')),
              ),
            TextButton(onPressed: onCancel, child: Text(tr.t('Fokus beenden', 'End focus'))),
          ],
        ),
        if (duePuzzles == 0)
          Text(tr.t('Heute sind keine Puzzles zu diesem Thema fällig.', 'No puzzles on this topic are due today.'), style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _result(Tr tr, ThemeData theme) {
    final c = state.lastClosed;
    if (c == null || c.status == FocusStatus.cancelled) return const SizedBox.shrink();
    final p = state.progress;
    final detail = p == null ? '' : ' (${p.occurrences} / ${c.target}, ${p.games} ${tr.t('Partien', 'games')})';
    final (icon, text) = switch (c.status) {
      FocusStatus.reached => ('✅', tr.t('Letzter Fokus „${tr.topicName(c.topic)}“: Ziel erreicht$detail.', 'Last focus “${tr.topicName(c.topic)}”: goal reached$detail.')),
      FocusStatus.missed => ('❌', tr.t('Letzter Fokus „${tr.topicName(c.topic)}“: Ziel verfehlt$detail. Das Thema bleibt ein Kandidat.', 'Last focus “${tr.topicName(c.topic)}”: goal missed$detail. The topic stays a candidate.')),
      _ => ('⏱', tr.t('Letzter Fokus „${tr.topicName(c.topic)}“: abgelaufen, zu wenige Partien für ein Urteil.', 'Last focus “${tr.topicName(c.topic)}”: expired, too few games to judge.')),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text('$icon $text', style: theme.textTheme.bodyMedium),
    );
  }

  Widget _idle(BuildContext context, Tr tr, ThemeData theme) {
    if (suggestions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _result(tr, theme),
          Text('🎯 ${tr.t('Wochenfokus', 'Weekly focus')}', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            tr.t(
              'Noch kein Vorschlag möglich. Ab $minGames analysierten Partien und einem Thema, das mindestens '
                  '$minOccurrences-mal in $minTopicGames Partien vorkommt, schlägt der Mentor einen Fokus vor.',
              'No suggestion yet. From $minGames analysed games and a topic that occurs at least $minOccurrences '
                  'times in $minTopicGames games, the mentor suggests a focus.',
            ),
          ),
        ],
      );
    }
    final first = suggestions.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _result(tr, theme),
        Text('🎯 ${tr.t('Vorschlag für deinen Wochenfokus', 'Suggested weekly focus')}', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(tr.topicName(first.topic), style: theme.textTheme.titleLarge),
        Text(tr.topicHint(first.topic)),
        const SizedBox(height: 6),
        Text(
          tr.t(
            '${first.stat.count}× in ${first.stat.games} Partien, im Schnitt ${first.stat.avgDrop.round()} Punkte Verlust.',
            '${first.stat.count}× in ${first.stat.games} games, on average ${first.stat.avgDrop.round()} points lost.',
          ),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(_goal(tr, first.target, first.goalGames, first.stat.count, first.baselineGames)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onStart == null ? null : () => onStart!(first),
          icon: const Icon(Icons.flag),
          label: Text(tr.t('Als Fokus wählen', 'Choose as focus')),
        ),
        if (suggestions.length > 1) ...[
          const SizedBox(height: 12),
          Text(tr.t('Oder stattdessen:', 'Or instead:'), style: theme.textTheme.labelMedium),
          for (final s in suggestions.skip(1))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(tr.topicName(s.topic)),
              subtitle: Text(tr.t('${s.stat.count}× in ${s.stat.games} Partien', '${s.stat.count}× in ${s.stat.games} games')),
              trailing: OutlinedButton(
                onPressed: onStart == null ? null : () => onStart!(s),
                child: Text(tr.t('Wählen', 'Choose')),
              ),
            ),
        ],
      ],
    );
  }
}
