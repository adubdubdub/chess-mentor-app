/// Zweizügige Puzzles: Nach dem ersten richtigen Zug antwortet der Gegner, und der nächste eigene Zug
/// wird gefragt, aber nur wenn er eindeutig ist (deutlich besser als jede Alternative).
library;

import 'package:dartchess/dartchess.dart';

import '../analysis/analysis.dart';
import '../analysis/chess_utils.dart';
import '../analysis/uci.dart';

/// Abstand in Gewinnchance-Prozentpunkten, ab dem der beste Zug als eindeutig gilt.
const uniqueGap = 15.0;

class FollowUp {
  const FollowUp({required this.fen, required this.reply, required this.move});

  /// Stellung vor dem Gegnerzug (nach dem ersten eigenen Zug).
  final String fen;

  /// Antwort des Gegners (Standard-UCI) und der gesuchte eigene Zug (Standard-UCI).
  final String reply;
  final String move;
}

/// Sucht den eindeutigen Folgezug nach [line] (erster eigener Zug, Antwort, ...), sonst null.
/// [line] muss mindestens drei Halbzüge haben, damit es überhaupt einen Folgezug gibt.
Future<FollowUp?> findFollowUp(String fen, List<String> line, UciEngine engine, {int depth = 16}) async {
  if (line.length < 3) return null;
  Position pos = Chess.fromSetup(Setup.parseFen(fen));
  final me = pos.turn;
  for (final u in line.take(2)) {
    final m = Move.parse(u);
    if (m is! NormalMove || !pos.isLegal(m)) return null;
    pos = pos.play(m);
    if (pos.isGameOver) return null;
  }
  final afterFirst = Chess.fromSetup(Setup.parseFen(fen)).play(Move.parse(line[0])! as NormalMove);
  final lines = await engine.analyse(rootFen: fen, moves: [line[0], line[1]], depth: depth, multiPv: 2);
  if (lines.isEmpty) return null;
  final best = legalPrefix(pos, lines.first.pv, 1);
  if (best.isEmpty) return null;
  if (lines.length > 1) {
    final a = winPct(lines[0].score, pos.turn, me);
    final b = winPct(lines[1].score, pos.turn, me);
    if (a - b < uniqueGap) return null;
  }
  return FollowUp(fen: afterFirst.fen, reply: line[1], move: best.first);
}
