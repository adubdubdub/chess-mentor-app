/// UCI-Dialog über Textzeilen; gemeinsam für Stockfish auf dem Handy und den Prozess in Tests.
library;

import 'dart:async';

import 'uci.dart';

abstract class LineEngine implements UciEngine {
  /// Ausgabe der Engine, eine Zeile je Ereignis (Broadcast).
  Stream<String> get lines;

  /// Eine Zeile an die Engine schicken.
  void send(String command);

  Future<void> _queue = Future.value();

  /// Befehle nacheinander ausführen, auch wenn mehrere Aufrufer gleichzeitig anfragen.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<String> _sendUntil(List<String> commands, String prefix) {
    final done = lines.firstWhere((l) => l.startsWith(prefix));
    commands.forEach(send);
    return done;
  }

  /// Grundeinstellungen; [hashMb] und [threads] wie beim Bot standardmäßig 128 MB und 1 Thread.
  Future<void> configure({int threads = 1, int hashMb = 128}) => _serial(() async {
    await _sendUntil(['uci'], 'uciok');
    await _sendUntil([
      'setoption name Threads value $threads',
      'setoption name Hash value $hashMb',
      'isready',
    ], 'readyok');
  });

  @override
  Future<void> newGame() => _serial(() => _sendUntil(['ucinewgame', 'isready'], 'readyok'));

  @override
  Future<List<PvLine>> analyse({
    required String rootFen,
    required List<String> moves,
    required int depth,
    required int multiPv,
  }) => _serial(() async {
    final latest = <int, PvLine>{};
    final sub = lines.listen((l) {
      final pv = PvLine.parse(l);
      if (pv != null) latest[pv.multipv] = pv;
    });
    try {
      final position = 'position fen $rootFen${moves.isEmpty ? '' : ' moves ${moves.join(' ')}'}';
      await _sendUntil(['setoption name MultiPV value $multiPv', 'isready'], 'readyok');
      await _sendUntil([position, 'go depth $depth'], 'bestmove');
    } finally {
      await sub.cancel();
    }
    return [for (final k in latest.keys.toList()..sort()) latest[k]!];
  });
}
