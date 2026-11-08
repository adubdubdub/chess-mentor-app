// Vergleich des Dart-Ports mit analysis.py des Telegram-Bots: dieselbe Engine (Stockfish 17.1 im Container
// chess-mentor), dieselbe Tiefe, Referenz aus tools/make_golden.sh. Ohne Docker-Container wird übersprungen.
@Tags(['engine'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_test/flutter_test.dart';

import 'support/process_engine.dart';

const _classDe = {
  MistakeClass.blunder: 'Patzer',
  MistakeClass.mistake: 'Fehler',
  MistakeClass.inaccuracy: 'Ungenauigkeit',
};
const _phaseDe = {GamePhase.opening: 'Eröffnung', GamePhase.middlegame: 'Mittelspiel', GamePhase.endgame: 'Endspiel'};

String _motifDe(Motif m) => switch (m.code) {
  'mate_missed' => 'Matt in ${m.n} verpasst',
  'allows_mate' => 'Partiezug lässt Matt zu',
  'hangs_material' => 'Partiezug stellt Material ein (Gegner gewinnt es mit der besten Antwort)',
  'wins_material' => 'Beste Fortsetzung gewinnt etwa ${m.n} Bauerneinheiten Material',
  'best_is_check' => 'Bester Zug gibt Schach',
  'best_is_capture' => 'Bester Zug ist ein Schlagzug',
  _ => m.code,
};

bool _dockerAvailable() {
  try {
    return Process.runSync('docker', [
          'inspect',
          '-f',
          '{{.State.Running}}',
          'chess-mentor',
        ]).stdout.toString().trim() ==
        'true';
  } catch (_) {
    return false;
  }
}

void main() {
  final skip = _dockerAvailable() ? false : 'Container chess-mentor nicht erreichbar';
  late ProcessEngine engine;

  setUpAll(() async {
    if (skip == false) engine = await ProcessEngine.start();
  });
  tearDownAll(() async {
    if (skip == false) await engine.dispose();
  });

  for (final name in ['opera', 'opera_white', 'legal']) {
    test(
      '$name: Dart-Port rechnet wie der Bot',
      () async {
        final golden = jsonDecode(File('test/fixtures/$name.golden.json').readAsStringSync()) as Map<String, dynamic>;
        final ref = golden['analysis'] as Map<String, dynamic>;
        final game = ParsedGame.parse(File('test/fixtures/$name.pgn').readAsStringSync())!;
        final color = golden['color'] == 'white' ? Side.white : Side.black;
        final a = await analyseGame(game, color, engine, engineName: 'test', depth: golden['depth'] as int);

        expect(a.moves, ref['moves']);
        expect((a.accuracy! - (ref['accuracy'] as int)).abs(), lessThanOrEqualTo(1), reason: 'Genauigkeit');
        expect({for (final e in a.counts.entries) _classDe[e.key]: e.value}, ref['counts']);
        expect(a.evals.length, (ref['evals'] as List).length);
        for (var i = 0; i < a.evals.length; i++) {
          expect((a.evals[i] - (ref['evals'][i] as num)).abs(), lessThanOrEqualTo(1.0), reason: 'evals[$i]');
        }

        void compareMoments(List<Moment> mine, List refs, String what) {
          expect(mine.map((m) => m.ply).toList(), refs.map((r) => r['ply']).toList(), reason: '$what: Halbzüge');
          for (var i = 0; i < mine.length; i++) {
            final m = mine[i], r = refs[i] as Map<String, dynamic>;
            final at = '$what ply ${m.ply}';
            expect(m.fen, r['fen'], reason: '$at fen');
            expect(m.moveNo, r['move_no'], reason: at);
            expect(m.lastMove, r['last_move'], reason: '$at last_move');
            expect(germanSan(m.opponentLast ?? ''), r['opponent_last'] ?? '', reason: '$at opponent_last');
            expect(germanSan(m.played), r['played'], reason: '$at played');
            expect(m.playedUci, r['played_uci'], reason: at);
            expect(germanSan(m.best), r['best'], reason: '$at best');
            expect(m.bestUci, r['best_uci'], reason: at);
            expect(germanSan(m.bestLine), r['best_line'], reason: '$at best_line');
            expect(germanSan(m.replyLine), r['reply_line'], reason: '$at reply_line');
            expect(germanSan(m.threatReply ?? ''), r['threat_reply'] ?? '', reason: '$at threat_reply');
            expect(_classDe[m.mistake], r['class'], reason: at);
            expect(m.mistake.glyph, r['glyph'], reason: at);
            expect(_phaseDe[m.phase], r['phase'], reason: at);
            expect(m.motifs.map(_motifDe).toList(), r['motifs'], reason: '$at motifs');
            expect((m.drop - (r['drop'] as num)).abs(), lessThanOrEqualTo(0.2), reason: '$at drop');
            expect((m.winBefore - (r['win_before'] as num)).abs(), lessThanOrEqualTo(0.2), reason: at);
            final alts = r['alternatives'] as List;
            expect(
              m.alternatives.map((x) => germanSan(x.san)).toList(),
              alts.map((x) => x['move']).toList(),
              reason: '$at alternatives',
            );
          }
        }

        compareMoments(a.moments, ref['moments'] as List, 'moments');
        compareMoments(a.puzzles, ref['puzzles'] as List, 'puzzles');
      },
      skip: skip,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
