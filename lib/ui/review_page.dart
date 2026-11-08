import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../analysis/analysis.dart';
import '../analysis/chess_utils.dart';
import '../analysis/judge.dart';
import '../coach/coach_texts.dart';
import 'app_scope.dart';
import 'game_page.dart' show classColors;
import 'strings.dart';

/// Sokratische Besprechung: je Schlüsselmoment eine Frage, Zug am Brett, Prüfung durch Stockfish, Tipp und Auflösung.
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.analysis});

  final GameAnalysis analysis;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  int _idx = 0;
  int _tries = 0;
  bool _hint = false;
  bool _revealed = false;
  bool _judging = false;
  bool _finished = false;

  /// Rückmeldung zum letzten Versuch (Lob, „etwas Besseres“, Auflösung).
  String? _feedback;
  late ChessboardController _board;

  List<Moment> get _moments => widget.analysis.moments;
  Moment get _m => _moments[_idx];
  Position get _pos => Chess.fromSetup(Setup.parseFen(_m.fen));

  @override
  void initState() {
    super.initState();
    _board = ChessboardController(game: _game(_pos));
    if (_moments.isEmpty) _finished = true;
  }

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  GameData _game(Position pos, {Move? lastMove}) => GameData(
    fen: pos.fen,
    lastMove: lastMove ?? (_moments.isEmpty || _m.lastMove == null ? null : Move.parse(_m.lastMove!)),
    playerSide: _revealed || _judging
        ? PlayerSide.none
        : (pos.turn == Side.white ? PlayerSide.white : PlayerSide.black),
    sideToMove: pos.turn,
    kingSquareInCheck: pos.isCheck ? pos.board.kingOf(pos.turn) : null,
    validMoves: makeLegalMoves(pos),
  );

  void _resetBoard() => _board.updatePosition(_game(_pos), animate: false, resetPremove: true);

  Future<void> _onMove(Move move, {bool? viaDragAndDrop}) async {
    if (move is! NormalMove || !_pos.isLegal(move)) return;
    final tr = Tr.of(context);
    final pos = _pos;
    final uci = stdUci(pos, move);
    final san = tr.san(pos.makeSan(move).$2);
    setState(() => _judging = true);
    _board.updatePosition(_game(pos.play(move), lastMove: move));
    final scope = AppScope.of(context);
    final (verdict, _) = await judgeMove(_m, uci, await scope.service.engine(), depth: scope.settings.depth);
    if (!mounted) return;
    setState(() {
      _judging = false;
      switch (verdict) {
        case Verdict.best:
          _reveal(tr.t('✅ $san – genau das ist der stärkste Zug!', '✅ $san – exactly the strongest move!'));
        case Verdict.good:
          _reveal(
            tr.t(
              '👍 $san ist auch gut spielbar, fast so stark wie der Engine-Zug.',
              '👍 $san is also playable, almost as strong as the engine move.',
            ),
          );
        case Verdict.played || Verdict.weak when _tries >= 1:
          _reveal(tr.t('❌ $san ist leider auch nicht besser.', '❌ Unfortunately $san is not better either.'));
        case Verdict.played || Verdict.weak:
          _tries = 1;
          _hint = true;
          _feedback = verdict == Verdict.played
              ? tr.t(
                  '🤔 Das war dein Partiezug – da gibt es etwas Besseres. Noch ein Versuch?',
                  '🤔 That was your game move – there is something better. Try again?',
                )
              : tr.t(
                  '🤔 $san – da gibt es etwas Besseres. Noch ein Versuch?',
                  '🤔 $san – there is something better. Try again?',
                );
      }
    });
    if (!_revealed) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) _resetBoard();
    }
  }

  /// Auflösung: Partiezug rot, besserer Zug grün, Erklärung.
  void _reveal([String? prefix]) {
    _revealed = true;
    _feedback = prefix;
    _board.updatePosition(_game(_pos), animate: false, resetPremove: true);
  }

  void _next() {
    setState(() {
      if (_idx + 1 >= _moments.length) {
        _finished = true;
        return;
      }
      _idx++;
      _tries = 0;
      _hint = false;
      _revealed = false;
      _feedback = null;
    });
    _resetBoard();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final coach = CoachTexts(tr);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _finished
              ? tr.t('Abschluss', 'Wrap-up')
              : tr.t('Moment ${_idx + 1} von ${_moments.length}', 'Moment ${_idx + 1} of ${_moments.length}'),
        ),
      ),
      body: _finished ? _finishView(context, coach) : _momentView(context, coach),
    );
  }

  Widget _momentView(BuildContext context, CoachTexts coach) {
    final tr = coach.tr;
    final theme = Theme.of(context);
    final m = _m;
    final width = MediaQuery.sizeOf(context).width;
    final played = Move.parse(m.playedUci) as NormalMove;
    final best = Move.parse(m.bestUci) as NormalMove;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '${tr.t('Zug', 'Move')} ${m.moveNo} · ${coach.toMove(_pos.turn)} · ${tr.phase(m.phase)}',
            style: theme.textTheme.labelLarge,
          ),
        ),
        Chessboard(
          size: width,
          controller: _board,
          orientation: widget.analysis.color,
          onMove: _onMove,
          shapes: _revealed
              ? {
                  Arrow(color: const Color(0xCCD64545), orig: played.from, dest: played.to),
                  Arrow(color: const Color(0xCC15781B), orig: best.from, dest: best.to),
                }
              : const {},
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_revealed) ...[
                Text('❓ ${coach.question(m)}', style: theme.textTheme.titleMedium),
                if (_hint) ...[const SizedBox(height: 8), Text('💡 ${coach.tip(m)}')],
                if (_feedback != null) ...[const SizedBox(height: 8), Text(_feedback!)],
                const SizedBox(height: 8),
                if (_judging)
                  Row(
                    children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text(tr.t('Stockfish prüft deinen Zug …', 'Stockfish is checking your move …')),
                    ],
                  )
                else
                  Text(
                    tr.t('Zieh deinen Zug auf dem Brett.', 'Make your move on the board.'),
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!_hint)
                      OutlinedButton.icon(
                        onPressed: _judging ? null : () => setState(() => _hint = true),
                        icon: const Icon(Icons.lightbulb_outline),
                        label: Text(tr.t('Tipp', 'Hint')),
                      ),
                    FilledButton.tonalIcon(
                      onPressed: _judging ? null : () => setState(_reveal),
                      icon: const Icon(Icons.visibility),
                      label: Text(tr.t('Auflösung', 'Solution')),
                    ),
                    TextButton(onPressed: _judging ? null : _next, child: Text(tr.t('Überspringen', 'Skip'))),
                  ],
                ),
              ] else ...[
                if (_feedback != null) ...[
                  Text(_feedback!, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: classColors[m.mistake],
                      child: Text(m.mistake.glyph, style: const TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Text('${tr.san(m.played)} → ${tr.san(m.best)}', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(coach.explanation(m)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _next,
                  icon: Icon(_idx + 1 >= _moments.length ? Icons.flag : Icons.arrow_forward),
                  label: Text(_idx + 1 >= _moments.length ? tr.t('Abschluss', 'Wrap-up') : tr.t('Weiter', 'Next')),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _finishView(BuildContext context, CoachTexts coach) {
    final tr = coach.tr;
    final theme = Theme.of(context);
    final a = widget.analysis;
    final n = a.puzzles.length;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(coach.summary(a), style: theme.textTheme.bodyLarge),
        const SizedBox(height: 24),
        Text(
          '🎯 ${tr.t('Lernpunkt für die nächsten Partien', 'Takeaway for your next games')}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(coach.learningPoint(a), style: theme.textTheme.titleLarge),
        if (n > 0) ...[
          const SizedBox(height: 24),
          Text(
            tr.t(
              '🧩 $n ${n == 1 ? 'Stellung kommt' : 'Stellungen kommen'} später als Puzzle wieder.',
              '🧩 $n ${n == 1 ? 'position returns' : 'positions return'} later as a puzzle.',
            ),
          ),
        ],
        const SizedBox(height: 32),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr.t('Fertig', 'Done'))),
      ],
    );
  }
}
