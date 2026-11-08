import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../analysis/analysis.dart';
import '../coach/coach_texts.dart';
import '../data/game_store.dart';
import '../engine/analysis_service.dart';
import 'app_scope.dart';
import 'home_page.dart' show askColor;
import 'review_page.dart';
import 'strings.dart';

const classColors = {
  MistakeClass.blunder: Color(0xFFD64545),
  MistakeClass.mistake: Color(0xFFE08A2E),
  MistakeClass.inaccuracy: Color(0xFF5C9AD6),
};

/// Überblick über eine analysierte Partie: Genauigkeit, Fehler, Verlauf, Schlüsselmomente.
class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.id});

  final int id;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  StoredGame? _game;
  AnalysisService? _service;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service?.removeListener(_reload);
    _service = AppScope.of(context).service..addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _service?.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final g = await AppScope.of(context).store.get(widget.id);
    if (mounted) setState(() => _game = g);
  }

  Future<void> _delete() async {
    await AppScope.of(context).store.delete(widget.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final g = _game;
    return Scaffold(
      appBar: AppBar(
        title: Text(g == null ? '' : '${g.white} – ${g.black}', overflow: TextOverflow.ellipsis),
        actions: [IconButton(icon: const Icon(Icons.delete_outline), tooltip: tr.delete, onPressed: _delete)],
      ),
      body: g == null ? const SizedBox() : _body(context, g),
    );
  }

  Widget _body(BuildContext context, StoredGame g) {
    final tr = Tr.of(context);
    final a = g.analysis;
    final p = _service?.progress[g.id];
    if (g.status == GameStatus.waitingColor) {
      return Center(
        child: FilledButton(
          onPressed: () async {
            final color = await askColor(context);
            if (color != null) await _service!.setColorAndAnalyse(g.id, color);
          },
          child: Text(tr.whichColor),
        ),
      );
    }
    if (a == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 220, child: LinearProgressIndicator(value: p == null ? null : p.$1 / p.$2)),
            const SizedBox(height: 12),
            Text(switch (g.status) {
              GameStatus.error => '${tr.error}\n${g.error ?? ''}',
              _ when p != null => tr.progress(p.$1, p.$2),
              _ => tr.queued,
            }, textAlign: TextAlign.center),
            if (g.status == GameStatus.error) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: () => _service!.enqueue(g.id), child: Text(tr.analyse)),
            ],
          ],
        ),
      );
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${tr.youPlayed(a.color == Side.white ? tr.white : tr.black)} · ${g.result}'
          '${a.opening.isEmpty ? '' : ' · ${a.opening}'}',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('${a.accuracy ?? '–'} %', style: theme.textTheme.displaySmall),
            const SizedBox(width: 12),
            Text(tr.accuracy, style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final c in MistakeClass.values)
              Chip(
                avatar: CircleAvatar(backgroundColor: classColors[c], radius: 6),
                label: Text(tr.mistakeCount(c, a.counts[c] ?? 0)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(tr.winChance, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        SizedBox(
          height: 120,
          child: EvalChart(evals: a.evals, moments: a.moments, color: a.color),
        ),
        const SizedBox(height: 12),
        Text(CoachTexts(tr).summary(a)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReviewPage(analysis: a))),
          icon: const Icon(Icons.school),
          label: Text(
            a.moments.isEmpty ? tr.t('Abschluss ansehen', 'View wrap-up') : tr.t('Besprechung starten', 'Start review'),
          ),
        ),
        const SizedBox(height: 16),
        Text(tr.keyMoments, style: theme.textTheme.titleMedium),
        if (a.moments.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr.noMistakes)),
        for (final m in a.moments)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: classColors[m.mistake], child: Text(m.mistake.glyph)),
            title: Text('${tr.san(m.played)}${m.mistake.glyph}'),
            subtitle: Text('${tr.better}: ${tr.san(m.best)} · ${tr.phase(m.phase)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MomentPage(moment: m))),
          ),
        const SizedBox(height: 8),
        Text(
          '${tr.puzzles}: ${a.puzzles.length} · ${tr.engine}: ${a.engine}, ${tr.depth} ${a.depth}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Verlauf der Gewinnchance aus Sicht des Nutzers, Fehler als Punkte.
class EvalChart extends StatelessWidget {
  const EvalChart({super.key, required this.evals, required this.moments, required this.color});

  final List<double> evals;
  final List<Moment> moments;
  final Side color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _EvalPainter(
      [for (final e in evals) color == Side.white ? e : 100 - e],
      {for (final m in moments) m.ply + 1: classColors[m.mistake]!},
      Theme.of(context).colorScheme,
    ),
    size: Size.infinite,
  );
}

class _EvalPainter extends CustomPainter {
  _EvalPainter(this.values, this.marks, this.scheme);

  final List<double> values;
  final Map<int, Color> marks;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    Offset at(int i) => Offset(size.width * i / (values.length - 1), size.height * (1 - values[i] / 100));
    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surfaceContainerHighest);
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()..color = scheme.outlineVariant,
    );
    final path = Path()..moveTo(0, size.height);
    for (var i = 0; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = scheme.primary.withValues(alpha: 0.35));
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = scheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    marks.forEach((i, c) {
      if (i < values.length) canvas.drawCircle(at(i), 4.5, Paint()..color = c);
    });
  }

  @override
  bool shouldRepaint(_EvalPainter old) => old.values != values || old.marks != marks;
}

/// Ein Schlüsselmoment mit den Engine-Fakten. Die sokratische Besprechung folgt in Phase 2.
class MomentPage extends StatelessWidget {
  const MomentPage({super.key, required this.moment});

  final Moment moment;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final m = moment;
    final pos = Chess.fromSetup(Setup.parseFen(m.fen));
    final played = Move.parse(m.playedUci) as NormalMove;
    final best = Move.parse(m.bestUci) as NormalMove;
    final width = MediaQuery.sizeOf(context).width;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${tr.san(m.played)}${m.mistake.glyph} · ${tr.mistake(m.mistake)}')),
      body: ListView(
        children: [
          StaticChessboard(
            size: width,
            orientation: pos.turn,
            fen: m.fen,
            lastMove: m.lastMove == null ? null : Move.parse(m.lastMove!),
            shapes: {
              Arrow(color: const Color(0xCCD64545), orig: played.from, dest: played.to),
              Arrow(color: const Color(0xCC15781B), orig: best.from, dest: best.to),
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(context, tr.played, tr.san(m.played), const Color(0xFFD64545)),
                _row(context, tr.better, tr.san(m.best), const Color(0xFF15781B)),
                const SizedBox(height: 8),
                Text('${tr.winChance}: ${m.winBefore.toStringAsFixed(0)} % → ${m.winAfter.toStringAsFixed(0)} %'),
                const SizedBox(height: 12),
                for (final motif in m.motifs) Text('• ${tr.motif(motif)}'),
                const SizedBox(height: 12),
                Text(tr.bestLine, style: theme.textTheme.titleSmall),
                Text(tr.san(m.bestLine)),
                const SizedBox(height: 8),
                Text(tr.replyLine, style: theme.textTheme.titleSmall),
                Text(tr.san(m.replyLine.isEmpty ? '–' : m.replyLine)),
                const SizedBox(height: 8),
                Text(tr.alternatives, style: theme.textTheme.titleSmall),
                for (final alt in m.alternatives) Text('${tr.san(alt.san)}  ${alt.win.toStringAsFixed(0)} %'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Text('$label: ', style: Theme.of(context).textTheme.titleSmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
