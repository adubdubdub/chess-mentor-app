/// Schwächenprofil über die letzten Partien (Schritt 6a): Häufigkeit, Schwere, Trend und Puzzle-Stand je Thema.
library;

import '../analysis/analysis.dart';
import '../analysis/chess_utils.dart';
import 'records.dart';
import 'topics.dart';

/// Fenster: so viele der neuesten Partien fließen ein.
const profileWindow = 20;

/// Für den Trend: so viele neueste Partien gegen die davor.
const trendRecent = 5;

/// Aussagen erst ab so vielen Partien, und je Thema ab so vielen Vorkommen.
const minGames = 5;
const minOccurrences = 3;

class TopicStat {
  const TopicStat({
    required this.topic,
    required this.count,
    required this.games,
    required this.per100,
    required this.avgDrop,
    required this.trend,
    required this.puzzles,
    required this.mastered,
    required this.cleanRate,
    required this.score,
    required this.enough,
  });

  final Topic topic;

  /// Fehlzüge mit diesem Thema und in wie vielen Partien.
  final int count;
  final int games;

  /// Fehlzüge je 100 eigene Züge.
  final double per100;

  /// Durchschnittlicher Verlust an Gewinnchance (Prozentpunkte).
  final double avgDrop;

  /// Veränderung von per100: neueste [trendRecent] Partien minus die davor; null bei zu wenig Partien.
  /// Negativ = besser.
  final double? trend;

  /// Zugehörige Puzzles, davon gemeistert, und Anteil sauber gelöster Versuche (null ohne Versuche).
  final int puzzles;
  final int mastered;
  final double? cleanRate;

  /// Rangordnung für den Wochenfokus: Häufigkeit × Schwere × (1 − Beherrschung).
  final double score;

  /// Genug Daten für eine Aussage (Partien und Vorkommen).
  final bool enough;

  double get mastery => puzzles == 0 ? 0 : mastered / puzzles;
}

class PhaseStat {
  const PhaseStat({required this.phase, required this.moves, required this.mistakes, required this.per100});

  final GamePhase phase;
  final int moves;
  final int mistakes;
  final double per100;
}

class OpeningStat {
  const OpeningStat({required this.name, required this.games, required this.mistakes, required this.accuracy});

  final String name;
  final int games;
  final int mistakes;
  final double? accuracy;
}

class Profile {
  const Profile({
    required this.games,
    required this.ownMoves,
    required this.accuracy,
    required this.accuracySeries,
    required this.counts,
    required this.topics,
    required this.untagged,
    required this.phases,
    required this.openings,
  });

  /// Partien im Fenster, eigene Züge, durchschnittliche Genauigkeit (null ohne Werte).
  final int games;
  final int ownMoves;
  final double? accuracy;

  /// Genauigkeit je Partie, älteste zuerst.
  final List<({DateTime at, int accuracy})> accuracySeries;

  /// Fehlzüge nach Schwere (Ungenauigkeit, Fehler, Patzer).
  final Map<MistakeClass, int> counts;

  /// Nach [TopicStat.score] absteigend; nur Themen mit mindestens einem Vorkommen.
  final List<TopicStat> topics;

  /// Fehlzüge ohne erkennbares Thema.
  final int untagged;
  final List<PhaseStat> phases;

  /// Nur Eröffnungsfamilien mit mindestens [minOccurrences] Partien.
  final List<OpeningStat> openings;

  bool get enough => games >= minGames;

  /// Themen mit genug Daten, beste Kandidaten für den Wochenfokus zuerst.
  List<TopicStat> get candidates => [for (final t in topics) if (t.enough) t];
}

/// Eröffnungsfamilie: „Italian Game: Giuoco Piano“ → „Italian Game“.
String openingFamily(String name) {
  final n = name.trim();
  if (n.isEmpty) return '';
  return n.split(RegExp(r'[:,]')).first.trim();
}

