/// Eingabedaten für das Profil: eine analysierte Partie mit dem Lernstand ihrer Puzzles.
library;

import 'package:dartchess/dartchess.dart' show Side;

import '../analysis/analysis.dart';
import '../analysis/chess_utils.dart';

/// Lernstand eines Puzzles: Stufe, gemeistert, Zahl der Versuche und davon „sauber“ (erster Versuch ohne Tipp).
class PuzzleState {
  const PuzzleState({this.level = 0, this.mastered = false, this.attempts = 0, this.clean = 0});

  final int level;
  final bool mastered;
  final int attempts;
  final int clean;
}

class GameRecord {
  GameRecord({
    required this.id,
    required this.playedAt,
    required this.analysis,
    this.puzzles = const {},
    this.ownMovesByPhase = const {},
  });

  /// Aus PGN, Analyse und Puzzle-Ständen (nach Zugnummer `ply`). Die eigenen Züge je Phase ergeben sich aus der PGN.
  factory GameRecord.fromParts({
    required int id,
    required DateTime playedAt,
    required String pgn,
    required GameAnalysis analysis,
    Map<int, PuzzleState> puzzles = const {},
  }) {
    final byPhase = <GamePhase, int>{};
    final parsed = ParsedGame.parse(pgn);
    if (parsed != null) {
      var pos = parsed.start;
      for (final move in parsed.moves) {
        if (pos.turn == analysis.color) byPhase.update(phase(pos), (n) => n + 1, ifAbsent: () => 1);
        pos = pos.play(move);
      }
    }
    return GameRecord(id: id, playedAt: playedAt, analysis: analysis, puzzles: puzzles, ownMovesByPhase: byPhase);
  }

  final int id;
  final DateTime playedAt;
  final GameAnalysis analysis;

  /// Nach Zugnummer (ply) des Fehlzugs.
  final Map<int, PuzzleState> puzzles;
  final Map<GamePhase, int> ownMovesByPhase;

  /// Eigene Züge der Partie; ohne PGN-Auswertung aus der Halbzugzahl geschätzt.
  int get ownMoves {
    final fromPhases = ownMovesByPhase.values.fold(0, (a, b) => a + b);
    if (fromPhases > 0) return fromPhases;
    final plies = analysis.moves;
    return analysis.color == Side.white ? (plies + 1) ~/ 2 : plies ~/ 2;
  }

  /// Spieldatum aus den PGN-Kopfzeilen (`UTCDate`/`UTCTime`, sonst `Date`), sonst [fallback].
  static DateTime playedAtFrom(String pgn, DateTime fallback) {
    String? tag(String name) => RegExp('\\[$name "([^"]*)"\\]').firstMatch(pgn)?.group(1);
    final d = tag('UTCDate') ?? tag('Date');
    final m = d == null ? null : RegExp(r'^(\d{4})\.(\d{2})\.(\d{2})$').firstMatch(d);
    if (m == null) return fallback;
    final t = tag('UTCTime') ?? tag('StartTime');
    final tm = t == null ? null : RegExp(r'^(\d{2}):(\d{2}):(\d{2})$').firstMatch(t);
    return DateTime.utc(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      tm == null ? 12 : int.parse(tm.group(1)!),
      tm == null ? 0 : int.parse(tm.group(2)!),
      tm == null ? 0 : int.parse(tm.group(3)!),
    );
  }
}
