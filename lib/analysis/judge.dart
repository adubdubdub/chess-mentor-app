/// Bewertung eines Lösungsversuchs (Port von judge() in analysis.py des Bots).
library;

import 'package:dartchess/dartchess.dart';

import 'analysis.dart';
import 'uci.dart';

enum Verdict {
  /// Genau der Engine-Zug.
  best,

  /// Fast so stark wie der Engine-Zug (weniger als 5 Prozentpunkte schwächer).
  good,

  /// Derselbe Zug wie in der Partie.
  played,

  /// Deutlich schwächer.
  weak,
}

/// Prüft [uci] (Standard-UCI, Rochade als e1g1) in der Stellung des Moments.
/// Gibt das Urteil und die Gewinnchance nach dem Zug aus Sicht des Ziehenden zurück.
Future<(Verdict, double)> judgeMove(Moment m, String uci, UciEngine engine, {int depth = 16}) async {
  if (uci == m.bestUci) return (Verdict.best, m.winBefore);
  if (uci == m.playedUci) return (Verdict.played, m.winAfter);
  final pos = Chess.fromSetup(Setup.parseFen(m.fen));
  final move = Move.parse(uci);
  if (move is! NormalMove || !pos.isLegal(move)) return (Verdict.weak, 0.0);
  final after = pos.play(move);
  final Score score;
  if (after.isCheckmate) {
    score = const Score.mated();
  } else if (after.isGameOver) {
    score = const Score.cp(0);
  } else {
    final lines = await engine.analyse(rootFen: m.fen, moves: [uci], depth: depth, multiPv: 1);
    score = lines.first.score;
  }
  final win = winPct(score, after.turn, pos.turn);
  final rounded = (win * 10).round() / 10;
  return (m.winBefore - win < 5 ? Verdict.good : Verdict.weak, rounded);
}
