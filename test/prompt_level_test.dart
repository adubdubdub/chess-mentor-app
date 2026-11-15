import 'package:chess_mentor/ai/focus_text.dart';
import 'package:chess_mentor/ai/prompt_level.dart';
import 'package:chess_mentor/ai/prompts.dart';
import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:chess_mentor/mentor/focus.dart';
import 'package:chess_mentor/mentor/profile.dart';
import 'package:chess_mentor/mentor/records.dart';
import 'package:chess_mentor/mentor/strength.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_test/flutter_test.dart';

Moment _m() => const Moment(
  ply: 22,
  moveNo: 12,
  fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  lastMove: null,
  opponentLast: null,
  played: 'Bb5',
  playedUci: 'f1b5',
  alternatives: [Alternative('Qxf7#', 'h5f7', 100)],
  bestLine: '12.Qxf7#',
  replyLine: '12...Nxe4',
  threatReply: null,
  winBefore: 50,
  winAfter: 30,
  drop: 20,
  mistake: MistakeClass.blunder,
  phase: GamePhase.middlegame,
  motifs: [Motif('wins_material')],
);

GameAnalysis _analysis() => GameAnalysis(
  color: Side.white,
  white: 'Anna',
  black: 'Berta',
  result: '1-0',
  opening: '',
  moves: 60,
  accuracy: 80,
  counts: const {},
  moments: [_m()],
  puzzles: const [],
  evals: const [],
  engine: 'sf',
  depth: 12,
  flagged: [_m()],
);

void main() {
  group('Beschreibung der Spielstärke', () {
    test('mit Zahl: gerundet auf 50 und Stufe', () {
      final l = promptLevel(level: Level.advancedBeginner, elo: 1337, sendElo: true, de: true);
      expect(l.text, 'ca. 1350 Elo, Stufe „Fortgeschrittener Anfänger“');
      expect(l.keyPart, ':l1');
    });

    test('ohne Zahl: nur die Stufe, keine Ziffer im Text', () {
      for (final de in [true, false]) {
        final l = promptLevel(level: Level.intermediate, elo: 1612, sendElo: false, de: de);
        expect(RegExp(r'\d').hasMatch(l.text), isFalse, reason: l.text);
        expect(l.text, contains(de ? 'Mittelstufe' : 'Intermediate'));
      }
    });

    test('jede Stufe hat einen eigenen Stil, deutsch wie englisch', () {
      for (final de in [true, false]) {
        final styles = {for (final l in Level.values) levelStyle(l, de: de)};
        expect(styles, hasLength(4));
        expect(styles.every((s) => s.length > 40), isTrue);
      }
      expect({for (final l in Level.values) promptLevel(level: l, elo: 1200, sendElo: true, de: true).keyPart}, hasLength(4));
    });

    test('Ausweichwert: der frühere Standard ohne Stilzeile und ohne Stufe im Schlüssel', () {
      const l = PromptLevel.fallback();
      expect(l.text, contains('1200'));
      expect(l.keyPart, '');
      expect(styleLine(l, de: true), '');
    });
  });

  group('Prompts', () {
    final level = promptLevel(level: Level.beginner, elo: 850, sendElo: true, de: true);
    final levelEn = promptLevel(level: Level.advanced, elo: 1950, sendElo: true, de: false);

    test('Puzzle: Schüler und Stil stehen im Prompt', () {
      final de = puzzlePrompt(_m(), de: true, level: level);
      expect(de, contains('ca. 850 Elo, Stufe „Einsteiger“'));
      expect(de, contains('Stil für dieses Niveau: Sehr einfache Wörter'));
      final en = puzzlePrompt(_m(), de: false, level: levelEn);
      expect(en, contains('about 1950 Elo'));
      expect(en, contains('Style for this level: Concise and precise'));
    });

    test('Besprechung: Stufe, Stil, aber weiterhin keine Spielernamen', () {
      final p = reviewPrompt(_analysis(), de: true, level: level);
      expect(p, contains('Stufe „Einsteiger“'));
      expect(p, contains('Stil für dieses Niveau'));
      expect(p, isNot(contains('Anna')));
      expect(p, isNot(contains('Berta')));
    });

    test('Fokustext: Stufe im Prompt und im Zwischenspeicher-Schlüssel', () {
      final records = [
        for (var i = 0; i < 6; i++)
          GameRecord(
            id: i,
            playedAt: DateTime.utc(2026, 11, 10).subtract(Duration(days: i)),
            analysis: _analysis(),
            ownMovesByPhase: const {GamePhase.middlegame: 30},
          ),
      ];
      final s = suggestFocus(buildProfile(records)).first;
      final facts = focusFacts(s, topicMoments(s.topic, records), de: true, levelKey: level.keyPart);
      expect(facts.cacheKey, endsWith('v$promptVersion:l0'));
      expect(focusPrompt(facts, de: true, level: level), allOf(contains('Stufe „Einsteiger“'), contains('Stil für dieses Niveau')));
      final other = focusFacts(s, topicMoments(s.topic, records), de: true, levelKey: ':l3');
      expect(other.cacheKey, isNot(facts.cacheKey));
    });

    test('Ausweichwert ändert die Prompts nicht: kein Stil, alter Text', () {
      final p = puzzlePrompt(_m(), de: true);
      expect(p, contains('ca. 1200 Elo, zwischen Einsteiger und Fortgeschritten'));
      expect(p, isNot(contains('Stil für dieses Niveau')));
    });

    test('Prompt-Version 3 verwirft Texte der Vorversion', () {
      expect(promptVersion, 3);
    });
  });
}
