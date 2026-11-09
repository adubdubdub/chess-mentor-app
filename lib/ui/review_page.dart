import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../analysis/analysis.dart';
import '../analysis/chess_utils.dart';
import '../analysis/judge.dart';
import '../coach/coach_texts.dart';
import 'app_scope.dart';
import 'evaluation_table.dart';
import 'line_viewer.dart';
import 'mistake_icons.dart';
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

  /// Eigener Versuch, der weder bester Zug noch Partiezug war: Urteil, Gewinnchance und erwartete Variante.
  (Verdict, double, List<String>)? _attempt;
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
    final result = await judgeMove(_m, uci, await scope.service.engine(), depth: scope.settings.depth);
    final verdict = result.$1;
    if (!mounted) return;
    setState(() {
      _judging = false;
      if (verdict == Verdict.good || verdict == Verdict.weak) _attempt = result;
      switch (verdict) {
        case Verdict.best:
          final b = CoachTexts.mark('b', san);
          _reveal(tr.t('✅ $b – genau das ist der stärkste Zug!', '✅ $b – exactly the strongest move!'));
        case Verdict.good:
          final a = CoachTexts.mark('a', san);
          _reveal(
            tr.t(
              '👍 $a ist auch gut spielbar, fast so stark wie der beste Zug.',
              '👍 $a is also playable, almost as strong as the best move.',
            ),
          );
        case Verdict.played || Verdict.weak when _tries >= 1:
          final a = CoachTexts.mark(verdict == Verdict.played ? 'p' : 'a', san);
          _reveal(tr.t('❌ $a ist leider auch nicht besser.', '❌ Unfortunately $a is not better either.'));
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
      _attempt = null;
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
    final attempt = _attempt;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '${tr.t('Zug', 'Move')} ${m.moveNo} · ${coach.toMove(_pos.turn)} · ${tr.phase(m.phase)}',
            style: theme.textTheme.labelLarge,
          ),
        ),
        if (_revealed)
          LineViewer(
            key: ValueKey('line$_idx'),
            fen: m.fen,
            orientation: widget.analysis.color,
            lastMove: m.lastMove,
            options: lineOptions(tr, m, attempt: attempt),
            initial: 1,
          )
        else
          Chessboard(size: width, controller: _board, orientation: widget.analysis.color, onMove: _onMove),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_revealed) ...[
                Text('❓ ${coach.question(m)}', style: theme.textTheme.titleMedium),
                if (_hint) ...[const SizedBox(height: 8), Text('💡 ${coach.tip(m)}')],
                if (_feedback != null) ...[const SizedBox(height: 8), MoveText(_feedback!)],
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
                  MoveText(_feedback!, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    MistakeBadge(m.mistake, size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MoveText(
                        '${CoachTexts.mark('p', tr.san(m.played))} → ${CoachTexts.mark('b', tr.san(m.best))}',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...explanationSections(coach, m, attempt: attempt),
                const SizedBox(height: 4),
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

/// Varianten zum Durchklicken: Partiezug (rot), bester Zug (grün) und ggf. dein Versuch (grau).
List<LineOption> lineOptions(Tr tr, Moment m, {(Verdict, double, List<String>)? attempt}) => [
  LineOption(label: tr.t('Partiezug', 'Game move'), color: playedColor, moves: m.playedMoves, win: m.winAfter),
  LineOption(label: tr.t('Bester Zug', 'Best move'), color: bestColor, moves: m.bestMoves, win: m.winBefore),
  if (attempt != null && attempt.$3.isNotEmpty)
    LineOption(label: tr.t('Dein Versuch', 'Your try'), color: attemptColor, moves: attempt.$3, win: attempt.$2),
];

/// Erklärung: Gewinnchance-Tabelle, dann farbige Abschnitte (warum der Partiezug schwach ist, warum der beste Zug stark
/// ist, dein Versuch). Die Prozentwerte stehen nur in der Tabelle.
List<Widget> explanationSections(CoachTexts coach, Moment m, {(Verdict, double, List<String>)? attempt}) {
  final tr = coach.tr;
  final p = CoachTexts.mark('p', tr.san(m.played));
  final b = CoachTexts.mark('b', tr.san(m.best));
  final pos = Chess.fromSetup(Setup.parseFen(m.fen));
  final first = attempt == null || attempt.$3.isEmpty ? null : legalUci(pos, attempt.$3.first);
  return [
    EvaluationTable(moment: m, tr: tr, ownSan: first == null ? null : numbered(pos, [first]), ownWin: attempt?.$2),
    const SizedBox(height: 8),
    ColoredSection(
      color: playedColor,
      title: tr.t('Warum $p nicht gut war', 'Why $p was not good'),
      text: coach.whyPlayedBad(m, withChange: false),
    ),
    ColoredSection(
      color: bestColor,
      title: tr.t('Warum $b stärker ist', 'Why $b is stronger'),
      text: coach.whyBestGood(m, standing: false),
    ),
    if (attempt != null && attempt.$3.isNotEmpty)
      ColoredSection(
        color: attemptColor,
        title: tr.t('Dein Versuch', 'Your try'),
        text: coach.aboutAttempt(m, attempt.$3, attempt.$1, attempt.$2, standing: false),
      ),
    Text(
      tr.t(
        'Tippe oben auf eine Variante und blättere mit ‹ › oder Wischen durch die Züge.',
        'Tap a line above and step through the moves with ‹ › or by swiping.',
      ),
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
    ),
  ];
}
