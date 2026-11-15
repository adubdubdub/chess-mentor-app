import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:chess_mentor/mentor/focus.dart';
import 'package:chess_mentor/mentor/profile.dart';
import 'package:chess_mentor/mentor/records.dart';
import 'package:chess_mentor/mentor/topics.dart';
import 'package:dartchess/dartchess.dart' show Side;
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

GameRecord _game(int id, DateTime at, List<Moment> ms) => GameRecord(
  id: id,
  playedAt: at,
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

final _start = DateTime.utc(2026, 11, 16, 14); // Montag

FocusEntry _focus({int target = 2, FocusStatus status = FocusStatus.active, Topic topic = Topic.missedMaterial}) => FocusEntry(
  id: 1,
  topic: topic,
  startedAt: _start,
  endsAt: _start.add(const Duration(days: focusDays)),
  goalGames: 3,
  target: target,
  baselineCount: 12,
  baselineGames: 6,
  status: status,
);

DateTime _day(int d, [int h = 12]) => DateTime.utc(2026, 11, d, h);

void main() {
  group('Ziel', () {
    test('Fehlzüge halbieren, abgerundet; bei seltenen Themen null', () {
      expect(targetFor(12, 6, 3), 3); // 2 je Partie, 6 erwartet, erlaubt 3
      expect(targetFor(15, 7, 3), 3); // 6,4 erwartet -> 3,2 -> 3
      expect(targetFor(3, 6, 3), 0); // 1,5 erwartet -> 0,75 -> 0
      expect(targetFor(5, 0, 3), 0);
    });
  });

  group('Vorschlag', () {
    Profile profile() {
      final games = [
        for (var i = 0; i < 6; i++)
          _game(i, _day(10 - i), [
            _m(10, ['wins_material'], drop: 30),
            _m(20, ['best_is_check'], drop: 11),
            _m(30, ['best_is_check'], drop: 11),
          ]),
      ];
      return buildProfile(games);
    }

    test('bestes Thema zuerst, bis zu drei, mit abgeleitetem Ziel', () {
      final s = suggestFocus(profile());
      expect(s.first.topic, Topic.missedMaterial);
      expect(s.length, 2);
      expect(s.first.target, targetFor(6, 6, 3));
      expect(s.first.goalGames, 3);
    });

    test('dasselbe Thema wie zuletzt rückt nach hinten, außer es wird schlechter', () {
      final s = suggestFocus(profile(), lastTopic: Topic.missedMaterial);
      expect(s.first.topic, Topic.missedCheck);
      expect(s.last.topic, Topic.missedMaterial);
    });

    test('ohne genug Daten kein Vorschlag', () {
      expect(suggestFocus(buildProfile([_game(0, _day(10), [_m(10, ['wins_material'])])])), isEmpty);
    });

    test('Fokus startet für sieben Tage', () {
      final s = suggestFocus(profile()).first;
      final f = startFocusFrom(s, _start);
      expect(f.endsAt, _start.add(const Duration(days: 7)));
      expect(f.status, FocusStatus.active);
      expect(f.baselineCount, s.stat.count);
    });
  });

  group('Auswertung', () {
    test('Partien vor dem Starttag zählen nicht, vom Starttag an schon', () {
      final records = [
        _game(1, _day(15), [_m(10, ['wins_material'])]), // Vortag
        _game(2, _day(16, 8), [_m(10, ['wins_material'])]), // Starttag, früher am Tag
      ];
      final p = evaluateFocus(_focus(), records, _day(17));
      expect(p.games, 1);
      expect(p.occurrences, 1);
      expect(p.status, FocusStatus.active);
    });

    test('erreicht nach drei Partien mit höchstens dem erlaubten Wert', () {
      final records = [
        _game(1, _day(16, 15), [_m(10, ['wins_material'])]),
        _game(2, _day(17), [_m(10, ['wins_material'])]),
        _game(3, _day(18), const []),
      ];
      final p = evaluateFocus(_focus(target: 2), records, _day(18, 20));
      expect((p.games, p.occurrences), (3, 2));
      expect(p.status, FocusStatus.reached);
    });

    test('verfehlt sofort, sobald mehr Fehlzüge als erlaubt vorkommen', () {
      final records = [
        _game(1, _day(16, 15), [_m(10, ['wins_material']), _m(20, ['best_is_capture']), _m(30, ['wins_material'])]),
      ];
      final p = evaluateFocus(_focus(target: 2), records, _day(16, 20));
      expect(p.occurrences, 3);
      expect(p.status, FocusStatus.missed);
    });

    test('Ziel null: schon ein Fehlzug verfehlt es', () {
      final p = evaluateFocus(_focus(target: 0), [_game(1, _day(16, 15), [_m(10, ['wins_material'])])], _day(17));
      expect(p.status, FocusStatus.missed);
    });

    test('abgelaufen ohne genug Partien: kein Urteil', () {
      final p = evaluateFocus(_focus(), [_game(1, _day(17), const [])], _day(24));
      expect((p.games, p.status), (1, FocusStatus.expired));
    });

    test('Partien nach dem Ende zählen nicht', () {
      final p = evaluateFocus(_focus(), [_game(1, _day(24), [_m(10, ['wins_material'])])], _day(25));
      expect(p.games, 0);
      expect(p.status, FocusStatus.expired);
    });

    test('nur die ersten drei Partien zählen für das Ziel', () {
      final records = [
        for (var i = 0; i < 3; i++) _game(i, _day(16 + i, 15), const []),
        _game(9, _day(21), [_m(10, ['wins_material']), _m(20, ['wins_material']), _m(30, ['wins_material'])]),
      ];
      final p = evaluateFocus(_focus(target: 1), records, _day(22));
      expect((p.games, p.occurrences, p.status), (3, 0, FocusStatus.reached));
    });

    test('ein beendeter Fokus behält seinen Status; Tage bis zum Ende', () {
      expect(evaluateFocus(_focus(status: FocusStatus.cancelled), const [], _day(17)).status, FocusStatus.cancelled);
      expect(evaluateFocus(_focus(), const [], _day(18)).daysLeft, 5);
      expect(evaluateFocus(_focus(), const [], _day(30)).daysLeft, 0);
    });
  });
}
