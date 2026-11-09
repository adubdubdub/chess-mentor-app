import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../analysis/chess_utils.dart';
import '../analysis/judge.dart';
import '../coach/coach_texts.dart';
import '../data/game_store.dart';
import 'app_scope.dart';
import 'strings.dart';

/// Puzzles aus eigenen Fehlern: Stellung vor dem Fehler, besten Zug finden, Wiederholung nach Plan.
class PuzzlePage extends StatefulWidget {
  const PuzzlePage({super.key});

  @override
  State<PuzzlePage> createState() => _PuzzlePageState();
}

class _PuzzlePageState extends State<PuzzlePage> {
  StoredPuzzle? _p;
  PuzzleStats? _stats;
  int _left = 0;
  int _tries = 0;
  bool _hint = false;
  bool _judging = false;

  /// Nach dem Ergebnis: neue Fälligkeit bzw. null = gemeistert.
  bool _done = false;
  String? _nextDue;
  String? _feedback;

  /// Gewinnchance nach dem letzten eigenen Zug (null = Lösung angezeigt) und dessen Notation.
  double? _ownWin;
  String? _ownSan;
  bool _loading = true;

  /// Nichts fällig, aber der Nutzer möchte das nächste Puzzle vorziehen.
  bool _early = false;
  ChessboardController? _board;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  @override
  void dispose() {
    _board?.dispose();
    super.dispose();
  }

