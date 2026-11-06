import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dartchess: Zug in SAN und FEN', () {
    final (pos, san) = Chess.initial.makeSan(Move.parse('e2e4')!);
    expect(san, 'e4');
    expect(pos.turn, Side.black);
  });
}
