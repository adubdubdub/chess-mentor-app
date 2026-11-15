import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:chess_mentor/mentor/focus.dart';
import 'package:chess_mentor/mentor/focus_keeper.dart';
import 'package:chess_mentor/mentor/profile.dart';
import 'package:chess_mentor/mentor/records.dart';
import 'package:chess_mentor/mentor/topics.dart';
import 'package:chess_mentor/ui/focus_card.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

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

Profile _profile() => buildProfile([
  for (var i = 0; i < 6; i++)
    GameRecord(
      id: i,
      playedAt: DateTime.utc(2026, 11, 10).subtract(Duration(days: i)),
      analysis: GameAnalysis(
        color: Side.white,
        white: 'a',
        black: 'b',
        result: '1-0',
        opening: '',
        moves: 60,
        accuracy: 80,
        counts: const {},
        moments: [_m(10, ['wins_material'], drop: 30), _m(20, ['best_is_check'], drop: 11), _m(30, ['best_is_check'], drop: 11)],
        puzzles: const [],
        evals: const [],
        engine: 'sf',
        depth: 12,
        flagged: [_m(10, ['wins_material'], drop: 30), _m(20, ['best_is_check'], drop: 11), _m(30, ['best_is_check'], drop: 11)],
      ),
      ownMovesByPhase: const {GamePhase.middlegame: 30},
    ),
]);

Widget _wrap(Widget child, {String lang = 'de'}) => MaterialApp(
  locale: Locale(lang),
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('de'), Locale('en')],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

FocusEntry _entry(FocusStatus s) => FocusEntry(
  id: 1,
  topic: Topic.missedMaterial,
  startedAt: DateTime.utc(2026, 11, 16),
  endsAt: DateTime.utc(2026, 11, 23),
  goalGames: 3,
  target: 3,
  baselineCount: 12,
  baselineGames: 6,
  status: s,
);

void main() {
  testWidgets('Vorschlag mit Wahl: erstes Thema groß, Alternativen wählbar', (tester) async {
    final profile = _profile();
    final suggestions = suggestFocus(profile);
    FocusSuggestion? chosen;
    await tester.pumpWidget(
      _wrap(FocusCard(state: const FocusState(), suggestions: suggestions, profile: profile, onStart: (s) => chosen = s)),
    );
    expect(find.text('Vorschlag für deinen Wochenfokus'), findsNothing); // mit Emoji davor
    expect(find.textContaining('Vorschlag für deinen Wochenfokus'), findsOneWidget);
    expect(find.text('Material verpasst'), findsOneWidget);
    expect(find.textContaining('Ziel: in den nächsten 3 Partien'), findsOneWidget);
    await tester.tap(find.text('Wählen'));
    expect(chosen!.topic, Topic.missedCheck);
    await tester.tap(find.text('Als Fokus wählen'));
    expect(chosen!.topic, Topic.missedMaterial);
  });

  testWidgets('ohne Vorschläge: erklärender Hinweis', (tester) async {
    await tester.pumpWidget(_wrap(FocusCard(state: const FocusState(), suggestions: const [], profile: buildProfile(const []))));
    expect(find.textContaining('Noch kein Vorschlag möglich'), findsOneWidget);
  });

  testWidgets('laufender Fokus: Merksatz, Prüffrage, Stand und Fokus-Puzzles', (tester) async {
    var practised = false, cancelled = false;
    await tester.pumpWidget(
      _wrap(
        FocusCard(
          state: FocusState(
            active: _entry(FocusStatus.active),
            progress: const FocusProgress(games: 1, occurrences: 2, status: FocusStatus.active, daysLeft: 5),
          ),
          suggestions: const [],
          profile: _profile(),
          duePuzzles: 4,
          onPractice: () => practised = true,
          onCancel: () => cancelled = true,
        ),
      ),
    );
    expect(find.textContaining('Wochenfokus: Material verpasst'), findsOneWidget);
    expect(find.textContaining('Hat mein Gegner gerade etwas ungedeckt gelassen?'), findsOneWidget);
    expect(find.textContaining('Stand: 1 von 3 Partien, 2 Fehlzüge (erlaubt 3)'), findsOneWidget);
    await tester.tap(find.text('4 Fokus-Puzzles üben'));
    await tester.tap(find.text('Fokus beenden'));
    expect(practised && cancelled, isTrue);
  });

  testWidgets('Ergebnis des letzten Fokus wird gezeigt', (tester) async {
    for (final (status, text) in [
      (FocusStatus.reached, 'Ziel erreicht'),
      (FocusStatus.missed, 'Ziel verfehlt'),
      (FocusStatus.expired, 'abgelaufen'),
    ]) {
      await tester.pumpWidget(
        _wrap(FocusCard(state: FocusState(lastClosed: _entry(status)), suggestions: suggestFocus(_profile()), profile: _profile())),
      );
      expect(find.textContaining(text), findsOneWidget, reason: status.name);
    }
  });

  testWidgets('schmales Display, deutsch und englisch: kein Überlauf', (tester) async {
    tester.view.physicalSize = const Size(360 * 2.75, 740 * 2.75);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final profile = _profile();
    for (final lang in ['de', 'en']) {
      for (final state in [
        const FocusState(),
        FocusState(
          active: _entry(FocusStatus.active),
          progress: const FocusProgress(games: 2, occurrences: 1, status: FocusStatus.active, daysLeft: 3),
        ),
      ]) {
        await tester.pumpWidget(_wrap(FocusCard(state: state, suggestions: state.active == null ? suggestFocus(profile) : const [], profile: profile, duePuzzles: 2), lang: lang));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });
}
