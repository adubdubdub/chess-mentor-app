import 'package:chess_mentor/ai/focus_text.dart';
import 'package:chess_mentor/ai/verify.dart';
import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:chess_mentor/mentor/focus.dart';
import 'package:chess_mentor/mentor/focus_notice.dart';
import 'package:chess_mentor/mentor/profile.dart';
import 'package:chess_mentor/mentor/records.dart';
import 'package:chess_mentor/mentor/topics.dart';
import 'package:chess_mentor/ui/strings.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_test/flutter_test.dart';

Moment _m(int ply, {double drop = 14}) => Moment(
  ply: ply,
  moveNo: ply ~/ 2 + 1,
  fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  lastMove: null,
  opponentLast: null,
  played: 'Bb5',
  playedUci: 'f1b5',
  alternatives: const [Alternative('Qxf7#', 'h5f7', 100)],
  bestLine: '12.Qxf7#',
  replyLine: '12...Nxe4 13.Qxf7+',
  threatReply: null,
  winBefore: 50,
  winAfter: 50 - drop,
  drop: drop,
  mistake: MistakeClass.forDrop(drop) ?? MistakeClass.inaccuracy,
  phase: GamePhase.middlegame,
  motifs: const [Motif('wins_material')],
);

GameRecord _game(int id, List<Moment> ms) => GameRecord(
  id: id,
  playedAt: DateTime.utc(2026, 11, 10).subtract(Duration(days: id)),
  analysis: GameAnalysis(
    color: Side.white,
    white: 'a',
    black: 'b',
    result: '1-0',
    opening: '',
    moves: 60,
    accuracy: 80,
    counts: const {},
    moments: ms,
    puzzles: const [],
    evals: const [],
    engine: 'sf',
    depth: 12,
    flagged: ms,
  ),
  ownMovesByPhase: const {GamePhase.middlegame: 30},
);

void main() {
  final records = [for (var i = 0; i < 6; i++) _game(i, [_m(22, drop: 20 + i.toDouble())])];
  final suggestion = suggestFocus(buildProfile(records)).first;
  final facts = focusFacts(suggestion, topicMoments(suggestion.topic, records), de: true);

  group('Zahlenprüfung', () {
    test('Zugnummern und Zahlen in Zügen zählen nicht als fremde Zahlen', () {
      expect(unknownNumbers('Nach 12.Dxf7 und Sf3 steht es 6 Mal so, auf e4.', {12, 6}), isEmpty);
    });
    test('fremde Zahlen werden gemeldet', () {
      expect(unknownNumbers('Das passierte 17 Mal, in 6 Partien.', {6}), [17]);
    });
  });

  group('Fakten und Prüfung des KI-Textes', () {
    test('Fakten enthalten Kennzahlen, Ziel und Beispiele in deutscher Notation', () {
      expect(facts.json, contains('"vorkommen": 6'));
      expect(facts.json, contains('"hoechstens_fehlzuege"'));
      expect(facts.json, contains('Lb5')); // Läufer, deutsche Notation
      expect(facts.cacheKey, startsWith('focus:missedMaterial:6:'));
    });

    test('höchstens drei Beispiele, die schwersten zuerst', () {
      final f = focusFacts(suggestion, topicMoments(suggestion.topic, records), de: true);
      expect('"zugnummer"'.allMatches(f.json).length, focusExamples);
      expect(f.json, contains('"verlust_punkte": 25'));
    });

    test('guter Text besteht, mit Zügen und Zahlen aus den Fakten', () {
      const ok =
          'Du hast 6 Mal Material verpasst, im Schnitt gingen dabei 23 Punkte verloren. Im Beispiel zu Zug 12 spielst du Lb5, '
          'dabei war Dxf7 besser. Prüfe vor jedem Zug, was ungedeckt steht.';
      expect(checkFocusText(ok, facts), ok);
    });

    test('erfundene Züge oder Zahlen verwerfen den Text', () {
      expect(checkFocusText('Besser war 14.Sc3 mit Td1.', facts), isNull);
      expect(checkFocusText('Das passierte 47 Mal.', facts), isNull);
      expect(checkFocusText('   ', facts), isNull);
      expect(checkFocusText('x' * 1300, facts), isNull);
    });

    test('Prompt enthält Regeln und Fakten, deutsch wie englisch', () {
      expect(focusPrompt(facts, de: true), allOf(contains('AUSSCHLIESSLICH'), contains('"thema"')));
      final en = focusFacts(suggestion, topicMoments(suggestion.topic, records), de: false);
      expect(focusPrompt(en, de: false), allOf(contains('ONLY moves and numbers'), contains('Bb5')));
    });
  });

  group('Benachrichtigungstexte', () {
    final tr = Tr(true);
    final start = DateTime.utc(2026, 11, 16);
    final focus = FocusEntry(
      topic: Topic.missedMaterial,
      startedAt: start,
      endsAt: start.add(const Duration(days: 7)),
      goalGames: 3,
      target: 2,
      baselineCount: 6,
      baselineGames: 6,
    );

    test('Wochenanfang mit laufendem Fokus: Thema und Prüffrage', () {
      final n = weeklyNotice(tr, active: focus, at: DateTime.utc(2026, 11, 20), hasSuggestion: true)!;
      expect(n.title, contains('Material verpasst'));
      expect(n.body, contains('ungedeckt'));
    });

    test('Fokus schon abgelaufen oder keiner: neuer Vorschlag, sonst nichts', () {
      final late = weeklyNotice(tr, active: focus, at: DateTime.utc(2026, 11, 30), hasSuggestion: true)!;
      expect(late.title, contains('Neuer Wochenfokus'));
      expect(weeklyNotice(tr, at: DateTime.utc(2026, 11, 30), hasSuggestion: true)!.title, contains('Neuer Wochenfokus'));
      expect(weeklyNotice(tr, at: DateTime.utc(2026, 11, 30), hasSuggestion: false), isNull);
    });

    test('Ergebnis nur bei erreicht und verfehlt', () {
      expect(verdictNotice(tr, focus, FocusStatus.reached)!.title, contains('erreicht'));
      expect(verdictNotice(tr, focus, FocusStatus.missed)!.title, contains('verfehlt'));
      expect(verdictNotice(tr, focus, FocusStatus.expired), isNull);
      expect(verdictNotice(tr, focus, FocusStatus.cancelled), isNull);
      expect(verdictNotice(Tr(false), focus, FocusStatus.reached)!.body, contains('Missed material'));
    });
  });
}
