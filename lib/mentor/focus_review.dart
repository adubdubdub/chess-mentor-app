/// Wochenrückblick (Schritt 6e): Was hat der Fokus gebracht? Vergleich mit vorher, Partien der Woche, Fehlzüge des Themas.
library;

import '../analysis/analysis.dart';
import 'focus.dart';
import 'records.dart';
import 'topics.dart';

class ReviewGame {
  const ReviewGame({required this.record, required this.topicMistakes, required this.allMistakes});

  final GameRecord record;

  /// Fehlzüge zum Fokusthema und alle Fehlzüge dieser Partie.
  final int topicMistakes;
  final int allMistakes;

  int? get accuracy => record.analysis.accuracy;
}

class FocusReview {
  const FocusReview({
    required this.focus,
    required this.status,
    required this.games,
    required this.occurrences,
    required this.perGameBefore,
    required this.perGameNow,
    required this.change,
    required this.accuracyNow,
    required this.accuracyBefore,
    required this.puzzleAttempts,
    required this.puzzleClean,
    required this.moments,
  });

  final FocusEntry focus;
  final FocusStatus status;

  /// Die gezählten Partien der Woche, älteste zuerst, und darin die Fehlzüge des Themas.
  final List<ReviewGame> games;
  final int occurrences;

  /// Fehlzüge des Themas je Partie: vorher (Ausgangslage beim Start) und in der Woche (null ohne Partien).
  final double perGameBefore;
  final double? perGameNow;

  /// Veränderung in Prozent (negativ = besser); null, wenn es vorher keine gab oder noch keine Partie gespielt wurde.
  final double? change;

  /// Durchschnittliche Genauigkeit in der Woche und in den Partien davor (null ohne Werte).
  final double? accuracyNow;
  final double? accuracyBefore;

  /// Puzzle-Versuche zum Thema während der Woche und davon sauber gelöste.
  final int puzzleAttempts;
  final int puzzleClean;

  /// Die Fehlzüge zum Thema in den gezählten Partien, zum Nachschauen.
  final List<({GameRecord game, Moment moment})> moments;
}

double? _mean(Iterable<int> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;

/// Baut den Rückblick zu [f]. Gezählt werden dieselben Partien wie bei der Auswertung ([evaluateFocus]).
FocusReview buildFocusReview(FocusEntry f, List<GameRecord> records, {int puzzleAttempts = 0, int puzzleClean = 0}) {
  final from = DateTime.utc(f.startedAt.toUtc().year, f.startedAt.toUtc().month, f.startedAt.toUtc().day);
  final to = f.endsAt.toUtc();
  final inWeek = [
    for (final r in records)
      if (!r.playedAt.isBefore(from) && r.playedAt.isBefore(to)) r,
  ]..sort((a, b) => a.playedAt.compareTo(b.playedAt));
  final counted = inWeek.take(f.goalGames).toList();
  final games = [
    for (final r in counted)
      ReviewGame(
        record: r,
        topicMistakes: r.analysis.flagged.where((m) => topicsOf(m).contains(f.topic)).length,
        allMistakes: r.analysis.flagged.length,
      ),
  ];
  final occ = games.fold(0, (a, g) => a + g.topicMistakes);
  final before = f.baselineGames == 0 ? 0.0 : f.baselineCount / f.baselineGames;
  final now = games.isEmpty ? null : occ / games.length;
  return FocusReview(
    focus: f,
    status: f.status,
    games: games,
    occurrences: occ,
    perGameBefore: before,
    perGameNow: now,
    change: now == null || before == 0 ? null : (now - before) / before * 100,
    accuracyNow: _mean([for (final g in games) if (g.accuracy != null) g.accuracy!]),
    accuracyBefore: _mean([
      for (final r in records)
        if (r.playedAt.isBefore(from) && r.analysis.accuracy != null) r.analysis.accuracy!,
    ]),
    puzzleAttempts: puzzleAttempts,
    puzzleClean: puzzleClean,
    moments: [
      for (final g in games)
        for (final m in ([...g.record.analysis.flagged]..sort((a, b) => a.ply.compareTo(b.ply))))
          if (topicsOf(m).contains(f.topic)) (game: g.record, moment: m),
    ],
  );
}
