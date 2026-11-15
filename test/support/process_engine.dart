import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chess_mentor/analysis/line_engine.dart';

/// Befehl für Stockfish in Tests: Umgebungsvariable STOCKFISH_BIN (lokales Binary),
/// sonst /root/dev/stockfish/stockfish.
List<String>? engineCommand() {
  final env = Platform.environment['STOCKFISH_BIN'];
  for (final path in [if (env != null && env.isNotEmpty) env, '/root/dev/stockfish/stockfish']) {
    if (File(path).existsSync()) return [path];
  }
  return null;
}

/// Stockfish als Prozess für Tests auf dem Server.
class ProcessEngine extends LineEngine {
  ProcessEngine._(this._process) {
    _process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_lines.add);
  }

  final Process _process;
  final _lines = StreamController<String>.broadcast();

  @override
  Stream<String> get lines => _lines.stream;

  @override
  void send(String command) => _process.stdin.writeln(command);

  static Future<ProcessEngine> start({List<String>? command}) async {
    command ??= engineCommand()!;
    final engine = ProcessEngine._(await Process.start(command.first, command.sublist(1)));
    await engine.configure();
    return engine;
  }

  Future<void> dispose() async {
    send('quit');
    await _process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _process.kill();
        return -1;
      },
    );
    await _lines.close();
  }
}
