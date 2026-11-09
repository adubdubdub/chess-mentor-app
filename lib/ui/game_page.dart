import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../analysis/analysis.dart';
import '../coach/coach_texts.dart';
import '../data/game_store.dart';
import '../engine/analysis_service.dart';
import 'app_scope.dart';
import 'evaluation_table.dart';
import 'home_page.dart' show askColor;
import 'line_viewer.dart';
import 'mistake_icons.dart';
import 'review_page.dart';
import 'strings.dart';

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

  /// Ergebnis aus Sicht des Nutzers: „gewonnen (1-0)“, „verloren (0-1)“, „remis (½-½)“.
  String _outcome(Tr tr, Side color, String result) => switch (result) {
    '1-0' when color == Side.white => tr.t('gewonnen (1-0)', 'won (1-0)'),
    '0-1' when color == Side.black => tr.t('gewonnen (0-1)', 'won (0-1)'),
    '1-0' || '0-1' => tr.t('verloren ($result)', 'lost ($result)'),
    '1/2-1/2' => tr.t('remis', 'draw'),
    _ => result,
  };

  /// Hinweis zur Bedienung des Verlaufs verschwindet nach dem ersten Antippen oder Zoomen.
  void _chartUsed() {
    final settings = AppScope.of(context).settings;
    if (!settings.chartHintSeen) setState(() => settings.chartHintSeen = true);
  }

  Set<String> get _filter => AppScope.of(context).settings.momentFilter;

  /// Markierte Züge nach Filter: besprochene oder Züge der gewählten Einstufungen.
  List<Moment> _filtered(GameAnalysis a) {
    final f = _filter;
    final reviewed = {for (final m in a.moments) m.ply};
    return [
      for (final m in a.flagged)
        if ((f.contains('review') && reviewed.contains(m.ply)) || f.contains(m.mistake.name)) m,
    ];
  }

  Widget _filterChip(String key, String label, MistakeClass? mistake) => FilterChip(
    label: Text(label),
    avatar: mistake == null ? null : MistakeBadge(mistake, size: 18),
    showCheckmark: false,
    selected: _filter.contains(key),
    visualDensity: VisualDensity.compact,
    onSelected: (on) {
      final f = {..._filter};
      on ? f.add(key) : f.remove(key);
      setState(() => AppScope.of(context).settings.momentFilter = f);
    },
  );

  void _openMoment(Moment m, Side color) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MomentPage(moment: m, orientation: color),
    ),
  );

  /// Kurzinfo zu einem Punkt im Verlauf, mit Sprung zum Moment.
  void _showMoment(Moment m, GameAnalysis a) {
    final tr = Tr.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 6),
              Text(
                '${tr.mistake(m.mistake)} · ${tr.phase(m.phase)}'
                '${a.moments.any((k) => k.ply == m.ply) ? ' · 🎓' : ''}',
                style: theme.textTheme.bodySmall,
              ),
              EvaluationTable(moment: m, tr: tr),
              const SizedBox(height: 10),
              MoveText(CoachTexts(tr).shortWhy(m)),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openMoment(m, a.color);
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(tr.t('Zum Moment', 'Open moment')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final g = _game;
    return Scaffold(
      appBar: AppBar(
        title: Text(g == null ? '' : '${g.white} – ${g.black}', overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _delete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(tr.delete)),
              ),
              if (g?.analysis case final a?)
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    '${tr.engine}: ${a.engine}, ${tr.depth} ${a.depth} · ${tr.puzzles}: ${a.puzzles.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ],
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('${a.accuracy ?? '–'} %', style: theme.textTheme.displaySmall),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr.accuracy, style: theme.textTheme.titleSmall),
                  Text(
                    '${a.color == Side.white ? tr.white : tr.black} · ${_outcome(tr, a.color, g.result)}'
                    '${a.opening.isEmpty ? '' : ' · ${a.opening}'}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Fehlerzahlen kompakt als Untertitel
        Text.rich(
          TextSpan(
            style: theme.textTheme.bodyMedium,
            children: [
              for (final (i, c) in MistakeClass.values.indexed) ...[
                if (i > 0) const TextSpan(text: '   '),
                mistakeSpan(c),
                TextSpan(text: ' ${tr.mistakeCount(c, a.counts[c] ?? 0)}'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(CoachTexts(tr).summaryShort(a), style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 134,
          child: EvalChart(
            evals: a.evals,
            moments: a.flagged,
            color: a.color,
            onTap: (m) => _showMoment(m, a),
            onInteract: _chartUsed,
          ),
        ),
        if (!AppScope.of(context).settings.chartHintSeen)
          Text(
            tr.t(
              'Tipp: Symbol antippen für Details, mit zwei Fingern zoomen.',
              'Tip: tap a symbol for details, pinch to zoom.',
            ),
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReviewPage(analysis: a))),
          icon: const Icon(Icons.school),
          label: Text(
            a.moments.isEmpty
                ? tr.t('Abschluss ansehen', 'View wrap-up')
                : tr.t('Besprechung starten · ${a.moments.length}', 'Start review · ${a.moments.length}'),
          ),
        ),
        const SizedBox(height: 16),
        Text(tr.t('Markierte Züge', 'Marked moves'), style: theme.textTheme.titleMedium),
        if (a.flagged.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr.noMistakes)),
        if (a.flagged.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              children: [
                _filterChip('review', '🎓 ${a.moments.length}', null),
                for (final c in MistakeClass.values)
                  if ((a.counts[c] ?? 0) > 0) _filterChip(c.name, '${a.counts[c]}', c),
              ],
            ),
          ),
        for (final m in _filtered(a))
          ListTile(
            contentPadding: EdgeInsets.zero,
            horizontalTitleGap: 10,
            leading: MistakeBadge(m.mistake, size: 24),
            title: MoveText(
              '${CoachTexts.mark('p', '${tr.san(m.played)}${m.mistake.glyph}')} → '
              '${CoachTexts.mark('b', tr.san(m.best))}'
              '${_filter.length > 1 && a.moments.any((k) => k.ply == m.ply) ? '  🎓' : ''}',
            ),
            subtitle: MoveText(CoachTexts(tr).shortWhy(m), maxLines: 2),
            onTap: () => _openMoment(m, a.color),
          ),
        if (a.flagged.isNotEmpty && _filtered(a).isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(tr.t('Kein Zug passt zum Filter.', 'No move matches the filter.')),
          ),
      ],
    );
  }
}

