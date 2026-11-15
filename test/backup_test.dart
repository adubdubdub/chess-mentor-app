import 'dart:convert';

import 'package:chess_mentor/ai/prompts.dart';
import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:chess_mentor/data/backup.dart';
import 'package:chess_mentor/data/game_store.dart';
import 'package:chess_mentor/puzzles/schedule.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _pgn = '[White "A"]\n[Black "B"]\n[Result "*"]\n\n1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *';

Moment _moment(int ply) => Moment(
  ply: ply,
  moveNo: 3,
  fen: 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
  lastMove: null,
  opponentLast: '2...Nc6',
  played: 'Bb5',
  playedUci: 'f1b5',
  alternatives: const [Alternative('Bc4', 'f1c4', 55)],
  bestLine: '3.Bc4',
  replyLine: '3...a6',
  threatReply: null,
  winBefore: 55,
  winAfter: 40,
  drop: 15,
  mistake: MistakeClass.blunder,
  phase: GamePhase.opening,
  motifs: const [],
);

GameAnalysis _analysis() => GameAnalysis(
  color: Side.white,
  white: 'A',
  black: 'B',
  result: '*',
  opening: 'Test',
  moves: 6,
  accuracy: 80,
  counts: const {},
  moments: [_moment(4)],
  puzzles: [_moment(4)],
  evals: const [],
  engine: 'sf',
  depth: 12,
);

Future<GameStore> _store() => GameStore.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);

void main() {
  setUpAll(sqfliteFfiInit);

  test('Telegram-Bot-Daten: Lernstand wird nach der Analyse auf das Puzzle übertragen', () async {
    final store = await _store();
    final ids = <int>[];
    final bundle = jsonEncode({
      'format': exportFormat,
      'version': 1,
      'games': [
        {
          'pgn': _pgn,
          'color': 'white',
          'added': '2026-11-05T10:00:00',
          'analysis': null,
          'puzzles': [
            {'ply': 4, 'level': 1, 'due': '2026-11-20', 'reps': 1, 'lapses': 0},
            {'ply': 99, 'level': 2, 'due': '2026-12-01', 'reps': 2, 'lapses': 0},
          ],
          'reviewTexts': {
            'de': jsonEncode({
              'summary': 'Gut gespielt.',
              'learning': null,
              'moments': <String, dynamic>{},
            }),
          },
        },
        {'pgn': 'kein pgn'},
      ],
    });
    final r = await Backup(store).import(bundle, onQueued: ids.add);
    expect((r.added, r.invalid), (1, 1));
    expect(ids, hasLength(1));
    expect(await store.aiText('review:${ids.first}:de:v$promptVersion'), contains('Gut gespielt'));

    await store.setAnalysis(ids.first, _analysis());
    final p = (await store.db.query('puzzles')).single;
    expect((p['level'], p['due'], p['reps']), (1, '2026-11-20', 1));
    expect(await store.db.query('meta', where: "key LIKE 'pending:%'"), isEmpty);

    // zweiter Import derselben Datei: Partie ist schon da
    expect((await Backup(store).import(bundle)).skipped, 1);
  });

  test('Export und Import: Analyse, Lernstand, Versuche und Texte bleiben erhalten', () async {
    final a = await _store();
    final (id, _) = await a.add(_pgn, ParsedGame.parse(_pgn)!, Side.white);
    await a.setAnalysis(id, _analysis());
    final pid = (await a.db.query('puzzles')).single['id']! as int;
    await a.gradePuzzle(pid, Attempt.second, wrong: 1, hint: true);
    await a.putAiText('puzzle:$pid:de:v$promptVersion', 'Erklärung');
    await a.putAiText('review:$id:de:v$promptVersion', '{"summary":"x","learning":null,"moments":{}}');

    final json = await Backup(a).export();
    expect(looksLikeExport(json), isTrue);
    expect(json, isNot(contains('apiKey')));

    final b = await _store();
    final r = await Backup(b).import(json);
    expect((r.added, r.puzzles), (1, 1));
    final g = (await b.all()).single;
    expect(g.status, GameStatus.done);
    expect(g.analysis, isNotNull);
    final p = (await b.db.query('puzzles')).single;
    expect((p['level'], p['reps']), (0, 1));
    final att = (await b.db.query('puzzle_attempts')).single;
    expect((att['result'], att['wrong'], att['hint']), ('second', 1, 1));
    expect(await b.aiText('puzzle:${p['id']}:de:v$promptVersion'), 'Erklärung');
  });

  test('fremde Datei und neuere Version werden abgelehnt', () async {
    final s = await _store();
    expect(Backup(s).import('{"format":"x"}'), throwsFormatException);
    expect(Backup(s).import('{"format":"$exportFormat","version":99}'), throwsFormatException);
    expect(looksLikeExport('1. e4 e5'), isFalse);
  });
}
