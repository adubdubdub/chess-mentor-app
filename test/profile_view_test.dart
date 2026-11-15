import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:chess_mentor/mentor/profile.dart';
import 'package:chess_mentor/mentor/records.dart';
import 'package:chess_mentor/mentor/topics.dart';
import 'package:chess_mentor/ui/profile_view.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Moment _m(int ply, List<String> motifs, {double drop = 14, double winBefore = 50}) => Moment(
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
  winBefore: winBefore,
  winAfter: winBefore - drop,
  drop: drop,
  mistake: MistakeClass.forDrop(drop) ?? MistakeClass.inaccuracy,
  phase: GamePhase.middlegame,
  motifs: [for (final c in motifs) Motif(c)],
);

GameRecord _game(int i, List<Moment> ms) => GameRecord(
  id: i,
  playedAt: DateTime.utc(2026, 11, 15).subtract(Duration(days: i)),
  analysis: GameAnalysis(
    color: Side.white,
    white: 'a',
    black: 'b',
    result: '1-0',
    opening: '',
    moves: 60,
    accuracy: 80 + i,
    counts: const {},
    moments: ms,
    puzzles: const [],
    evals: const [],
    engine: 'sf',
    depth: 12,
    flagged: ms,
  ),
  ownMovesByPhase: const {GamePhase.opening: 10, GamePhase.middlegame: 20},
);

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('de'),
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('de')],
  home: Scaffold(body: child),
);

/// Hohes Fenster, damit die ganze Liste gebaut wird (ListView baut nur Sichtbares).
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('leeres Profil zeigt einen Hinweis statt Zahlen', (tester) async {
    await tester.pumpWidget(_wrap(ProfileView(profile: buildProfile(const []))));
    expect(find.textContaining('Noch keine analysierten Partien'), findsOneWidget);
  });

  testWidgets('wenig Daten: Hinweis und Themen abgeblendet mit Erklärung', (tester) async {
    _tall(tester);
    final p = buildProfile([_game(0, [_m(10, ['wins_material'])]), _game(1, const [])]);
    await tester.pumpWidget(_wrap(ProfileView(profile: p)));
    expect(find.textContaining('Noch zu wenig Daten'), findsOneWidget);
    expect(find.text('Material verpasst'), findsOneWidget);
    expect(find.textContaining('Noch kein Muster'), findsOneWidget);
  });

  testWidgets('genug Daten: Thema mit Zahlen, Antippen meldet das Thema', (tester) async {
    _tall(tester);
    final games = [for (var i = 0; i < 6; i++) _game(i, [_m(10, ['wins_material']), _m(20, ['best_is_check'], drop: 11)])];
    Topic? tapped;
    await tester.pumpWidget(_wrap(ProfileView(profile: buildProfile(games), onTopic: (t) => tapped = t)));
    expect(find.textContaining('Noch zu wenig Daten'), findsNothing);
    expect(find.text('Material verpasst'), findsOneWidget);
    expect(find.text('6× in 6 Partien'), findsNWidgets(2));
    expect(find.textContaining('Noch kein Muster'), findsNothing);
    await tester.tap(find.text('Schachgebot übersehen'));
    expect(tapped, Topic.missedCheck);
  });

  testWidgets('schmales Handy-Display (360 dp): kein Überlauf, auch englisch', (tester) async {
    tester.view.physicalSize = const Size(360 * 2.75, 740 * 2.75);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final games = [
      for (var i = 0; i < 12; i++)
        _game(i, [_m(10, ['wins_material', 'hangs_material']), _m(20, ['best_is_check'], drop: 11), _m(30, const [], winBefore: 30)]),
    ];
    for (final lang in ['de', 'en']) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('de'), Locale('en')],
          home: Scaffold(body: ProfileView(profile: buildProfile(games))),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

