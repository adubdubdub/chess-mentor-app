import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:chess_mentor/mentor/profile.dart';
import 'package:chess_mentor/mentor/records.dart';
import 'package:chess_mentor/mentor/topics.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_test/flutter_test.dart';

Moment _m({
  int ply = 10,
  List<String> motifs = const [],
  double winBefore = 50,
  double drop = 12,
  GamePhase phase = GamePhase.middlegame,
}) => Moment(
  ply: ply,
  moveNo: ply ~/ 2 + 1,
  fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  lastMove: null,
  opponentLast: null,
  played: 'a3',
  playedUci: 'a2a3',
  alternatives: const [Alternative('e4', 'e2e4', 50)],
  bestLine: '1.e4',
  replyLine: '1...e5',
  threatReply: null,
  winBefore: winBefore,
  winAfter: winBefore - drop,
  drop: drop,
  mistake: MistakeClass.forDrop(drop) ?? MistakeClass.inaccuracy,
  phase: phase,
  motifs: [for (final c in motifs) Motif(c)],
);

GameRecord _game(
  int id,
  int daysAgo,
  List<Moment> moments, {
  int accuracy = 80,
  String opening = '',
  int ownMoves = 30,
  Map<int, PuzzleState> puzzles = const {},
}) => GameRecord(
  id: id,
  playedAt: DateTime.utc(2026, 11, 15).subtract(Duration(days: daysAgo)),
  analysis: GameAnalysis(
    color: Side.white,
    white: 'a',
    black: 'b',
    result: '1-0',
    opening: opening,
    moves: ownMoves * 2,
    accuracy: accuracy,
    counts: const {},
    moments: moments,
    puzzles: const [],
    evals: const [],
    engine: 'sf',
    depth: 12,
    flagged: moments,
  ),
  puzzles: puzzles,
  ownMovesByPhase: {GamePhase.opening: 10, GamePhase.middlegame: ownMoves - 10},
);

