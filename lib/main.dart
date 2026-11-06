// Phase 0: Prüf-App für Brett (chessground) und Engine (multistockfish).
// Nach jedem Zug bewertet Stockfish die Stellung und zeigt den besten Zug als Pfeil.
import 'dart:async';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:multistockfish/multistockfish.dart';

void main() => runApp(const ChessMentorApp());

class ChessMentorApp extends StatelessWidget {
  const ChessMentorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schach-Mentor',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF4A7C59), useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF4A7C59), brightness: Brightness.dark, useMaterial3: true),
      home: const BoardPage(),
    );
  }
}

class BoardPage extends StatefulWidget {
  const BoardPage({super.key});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  Position _position = Chess.initial;
  Move? _lastMove;
  final List<String> _san = [];
  late final ChessboardController _controller = ChessboardController(game: _game());

  Stockfish? _engine;
  StreamSubscription<String>? _sub;
  String _status = 'Stockfish startet …';
  String? _eval;
  int _depth = 0;
  NormalMove? _best;

  @override
  void initState() {
    super.initState();
    _startEngine();
  }

  Future<void> _startEngine() async {
    try {
      final engine = await Stockfish.create();
      _sub = engine.stdout.listen(_onEngineLine);
      engine.stdin = 'setoption name MultiPV value 1';
      setState(() {
        _engine = engine;
        _status = 'Stockfish bereit';
      });
      _analyse();
    } catch (e) {
      setState(() => _status = 'Stockfish-Fehler: $e');
    }
  }

  void _analyse() {
    final engine = _engine;
    if (engine == null) return;
    _best = null;
    _eval = null;
    _depth = 0;
    if (_position.isGameOver) {
      setState(() => _status = 'Partie beendet');
      return;
    }
    engine.stdin = 'stop';
    engine.stdin = 'position fen ${_position.fen}';
    engine.stdin = 'go depth 16';
    setState(() => _status = 'rechnet …');
  }

  void _onEngineLine(String line) {
    if (line.startsWith('info') && line.contains(' pv ')) {
      final parts = line.split(' ');
      final depth = int.tryParse(parts[parts.indexOf('depth') + 1]) ?? 0;
      final scoreAt = parts.indexOf('score');
      final kind = parts[scoreAt + 1];
      final value = int.parse(parts[scoreAt + 2]);
      // Stockfish bewertet aus Sicht der Seite am Zug; angezeigt wird aus Sicht von Weiß.
      final sign = _position.turn == Side.white ? 1 : -1;
      final eval = kind == 'mate'
          ? 'Matt in ${value.abs()} für ${value * sign > 0 ? 'Weiß' : 'Schwarz'}'
          : (value * sign / 100).toStringAsFixed(2);
      final move = Move.parse(parts[parts.indexOf('pv') + 1]);
      setState(() {
        _depth = depth;
        _eval = eval;
        _best = move is NormalMove ? move : null;
      });
    } else if (line.startsWith('bestmove')) {
      setState(() => _status = 'fertig');
    }
  }

  GameData _game() => GameData(
        fen: _position.fen,
        lastMove: _lastMove,
        playerSide: _position.turn == Side.white ? PlayerSide.white : PlayerSide.black,
        sideToMove: _position.turn,
        kingSquareInCheck: _position.isCheck ? _position.board.kingOf(_position.turn) : null,
        validMoves: makeLegalMoves(_position),
      );

  void _onMove(Move move, {bool? viaDragAndDrop}) {
    if (!_position.isLegal(move)) return;
    final (next, san) = _position.makeSan(move);
    setState(() {
      _position = next;
      _lastMove = move;
      _san.add(san);
    });
    _controller.updatePosition(_game());
    _analyse();
  }

  void _reset() {
    setState(() {
      _position = Chess.initial;
      _lastMove = null;
      _san.clear();
    });
    _controller.updatePosition(_game(), animate: false);
    _analyse();
  }

  String _moveList() {
    final out = StringBuffer();
    for (var i = 0; i < _san.length; i++) {
      if (i.isEven) out.write('${i ~/ 2 + 1}.');
      out.write('${_san[i]} ');
    }
    return out.toString();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _engine?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final best = _best;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schach-Mentor'),
        actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: 'Neue Partie', onPressed: _reset)],
      ),
      body: ListView(
        children: [
          Chessboard(
            size: width,
            controller: _controller,
            orientation: Side.white,
            onMove: _onMove,
            shapes: {
              if (best != null) Arrow(color: const Color(0xAA15781B), orig: best.from, dest: best.to),
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bewertung: ${_eval ?? '–'}  (Tiefe $_depth)',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(_status),
                const SizedBox(height: 12),
                Text(_moveList()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
