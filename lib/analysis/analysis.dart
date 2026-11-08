/// Engine-Analyse einer Partie: Gewinnchance je Zug, Fehler-Einstufung wie Lichess, Schlüsselmomente mit Fakten.
///
/// Port von analysis.py des Telegram-Bots. Stockfish liefert alle schachlichen Aussagen, Texte entstehen später
/// daraus. Züge werden in englischer SAN gespeichert und erst in der Oberfläche übersetzt.
library;

import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';

import 'chess_utils.dart';
import 'uci.dart';

const maxMoments = 4;

/// Ab diesem Verlust an Gewinnchance (Prozentpunkte) wird ein eigener Zug zum Wiederholungs-Puzzle.
const puzzleMinDrop = 10.0;

/// Lichess-Schwellen: Verlust an Gewinnchance in Prozentpunkten.
enum MistakeClass {
  blunder(15, '??'),
  mistake(10, '?'),
  inaccuracy(5, '?!');

  const MistakeClass(this.threshold, this.glyph);
  final double threshold;
  final String glyph;

  static MistakeClass? forDrop(double drop) {
    for (final c in values) {
      if (drop >= c.threshold) return c;
    }
    return null;
  }
}

final _computer = RegExp(r'stockfish|computer|engine|\bai\b|level|\bki\b', caseSensitive: false);

/// Gewinnchance in Prozent aus Sicht von [side]; [score] gilt für die Seite am Zug [turn].
double winPct(Score score, Side turn, Side side) {
  final cp = (turn == side ? score : score.flipped).centipawns();
  return 50 + 50 * (2 / (1 + math.exp(-0.00368208 * cp)) - 1);
}

double moveAccuracy(double drop) => math.max(0, math.min(100, 103.1668 * math.exp(-0.04354 * drop) - 3.1669));

double _round1(double x) => (x * 10).round() / 10;

/// Eingelesene Partie: Startstellung und legale Hauptvariante.
class ParsedGame {
  ParsedGame(this.headers, this.start, this.moves);

  final Map<String, String> headers;
  final Position start;
  final List<NormalMove> moves;

  /// PGN lesen; null bei Fehlern, illegalen Zügen oder ohne Züge.
  static ParsedGame? parse(String pgn) {
    try {
      final game = PgnGame.parsePgn(pgn);
      var pos = PgnGame.startingPosition(game.headers);
      final start = pos;
      final moves = <NormalMove>[];
      for (final node in game.moves.mainline()) {
        final move = pos.parseSan(node.san);
        if (move is! NormalMove) return null;
        moves.add(move);
        pos = pos.play(move);
      }
      return moves.isEmpty ? null : ParsedGame(game.headers, start, moves);
    } catch (_) {
      return null;
    }
  }

  /// Farbe des Nutzers: Lichess-Name oder ein erkennbarer Computer-Gegner; sonst null (nachfragen).
  Side? guessColor({String lichessUser = ''}) {
    final w = headers['White'] ?? '', b = headers['Black'] ?? '';
    final user = lichessUser.toLowerCase();
    if (user.isNotEmpty && w.toLowerCase() == user) return Side.white;
    if (user.isNotEmpty && b.toLowerCase() == user) return Side.black;
    if (_computer.hasMatch(b) && !_computer.hasMatch(w)) return Side.white;
    if (_computer.hasMatch(w) && !_computer.hasMatch(b)) return Side.black;
    return null;
  }
}

class Motif {
  const Motif(this.code, [this.n]);

  /// mate_missed (n Züge), allows_mate, hangs_material, wins_material (n Bauerneinheiten), best_is_check, best_is_capture
  final String code;
  final int? n;

  Map<String, dynamic> toJson() => {'code': code, if (n != null) 'n': n};
  factory Motif.fromJson(Map<String, dynamic> j) => Motif(j['code'] as String, j['n'] as int?);
}

class Alternative {
  const Alternative(this.san, this.uci, this.win);

  final String san;
  final String uci;
  final double win;

  Map<String, dynamic> toJson() => {'san': san, 'uci': uci, 'win': win};
  factory Alternative.fromJson(Map<String, dynamic> j) =>
      Alternative(j['san'] as String, j['uci'] as String, (j['win'] as num).toDouble());
}

/// Ein eigener Fehler mit allen Fakten für Besprechung und Puzzle.
class Moment {
  const Moment({
    required this.ply,
    required this.moveNo,
    required this.fen,
    required this.lastMove,
    required this.opponentLast,
    required this.played,
    required this.playedUci,
    required this.alternatives,
    required this.bestLine,
    required this.replyLine,
    required this.threatReply,
    required this.winBefore,
    required this.winAfter,
    required this.drop,
    required this.mistake,
    required this.phase,
    required this.motifs,
  });

  final int ply;
  final int moveNo;

  /// Stellung VOR dem Partiezug.
  final String fen;
  final String? lastMove;
  final String? opponentLast;
  final String played;
  final String playedUci;
  final List<Alternative> alternatives;
  final String bestLine;
  final String replyLine;
  final String? threatReply;
  final double winBefore;
  final double winAfter;
  final double drop;
  final MistakeClass mistake;
  final GamePhase phase;
  final List<Motif> motifs;

