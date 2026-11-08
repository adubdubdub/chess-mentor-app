/// Einfache Brett-Fakten zu einem Zug und zur Antwort darauf: Was wird geschlagen, was hängt, gibt es eine Gabel?
///
/// Grundlage für verständliche Erklärungen ohne Sprachmodell. Die Züge selbst stammen immer aus Stockfish,
/// hier wird nur beschrieben, was auf dem Brett passiert.
library;

import 'package:dartchess/dartchess.dart';

import '../analysis/chess_utils.dart';

/// Wert einer Figur in Bauerneinheiten; König zählt hier als unendlich wertvoll.
int value(Role role) => role == Role.king ? 100 : pieceValues[role]!;

/// Eine Figur auf einem Feld.
typedef Target = ({Role role, Square square});

/// Ist die Figur auf [sq] in Gefahr: angegriffen und ungedeckt oder von einer billigeren Figur angegriffen?
bool enPrise(Position pos, Square sq) {
  final piece = pos.board.pieceAt(sq);
  if (piece == null || piece.role == Role.king) return false;
  final attackers = pos.board.attacksTo(sq, piece.color.opposite);
  if (attackers.isEmpty) return false;
  if (pos.board.attacksTo(sq, piece.color).isEmpty) return true;
  final cheapest = attackers.squares.map((s) => value(pos.board.roleAt(s)!)).reduce((a, b) => a < b ? a : b);
  return cheapest < value(piece.role);
}

/// Was ein einzelner Zug auf dem Brett bewirkt.
class MoveFacts {
  MoveFacts._({
    required this.move,
    required this.side,
    required this.mover,
    required this.captured,
    required this.capturedUndefended,
    required this.check,
    required this.mate,
    required this.targets,
    required this.rescued,
    required this.castles,
    required this.develops,
    required this.centerPawn,
  });

  /// Fakten zu [uci] in [pos]; null, wenn der Zug nicht legal ist.
  static MoveFacts? of(Position pos, String uci) {
    final move = legalUci(pos, uci);
    if (move == null) return null;
    final mover = pos.board.pieceAt(move.from)!;
    final after = pos.play(move);
    final to = Square.parse(uci.substring(2, 4))!;
    Target? captured;
    var undefended = false;
    if (isCapture(pos, move)) {
      final sq = pos.board.pieceAt(to) != null ? to : Square.fromCoords(to.file, move.from.rank);
      captured = (role: pos.board.roleAt(sq) ?? Role.pawn, square: sq);
      undefended = pos.board.attacksTo(sq, mover.color.opposite).isEmpty;
    }
    // Gabel/Doppelangriff: wertvolle Ziele der gezogenen Figur nach dem Zug
    final targets = <Target>[];
    final piece = after.board.pieceAt(to);
    if (piece != null) {
      final hit = attacks(piece, to, after.board.occupied).intersect(after.board.bySide(mover.color.opposite));
      for (final sq in hit.squares) {
        final role = after.board.roleAt(sq)!;
        final worthIt =
            role == Role.king ||
            (value(role) >= 3 &&
                (value(role) > value(piece.role) || after.board.attacksTo(sq, piece.color.opposite).isEmpty));
        if (worthIt) targets.add((role: role, square: sq));
      }
      targets.sort((a, b) => value(b.role).compareTo(value(a.role)));
    }
    final castles = mover.role == Role.king && (move.from.file - to.file).abs() == 2;
    final homeRank = mover.color == Side.white ? Rank.first : Rank.eighth;
    return MoveFacts._(
      move: move,
      side: mover.color,
      mover: mover.role,
      captured: captured,
      capturedUndefended: undefended,
      check: after.isCheck,
      mate: after.isCheckmate,
      targets: targets,
      rescued: mover.role != Role.king && enPrise(pos, move.from) && !enPrise(after, to),
      castles: castles,
      develops: (mover.role == Role.knight || mover.role == Role.bishop) && move.from.rank == homeRank,
      centerPawn:
          mover.role == Role.pawn &&
          (to.file == File.d || to.file == File.e) &&
          (to.rank == Rank.fourth || to.rank == Rank.fifth),
    );
  }

  final NormalMove move;
  final Side side;
  final Role mover;
  final Target? captured;

  /// Die geschlagene Figur war vor dem Zug von niemandem gedeckt.
  final bool capturedUndefended;
  final bool check;
  final bool mate;

  /// Wertvolle gegnerische Figuren, die die gezogene Figur danach angreift (König, wertvoller oder ungedeckt).
  final List<Target> targets;

  /// Die gezogene Figur stand in Gefahr und ist danach sicher.
  final bool rescued;
  final bool castles;
  final bool develops;
  final bool centerPawn;

  /// Gabel: mindestens zwei wertvolle Ziele gleichzeitig.
  bool get fork => targets.length >= 2;
}

/// Was nach dem eigenen Zug [own] schiefgeht: die beste Antwort des Gegners und ihr Zusammenhang mit dem Zug.
class Problem {
  Problem._(this.reply, this.lostMovedPiece, this.threatIgnored, this.defenderLeft);

  /// [line] beginnt mit dem eigenen Zug, danach die erwartete Antwort.
  static Problem? of(Position pos, List<String> line) {
    if (line.length < 2) return null;
    final own = legalUci(pos, line[0]);
    if (own == null) return null;
    final after = pos.play(own);
    final reply = MoveFacts.of(after, line[1]);
    if (reply == null) return null;
    final to = Square.parse(line[0].substring(2, 4))!;
    final cap = reply.captured;
    var lost = false, ignored = false;
    Square? defender;
    if (cap != null) {
      lost = cap.square == to;
      // Stand die Figur schon vorher dort und war angegriffen? Dann bestand die Drohung schon.
      ignored = !lost && pos.board.pieceAt(cap.square)?.color == pos.turn && enPrise(pos, cap.square);
      // Hat die gezogene Figur das Feld vorher gedeckt?
      if (!lost && !ignored) {
        final defendersBefore = pos.board.attacksTo(cap.square, pos.turn);
        if (defendersBefore.has(own.from) && after.board.attacksTo(cap.square, pos.turn).isEmpty) defender = own.from;
      }
    }
    return Problem._(reply, lost, ignored, defender);
  }

  final MoveFacts reply;

  /// Der Gegner schlägt genau die Figur, die gerade gezogen wurde.
  final bool lostMovedPiece;

  /// Die geschlagene Figur war schon vor dem Zug in Gefahr.
  final bool threatIgnored;

  /// Feld der Figur, die vorher gedeckt hat und weggezogen ist.
  final Square? defenderLeft;
}

/// Materialänderung entlang einer Variante aus Sicht von [side] (nur legale Züge).
int lineMaterial(Position pos, List<String> line, Side side) {
  var p = pos;
  final start = material(p, side);
  for (final uci in line) {
    final move = legalUci(p, uci);
    if (move == null) break;
    p = p.play(move);
  }
  return material(p, side) - start;
}

/// Variante als Liste nummerierter SAN je Halbzug ("12.Qxb5+", "12...Kf8"), nur legale Züge.
List<String> lineSans(Position pos, List<String> line) {
  final out = <String>[];
  var p = pos;
  for (final uci in line) {
    final move = legalUci(p, uci);
    if (move == null) break;
    out.add(numbered(p, [move]));
    p = p.play(move);
  }
  return out;
}