void main() {
  group('Themen eines Fehlzugs', () {
    test('Motive und Gewinnchance ergeben Themen, mehrere sind erlaubt', () {
      expect(topicsOf(_m(motifs: ['hangs_material'])), {Topic.hangsPiece});
      expect(topicsOf(_m(motifs: ['allows_mate', 'hangs_material'])), {Topic.allowsMate, Topic.hangsPiece});
      expect(topicsOf(_m(motifs: ['wins_material'])), {Topic.missedMaterial});
      expect(topicsOf(_m(motifs: ['best_is_capture'])), {Topic.missedMaterial});
      expect(topicsOf(_m(motifs: ['best_is_check'])), {Topic.missedCheck});
    });

    test('verpasstes Matt zählt nicht zusätzlich als verpasstes Schach', () {
      expect(topicsOf(_m(motifs: ['mate_missed', 'best_is_check'])), {Topic.missedMate});
    });

    test('Vorteil verspielt braucht gute Stellung und schweren Fehler, schlechte Stellung ist eigenes Thema', () {
      expect(topicsOf(_m(winBefore: 70, drop: 20)), {Topic.advantageLost});
      expect(topicsOf(_m(winBefore: 70, drop: 12)), isEmpty);
      expect(topicsOf(_m(winBefore: 64, drop: 30)), isEmpty);
      expect(topicsOf(_m(winBefore: 30, drop: 12)), {Topic.whenWorse});
    });
  });

  group('Profil', () {
    test('zu wenige Partien: keine Aussage, aber Zahlen sind da', () {
      final p = buildProfile([
        for (var i = 0; i < 3; i++) _game(i, i, [_m(motifs: ['hangs_material'])]),
      ]);
      expect(p.games, 3);
      expect(p.enough, isFalse);
      expect(p.candidates, isEmpty);
      expect(p.topics.single.count, 3);
    });

    test('Häufigkeit je 100 eigene Züge, Schwere und Mindestvorkommen', () {
      final games = [
        for (var i = 0; i < 6; i++)
          _game(i, i, [
            _m(motifs: ['hangs_material'], drop: 20),
            if (i < 2) _m(ply: 20, motifs: ['best_is_check'], drop: 10),
          ]),
      ];
      final p = buildProfile(games);
      final hangs = p.topics.firstWhere((t) => t.topic == Topic.hangsPiece);
      expect(hangs.count, 6);
      expect(hangs.per100, closeTo(100 * 6 / 180, 1e-9));
      expect(hangs.avgDrop, 20);
      expect(hangs.enough, isTrue);
      final check = p.topics.firstWhere((t) => t.topic == Topic.missedCheck);
      expect(check.count, 2);
      expect(check.enough, isFalse); // unter 3 Vorkommen
      expect(p.candidates.map((t) => t.topic), [Topic.hangsPiece]);
    });

    test('ein Thema nur aus einer einzigen Partie ist kein Muster', () {
      final games = [
        _game(0, 0, [for (var k = 0; k < 4; k++) _m(ply: 10 + 2 * k, motifs: ['hangs_material'])]),
        for (var i = 1; i < 6; i++) _game(i, i, const []),
      ];
      final t = buildProfile(games).topics.single;
      expect((t.count, t.games), (4, 1));
      expect(t.enough, isFalse);
    });

    test('Beherrschung der Puzzles senkt die Punktzahl', () {
      List<GameRecord> make(bool mastered) => [
        for (var i = 0; i < 6; i++)
          _game(
            i,
            i,
            [_m(motifs: ['hangs_material'], drop: 20)],
            puzzles: {10: PuzzleState(mastered: mastered, attempts: 2, clean: mastered ? 2 : 0)},
          ),
      ];
      final open = buildProfile(make(false)).topics.single;
      final done = buildProfile(make(true)).topics.single;
      expect(open.mastery, 0);
      expect(done.mastery, 1);
      expect(done.score, 0);
      expect(open.score, greaterThan(0));
      expect(open.cleanRate, 0);
      expect(done.cleanRate, 1);
    });

    test('Rangfolge: Punktzahl aus Häufigkeit mal Schwere', () {
      final games = [
        for (var i = 0; i < 6; i++)
          _game(i, i, [
            _m(motifs: ['hangs_material'], drop: 25),
            _m(ply: 20, motifs: ['best_is_check'], drop: 10),
            _m(ply: 30, motifs: ['best_is_check'], drop: 10),
          ]),
      ];
      final p = buildProfile(games);
      // hangs: 6 × 25; check: 12 × 10 -> hangs hat die höhere Punktzahl
      expect(p.topics.first.topic, Topic.hangsPiece);
      expect(p.topics.last.topic, Topic.missedCheck);
    });

    test('Trend nur mit genug Partien; negativ heißt besser', () {
      // neueste 5: keine Fehler mit dem Thema, ältere 6: je einer -> Trend negativ
      final games = [
        for (var i = 0; i < 5; i++) _game(i, i, const []),
        for (var i = 5; i < 11; i++) _game(i, i, [_m(motifs: ['hangs_material'])]),
      ];
      final t = buildProfile(games).topics.single;
      expect(t.trend, isNotNull);
      expect(t.trend!, lessThan(0));
      final few = buildProfile([for (var i = 0; i < 6; i++) _game(i, i, [_m(motifs: ['hangs_material'])])]);
      expect(few.topics.single.trend, isNull);
    });

    test('Fenster: nur die neuesten Partien zählen', () {
      final games = [for (var i = 0; i < 25; i++) _game(i, i, [_m(motifs: ['hangs_material'])])];
      expect(buildProfile(games).games, profileWindow);
      expect(buildProfile(games, window: 8).games, 8);
    });

    test('Phasen, Eröffnungsfamilien (ab 3 Partien) und Genauigkeitsverlauf', () {
      final games = [
        _game(1, 1, [_m(phase: GamePhase.opening)], accuracy: 70, opening: 'Italian Game: Giuoco Piano'),
        _game(2, 2, [_m(phase: GamePhase.middlegame)], accuracy: 80, opening: 'Italian Game: Evans'),
        _game(3, 3, const [], accuracy: 90, opening: 'Italian Game'),
        _game(4, 4, const [], accuracy: 60, opening: 'Sicilian Defense'),
      ];
      final p = buildProfile(games);
      expect(p.openings.map((o) => o.name), ['Italian Game']);
      expect(p.openings.single.games, 3);
      expect(p.openings.single.accuracy, 80);
      expect(p.phases.firstWhere((x) => x.phase == GamePhase.opening).mistakes, 1);
      expect(p.accuracy, 75);
      expect(p.accuracySeries.first.accuracy, 60); // älteste zuerst
      expect(p.untagged, 2);
    });

    test('ohne Partien: leeres Profil ohne Fehler', () {
      final p = buildProfile(const []);
      expect((p.games, p.ownMoves, p.accuracy), (0, 0, null));
      expect(p.topics, isEmpty);
    });
  });

  group('Datensatz', () {
    test('Spieldatum aus UTCDate/UTCTime, sonst Date, sonst Ersatz', () {
      final fb = DateTime.utc(2000);
      expect(
        GameRecord.playedAtFrom('[UTCDate "2026.11.12"]\n[UTCTime "08:30:15"]', fb),
        DateTime.utc(2026, 11, 12, 8, 30, 15),
      );
      expect(GameRecord.playedAtFrom('[Date "2026.11.10"]', fb), DateTime.utc(2026, 11, 10, 12));
      expect(GameRecord.playedAtFrom('[Date "????.??.??"]', fb), fb);
      expect(GameRecord.playedAtFrom('1. e4 e5', fb), fb);
    });

    test('eigene Züge je Phase aus der PGN', () {
      const pgn = '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *';
      final a = _game(1, 1, const []).analysis;
      final r = GameRecord.fromParts(id: 1, playedAt: DateTime.utc(2026), pgn: pgn, analysis: a);
      expect(r.ownMoves, 3);
      expect(r.ownMovesByPhase, {GamePhase.opening: 3});
    });
  });
}
