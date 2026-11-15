import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:chess_mentor/data/game_store.dart';
import 'package:chess_mentor/mentor/focus.dart';
import 'package:chess_mentor/mentor/focus_review.dart';
import 'package:chess_mentor/mentor/records.dart';
import 'package:chess_mentor/mentor/topics.dart';
import 'package:chess_mentor/puzzles/schedule.dart';
import 'package:chess_mentor/ui/focus_review_view.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Moment _m(int ply, List<String> motifs, {double drop = 14}) => Moment(
  ply: ply,
  moveNo: ply ~/ 2 + 1,
  fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  lastMove: null,
  opponentLast: null,
  played: 'a3',
  playedUci: 'a2a3',
  alternatives: const [Alternative('Nxe5', 'g1e5', 50)],
  bestLine: '1.Nxe5',
  replyLine: '1...d6',
  threatReply: null,
  winBefore: 50,
  winAfter: 50 - drop,
  drop: drop,
  mistake: MistakeClass.forDrop(drop) ?? MistakeClass.inaccuracy,
  phase: GamePhase.middlegame,
  motifs: [for (final c in motifs) Motif(c)],
);

GameRecord _game(int id, DateTime at, List<Moment> ms, {int accuracy = 80}) => GameRecord(
  id: id,
  playedAt: at,
  analysis: GameAnalysis(
    color: Side.white,
    white: 'A$id',
    black: 'B$id',
    result: '1-0',
    opening: '',
    moves: 60,
    accuracy: accuracy,
    counts: const {},
    moments: ms,
    puzzles: ms,
    evals: const [],
    engine: 'sf',
    depth: 12,
    flagged: ms,
  ),
  ownMovesByPhase: const {GamePhase.middlegame: 30},
);

final _start = DateTime.utc(2026, 11, 16, 14);
DateTime _day(int d, [int h = 12]) => DateTime.utc(2026, 11, d, h);

FocusEntry _focus({FocusStatus status = FocusStatus.reached, int target = 3}) => FocusEntry(
  id: 1,
  topic: Topic.missedMaterial,
  startedAt: _start,
  endsAt: _start.add(const Duration(days: 7)),
  goalGames: 3,
  target: target,
  baselineCount: 12,
  baselineGames: 6, // vorher 2 je Partie
  status: status,
);

Widget _wrap(Widget child, {String lang = 'de'}) => MaterialApp(
  locale: Locale(lang),
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('de'), Locale('en')],
  home: Scaffold(body: child),
);