  Position get _pos => Chess.fromSetup(Setup.parseFen(_p!.moment.fen));

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final stats = await scope.store.puzzleStats();
    final left = scope.settings.puzzlesPerDay - stats.doneToday;
    final due = _early
        ? [?await scope.store.nextPuzzle()]
        : left > 0
        ? await scope.store.duePuzzles(limit: 1)
        : <StoredPuzzle>[];
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _left = left < stats.due ? left : stats.due;
      _p = due.firstOrNull;
      _tries = 0;
      _hint = false;
      _done = false;
      _feedback = null;
      _ownWin = null;
      _ownSan = null;
      _nextDue = null;
      _loading = false;
      _early = false;
    });
    if (_p != null) {
      final game = _game(_pos);
      _board == null ? _board = ChessboardController(game: game) : _board!.updatePosition(game, animate: false);
    }
  }

  GameData _game(Position pos, {Move? lastMove}) => GameData(
    fen: pos.fen,
    lastMove: lastMove ?? (_p!.moment.lastMove == null ? null : Move.parse(_p!.moment.lastMove!)),
    playerSide: _done || _judging ? PlayerSide.none : (pos.turn == Side.white ? PlayerSide.white : PlayerSide.black),
    sideToMove: pos.turn,
    kingSquareInCheck: pos.isCheck ? pos.board.kingOf(pos.turn) : null,
    validMoves: makeLegalMoves(pos),
  );

  Future<void> _onMove(Move move, {bool? viaDragAndDrop}) async {
    if (move is! NormalMove || !_pos.isLegal(move)) return;
    final tr = Tr.of(context);
    final scope = AppScope.of(context);
    final pos = _pos;
    final san = tr.san(pos.makeSan(move).$2);
    setState(() => _judging = true);
    _board!.updatePosition(_game(pos.play(move), lastMove: move));
    final (verdict, win, _) = await judgeMove(
      _p!.moment,
      stdUci(pos, move),
      await scope.service.engine(),
      depth: scope.settings.depth,
    );
    if (!mounted) return;
    setState(() => _judging = false);
    switch (verdict) {
      case Verdict.best || Verdict.good:
        await _finish(
          true,
          own: (san, win),
          verdict == Verdict.best
              ? tr.t('✅ $san – genau der stärkste Zug!', '✅ $san – exactly the strongest move!')
              : tr.t('✅ $san – auch gut spielbar!', '✅ $san – also playable!'),
        );
      case Verdict.played || Verdict.weak when _tries >= 1:
        await _finish(
          false,
          own: (san, win),
          tr.t('❌ $san ist leider auch nicht besser.', '❌ Unfortunately $san is not better either.'),
        );
      case Verdict.played || Verdict.weak:
        final chance = tr.t(
          'Gewinnchance nach dem Zug: ${win.round()} %, vorher ${_p!.moment.winBefore.round()} %.',
          'Winning chance after the move: ${win.round()} %, before ${_p!.moment.winBefore.round()} %.',
        );
        setState(() {
          _tries = 1;
          _hint = true;
          _feedback = verdict == Verdict.played
              ? tr.t(
                  '🤔 Das war dein Partiezug von damals ($chance) Noch ein Versuch?',
                  '🤔 That was your move back then ($chance) Try again?',
                )
              : tr.t('🤔 $san reicht nicht. $chance Noch ein Versuch?', '🤔 $san is not enough. $chance Try again?');
        });
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) _board!.updatePosition(_game(_pos), animate: false, resetPremove: true);
    }
  }

  Future<void> _finish(bool solved, String? feedback, {(String, double)? own}) async {
    final scope = AppScope.of(context);
    final due = await scope.store.gradePuzzle(_p!.id, solved);
    await scope.reminders.reschedule();
    if (!mounted) return;
    setState(() {
      _done = true;
      _nextDue = due;
      _feedback = feedback;
      _ownSan = own?.$1;
      _ownWin = own?.$2;
    });
    _board!.updatePosition(_game(_pos), animate: false, resetPremove: true);
  }

  /// Auswertung nach dem Puzzle in drei Blöcken: Gewinnchance je Zug, Folge des Partiezugs, Begründung.
  Widget _evaluation(Tr tr, CoachTexts coach) {
    final m = _p!.moment;
    final theme = Theme.of(context);
    String diff(double v) => '${v >= 0 ? '+' : '−'}${v.abs().round()} %';
    Widget row(Color color, String label, double win, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null),
          ),
          Text('${win.round()} %', style: const TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(
            width: 64,
            child: Text(win == m.winBefore ? '' : ' ${diff(win - m.winBefore)}', textAlign: TextAlign.end),
          ),
        ],
      ),
    );
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
    );
    final alts = m.alternatives.where((a) => a.uci != m.bestUci && m.winBefore - a.win < 5);
    const green = Color(0xFF4CAF50), red = Color(0xFFD64545), grey = Color(0xFF9E9E9E);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(tr.t('Gewinnchance', 'Winning chance')),
        row(green, tr.t('Bester Zug ${tr.san(m.best)}', 'Best move ${tr.san(m.best)}'), m.winBefore, bold: true),
        for (final a in alts)
          row(green.withAlpha(150), tr.t('Auch gut ${tr.san(a.san)}', 'Also good ${tr.san(a.san)}'), a.win),
        if (_ownWin != null && _ownSan != null) row(grey, tr.t('Dein Zug $_ownSan', 'Your move $_ownSan'), _ownWin!),
        row(
          red,
          tr.t('Partiezug ${tr.san(m.played)}${m.mistake.glyph}', 'Game move ${tr.san(m.played)}${m.mistake.glyph}'),
          m.winAfter,
        ),
        if (m.replyLine.isNotEmpty) ...[
          heading(tr.t('Folge des Partiezugs', 'What follows the game move')),
          Text(tr.san(m.replyLine)),
        ],
        heading(tr.t('Warum', 'Why')),
        Text(coach.puzzleWhy(m)),
      ],
    );
  }

  String _date(String iso) {
    final d = DateTime.parse(iso);
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr.puzzles)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _p == null
          ? _empty(context, tr)
          : _puzzle(context, tr),
    );
  }

  Widget _empty(BuildContext context, Tr tr) {
    final s = _stats!;
    final text = s.total == 0
        ? tr.t(
            'Noch keine Puzzles. Sie entstehen aus Fehlern und Patzern in deinen Partien.',
            'No puzzles yet. They come from mistakes and blunders in your games.',
          )
        : s.due > 0
        ? tr.t(
            '✅ ${s.doneToday} Puzzles geschafft, das reicht für heute. Morgen geht es weiter.',
            '✅ ${s.doneToday} puzzles done, that is enough for today. More tomorrow.',
          )
        : tr.t(
            '✅ Keine Puzzles mehr fällig.${s.nextDue == null ? '' : ' Nächstes am ${_date(s.nextDue!)}'}',
            '✅ No more puzzles due.${s.nextDue == null ? '' : ' Next on ${_date(s.nextDue!)}'}',
          );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            if (s.total > 0 && s.due == 0 && s.nextDue != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _early = true;
                  });
                  _load();
                },
                icon: const Icon(Icons.fast_forward),
                label: Text(tr.t('Nächstes vorziehen', 'Practise the next one now')),
              ),
            ],
            if (s.total > 0) ...[
              const SizedBox(height: 16),
              Text(
                tr.t(
                  '${s.total} Puzzles, davon ${s.mastered} gemeistert 🏆',
                  '${s.total} puzzles, ${s.mastered} mastered 🏆',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _puzzle(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final p = _p!;
    final m = p.moment;
    final coach = CoachTexts(tr);
    final played = Move.parse(m.playedUci) as NormalMove;
    final best = Move.parse(m.bestUci) as NormalMove;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            tr.t(
              '🧩 ${_left > 0 ? 'noch $_left heute' : 'vorgezogen'} · aus ${p.white} – ${p.black}, Zug ${m.moveNo}',
              '🧩 ${_left > 0 ? '$_left left today' : 'early'} · from ${p.white} – ${p.black}, move ${m.moveNo}',
            ),
            style: theme.textTheme.labelLarge,
          ),
        ),
        Chessboard(
          size: MediaQuery.sizeOf(context).width,
          controller: _board!,
          orientation: _pos.turn,
          onMove: _onMove,
          shapes: _done
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
              if (!_done) ...[
                Text(
                  '${coach.toMove(_pos.turn)}: ${tr.t('Finde den besten Zug!', 'Find the best move!')}',
                  style: theme.textTheme.titleMedium,
                ),
                if (p.lapses > 0)
                  Text(tr.t('Diese Stellung hattest du schon mal falsch.', 'You got this position wrong before.')),
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
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    if (!_hint)
                      OutlinedButton.icon(
                        onPressed: _judging ? null : () => setState(() => _hint = true),
                        icon: const Icon(Icons.lightbulb_outline),
                        label: Text(tr.t('Tipp', 'Hint')),
                      ),
                    FilledButton.tonalIcon(
                      onPressed: _judging ? null : () => _finish(false, null),
                      icon: const Icon(Icons.visibility),
                      label: Text(tr.t('Lösung', 'Solution')),
                    ),
                  ],
                ),
              ] else ...[
                if (_feedback != null) ...[
                  Text(_feedback!, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                ],
                Text(tr.t('Lösung: ${tr.san(m.bestLine)}', 'Solution: ${tr.san(m.bestLine)}')),
                const SizedBox(height: 8),
                _evaluation(tr, coach),
                const SizedBox(height: 8),
                Text(
                  _nextDue == null
                      ? tr.t(
                          'Gemeistert 🏆 – dieses Puzzle kommt nicht mehr wieder.',
                          'Mastered 🏆 – this puzzle will not return.',
                        )
                      : tr.t('Kommt am ${_date(_nextDue!)} wieder.', 'Returns on ${_date(_nextDue!)}.'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _loading = true);
                    _load();
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(tr.t('Nächstes Puzzle', 'Next puzzle')),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
