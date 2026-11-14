@Tags(['engine'])
library;

import 'package:chess_mentor/puzzles/follow_up.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/process_engine.dart';

void main() {
  final skip = engineCommand() != null ? false : 'Kein Stockfish (STOCKFISH_BIN setzen)';
  late ProcessEngine engine;
  setUpAll(() async {
    if (skip == false) engine = await ProcessEngine.start();
  });
  tearDownAll(() async {
    if (skip == false) await engine.dispose();
  });

  test('Folgezug (falls eindeutig) ist ein legaler Zug nach der Gegnerantwort', () async {
    // Matt in zwei: Weiß Dh5+!? ist unnötig, hier ein einfaches Mattnetz: 1.Qxf7+ Kd7 2.Qe6#? (nicht erzwungen geprüft)
    const fen = 'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4';
    final f = await findFollowUp(fen, ['h5f7', 'e8e7', 'c4e6'], engine, depth: 12);
    if (f != null) {
      final pos = Chess.fromSetup(Setup.parseFen(fen)).play(Move.parse('h5f7')!).play(Move.parse(f.reply)!);
      expect(pos.isLegal(Move.parse(f.move)!), isTrue);
    }
  }, skip: skip);

  test('zu kurze Variante: kein Folgezug', () async {
    const fen = 'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4';
    expect(await findFollowUp(fen, ['h5f7'], engine, depth: 12), isNull);
  }, skip: skip);
}
