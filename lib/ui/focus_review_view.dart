import 'package:flutter/material.dart';

import '../mentor/focus.dart';
import '../mentor/focus_review.dart';
import '../mentor/records.dart';
import '../mentor/topic_texts.dart';
import '../analysis/analysis.dart';
import 'strings.dart';
import 'topic_info_sheet.dart';

/// Rückblick auf einen Wochenfokus: Ergebnis, Vergleich mit vorher, Partien der Woche, Fehlzüge zum Nachschauen.
class FocusReviewView extends StatelessWidget {
  const FocusReviewView({super.key, required this.review, this.next, this.onMoment, this.onGame, this.onNew});

  final FocusReview review;

  /// Vorschlag für den nächsten Fokus (Thema und Ziel), falls es einen gibt.
  final FocusSuggestion? next;
  final void Function(GameRecord game, Moment moment)? onMoment;
  final void Function(int gameId)? onGame;
  final VoidCallback? onNew;

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final r = review;
    final f = r.focus;
    final (icon, headline) = switch (r.status) {
      FocusStatus.reached => ('✅', tr.t('Ziel erreicht', 'Goal reached')),
      FocusStatus.missed => ('❌', tr.t('Ziel verfehlt', 'Goal missed')),
      FocusStatus.expired => ('⏱', tr.t('Abgelaufen, kein Urteil', 'Expired, no verdict')),
      FocusStatus.cancelled => ('⏹', tr.t('Beendet', 'Ended')),
      FocusStatus.active => ('🎯', tr.t('Läuft noch', 'In progress')),
    };
    String fmt(double v) => v.toStringAsFixed(1).replaceAll('.', tr.de ? ',' : '.');
    final changeText = r.change == null
        ? null
        : r.change! <= -1
        ? tr.t('${r.change!.abs().round()} % weniger als vorher', '${r.change!.abs().round()} % fewer than before')
        : r.change! >= 1
        ? tr.t('${r.change!.round()} % mehr als vorher', '${r.change!.round()} % more than before')
        : tr.t('etwa wie vorher', 'about the same as before');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('$icon ${tr.topicName(f.topic)}', style: theme.textTheme.titleLarge),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: tr.t('Erklärung und Tipps', 'Explanation and tips'),
              onPressed: () => showTopicInfo(context, f.topic),
            ),
          ],
        ),
        Text(
          '$headline · ${_date(f.startedAt)}–${_date(f.endsAt.subtract(const Duration(days: 1)))}',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Line(
                  tr.t('Ziel', 'Goal'),
                  f.target == 0
                      ? tr.t('kein Fehlzug in ${f.goalGames} Partien', 'no mistake in ${f.goalGames} games')
                      : tr.t('höchstens ${f.target} Fehlzüge in ${f.goalGames} Partien', 'at most ${f.target} mistakes in ${f.goalGames} games'),
                ),
                _Line(
                  tr.t('Ergebnis', 'Result'),
                  r.games.isEmpty
                      ? tr.t('keine Partie gespielt', 'no game played')
                      : tr.t('${r.occurrences} Fehlzüge in ${r.games.length} Partien', '${r.occurrences} mistakes in ${r.games.length} games'),
                ),
                _Line(
                  tr.t('Je Partie', 'Per game'),
                  r.perGameNow == null
                      ? tr.t('vorher ${fmt(r.perGameBefore)}', 'before ${fmt(r.perGameBefore)}')
                      : tr.t(
                          'vorher ${fmt(r.perGameBefore)}, jetzt ${fmt(r.perGameNow!)}${changeText == null ? '' : ' ($changeText)'}',
                          'before ${fmt(r.perGameBefore)}, now ${fmt(r.perGameNow!)}${changeText == null ? '' : ' ($changeText)'}',
                        ),
                ),
                if (r.accuracyNow != null)
                  _Line(
                    tr.t('Genauigkeit', 'Accuracy'),
                    r.accuracyBefore == null
                        ? '${r.accuracyNow!.round()} %'
                        : tr.t(
                            '${r.accuracyNow!.round()} % (davor Ø ${r.accuracyBefore!.round()} %)',
                            '${r.accuracyNow!.round()} % (before avg ${r.accuracyBefore!.round()} %)',
                          ),
                  ),
                if (r.puzzleAttempts > 0)
                  _Line(
                    tr.t('Puzzles', 'Puzzles'),
                    tr.t(
                      '${r.puzzleAttempts} Versuche zum Thema, ${r.puzzleClean} davon sauber gelöst',
                      '${r.puzzleAttempts} attempts on the topic, ${r.puzzleClean} solved cleanly',
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(_verdictText(tr, r)),
        if (r.games.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(tr.t('Partien der Woche', 'Games of the week'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final g in r.games)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${_date(g.record.playedAt)} · ${g.record.analysis.white} – ${g.record.analysis.black}'),
              subtitle: Text(
                tr.t(
                  '${g.topicMistakes} Fehlzüge zum Thema · ${g.allMistakes} insgesamt${g.accuracy == null ? '' : ' · Genauigkeit ${g.accuracy} %'}',
                  '${g.topicMistakes} on the topic · ${g.allMistakes} in total${g.accuracy == null ? '' : ' · accuracy ${g.accuracy} %'}',
                ),
              ),
              trailing: onGame == null ? null : const Icon(Icons.chevron_right),
              onTap: onGame == null ? null : () => onGame!(g.record.id),
            ),
        ],
        if (r.moments.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(tr.t('Diese Fehlzüge waren es', 'These were the mistakes'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final e in r.moments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                tr.t(
                  'Zug ${e.moment.moveNo}: ${tr.san(e.moment.played)} statt ${tr.san(e.moment.best)}',
                  'Move ${e.moment.moveNo}: ${tr.san(e.moment.played)} instead of ${tr.san(e.moment.best)}',
                ),
              ),
              subtitle: Text('${e.game.analysis.white} – ${e.game.analysis.black} · −${e.moment.drop.round()} ${tr.t('Punkte', 'points')}'),
              trailing: onMoment == null ? null : const Icon(Icons.chevron_right),
              onTap: onMoment == null ? null : () => onMoment!(e.game, e.moment),
            ),
        ],
        const SizedBox(height: 20),
        _nextStep(context, tr, theme),
      ],
    );
  }

  /// Einordnung in ein, zwei Sätzen, abhängig vom Ausgang (Textbaustein).
  String _verdictText(Tr tr, FocusReview r) => switch (r.status) {
    FocusStatus.reached => tr.t(
      'Gut gemacht: Die Fehlzüge zu diesem Thema sind in der Woche spürbar zurückgegangen. Bleib bei der Prüffrage, dann '
          'wird daraus eine Gewohnheit. Als Nächstes lohnt sich ein neues Thema.',
      'Well done: mistakes on this topic dropped noticeably this week. Keep asking the check question so it becomes a '
          'habit. A new topic is worth tackling next.',
    ),
    FocusStatus.missed => tr.t(
      'Das Ziel war diesmal zu hoch. Das ist kein Rückschritt: Schau dir unten die Fehlzüge an und überlege bei jedem, '
          'welche Prüffrage ihn verhindert hätte. Du kannst das Thema in der nächsten Woche noch einmal wählen.',
      'The goal was too high this time. That is no setback: look at the mistakes below and think for each which check '
          'question would have prevented it. You can choose this topic again next week.',
    ),
    FocusStatus.expired => tr.t(
      'In dieser Woche kamen zu wenige Partien zusammen, um das Ziel zu beurteilen. Der Zwischenstand oben zeigt, wie es bis '
          'dahin lief.',
      'Too few games were played this week to judge the goal. The status above shows how it went so far.',
    ),
    _ => '',
  };

  Widget _nextStep(BuildContext context, Tr tr, ThemeData theme) {
    final n = next;
    return Card(
      color: theme.colorScheme.secondaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.t('Wie geht es weiter?', 'What next?'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              n == null
                  ? tr.t(
                      'Sobald genug neue Partien analysiert sind, schlägt der Mentor das nächste Thema vor.',
                      'Once enough new games are analysed, the mentor suggests the next topic.',
                    )
                  : tr.t(
                      'Vorschlag für die nächste Woche: ${tr.topicName(n.topic)}.',
                      'Suggestion for next week: ${tr.topicName(n.topic)}.',
                    ),
            ),
            if (onNew != null) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.flag),
                label: Text(tr.t('Zum Mentor', 'Go to the mentor')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: theme.textTheme.bodySmall)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
