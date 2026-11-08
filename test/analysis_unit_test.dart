import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:chess_mentor/analysis/uci.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Gewinnchance wie Lichess und python-chess', () {
    expect(winPct(const Score.cp(0), Side.white, Side.white), 50);
    expect(winPct(const Score.cp(100), Side.white, Side.white), closeTo(59.1, 0.1));
    expect(winPct(const Score.cp(100), Side.white, Side.black), closeTo(40.9, 0.1));
    expect(winPct(const Score.mated(), Side.white, Side.white), closeTo(0, 0.01));
    expect(winPct(const Score.mated(), Side.white, Side.black), closeTo(100, 0.01));
    expect(winPct(const Score.mate(3), Side.black, Side.black), greaterThan(99.9));
  });

  test('Fehlerklassen nach Verlust', () {
    expect(MistakeClass.forDrop(4.9), isNull);
    expect(MistakeClass.forDrop(5), MistakeClass.inaccuracy);
    expect(MistakeClass.forDrop(12), MistakeClass.mistake);
    expect(MistakeClass.forDrop(15), MistakeClass.blunder);
  });

  test('UCI-Zeile auswerten', () {
    final l = PvLine.parse('info depth 14 seldepth 19 multipv 2 score cp -30 nodes 1 pv e7e5 g1f3')!;
    expect(l.multipv, 2);
    expect(l.depth, 14);
    expect(l.score.cp, -30);
    expect(l.pv, ['e7e5', 'g1f3']);
    expect(PvLine.parse('info depth 3 multipv 1 score mate -2 pv a1a2')!.score.mate, -2);
    expect(PvLine.parse('info string NNUE evaluation'), isNull);
  });

  test('Rochade als Königszug für Stockfish', () {
    final pos = Chess.fromSetup(Setup.parseFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1'));
    final short = pos.parseSan('O-O')! as NormalMove;
    expect(stdUci(pos, short), 'e1g1');
    expect(stdUci(pos, pos.parseSan('O-O-O')! as NormalMove), 'e1c1');
    expect(legalUci(pos, 'e1g1'), isNotNull);
    expect(numbered(pos, [legalUci(pos, 'e1g1')!]), '1.O-O');
  });

  test('Nummerierte Varianten und deutsche SAN', () {
    final game = ParsedGame.parse('1. e4 e5 2. Nf3 Nc6 3. Bb5 *')!;
    var pos = game.start;
    for (final m in game.moves.take(3)) {
      pos = pos.play(m);
    }
    expect(numbered(pos, game.moves.sublist(3)), '2...Nc6 3.Bb5');
    expect(germanSan('3.Bb5 Nf6 4.O-O Qe7 5.Rxe1 exd8=Q+'), '3.Lb5 Sf6 4.O-O De7 5.Txe1 exd8=D+');
  });

  test('Farbe erkennen', () {
    ParsedGame g(String w, String b) => ParsedGame.parse('[White "$w"]\n[Black "$b"]\n\n1. e4 *')!;
    expect(g('Anonymous', 'Stockfish level 3').guessColor(), Side.white);
    expect(g('Computer', 'Anonymous').guessColor(), Side.black);
    expect(g('Anonymous', 'Anonymous').guessColor(), isNull);
    expect(g('adubdubdub', 'x').guessColor(lichessUser: 'AdubDubDub'), Side.white);
  });

  test('Ungültige PGN', () {
    expect(ParsedGame.parse(''), isNull);
    expect(ParsedGame.parse('1. e4 e4 *'), isNull);
  });
}
