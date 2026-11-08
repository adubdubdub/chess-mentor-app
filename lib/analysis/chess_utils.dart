/// Schach-Hilfen für die Analyse (Gegenstück zu den Hilfsfunktionen in analysis.py des Bots).
library;

import 'package:dartchess/dartchess.dart';

const pieceValues = {Role.pawn: 1, Role.knight: 3, Role.bishop: 3, Role.rook: 5, Role.queen: 9};

/// Zug in Standard-UCI wie Stockfish: Rochade als Königszug (e1g1), nicht König-auf-Turm (e1h1) wie dartchess.
String stdUci(Position pos, NormalMove move) {
  final piece = pos.board.pieceAt(move.from);
  if (piece?.role == Role.king) {
    final target = pos.board.pieceAt(move.to);
    final ownRook = target?.role == Role.rook && target?.color == piece!.color;
    if (ownRook || (move.to.file - move.from.file).abs() == 2) {
      final file = move.to.file > move.from.file ? File.g : File.c;
      return move.from.name + Square.fromCoords(file, move.from.rank).name;
    }
  }
  return move.uci;
}

/// UCI-Zug (auch e1g1) zu einem legalen Zug der Stellung, sonst null.
NormalMove? legalUci(Position pos, String uci) {
  final move = Move.parse(uci);
  if (move is! NormalMove || !pos.isLegal(move)) return null;
  return move;
}

/// Materialbilanz aus Sicht von [side].
int material(Position pos, Side side) {
  var sum = 0;
  pieceValues.forEach((role, value) {
    sum += value * (pos.board.piecesOf(side, role).size - pos.board.piecesOf(side.opposite, role).size);
  });
  return sum;
}

bool isCapture(Position pos, NormalMove move) {
  final mover = pos.board.pieceAt(move.from);
  final target = pos.board.pieceAt(move.to);
  if (target != null) return target.color != mover?.color;
  return mover?.role == Role.pawn && move.to == pos.epSquare;
}

bool givesCheck(Position pos, NormalMove move) => pos.play(move).isCheck;

/// Züge als nummerierte SAN ab [pos]: "1.e4 e5 2.Nf3", ab Schwarz "6...Bc6 7.f4".
String numbered(Position pos, List<NormalMove> moves) {
  final out = <String>[];
  var p = pos;
  for (var i = 0; i < moves.length; i++) {
    final (next, san) = p.makeSan(moves[i]);
    if (p.turn == Side.white) {
      out.add('${p.fullmoves}.$san');
    } else {
      out.add(i == 0 ? '${p.fullmoves}...$san' : san);
    }
    p = next;
  }
  return out.join(' ');
}

/// Engine-Variante als nummerierte SAN (höchstens [n] Züge) und Materialänderung aus Sicht des Ziehenden.
(String, int) line(Position pos, List<String> pv, [int n = 6]) {
  final me = pos.turn;
  final start = material(pos, me);
  final legal = <NormalMove>[];
  var p = pos;
  for (final uci in pv.take(n)) {
    final move = legalUci(p, uci);
    if (move == null) break;
    legal.add(move);
    p = p.play(move);
  }
  return (numbered(pos, legal), material(p, me) - start);
}

/// Legaler Anfang einer Engine-Variante (höchstens [n] Züge) als Standard-UCI.
List<String> legalPrefix(Position pos, List<String> pv, int n) {
  final out = <String>[];
  var p = pos;
  for (final uci in pv.take(n)) {
    final move = legalUci(p, uci);
    if (move == null) break;
    out.add(uci);
    p = p.play(move);
  }
  return out;
}

/// Nummerierte englische SAN ("12...Nf6 13.Bxf4") zurück in Standard-UCI, bis zum ersten unlesbaren Zug.
List<String> pvFromLine(Position pos, String line) {
  final out = <String>[];
  var p = pos;
  for (final token in line.split(' ')) {
    final san = token.replaceFirst(RegExp(r'^\d+\.(\.\.)?'), '');
    if (san.isEmpty) continue;
    final move = p.parseSan(san);
    if (move is! NormalMove) break;
    out.add(stdUci(p, move));
    p = p.play(move);
  }
  return out;
}

/// Deutsche Figurenbuchstaben (S, L, T, D, K) in SAN.
String germanSan(String san) =>
    san.replaceAllMapped(RegExp('[NBRQ]'), (m) => const {'N': 'S', 'B': 'L', 'R': 'T', 'Q': 'D'}[m[0]]!);

enum GamePhase { opening, middlegame, endgame }

GamePhase phase(Position pos) {
  if (pos.fullmoves <= 10) return GamePhase.opening;
  var heavy = 0;
  for (final role in [Role.knight, Role.bishop, Role.rook, Role.queen]) {
    for (final side in Side.values) {
      heavy += pieceValues[role]! * pos.board.piecesOf(side, role).size;
    }
  }
  return heavy <= 13 ? GamePhase.endgame : GamePhase.middlegame;
}