void main() {
  setUpAll(sqfliteFfiInit);

  group('Rückblick berechnen', () {
    final records = [
      _game(1, _day(10), [_m(10, ['wins_material']), _m(20, ['wins_material']), _m(30, ['best_is_check'])], accuracy: 70), // davor
      _game(2, _day(11), const [], accuracy: 90), // davor
      _game(3, _day(16, 15), [_m(10, ['wins_material'])], accuracy: 85),
      _game(4, _day(18), const [], accuracy: 95),
      _game(5, _day(20), [_m(10, ['wins_material']), _m(20, ['best_is_check'])], accuracy: 75),
      _game(6, _day(22), [_m(10, ['wins_material']), _m(20, ['wins_material'])]), // vierte Partie der Woche zählt nicht
    ];

    test('zählt die ersten drei Partien der Woche, vergleicht mit vorher', () {
      final r = buildFocusReview(_focus(), records, puzzleAttempts: 5, puzzleClean: 3);
      expect(r.games.map((g) => g.record.id), [3, 4, 5]);
      expect(r.occurrences, 2);
      expect(r.perGameBefore, 2.0);
      expect(r.perGameNow, closeTo(2 / 3, 1e-9));
      expect(r.change!, closeTo((2 / 3 - 2) / 2 * 100, 1e-9)); // etwa −67 %
      expect(r.accuracyNow, closeTo(85, 1e-9));
      expect(r.accuracyBefore, closeTo(80, 1e-9));
      expect((r.puzzleAttempts, r.puzzleClean), (5, 3));
      expect(r.games.last.allMistakes, 2);
      expect(r.moments.map((e) => (e.game.id, e.moment.ply)), [(3, 10), (5, 10)]);
    });

    test('ohne Partien: keine Veränderung, keine Zahlen', () {
      final r = buildFocusReview(_focus(status: FocusStatus.expired), [records.first], puzzleAttempts: 0);
      expect(r.games, isEmpty);
      expect(r.perGameNow, isNull);
      expect(r.change, isNull);
      expect(r.accuracyNow, isNull);
      expect(r.accuracyBefore, 70);
    });

    test('war das Thema vorher nie ein Problem, gibt es keine Prozentveränderung', () {
      final f = FocusEntry(
        topic: Topic.missedMaterial,
        startedAt: _start,
        endsAt: _start.add(const Duration(days: 7)),
        goalGames: 3,
        target: 0,
        baselineCount: 0,
        baselineGames: 6,
      );
      expect(buildFocusReview(f, records).change, isNull);
    });
  });

  test('focusPuzzleStats zählt nur Versuche zum Thema innerhalb der Laufzeit', () async {
    final store = await GameStore.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    const pgn = '[White "A"]\n[Black "B"]\n[Result "*"]\n\n1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *';
    final (id, _) = await store.add(pgn, ParsedGame.parse(pgn)!, Side.white);
    await store.setAnalysis(
      id,
      GameAnalysis(
        color: Side.white,
        white: 'A',
        black: 'B',
        result: '*',
        opening: '',
        moves: 6,
        accuracy: 80,
        counts: const {},
        moments: const [],
        puzzles: [_m(2, ['wins_material']), _m(4, ['best_is_check'])],
        evals: const [],
        engine: 'sf',
        depth: 12,
        flagged: const [],
      ),
    );
    final ids = {for (final r in await store.db.query('puzzles')) r['ply']! as int: r['id']! as int};
    final f = FocusEntry(
      topic: Topic.missedMaterial,
      startedAt: DateTime.now().subtract(const Duration(days: 1)),
      endsAt: DateTime.now().add(const Duration(days: 6)),
      goalGames: 3,
      target: 1,
      baselineCount: 6,
      baselineGames: 6,
    );
    await store.gradePuzzle(ids[2]!, Attempt.first); // Thema, sauber
    await store.gradePuzzle(ids[2]!, Attempt.second); // Thema, nicht sauber
    await store.gradePuzzle(ids[4]!, Attempt.first); // anderes Thema
    final stats = await store.focusPuzzleStats(f);
    expect((stats.attempts, stats.clean), (2, 1));
  });

  group('Ansicht', () {
    final records = [
      _game(3, _day(16, 15), [_m(10, ['wins_material'])], accuracy: 85),
      _game(4, _day(18), const [], accuracy: 95),
    ];

    testWidgets('erreicht: Ergebnis, Vergleich, Partien, Fehlzüge und nächster Schritt', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      GameRecord? openedGame;
      var wentOn = false;
      final review = buildFocusReview(_focus(), records, puzzleAttempts: 4, puzzleClean: 3);
      await tester.pumpWidget(_wrap(FocusReviewView(review: review, onMoment: (g, m) => openedGame = g, onNew: () => wentOn = true)));
      expect(find.textContaining('Material verpasst'), findsWidgets);
      expect(find.textContaining('Ziel erreicht'), findsOneWidget);
      expect(find.text('1 Fehlzüge in 2 Partien'), findsOneWidget);
      expect(find.textContaining('vorher 2,0, jetzt 0,5'), findsOneWidget);
      expect(find.textContaining('75 % weniger als vorher'), findsOneWidget);
      expect(find.textContaining('4 Versuche zum Thema, 3 davon sauber gelöst'), findsOneWidget);
      expect(find.textContaining('A3 – B3'), findsWidgets);
      await tester.tap(find.textContaining('statt Sxe5'));
      expect(openedGame!.id, 3);
      await tester.tap(find.text('Zum Mentor'));
      expect(wentOn, isTrue);
    });

    testWidgets('verfehlt, abgelaufen und englisch: passende Einordnung, kein Überlauf', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.75, 740 * 2.75);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      for (final (status, text) in [(FocusStatus.missed, 'Ziel verfehlt'), (FocusStatus.expired, 'Abgelaufen, kein Urteil')]) {
        await tester.pumpWidget(_wrap(FocusReviewView(review: buildFocusReview(_focus(status: status, target: 0), records))));
        expect(find.textContaining(text), findsOneWidget, reason: status.name);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(_wrap(FocusReviewView(review: buildFocusReview(_focus(), records)), lang: 'en'));
      expect(find.textContaining('Goal reached'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
