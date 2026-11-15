/// Wertungen von Lichess und Chess.com (öffentliche Schnittstellen, kein Schlüssel).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../mentor/strength.dart';
import 'online_games.dart';

/// Lichess: `perfs.<art>` mit `rating`, `games` und `prov` (vorläufig). Nur Spielarten mit mindestens einer Partie.
List<PerfRating> parseLichessPerfs(Map<String, dynamic> user) {
  final perfs = user['perfs'];
  if (perfs is! Map) return const [];
  return [
    for (final e in perfs.entries)
      if (perfFactors.containsKey(e.key) && e.value is Map && ((e.value as Map)['games'] as num? ?? 0) > 0)
        PerfRating(
          perf: e.key as String,
          rating: ((e.value as Map)['rating'] as num).round(),
          games: ((e.value as Map)['games'] as num).round(),
          provisional: (e.value as Map)['prov'] == true,
        ),
  ];
}

/// Chess.com: `chess_<art>.last.rating` und `record` (Siege, Niederlagen, Remis). Unter 10 Partien gilt als vorläufig.
List<PerfRating> parseChessComStats(Map<String, dynamic> stats) {
  final out = <PerfRating>[];
  for (final e in stats.entries) {
    if (!e.key.startsWith('chess_') || e.value is! Map) continue;
    final perf = e.key.substring('chess_'.length);
    final v = e.value as Map;
    final rating = (v['last'] as Map?)?['rating'] as num?;
    final rec = v['record'] as Map?;
    if (!perfFactors.containsKey(perf) || rating == null || rec == null) continue;
    final games = [
      for (final k in ['win', 'loss', 'draw']) (rec[k] as num?)?.round() ?? 0,
    ].fold(0, (a, b) => a + b);
    if (games == 0) continue;
    out.add(PerfRating(perf: perf, rating: rating.round(), games: games, provisional: games < 10));
  }
  return out;
}

Future<Map<String, dynamic>> _getJson(http.Client c, Uri uri, String who, String user) async {
  final http.Response r;
  try {
    r = await c
        .get(uri, headers: {'Accept': 'application/json', 'User-Agent': userAgent})
        .timeout(const Duration(seconds: 30));
  } catch (_) {
    throw FetchException('$who: keine Verbindung');
  }
  if (r.statusCode == 404) throw FetchException('$who: Benutzer „$user“ nicht gefunden');
  if (r.statusCode != 200) throw FetchException('$who: Fehler ${r.statusCode}');
  return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
}

Future<List<PerfRating>> fetchLichessRatings(String user, {http.Client? client}) async => parseLichessPerfs(
  await _getJson(
    client ?? http.Client(),
    Uri.https('lichess.org', '/api/user/${Uri.encodeComponent(user)}'),
    'Lichess',
    user,
  ),
);

Future<List<PerfRating>> fetchChessComRatings(String user, {http.Client? client}) async => parseChessComStats(
  await _getJson(
    client ?? http.Client(),
    Uri.https('api.chess.com', '/pub/player/${Uri.encodeComponent(user.toLowerCase())}/stats'),
    'Chess.com',
    user,
  ),
);
