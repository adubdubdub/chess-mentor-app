import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:chess_mentor/mentor/focus.dart';
import 'package:chess_mentor/mentor/focus_keeper.dart';
import 'package:chess_mentor/mentor/profile.dart';
import 'package:chess_mentor/mentor/records.dart';
import 'package:chess_mentor/mentor/strength.dart';
import 'package:chess_mentor/mentor/topics.dart';
import 'package:chess_mentor/ui/focus_card.dart';
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

/// Zwei Themen mit fast gleicher Punktzahl: Figur eingestellt (leicht schwächer) und Vorteil verspielt (etwas stärker).
Profile _closeProfile() => buildProfile([
  for (var i = 0; i < 6; i++)
    _game(i, [
      _m(10, ['hangs_material'], drop: 20),
      _m(20, const [], drop: 22, winBefore: 70), // Vorteil verspielt
    ]),
]);

void main() {
  group('Ziel je Stufe', () {
    test('Anfänger mild, Starke streng', () {
      expect([for (final l in Level.values) goalFactor(l)], [0.6, 0.5, 0.45, 0.4]);
      expect(goalFactor(null), 0.5);
      expect([for (final l in Level.values) targetFor(20, 5, 3, factor: goalFactor(l))], [7, 6, 5, 4]);
    });

    test('Vorschlag trägt das Ziel der Stufe', () {
      final profile = _closeProfile();
      final beginner = suggestFocus(profile, level: Level.beginner).first;
      final advanced = suggestFocus(profile, level: Level.advanced).first;
      final neutral = suggestFocus(profile).first;
      // je Partie 1 Fehlzug des Themas, 3 Partien -> erwartet 3
      expect(targetFor(6, 6, 3, factor: 0.6), 1);
      expect(beginner.target, greaterThanOrEqualTo(advanced.target));
      expect(neutral.target, targetFor(neutral.stat.count, 6, 3));
    });
  });

  group('Gewichte je Stufe', () {
    test('Einsteiger: Sicherheit zuerst, Fortgeschrittene: Vorteil verwerten', () {
      final p = _closeProfile();
      expect(suggestFocus(p, level: Level.beginner).first.topic, Topic.hangsPiece);
      expect(suggestFocus(p, level: Level.advanced).first.topic, Topic.advantageLost);
    });

    test('ohne Stufe entscheidet allein die Punktzahl', () {
      final p = _closeProfile();
      final byScore = [...p.candidates]..sort((a, b) => b.score.compareTo(a.score));
      expect(suggestFocus(p).first.topic, byScore.first.topic);
    });

    test('Gewichte nach Plan', () {
      expect(topicWeight(Level.beginner, Topic.hangsPiece), 1.5);
      expect(topicWeight(Level.beginner, Topic.advantageLost), 0.6);
      expect(topicWeight(Level.advancedBeginner, Topic.hangsPiece), 1.2);
      expect(topicWeight(Level.advancedBeginner, Topic.missedCheck), 1.0);
      expect(topicWeight(Level.intermediate, Topic.whenWorse), 1.1);
      expect(topicWeight(Level.advanced, Topic.missedCheck), 0.8);
      expect(topicWeight(null, Topic.hangsPiece), 1.0);
    });

    test('Wiederholungs-Strafe bleibt vor den Gewichten', () {
      final p = _closeProfile();
      final s = suggestFocus(p, level: Level.beginner, lastTopic: Topic.hangsPiece);
      expect(s.first.topic, Topic.advantageLost);
    });
  });

  testWidgets('Vorschlagskarte nennt die Stufe', (tester) async {
    final p = _closeProfile();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('de')],
        home: Scaffold(
          body: SingleChildScrollView(
            child: FocusCard(state: const FocusState(), suggestions: suggestFocus(p, level: Level.intermediate), profile: p, level: Level.intermediate),
          ),
        ),
      ),
    );
    expect(find.textContaining('auf deine Stufe „Mittelstufe“ abgestimmt'), findsOneWidget);
  });
}