/// Verlauf der Gewinnchance aus Sicht des Nutzers, Fehler als Symbole.
///
/// Zwei Finger zoomen waagerecht, ein Finger verschiebt im gezoomten Zustand, ↺ setzt zurück.
class EvalChart extends StatefulWidget {
  const EvalChart({
    super.key,
    required this.evals,
    required this.moments,
    required this.color,
    this.onTap,
    this.onInteract,
  });

  final List<double> evals;
  final List<Moment> moments;
  final Side color;

  /// Antippen eines markierten Punkts (der nächste im Umkreis von 28 px).
  final void Function(Moment)? onTap;

  /// Erste Bedienung (Antippen oder Zoomen), z. B. um einen Hinweis auszublenden.
  final VoidCallback? onInteract;

  @override
  State<EvalChart> createState() => _EvalChartState();
}

class _EvalChartState extends State<EvalChart> {
  /// Sichtbarer Ausschnitt als Anteil der ganzen Partie (0 = Start, 1 = Ende).
  double _lo = 0, _hi = 1;

  // Zwei-Finger-Zoom: aktuelle Finger und Ausgangslage
  final _pointers = <int, Offset>{};
  double? _startDist, _startLo, _startSpan, _startFocal;

  bool get _zoomed => _hi - _lo < 0.999;

  /// Kleinster Ausschnitt: etwa 6 Züge, höchstens die ganze Partie.
  double get _minSpan => (12 / (widget.evals.length - 1)).clamp(0.02, 1.0);

  void _setView(double lo, double span) {
    span = span.clamp(_minSpan, 1.0);
    lo = lo.clamp(0.0, 1.0 - span);
    setState(() {
      _lo = lo;
      _hi = lo + span;
    });
  }

  void _pinchStart(double width) {
    final p = _pointers.values.toList();
    _startDist = (p[0].dx - p[1].dx).abs().clamp(20.0, double.infinity);
    _startLo = _lo;
    _startSpan = _hi - _lo;
    _startFocal = ((p[0].dx + p[1].dx) / 2 - _EvalPainter._left) / width;
  }

  void _pinchUpdate(double width) {
    final p = _pointers.values.toList();
    final dist = (p[0].dx - p[1].dx).abs().clamp(20.0, double.infinity);
    final focal = ((p[0].dx + p[1].dx) / 2 - _EvalPainter._left) / width;
    final span = (_startSpan! * _startDist! / dist).clamp(_minSpan, 1.0);
    // Der Punkt unter den Fingern bleibt unter den Fingern
    final anchor = _startLo! + _startFocal! * _startSpan!;
    _setView(anchor - focal * span, span);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final values = [for (final e in widget.evals) widget.color == Side.white ? e : 100 - e];
      final w = box.maxWidth - _EvalPainter._left, h = box.maxHeight - _EvalPainter._bottom;
      final span = _hi - _lo;
      Offset at(int i) =>
          Offset(_EvalPainter._left + w * (i / (values.length - 1) - _lo) / span, h * (1 - values[i] / 100));
      return Stack(
        children: [
          Listener(
            onPointerDown: (e) {
              _pointers[e.pointer] = e.localPosition;
              if (_pointers.length == 2) {
                _pinchStart(w);
                widget.onInteract?.call();
              }
            },
            onPointerMove: (e) {
              if (!_pointers.containsKey(e.pointer)) return;
              _pointers[e.pointer] = e.localPosition;
              if (_pointers.length == 2 && _startDist != null) _pinchUpdate(w);
            },
            onPointerUp: (e) => _pointers.remove(e.pointer),
            onPointerCancel: (e) => _pointers.remove(e.pointer),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Verschieben nur im Zoom, sonst bleibt das Wischen frei für die Seite
              onHorizontalDragUpdate: _zoomed && values.length >= 2
                  ? (d) {
                      if (_pointers.length < 2) _setView(_lo - d.delta.dx / w * span, span);
                    }
                  : null,
              onTapUp: widget.onTap == null || values.length < 2
                  ? null
                  : (d) {
                      Moment? best;
                      var dist = 28.0;
                      for (final m in widget.moments) {
                        final i = m.ply + 1;
                        if (i >= values.length) continue;
                        final dd = (at(i) - d.localPosition).distance;
                        if (dd < dist) (best, dist) = (m, dd);
                      }
                      if (best != null) {
                        widget.onInteract?.call();
                        widget.onTap!(best);
                      }
                    },
              child: CustomPaint(
                painter: _EvalPainter(
                  values,
                  {for (final m in widget.moments) m.ply + 1: m.mistake},
                  Theme.of(context).colorScheme,
                  _lo,
                  _hi,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          if (_zoomed)
            Positioned(
              right: 0,
              top: 0,
              child: IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: Tr.of(context).t('Ganze Partie zeigen', 'Show whole game'),
                icon: const Icon(Icons.zoom_out_map),
                onPressed: () => _setView(0, 1),
              ),
            ),
        ],
      );
    },
  );
}

class _EvalPainter extends CustomPainter {
  _EvalPainter(this.values, this.marks, this.scheme, this.lo, this.hi);

