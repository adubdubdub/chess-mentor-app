import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:chess_mentor/coach/move_facts.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

Position _pos(String fen) => Chess.fromSetup(Setup.parseFen(fen));

void main() {
  test('Springergabel mit Schach erkennt König und Turm', () {
    // Weißer Springer d5, schwarzer König e8, Turm a8: Sc7+ gabelt
    final pos = _pos('r3k3/8/8/3N4/8/8/8/4K3 w - - 0 1');
    final f = MoveFacts.of(pos, 'd5c7')!;
    expect(f.check, isTrue);
    expect(f.fork, isTrue);
    expect(f.targets.map((t) => t.role), [Role.king, Role.rook]);
  });

  test('Ungedeckte Figur schlagen', () {
    final pos = _pos('4k3/8/8/3n4/8/8/8/3QK3 w - - 0 1');
    final f = MoveFacts.of(pos, 'd1d5')!;
    expect(f.captured?.role, Role.knight);
    expect(f.capturedUndefended, isTrue);
  });

  test('Problem: gezogene Figur wird geschlagen bzw. Drohung übersehen', () {
    // Weiß zieht Lc4?? auf ein Feld, das der schwarze Bauer d5 angreift
    final pos = _pos('4k3/8/8/3p4/8/8/8/2B1K3 w - - 0 1');
    final p = Problem.of(pos, ['c1e3', 'd5d4'])!;
    expect(p.reply.captured, isNull);
    final hang = Problem.of(_pos('4k3/8/8/3p4/8/8/8/4KB2 w - - 0 1'), ['f1c4', 'd5c4'])!;
    expect(hang.lostMovedPiece, isTrue);
    // Springer e5 ist angegriffen, Weiß zieht den König: Drohung übersehen
    final threat = Problem.of(_pos('4k3/8/3p4/4N3/8/8/8/4K3 w - - 0 1'), ['e1d2', 'd6e5'])!;
    expect(threat.threatIgnored, isTrue);
  });

  test('Rettung einer angegriffenen Figur', () {
    final pos = _pos('4k3/8/3p4/4N3/8/8/8/4K3 w - - 0 1');
    expect(MoveFacts.of(pos, 'e5f3')!.rescued, isTrue);
  });

  test('Varianten aus alter SAN-Notation rekonstruieren', () {
    final pos = Chess.initial;
    expect(pvFromLine(pos, '1.e4 e5 2.Nf3 Nc6 3.O-O'), ['e2e4', 'e7e5', 'g1f3', 'b8c6']);
    expect(lineSans(pos, ['e2e4', 'e7e5']), ['1.e4', '1...e5']);
  });

  test('Moment ohne gespeicherte Varianten nutzt bestLine und replyLine', () {
    const m = Moment(
      ply: 0,
      moveNo: 1,
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      lastMove: null,
      opponentLast: null,
      played: '1.f3',
      playedUci: 'f2f3',
      alternatives: [Alternative('1.e4', 'e2e4', 50)],
      bestLine: '1.e4 e5 2.Nf3',
      replyLine: '1...e5 2.g4',
      threatReply: null,
      winBefore: 50,
      winAfter: 45,
      drop: 5,
      mistake: MistakeClass.inaccuracy,
      phase: GamePhase.opening,
      motifs: [],
    );
    expect(m.bestMoves, ['e2e4', 'e7e5', 'g1f3']);
    expect(m.playedMoves, ['f2f3', 'e7e5', 'g2g4']);
    expect(Moment.fromJson(m.toJson()).bestPv, isEmpty);
  });
}
