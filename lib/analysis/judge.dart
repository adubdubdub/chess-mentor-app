/// Bewertung eines Lösungsversuchs (Port von judge() in analysis.py des Bots).
library;

import 'package:dartchess/dartchess.dart';

import 'analysis.dart';
import 'chess_utils.dart';
import 'uci.dart';

enum Verdict {
  /// Genau der beste Zug laut Stockfish.
  best,

  /// Fast so stark wie der beste Zug (weniger als 5 Prozentpunkte schwächer).
  good,

  /// Derselbe Zug wie in der Partie.
  played,

  /// Deutlich schwächer.
  weak,
}

/// Prüft [uci] (Standard-UCI, Rochade als e1g1) in der Stellung des Moments.
/// Gibt das Urteil, die Gewinnchance nach dem Zug aus Sicht des Ziehenden und die erwartete Variante
/// (beginnt mit [uci], Standard-UCI) zurück.
Future<(Verdict, double, List<String>)> judgeMove(Moment m, String uci, UciEngine engine, {int depth = 16}) async {
  if (uci == m.bestUci) return (Verdict.best, m.winBefore, m.bestMoves);
  if (uci == m.playedUci) return (Verdict.played, m.winAfter, m.playedMoves);
  final pos = Chess.fromSetup(Setup.parseFen(m.fen));
  final move = Move.parse(uci);
  if (move is! NormalMove || !pos.isLegal(move)) return (Verdict.weak, 0.0, <String>[]);
  final after = pos.play(move);
  final Score score;
  var pv = <String>[];
  if (after.isCheckmate) {
    score = const Score.mated();
  } else if (after.isGameOver) {
    score = const Score.cp(0);
  } else {
    final lines = await engine.analyse(rootFen: m.fen, moves: [uci], depth: depth, multiPv: 1);
    score = lines.first.score;
    pv = legalPrefix(after, lines.first.pv, pvPlies - 1);
  }
  final win = winPct(score, after.turn, pos.turn);
  final rounded = (win * 10).round() / 10;
  return (m.winBefore - win < 5 ? Verdict.good : Verdict.weak, rounded, [uci, ...pv]);
}
