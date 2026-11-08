/// Führt Analysen nacheinander aus und hält die Engine passend zu den Einstellungen bereit.
library;

import 'dart:async';

import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../analysis/analysis.dart';
import '../data/game_store.dart';
import '../data/settings.dart';
import 'mobile_engine.dart';
import 'net_manager.dart';

class AnalysisService extends ChangeNotifier {
  AnalysisService(this.store, this.settings, this.nets);

  final GameStore store;
  final Settings settings;
  final NetManager nets;

  MobileEngine? _engine;
  (EngineNet, int)? _engineConfig;
  final _queue = <int>[];
  bool _running = false;

  /// Fortschritt der laufenden Analyse: Partie-id → (bewertete Stellungen, alle Stellungen).
  final progress = <int, (int, int)>{};

  /// Netz, das wirklich genutzt wird: das große nur, wenn gewählt und geladen.
  Future<EngineNet> effectiveNet() async =>
      settings.net == EngineNet.full && await nets.installed() ? EngineNet.full : EngineNet.light;

  Future<MobileEngine> _ensureEngine() async {
    final net = await effectiveNet();
    final config = (net, settings.threads);
    if (_engine != null && _engineConfig == config) return _engine!;
    await releaseEngine();
    _engine = await MobileEngine.start(
      net,
      nnuePath: net == EngineNet.full ? (await nets.file()).path : null,
      threads: settings.threads,
    );
    _engineConfig = config;
    return _engine!;
  }

  /// Engine freigeben, z. B. vor einer Messung oder einem Netzwechsel.
  Future<void> releaseEngine() async {
    final e = _engine;
    _engine = null;
    _engineConfig = null;
    await e?.dispose();
  }

  bool get busy => _running;

  void enqueue(int id) {
    if (!_queue.contains(id)) _queue.add(id);
    _run();
  }

  Future<void> setColorAndAnalyse(int id, Side color) async {
    await store.setColor(id, color);
    notifyListeners();
    enqueue(id);
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    // Bildschirm wach halten: Bei ausgeschaltetem Bildschirm pausiert Android die Engine (Test 08.11.2026)
    await WakelockPlus.enable();
    try {
      while (_queue.isNotEmpty) {
        final id = _queue.removeAt(0);
        final game = await store.get(id);
        if (game == null || game.color == null) continue;
        final parsed = ParsedGame.parse(game.pgn);
        if (parsed == null) {
          await store.setStatus(id, GameStatus.error, error: 'PGN');
          continue;
        }
        await store.setStatus(id, GameStatus.analysing);
        progress[id] = (0, parsed.moves.length + 1);
        notifyListeners();
        try {
          final engine = await _ensureEngine();
          final result = await analyseGame(
            parsed,
            game.color!,
            engine,
            engineName: engine.net.name,
            depth: settings.depth,
            onProgress: (done, total) {
              progress[id] = (done, total);
              notifyListeners();
            },
          );
          await store.setAnalysis(id, result);
        } catch (e) {
          await store.setStatus(id, GameStatus.error, error: e.toString());
        }
        progress.remove(id);
        notifyListeners();
      }
    } finally {
      _running = false;
      await WakelockPlus.disable();
    }
  }

  /// Nach einem App-Neustart liegengebliebene Analysen wieder aufnehmen.
  Future<void> resume() async {
    for (final g in await store.all()) {
      if (g.status == GameStatus.queued || g.status == GameStatus.analysing) enqueue(g.id);
    }
  }
}