  String get best => alternatives.first.san;
  String get bestUci => alternatives.first.uci;

  Map<String, dynamic> toJson() => {
    'ply': ply,
    'moveNo': moveNo,
    'fen': fen,
    'lastMove': lastMove,
    'opponentLast': opponentLast,
    'played': played,
    'playedUci': playedUci,
    'alternatives': [for (final a in alternatives) a.toJson()],
    'bestLine': bestLine,
    'replyLine': replyLine,
    'threatReply': threatReply,
    'winBefore': winBefore,
    'winAfter': winAfter,
    'drop': drop,
    'mistake': mistake.name,
    'phase': phase.name,
    'motifs': [for (final m in motifs) m.toJson()],
  };

  factory Moment.fromJson(Map<String, dynamic> j) => Moment(
    ply: j['ply'] as int,
    moveNo: j['moveNo'] as int,
    fen: j['fen'] as String,
    lastMove: j['lastMove'] as String?,
    opponentLast: j['opponentLast'] as String?,
    played: j['played'] as String,
    playedUci: j['playedUci'] as String,
    alternatives: [for (final a in j['alternatives'] as List) Alternative.fromJson(a as Map<String, dynamic>)],
    bestLine: j['bestLine'] as String,
    replyLine: j['replyLine'] as String,
    threatReply: j['threatReply'] as String?,
    winBefore: (j['winBefore'] as num).toDouble(),
    winAfter: (j['winAfter'] as num).toDouble(),
    drop: (j['drop'] as num).toDouble(),
    mistake: MistakeClass.values.byName(j['mistake'] as String),
    phase: GamePhase.values.byName(j['phase'] as String),
    motifs: [for (final m in j['motifs'] as List) Motif.fromJson(m as Map<String, dynamic>)],
  );
}

class GameAnalysis {
  const GameAnalysis({
    required this.color,
    required this.white,
    required this.black,
    required this.result,
    required this.opening,
    required this.moves,
    required this.accuracy,
    required this.counts,
    required this.moments,
    required this.puzzles,
    required this.evals,
    required this.engine,
    required this.depth,
  });

  final Side color;
  final String white;
  final String black;
  final String result;
  final String opening;
  final int moves;
  final int? accuracy;
  final Map<MistakeClass, int> counts;

  /// Höchstens [maxMoments] Schlüsselmomente für die Besprechung, nach Zugfolge.
  final List<Moment> moments;

  /// Alle eigenen Züge ab „Fehler“.
  final List<Moment> puzzles;

  /// Gewinnchance von Weiß nach jedem Halbzug (Index 0 = Startstellung).
  final List<double> evals;

  /// Welche Engine/welches Netz rechnete (z. B. "light", "full").
  final String engine;
  final int depth;

  Map<String, dynamic> toJson() => {
    'color': color.name,
    'white': white,
    'black': black,
    'result': result,
    'opening': opening,
    'moves': moves,
    'accuracy': accuracy,
    'counts': {for (final e in counts.entries) e.key.name: e.value},
    'moments': [for (final m in moments) m.toJson()],
    'puzzles': [for (final m in puzzles) m.toJson()],
    'evals': evals,
    'engine': engine,
    'depth': depth,
  };

  factory GameAnalysis.fromJson(Map<String, dynamic> j) => GameAnalysis(
    color: Side.values.byName(j['color'] as String),
    white: j['white'] as String,
    black: j['black'] as String,
    result: j['result'] as String,
    opening: j['opening'] as String,
    moves: j['moves'] as int,
    accuracy: j['accuracy'] as int?,
    counts: {
      for (final e in (j['counts'] as Map<String, dynamic>).entries) MistakeClass.values.byName(e.key): e.value as int,
    },
    moments: [for (final m in j['moments'] as List) Moment.fromJson(m as Map<String, dynamic>)],
    puzzles: [for (final m in j['puzzles'] as List) Moment.fromJson(m as Map<String, dynamic>)],
    evals: [for (final e in j['evals'] as List) (e as num).toDouble()],
    engine: j['engine'] as String,
    depth: j['depth'] as int,
  );
}

/// Endstellung ohne Engine: Matt oder Remis (Patt, zu wenig Material, 75-Züge-Regel).
List<PvLine>? _terminal(Position pos) {
  if (pos.isCheckmate) return const [PvLine(multipv: 1, depth: 0, score: Score.mated(), pv: [])];
  if (pos.isGameOver || pos.halfmoves >= 150) return const [PvLine(multipv: 1, depth: 0, score: Score.cp(0), pv: [])];
  return null;
}

