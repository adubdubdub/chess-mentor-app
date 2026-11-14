import 'dart:convert';

import 'package:chess_mentor/ai/review_texts.dart';
import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_test/flutter_test.dart';

Moment _moment() => const Moment(
  ply: 12,
  moveNo: 6,
  fen: 'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4',
  lastMove: null,
  opponentLast: '5...Nf6',
  played: 'Nf3',
  playedUci: 'g1f3',
  alternatives: [Alternative('Qxf7#', 'h5f7', 100)],
  bestLine: '6.Qxf7#',
  replyLine: '6...Nxe4 7.Qxf7+',
  threatReply: null,
  winBefore: 100,
  winAfter: 60,
  drop: 40,
  mistake: MistakeClass.blunder,
  phase: GamePhase.opening,
  motifs: [],
);

GameAnalysis _analysis() => GameAnalysis(
  color: Side.white,
  white: 'A',
  black: 'B',
  result: '1-0',
  opening: 'Test',
  moves: 12,
  accuracy: 80,
  counts: const {},
  moments: [_moment()],
  puzzles: const [],
  evals: const [],
  engine: 'sf',
  depth: 12,
);

String _json(Map<String, String> m) => jsonEncode({
  'zusammenfassung': m['sum'] ?? 'Gute Partie.',
  'lernpunkt': m['learn'] ?? 'Prüfe Schachgebote.',
  'momente': [
    {'ply': 12, 'frage': m['q'] ?? 'Was droht auf f7?', 'tipp': m['tip'] ?? 'Schau auf die Dame.', 'erklaerung': m['exp'] ?? 'Nach 6...Sxe4 steht es schlechter.'},
  ],
});

void main() {
  test('brauchbare Antwort wird übernommen', () {
    final t = parseReview(_json({}), _analysis(), de: true)!;
    expect(t.summary, 'Gute Partie.');
    expect(t.moments[12]!.question, 'Was droht auf f7?');
    expect(t.moments[12]!.explanation, isNotNull);
  });

  test('Frage und Tipp dürfen den besten Zug nicht verraten', () {
    final t = parseReview(_json({'q': 'Spielst du Dxf7?', 'tip': 'Dxf7 gewinnt.'}), _analysis(), de: true)!;
    expect(t.moments[12]!.question, isNull);
    expect(t.moments[12]!.tip, isNull);
  });

  test('erfundene Züge verwerfen nur das betroffene Feld', () {
    final t = parseReview(_json({'exp': 'Besser war 7.Sc3 und danach Td1.'}), _analysis(), de: true)!;
    expect(t.moments[12]!.explanation, isNull);
    expect(t.summary, isNotNull);
  });

  test('kein JSON: null; Zwischenspeicher-Roundtrip', () {
    expect(parseReview('Hallo', _analysis(), de: true), isNull);
    final t = parseReview(_json({}), _analysis(), de: true)!;
    expect(ReviewTexts.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>).moments[12]!.tip, t.moments[12]!.tip);
  });
}