  final List<double> values;
  final Map<int, MistakeClass> marks;
  final ColorScheme scheme;

  /// Sichtbarer Ausschnitt (Anteil der Partie).
  final double lo, hi;

  static const _left = 30.0, _bottom = 14.0;

  void _label(Canvas canvas, String text, Offset at, {bool right = false, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = right ? at.dx - tp.width : (center ? at.dx - tp.width / 2 : at.dx);
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size full) {
    if (values.length < 2) return;
    final size = Size(full.width - _left, full.height - _bottom);
    final last = values.length - 1;
    double xOf(num i) => size.width * (i / last - lo) / (hi - lo);
    Offset at(int i) => Offset(xOf(i), size.height * (1 - values[i] / 100));

    // Achsen: links Gewinnchance in %, unten Zugnummern passend zum Ausschnitt
    for (final (v, t) in [(100, '100 %'), (50, '50 %'), (0, '0 %')]) {
      _label(canvas, t, Offset(_left - 4, size.height * (1 - v / 100)), right: true);
    }
    final visibleMoves = (hi - lo) * last / 2;
    final step = [1, 2, 5, 10, 20, 50].firstWhere((s) => visibleMoves / s <= 8, orElse: () => 100);
    final ticks = [
      for (var n = step; 2 * n < last; n += step)
        if (xOf(2 * n) >= 0 && xOf(2 * n) <= size.width) n,
    ];
    for (final n in ticks) {
      _label(canvas, '$n', Offset(_left + xOf(2 * n), full.height - _bottom / 2), center: true);
    }

    canvas.save();
    canvas.translate(_left, 0);
    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surfaceContainerHighest);
    canvas.clipRect(Rect.fromLTWH(-8, -8, size.width + 16, size.height + 16));
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()..color = scheme.outlineVariant,
    );
    for (final n in ticks) {
      canvas.drawLine(
        Offset(xOf(2 * n), 0),
        Offset(xOf(2 * n), size.height),
        Paint()..color = scheme.outlineVariant.withValues(alpha: 0.4),
      );
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final path = Path()..moveTo(xOf(0), size.height);
    for (var i = 0; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    path
      ..lineTo(xOf(last), size.height)
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
    canvas.restore();
    // Markierte Züge mit dem Symbol ihrer Einstufung (nur im sichtbaren Ausschnitt)
    marks.forEach((i, c) {
      if (i >= values.length) return;
      final p = at(i);
      if (p.dx < -4 || p.dx > size.width + 4) return;
      final icon = classIcons[c]!;
      canvas.drawCircle(p, 6.5, Paint()..color = scheme.surface);
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(fontSize: 14, fontFamily: icon.fontFamily, package: icon.fontPackage, color: classColors[c]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    });
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EvalPainter old) => old.values != values || old.marks != marks || old.lo != lo || old.hi != hi;
}

/// Ein Schlüsselmoment: Brett zum Durchklicken der Varianten, Erklärung in Farben, Kandidatenzüge.
class MomentPage extends StatelessWidget {
  const MomentPage({super.key, required this.moment, required this.orientation});

  final Moment moment;
  final Side orientation;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final m = moment;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            MistakeBadge(m.mistake),
            const SizedBox(width: 8),
            Expanded(child: Text('${tr.san(m.played)}${m.mistake.glyph} · ${tr.mistake(m.mistake)}')),
          ],
        ),
      ),
      body: ListView(
        children: [
          LineViewer(
            fen: m.fen,
            orientation: orientation,
            lastMove: m.lastMove,
            options: lineOptions(tr, m),
            initial: 1,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [...explanationSections(CoachTexts(tr), m)],
            ),
          ),
        ],
      ),
    );
  }
}