/// Komplette Analyse; [onProgress] meldet bewertete Stellungen von insgesamt Züge + 1.
Future<GameAnalysis> analyseGame(
  ParsedGame game,
  Side color,
  UciEngine engine, {
  required String engineName,
  int depth = 16,
  int multiPv = 3,
  void Function(int done, int total)? onProgress,
}) async {
  final rootFen = game.start.fen;
  final positions = <Position>[game.start];
  final uci = <String>[];
  for (final move in game.moves) {
    uci.add(stdUci(positions.last, move));
    positions.add(positions.last.play(move));
  }

  await engine.newGame();
  final infos = <List<PvLine>>[];
  for (var i = 0; i < positions.length; i++) {
    infos.add(
      _terminal(positions[i]) ??
          await engine.analyse(rootFen: rootFen, moves: uci.sublist(0, i), depth: depth, multiPv: multiPv),
    );
    onProgress?.call(i + 1, positions.length);
  }

  final moments = <Moment>[];
  final accuracies = <double>[];
  for (var ply = 0; ply < game.moves.length; ply++) {
    final pos = positions[ply];
    if (pos.turn != color) continue;
    final best = infos[ply].first;
    final before = winPct(best.score, pos.turn, color);
    final after = winPct(infos[ply + 1].first.score, positions[ply + 1].turn, color);
    final drop = math.max(0.0, before - after);
    accuracies.add(moveAccuracy(drop));
    final cls = MistakeClass.forDrop(drop);
    if (cls != null && best.pv.isNotEmpty && uci[ply] != best.pv.first) {
      moments.add(_moment(positions, game.moves, uci, infos, ply, color, before, after, drop, cls));
    }
  }

  // Wie Pythons stabiles sorted(): bei gleichem Verlust zählt die Zugfolge.
  final key = [...moments]..sort((a, b) => b.drop != a.drop ? b.drop.compareTo(a.drop) : a.ply.compareTo(b.ply));
  final chosen = key.take(maxMoments).toList()..sort((a, b) => a.ply.compareTo(b.ply));
  final h = game.headers;
  return GameAnalysis(
    color: color,
    white: h['White'] ?? '?',
    black: h['Black'] ?? '?',
    result: h['Result'] ?? '*',
    opening: h['Opening'] ?? '',
    moves: game.moves.length,
    accuracy: accuracies.isEmpty ? null : (accuracies.reduce((a, b) => a + b) / accuracies.length).round(),
    counts: {for (final c in MistakeClass.values) c: moments.where((m) => m.mistake == c).length},
    moments: chosen,
    puzzles: moments.where((m) => m.drop >= puzzleMinDrop).toList(),
    evals: [
      for (var i = 0; i < infos.length; i++) _round1(winPct(infos[i].first.score, positions[i].turn, Side.white)),
    ],
    engine: engineName,
    depth: depth,
  );
}

Moment _moment(
  List<Position> positions,
  List<NormalMove> moves,
  List<String> uci,
  List<List<PvLine>> infos,
  int ply,
  Side color,
  double before,
  double after,
  double drop,
  MistakeClass cls,
) {
  final pos = positions[ply];
  final afterPos = positions[ply + 1];
  final best = infos[ply];
  final reply = infos[ply + 1].first.pv;
  final (replyLine, replyMat) = line(afterPos, reply, 5);
  final (bestLine, bestMat) = line(pos, best.first.pv);
  final bestMove = legalUci(pos, best.first.pv.first)!;
  final replyMove = reply.isEmpty ? null : legalUci(afterPos, reply.first);

  final motifs = <Motif>[];
  final scoreBest = best.first.score; // Seite am Zug ist der Nutzer
  final scoreAfter = infos[ply + 1].first.score.flipped;
  if (scoreBest.isMate && scoreBest.mate! > 0) motifs.add(Motif('mate_missed', scoreBest.mate));
  if (scoreAfter.isMate && scoreAfter.mate! <= 0) motifs.add(const Motif('allows_mate'));
  if (replyMove != null && isCapture(afterPos, replyMove) && -replyMat >= 2) motifs.add(const Motif('hangs_material'));
  if (bestMat >= 2) motifs.add(Motif('wins_material', bestMat));
  if (givesCheck(pos, bestMove)) motifs.add(const Motif('best_is_check'));
  if (isCapture(pos, bestMove)) motifs.add(const Motif('best_is_capture'));

  final alternatives = <Alternative>[];
  for (final info in best) {
    final m = info.pv.isEmpty ? null : legalUci(pos, info.pv.first);
    if (m != null) {
      alternatives.add(Alternative(numbered(pos, [m]), info.pv.first, _round1(winPct(info.score, pos.turn, color))));
    }
  }
  final prevPos = ply > 0 ? positions[ply - 1] : null;
  return Moment(
    ply: ply,
    moveNo: pos.fullmoves,
    fen: pos.fen,
    lastMove: prevPos != null ? uci[ply - 1] : null,
    opponentLast: prevPos != null ? numbered(prevPos, [moves[ply - 1]]) : null,
    played: numbered(pos, [moves[ply]]),
    playedUci: uci[ply],
    alternatives: alternatives,
    bestLine: bestLine,
    replyLine: replyLine,
    threatReply: replyMove != null ? numbered(afterPos, [replyMove]) : null,
    winBefore: _round1(before),
    winAfter: _round1(after),
    drop: _round1(drop),
    mistake: cls,
    phase: phase(pos),
    motifs: motifs,
  );
}
