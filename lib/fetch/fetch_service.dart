/// Holt neue Online-Partien der eingetragenen Konten und legt sie zur Analyse an.
library;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../analysis/analysis.dart';
import '../data/game_store.dart';
import '../data/settings.dart';
import '../engine/analysis_service.dart';
import 'online_games.dart';

class FetchResult {
  const FetchResult({this.added = 0, this.known = 0, this.errors = const []});

  /// Neue Partien, schon vorhandene, Fehlermeldungen je Dienst.
  final int added;
  final int known;
  final List<String> errors;
  bool get hasErrors => errors.isNotEmpty;
}

class FetchService extends ChangeNotifier {
  FetchService(this.store, this.settings, this.analysis, {this.client});

  final GameStore store;
  final Settings settings;
  final AnalysisService analysis;
  final http.Client? client;
  bool _busy = false;

  bool get busy => _busy;
  bool get configured => settings.lichessUser.isNotEmpty || settings.chesscomUser.isNotEmpty;

  /// Beim App-Start: höchstens einmal in 20 Stunden, nur wenn eingeschaltet und ein Konto eingetragen ist.
  Future<FetchResult?> autoFetch() async {
    final last = settings.lastFetch;
    if (!settings.autoFetch || !configured) return null;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 20)) return null;
    return fetchNow();
  }

  /// Alle eingetragenen Konten abrufen. Fehler eines Dienstes verhindern den anderen nicht.
  Future<FetchResult> fetchNow() async {
    if (_busy) return const FetchResult();
    _busy = true;
    notifyListeners();
    var added = 0, known = 0;
    final errors = <String>[];
    final users = [settings.lichessUser, settings.chesscomUser];
    try {
      Future<void> run(String user, Future<List<OnlineGame>> Function() fetch, void Function(int) saveSince) async {
        try {
          final games = await fetch();
          var newest = 0;
          for (final g in games) {
            if (g.timeMs > newest) newest = g.timeMs;
            final parsed = ParsedGame.parse(g.pgn);
            if (parsed == null) continue;
            final color = parsed.guessColor(users: users);
            final (id, isNew) = await store.add(g.pgn, parsed, color);
            if (!isNew) {
              known++;
              continue;
            }
            added++;
            if (color != null) await analysis.setColorAndAnalyse(id, color);
          }
          if (newest > 0) saveSince(newest);
        } on FetchException catch (e) {
          errors.add(e.message);
        }
      }

      if (settings.lichessUser.isNotEmpty) {
        await run(
          settings.lichessUser,
          () => fetchLichess(settings.lichessUser, sinceMs: settings.lichessSince, client: client),
          (v) => settings.lichessSince = v,
        );
      }
      if (settings.chesscomUser.isNotEmpty) {
        await run(
          settings.chesscomUser,
          () => fetchChessCom(settings.chesscomUser, sinceMs: settings.chesscomSince, client: client),
          (v) => settings.chesscomSince = v,
        );
      }
      if (errors.isEmpty) settings.lastFetch = DateTime.now();
    } finally {
      _busy = false;
      notifyListeners();
    }
    return FetchResult(added: added, known: known, errors: errors);
  }
}