Profile buildProfile(List<GameRecord> records, {int window = profileWindow, int recent = trendRecent}) {
  final games = ([...records]..sort((a, b) => b.playedAt.compareTo(a.playedAt))).take(window).toList();
  final newest = games.take(recent).toList();
  final older = games.skip(recent).toList();

  int moves(Iterable<GameRecord> g) => g.fold(0, (a, r) => a + r.ownMoves);
  double rate(int count, int own) => own == 0 ? 0 : 100 * count / own;

  final ownMoves = moves(games);
  final counts = {for (final c in MistakeClass.values) c: 0};
  final accuracies = <int>[];
  final series = <({DateTime at, int accuracy})>[];
  for (final g in games.reversed) {
    final a = g.analysis.accuracy;
    if (a != null) {
      accuracies.add(a);
      series.add((at: g.playedAt, accuracy: a));
    }
  }

  // Fehlzüge einer Gruppe von Partien nach Thema sammeln
  Map<Topic, List<(Moment, GameRecord)>> byTopic(Iterable<GameRecord> g) {
    final out = <Topic, List<(Moment, GameRecord)>>{};
    for (final r in g) {
      for (final m in r.analysis.flagged) {
        for (final t in topicsOf(m)) {
          (out[t] ??= []).add((m, r));
        }
      }
    }
    return out;
  }

  var untagged = 0;
  for (final g in games) {
    for (final m in g.analysis.flagged) {
      counts.update(m.mistake, (n) => n + 1);
      if (topicsOf(m).isEmpty) untagged++;
    }
  }

  final all = byTopic(games);
  final recentBy = byTopic(newest);
  final olderBy = byTopic(older);
  final recentMoves = moves(newest), olderMoves = moves(older);
  final canTrend = newest.length >= trendRecent && older.length >= trendRecent;

  final topics = <TopicStat>[];
  for (final entry in all.entries) {
    final items = entry.value;
    final count = items.length;
    final per100 = rate(count, ownMoves);
    final avgDrop = items.fold(0.0, (a, i) => a + i.$1.drop) / count;
    var puzzles = 0, mastered = 0, attempts = 0, clean = 0;
    for (final (m, r) in items) {
      final p = r.puzzles[m.ply];
      if (p == null) continue;
      puzzles++;
      if (p.mastered) mastered++;
      attempts += p.attempts;
      clean += p.clean;
    }
    final mastery = puzzles == 0 ? 0.0 : mastered / puzzles;
    final enough = games.length >= minGames && count >= minOccurrences;
    topics.add(
      TopicStat(
        topic: entry.key,
        count: count,
        games: {for (final i in items) i.$2.id}.length,
        per100: per100,
        avgDrop: avgDrop,
        trend: canTrend
            ? rate(recentBy[entry.key]?.length ?? 0, recentMoves) - rate(olderBy[entry.key]?.length ?? 0, olderMoves)
            : null,
        puzzles: puzzles,
        mastered: mastered,
        cleanRate: attempts == 0 ? null : clean / attempts,
        score: per100 * avgDrop * (1 - mastery),
        enough: enough,
      ),
    );
  }
  topics.sort((a, b) => b.score.compareTo(a.score));

  // Phasen: Fehlzüge je 100 eigene Züge in dieser Phase
  final phases = <PhaseStat>[];
  for (final ph in GamePhase.values) {
    final own = games.fold(0, (a, r) => a + (r.ownMovesByPhase[ph] ?? 0));
    final bad = [for (final g in games) for (final m in g.analysis.flagged) if (m.phase == ph) m].length;
    if (own > 0 || bad > 0) phases.add(PhaseStat(phase: ph, moves: own, mistakes: bad, per100: rate(bad, own)));
  }

  // Eröffnungen nach Familie
  final fam = <String, List<GameRecord>>{};
  for (final g in games) {
    final f = openingFamily(g.analysis.opening);
    if (f.isNotEmpty) (fam[f] ??= []).add(g);
  }
  final openings = [
    for (final e in fam.entries)
      if (e.value.length >= minOccurrences)
        OpeningStat(
          name: e.key,
          games: e.value.length,
          mistakes: e.value.fold(0, (a, g) => a + g.analysis.flagged.length),
          accuracy: _mean([for (final g in e.value) if (g.analysis.accuracy != null) g.analysis.accuracy!]),
        ),
  ]..sort((a, b) => b.games.compareTo(a.games));

  return Profile(
    games: games.length,
    ownMoves: ownMoves,
    accuracy: _mean(accuracies),
    accuracySeries: series,
    counts: counts,
    topics: topics,
    untagged: untagged,
    phases: phases,
    openings: openings,
  );
}

double? _mean(List<int> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
