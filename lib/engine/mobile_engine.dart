/// Stockfish auf dem Handy: kleines eingebautes Netz oder großes, nachgeladenes Netz.
library;

import 'package:multistockfish/multistockfish.dart';

import '../analysis/line_engine.dart';

enum EngineNet {
  /// Stockfish mit eingebautem kleinem Netz (~1 MB), sofort nutzbar.
  light,

  /// Stockfish mit großem Netz, das erst geladen werden muss.
  full,
}

class MobileEngine extends LineEngine {
  MobileEngine._(this._sf, this.net);

  final Stockfish _sf;
  final EngineNet net;

  @override
  Stream<String> get lines => _sf.stdout;

  @override
  void send(String command) => _sf.stdin = command;

  static Future<MobileEngine> start(EngineNet net, {String? nnuePath, int threads = 1, int hashMb = 64}) async {
    final sf = await Stockfish.create(
      flavor: net == EngineNet.light ? StockfishFlavor.light : StockfishFlavor.latestNoNNUE,
      nnuePath: net == EngineNet.full ? nnuePath : null,
    );
    final engine = MobileEngine._(sf, net);
    await engine.configure(threads: threads, hashMb: hashMb);
    return engine;
  }

  Future<void> dispose() => _sf.dispose();
}
