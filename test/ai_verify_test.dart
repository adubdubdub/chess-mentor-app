import 'package:chess_mentor/ai/provider.dart';
import 'package:chess_mentor/ai/verify.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final allowed = moveTokens(['Lc6', '6...Lc6 7.f4 Sxe4 8.Dh5+', 'O-O']);

  test('Züge aus den Fakten sind erlaubt', () {
    expect(unknownMoves('Nach 7.f4 und Sxe4 steht Weiß schlecht, danach kommt Dh5.', allowed), isEmpty);
  });

  test('Erfundene Züge werden gemeldet', () {
    expect(unknownMoves('Besser ist 8.Sf3 oder Td1.', allowed), containsAll(['Sf3', 'Td1']));
  });

  test('Rochade und Schach-Zeichen', () {
    expect(unknownMoves('Mit Dh5+ droht es, auch O-O ist denkbar.', allowed), isEmpty);
  });

  test('bloße Felder und gewöhnliche Wörter werden nicht beanstandet', () {
    expect(unknownMoves('Die Dame greift das Feld e4 an, der Läufer deckt f7.', allowed), isEmpty);
  });

  test('nummerierter Bauernzug außerhalb der Fakten fällt auf', () {
    expect(unknownMoves('Danach kommt 9.g4.', allowed), ['g4']);
  });

  test('OpenAI-kompatible Antwort wird gelesen, Fehler werfen', () async {
    final ok = OpenAiCompatibleProvider(
      baseUrl: 'https://example.invalid/v1/',
      model: 'm',
      apiKey: 'k',
      client: MockClient((req) async {
        expect(req.url.toString(), 'https://example.invalid/v1/chat/completions');
        expect(req.headers['Authorization'], 'Bearer k');
        return http.Response('{"choices":[{"message":{"content":" Hallo "}}]}', 200);
      }),
    );
    expect(await ok.complete('x'), 'Hallo');
    final bad = OpenAiCompatibleProvider(
      baseUrl: 'https://example.invalid/v1',
      model: 'm',
      client: MockClient((_) async => http.Response('no', 503)),
    );
    expect(bad.complete('x'), throwsA(isA<AiException>()));
  });
}
