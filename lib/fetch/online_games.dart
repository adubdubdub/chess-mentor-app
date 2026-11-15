/// Partien per Benutzername von Lichess und Chess.com holen (öffentliche APIs, kein Schlüssel).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../analysis/pgn_split.dart';

/// Ohne eigene Kennung antwortet Lichess mit 404; Chess.com verlangt sie ebenfalls.
const userAgent = 'SchachMentor/1.0 (Android-App, github.com/adubdubdub/chess-mentor-app)';

/// Beim ersten Abruf nur die letzten Tage holen.
const firstRunDays = 7;
const maxGames = 30;

class FetchException implements Exception {
  const FetchException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OnlineGame {
  const OnlineGame(this.pgn, this.timeMs);

  final String pgn;

  /// Zeitpunkt der Partie in Millisekunden (Lichess: Start, Chess.com: Ende) für „seit“ beim nächsten Abruf.
  final int timeMs;
}

int _utcMs(String pgn) {
  final d = RegExp(r'\[UTCDate "(\d{4})\.(\d{2})\.(\d{2})"\]').firstMatch(pgn);
  final t = RegExp(r'\[UTCTime "(\d{2}):(\d{2}):(\d{2})"\]').firstMatch(pgn);
  if (d == null) return 0;
  int g(RegExpMatch m, int i) => int.parse(m.group(i)!);
  return DateTime.utc(g(d, 1), g(d, 2), g(d, 3), t == null ? 0 : g(t, 1), t == null ? 0 : g(t, 2), t == null ? 0 : g(t, 3))
      .millisecondsSinceEpoch;
}

Never _fail(http.Response r, String who, String user) {
  if (r.statusCode == 404) throw FetchException('$who: Benutzer „$user“ nicht gefunden');
  if (r.statusCode == 429) throw FetchException('$who: zu viele Anfragen, bitte später noch einmal');
  throw FetchException('$who: Fehler ${r.statusCode}');
}

/// Beendete Standard-Partien von Lichess seit [sinceMs] (null: letzte [firstRunDays] Tage), älteste zuerst.
Future<List<OnlineGame>> fetchLichess(String user, {int? sinceMs, http.Client? client, DateTime? now}) async {
  final c = client ?? http.Client();
  final since = sinceMs ?? (now ?? DateTime.now()).subtract(const Duration(days: firstRunDays)).millisecondsSinceEpoch;
  final uri = Uri.https('lichess.org', '/api/games/user/${Uri.encodeComponent(user)}', {
    'since': '${since + 1}',
    'finished': 'true',
    'sort': 'dateAsc',
    'max': '$maxGames',
    'opening': 'true',
    'clocks': 'false',
    'evals': 'false',
    'perfType': 'ultraBullet,bullet,blitz,rapid,classical,correspondence', // nur Standardschach, keine Varianten
  });
  final http.Response r;
  try {
    r = await c.get(uri, headers: {'Accept': 'application/x-chess-pgn', 'User-Agent': userAgent}).timeout(
      const Duration(seconds: 60),
    );
  } catch (e) {
    throw const FetchException('Lichess: keine Verbindung');
  }
  if (r.statusCode != 200) _fail(r, 'Lichess', user);
  return [for (final p in splitPgn(utf8.decode(r.bodyBytes))) OnlineGame(p, _utcMs(p))];
}

/// Partien von Chess.com seit [sinceMs] (null: letzte [firstRunDays] Tage), nur Standardschach, älteste zuerst.
Future<List<OnlineGame>> fetchChessCom(String user, {int? sinceMs, http.Client? client, DateTime? now}) async {
  final c = client ?? http.Client();
  final since = sinceMs ?? (now ?? DateTime.now()).subtract(const Duration(days: firstRunDays)).millisecondsSinceEpoch;
  final name = Uri.encodeComponent(user.toLowerCase());
  Future<http.Response> get(Uri uri) async {
    try {
      return await c.get(uri, headers: {'Accept': 'application/json', 'User-Agent': userAgent}).timeout(
        const Duration(seconds: 60),
      );
    } catch (e) {
      throw const FetchException('Chess.com: keine Verbindung');
    }
  }

  final list = await get(Uri.https('api.chess.com', '/pub/player/$name/games/archives'));
  if (list.statusCode != 200) _fail(list, 'Chess.com', user);
  final archives = [for (final u in (jsonDecode(list.body)['archives'] as List? ?? const [])) u as String];
  // Archive sind Monate (…/games/2026/11); nur Monate ab dem Monat von „seit“ laden
  final from = DateTime.fromMillisecondsSinceEpoch(since, isUtc: true);
  final firstKey = '${from.year}/${from.month.toString().padLeft(2, '0')}';
  final games = <OnlineGame>[];
  for (final url in archives.where((u) => u.endsWith('/') ? false : u.substring(u.length - 7).compareTo(firstKey) >= 0)) {
    final r = await get(Uri.parse(url));
    if (r.statusCode != 200) _fail(r, 'Chess.com', user);
    for (final g in (jsonDecode(utf8.decode(r.bodyBytes))['games'] as List? ?? const [])) {
      final m = g as Map<String, dynamic>;
      final end = ((m['end_time'] as num?) ?? 0).toInt() * 1000;
      final pgn = m['pgn'] as String?;
      if (m['rules'] != 'chess' || pgn == null || pgn.isEmpty || end <= since) continue;
      games.add(OnlineGame(pgn, end));
    }
  }
  games.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  return games.length > maxGames ? games.sublist(games.length - maxGames) : games;
}
