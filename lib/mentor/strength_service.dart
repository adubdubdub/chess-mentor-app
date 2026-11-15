/// Aktualisiert die Spielstärke aus Online-Wertungen und eigenen Partien und speichert Schätzung und Stufe.
library;

import 'package:http/http.dart' as http;

import '../data/game_store.dart';
import '../data/settings.dart';
import '../fetch/ratings.dart';
import 'strength.dart';

class StrengthService {
  StrengthService(this.store, this.settings, {this.client});

  final GameStore store;
  final Settings settings;
  final http.Client? client;

  /// Neu schätzen. Mit [online] werden die Wertungen der eingetragenen Konten abgerufen (Fehler stoppen nichts, dann
  /// gilt der zuletzt bekannte Online-Wert). Gibt die neue Schätzung zurück.
  Future<Strength> refresh({bool online = false, DateTime? now}) async {
    final t = now ?? DateTime.now();
    final previous = settings.strength;
    var onlineElo = previous?.onlineElo;
    var onlineWeight = previous?.onlineWeight ?? 0.0;
    if (online) {
      final lichess = <PerfRating>[], chessCom = <PerfRating>[];
      try {
        if (settings.lichessUser.isNotEmpty) {
          lichess.addAll(await fetchLichessRatings(settings.lichessUser, client: client));
        }
      } catch (_) {}
      try {
        if (settings.chesscomUser.isNotEmpty) {
          chessCom.addAll(await fetchChessComRatings(settings.chesscomUser, client: client));
        }
      } catch (_) {}
      final est = onlineEstimate(lichess: lichess, chessCom: chessCom);
      if (est != null) {
        onlineElo = est.elo;
        onlineWeight = est.weight;
      }
    }
    final records = await store.mentorRecords(limit: 20);
    final accuracies = [
      for (final r in records)
        if (r.analysis.accuracy != null) r.analysis.accuracy!,
    ];
    final accuracy = accuracies.isEmpty ? null : accuracies.reduce((a, b) => a + b) / accuracies.length;
    final strength = estimateStrength(
      manual: settings.strengthManual ? settings.strengthManualElo : null,
      onlineElo: onlineElo,
      onlineWeight: onlineWeight,
      accuracy: accuracy,
      games: records.length,
      previous: previous,
      now: t,
    );
    settings.strength = strength;
    settings.levelState = nextLevel(
      settings.levelState,
      strength.elo,
      immediate: strength.source == StrengthSource.manual,
    );
    return strength;
  }
}
