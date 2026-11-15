import 'dart:convert';

import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/pgn_split.dart';
import 'package:chess_mentor/data/backup.dart';
import 'package:chess_mentor/data/game_store.dart';
import 'package:chess_mentor/data/settings.dart';
import 'package:chess_mentor/fetch/online_games.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

String _game(String white, String black, String date, String time) =>
    '[Event "Rated Blitz game"]\n[White "$white"]\n[Black "$black"]\n[Result "1-0"]\n[UTCDate "$date"]\n[UTCTime "$time"]\n\n'
    '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 1-0\n';

void main() {
  setUpAll(sqfliteFfiInit);

  test('Mehrfach-PGN wird in Partien zerlegt', () {
    final text = '${_game('a', 'b', '2026.11.10', '10:00:00')}\n${_game('c', 'd', '2026.11.11', '11:00:00')}';
    final games = splitPgn(text);
    expect(games, hasLength(2));
    expect(games.first, contains('[White "a"]'));
    expect(games.last, startsWith('[Event'));
    expect(splitPgn('1. e4 e5'), ['1. e4 e5']);
    expect(splitPgn('   '), isEmpty);
  });

  test('Lichess: Anfrage mit eigener Kennung, Zeitpunkt aus UTCDate und UTCTime', () async {
    late Uri url;
    late Map<String, String> headers;
    final client = MockClient((req) async {
      url = req.url;
      headers = req.headers;
      return http.Response(
        '${_game('me', 'x', '2026.11.10', '10:00:00')}\n${_game('y', 'me', '2026.11.12', '08:30:15')}',
        200,
      );
    });
    final games = await fetchLichess('Me', sinceMs: 1000, client: client);
    expect(url.host, 'lichess.org');
    expect(url.path, '/api/games/user/Me');
    expect(url.queryParameters['since'], '1001');
    expect(url.queryParameters['finished'], 'true');
    expect(url.queryParameters['perfType'], isNot(contains('chess960')));
    expect(headers['User-Agent'], userAgent);
    expect(games, hasLength(2));
    expect(games.last.timeMs, DateTime.utc(2026, 11, 12, 8, 30, 15).millisecondsSinceEpoch);
  });

  test('Lichess: unbekannter Benutzer und Limit melden verständliche Fehler', () async {
    expect(
      fetchLichess('nobody', client: MockClient((_) async => http.Response('', 404))),
      throwsA(isA<FetchException>().having((e) => e.message, 'message', contains('nicht gefunden'))),
    );
    expect(
      fetchLichess('me', client: MockClient((_) async => http.Response('', 429))),
      throwsA(isA<FetchException>().having((e) => e.message, 'message', contains('zu viele'))),
    );
  });

  test('Chess.com: nur Standardschach, nur neuere Partien, nur nötige Monate, sortiert', () async {
    final requested = <String>[];
    final client = MockClient((req) async {
      requested.add(req.url.path);
      if (req.url.path.endsWith('/games/archives')) {
        return http.Response(
          jsonEncode({
            'archives': [
              'https://api.chess.com/pub/player/me/games/2026/09',
              'https://api.chess.com/pub/player/me/games/2026/10',
              'https://api.chess.com/pub/player/me/games/2026/11',
            ],
          }),
          200,
        );
      }
      final end = req.url.path.endsWith('/10') ? 1792000000 : 1794000000;
      return http.Response(
        jsonEncode({
          'games': [
            {'pgn': _game('me', 'x', '2026.10.01', '10:00:00'), 'end_time': end + 20, 'rules': 'chess'},
            {'pgn': _game('me', 'x', '2026.10.01', '10:00:00'), 'end_time': end + 10, 'rules': 'chess960'},
            {'pgn': _game('me', 'x', '2026.10.01', '10:00:00'), 'end_time': 1000, 'rules': 'chess'},
          ],
        }),
        200,
      );
    });
    // „seit“ im Oktober 2026: der September-Archiv wird nicht geladen
    final since = DateTime.utc(2026, 10, 1).millisecondsSinceEpoch;
    final games = await fetchChessCom('Me', sinceMs: since, client: client);
    expect(requested, isNot(contains('/pub/player/me/games/2026/09')));
    expect(games, hasLength(2));
    expect(games.first.timeMs, lessThan(games.last.timeMs));
  });

  test('guessColor erkennt Konten beider Dienste, nicht bei gleichem Namen auf beiden Seiten', () {
    final g = ParsedGame.parse(_game('Me', 'someone', '2026.11.10', '10:00:00'))!;
    expect(g.guessColor(users: ['', 'ME']), Side.white);
    expect(g.guessColor(users: ['other']), isNull);
    final h = ParsedGame.parse(_game('Me', 'me', '2026.11.10', '10:00:00'))!;
    expect(h.guessColor(users: ['me']), isNull);
  });

  test('Export enthält Konten, Import übernimmt sie ohne vorhandene zu überschreiben', () async {
    SharedPreferences.setMockInitialValues({'chesscomUser': 'schon-da'});
    final settings = await Settings.load();
    final store = await GameStore.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    final json = jsonEncode({
      'format': exportFormat,
      'version': 1,
      'accounts': {'lichess': 'meinname', 'lichessSince': 1794647202505, 'chesscom': 'anderer'},
      'games': <Object>[],
    });
    await Backup(store, settings: settings).import(json);
    expect(settings.lichessUser, 'meinname');
    expect(settings.lichessSince, 1794647202505);
    expect(settings.chesscomUser, 'schon-da');
    final out = jsonDecode(await Backup(store, settings: settings).export()) as Map<String, dynamic>;
    expect(out['accounts'], containsPair('lichess', 'meinname'));
    expect((out['accounts'] as Map).containsKey('apiKey'), isFalse);
  });
}
