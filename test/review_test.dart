// Besprechung: Zugprüfung (Port von judge()) und Textbausteine, mit der Engine des Bots im Container.
@Tags(['engine'])
library;

import 'dart:io';

import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:chess_mentor/analysis/judge.dart';
import 'package:chess_mentor/coach/coach_texts.dart';
import 'package:chess_mentor/ui/strings.dart';
import 'package:dartchess/dartchess.dart' show Chess, Setup, Side;
import 'package:flutter_test/flutter_test.dart';

import 'support/process_engine.dart';

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
  final analyses = <String, GameAnalysis>{};

  setUpAll(() async {
    if (skip != false) return;
    engine = await ProcessEngine.start();
    for (final (name, color) in [('opera', Side.black), ('legal', Side.black), ('opera_white', Side.white)]) {
      final game = ParsedGame.parse(File('test/fixtures/$name.pgn').readAsStringSync())!;
      analyses[name] = await analyseGame(game, color, engine, engineName: 'test', depth: 12);
    }
  });
  tearDownAll(() async {
    if (skip == false) await engine.dispose();
  });

  test(
    'Zugprüfung: bester Zug, Partiezug, gleichwertige Alternative, schwacher Zug',
    () async {
      final m = analyses['opera']!.moments.firstWhere((m) => m.alternatives.length >= 2);
      expect((await judgeMove(m, m.bestUci, engine, depth: 12)).$1, Verdict.best);
      expect((await judgeMove(m, m.playedUci, engine, depth: 12)).$1, Verdict.played);
      final close = m.alternatives.skip(1).where((a) => m.winBefore - a.win < 3).firstOrNull;
      if (close != null) expect((await judgeMove(m, close.uci, engine, depth: 12)).$1, Verdict.good);

      // Légal-Matt: 5...Lxd1?? statt 5...dxe5 – der Partiezug ist bekannt, ein Damenopfer ist eindeutig schwach
      final legal = analyses['legal']!.moments.firstWhere((m) => m.ply == 9);
      expect((await judgeMove(legal, legal.playedUci, engine, depth: 12)).$1, Verdict.played);
      final pos = Chess.fromSetup(Setup.parseFen(legal.fen));
      final queenBlunder = pos.legalMoves.entries
          .where((e) => pos.board.pieceAt(e.key)?.role.name == 'queen')
          .expand((e) => e.value.squares.map((to) => '${e.key.name}${to.name}'))
          .first;
      final (verdict, win, line) = await judgeMove(legal, queenBlunder, engine, depth: 12);
      expect(line.first, queenBlunder);
      expect(verdict, Verdict.weak);
      expect(win, lessThan(legal.winBefore - 5));
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  for (final de in [true, false]) {
    test('Texte (${de ? 'DE' : 'EN'}): Frage und Tipp verraten den besten Zug nicht', () {
      final coach = CoachTexts(Tr(de));
      for (final a in analyses.values) {
        for (final m in a.moments) {
          final best = CoachTexts.bareSan(m.best);
          final shown = de ? germanSan(best) : best;
          final square = m.bestUci.substring(2, 4);
          for (final text in [coach.question(m), coach.tip(m)]) {
            expect(text.contains(shown), isFalse, reason: '${m.played}: "$text" nennt $shown');
            // Den letzten Zug des Gegners zu nennen ist gewollt (darauf lenkt die Frage), auch wenn er auf dem Zielfeld steht
            final withoutLast = m.opponentLast == null ? text : text.replaceAll(coach.tr.san(m.opponentLast!), '');
            expect(
              RegExp('\\b$square\\b').hasMatch(withoutLast),
              isFalse,
              reason: '${m.played}: "$text" nennt das Zielfeld',
            );
          }
          final bad = coach.whyPlayedBad(m), good = coach.whyBestGood(m);
          expect(bad, contains(CoachTexts.mark('p', coach.tr.san(m.played))), reason: bad);
          expect(bad.contains(coach.tr.san(m.best)), isFalse, reason: bad);
          expect(good, contains(CoachTexts.mark('b', coach.tr.san(m.best))), reason: good);
          expect(CoachTexts.plain(good).contains('«'), isFalse);
          // Varianten zum Durchklicken: beginnen mit Partiezug bzw. bestem Zug und sind länger als ein Zug
          expect(m.playedMoves.first, m.playedUci);
          expect(m.bestMoves.first, m.bestUci);
          expect(m.bestMoves.length, greaterThan(1));
        }
        // Alle markierten Züge: so viele wie gezählt, jeweils mit Kurzbegründung
        expect(a.flagged.length, a.counts.values.reduce((x, y) => x + y));
        for (final m in a.flagged) {
          expect(coach.shortWhy(m), isNotEmpty);
        }
        expect(GameAnalysis.fromJson(a.toJson()).flagged.length, a.flagged.length);
        expect(coach.summary(a), isNotEmpty);
        expect(coach.learningPoint(a), isNotEmpty);
      }
    }, skip: skip);
  }

  test('Erklärung der Légal-Falle: Partiezug lässt Matt zu, bester Zug schlägt', () {
    final coach = CoachTexts(const Tr(true));
    final legal = analyses['legal']!.moments.firstWhere((m) => m.ply == 9);
    expect(coach.whyPlayedBad(legal), contains('mattsetzen'));
    expect(coach.whyBestGood(legal), contains('schlägt'));
    // Fehlender Materialgewinn wird beim Partiezug als verpasste Chance genannt
    final white = analyses['opera_white']!.moments.where((m) => m.motifs.any((x) => x.code == 'wins_material'));
    for (final m in white) {
      expect(coach.whyPlayedBad(m), isNot(contains('leichtere Spiel')), reason: coach.whyPlayedBad(m));
    }
  }, skip: skip);

  test('Tipp nennt Figur und Art des besten Zugs', () {
    final coach = CoachTexts(const Tr(true));
    final legal = analyses['legal']!.moments.firstWhere((m) => m.ply == 9); // bester Zug 5...dxe5: Bauer schlägt
    expect(coach.tip(legal), 'Der stärkste Zug ist ein Bauernzug, der etwas schlägt.');
  }, skip: skip);
}
