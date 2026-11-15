import 'package:flutter/material.dart';

import 'strings.dart';

typedef AccuracyPoint = ({DateTime at, int accuracy, int gameId, String title});

/// Genauigkeit je Partie als Linie mit Achsen: Tippen oder Ziehen wählt eine Partie, darunter stehen Datum, Wert und
/// Partie mit Sprung dorthin. Dünne Linie, deutliche Punkte, zurückhaltendes Raster, Text in Textfarbe.
class AccuracyChart extends StatefulWidget {
  const AccuracyChart({super.key, required this.series, this.onOpen, this.height = 190});

  /// Älteste Partie zuerst.
  final List<AccuracyPoint> series;
  final void Function(int gameId)? onOpen;
  final double height;

  @override
  State<AccuracyChart> createState() => _AccuracyChartState();
}

class _AccuracyChartState extends State<AccuracyChart> {
  int? _selected;

  static const _left = 38.0, _right = 10.0, _top = 10.0, _bottom = 24.0;

  /// Y-Bereich in 10er-Schritten um die Werte, höchstens 0 bis 100.
  (double, double) _range() {
    final values = [for (final p in widget.series) p.accuracy.toDouble()];
    final lo = values.reduce((a, b) => a < b ? a : b), hi = values.reduce((a, b) => a > b ? a : b);
    final min = ((lo - 4) / 10).floor() * 10.0, max = ((hi + 4) / 10).ceil() * 10.0;
    return (min.clamp(0, 90).toDouble(), max.clamp(10, 100).toDouble());
  }

  void _pick(Offset local, double width) {
    final n = widget.series.length;
    if (n == 0) return;
    final plot = width - _left - _right;
    final i = n == 1 ? 0 : (((local.dx - _left) / plot) * (n - 1)).round().clamp(0, n - 1);
    setState(() => _selected = i);
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final s = widget.series;
    final sel = _selected == null ? null : s[_selected!];
    final avg = s.isEmpty ? 0.0 : s.fold<double>(0, (a, p) => a + p.accuracy) / s.length;
    final (lo, hi) = s.isEmpty ? (0.0, 100.0) : _range();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: tr.t(
            'Genauigkeit je Partie, ${s.length} Partien, Durchschnitt ${avg.round()} Prozent',
            'Accuracy per game, ${s.length} games, average ${avg.round()} percent',
          ),
          child: LayoutBuilder(
            builder: (context, c) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _pick(d.localPosition, c.maxWidth),
              onHorizontalDragStart: (d) => _pick(d.localPosition, c.maxWidth),
              onHorizontalDragUpdate: (d) => _pick(d.localPosition, c.maxWidth),
              child: SizedBox(
                height: widget.height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ChartPainter(
                    values: [for (final p in s) p.accuracy.toDouble()],
                    dates: [for (final p in s) _date(p.at)],
                    lo: lo,
                    hi: hi,
                    avg: avg,
                    selected: _selected,
                    line: theme.colorScheme.primary,
                    surface: theme.colorScheme.surface,
                    grid: theme.colorScheme.outlineVariant,
                    ink: theme.colorScheme.onSurfaceVariant,
                    inkStrong: theme.colorScheme.onSurface,
                    avgLabel: tr.t('Ø ${avg.round()} %', 'avg ${avg.round()} %'),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (sel == null)
          Text(
            tr.t(
              'Tippe oder wische über das Diagramm, um eine Partie zu wählen.',
              'Tap or swipe over the chart to pick a game.',
            ),
            style: theme.textTheme.bodySmall,
          )
        else
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_date(sel.at)} · ${sel.accuracy} % · ${sel.title}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.onOpen != null)
                TextButton(
                  onPressed: () => widget.onOpen!(sel.gameId),
                  child: Text(tr.t('Partie öffnen', 'Open game')),
                ),
            ],
          ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.values,
    required this.dates,
    required this.lo,
    required this.hi,
    required this.avg,
    required this.selected,
    required this.line,
    required this.surface,
    required this.grid,
    required this.ink,
    required this.inkStrong,
    required this.avgLabel,
  });

  final List<double> values;
  final List<String> dates;
  final double lo, hi, avg;
  final int? selected;
  final Color line, surface, grid, ink, inkStrong;
  final String avgLabel;

  TextPainter _text(String t, Color c, {double size = 11, FontWeight? weight}) => TextPainter(
    text: TextSpan(
      text: t,
      style: TextStyle(color: c, fontSize: size, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const left = _AccuracyChartState._left, right = _AccuracyChartState._right;
    const top = _AccuracyChartState._top, bottom = _AccuracyChartState._bottom;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    double y(double v) => plot.bottom - plot.height * (v - lo) / (hi - lo);
    double x(int i) => values.length == 1 ? plot.center.dx : plot.left + plot.width * i / (values.length - 1);

    // Raster und Y-Beschriftung (alle 10, bei großem Bereich alle 20)
    final step = (hi - lo) > 40 ? 20 : 10;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var v = lo; v <= hi + 0.1; v += step) {
      canvas.drawLine(Offset(plot.left, y(v)), Offset(plot.right, y(v)), gridPaint);
      final t = _text('${v.round()}', ink);
      t.paint(canvas, Offset(plot.left - 6 - t.width, y(v) - t.height / 2));
    }
    final unit = _text('%', ink);
    unit.paint(canvas, Offset(0, 0));

    // Durchschnitt: gestrichelt, einmal direkt beschriftet
    final avgY = y(avg);
    final dash = Paint()
      ..color = ink
      ..strokeWidth = 1;
    for (var dx = plot.left; dx < plot.right; dx += 8) {
      canvas.drawLine(Offset(dx, avgY), Offset((dx + 4).clamp(plot.left, plot.right), avgY), dash);
    }
    final al = _text(avgLabel, ink, size: 10);
    al.paint(canvas, Offset(plot.right - al.width, avgY - al.height - 1));

    // X-Beschriftung: erste, letzte und bei genug Partien die mittlere
    final labelIdx = {0, values.length - 1, if (values.length >= 5) values.length ~/ 2};
    for (final i in labelIdx) {
      final t = _text(dates[i], ink);
      final dx = (x(i) - t.width / 2).clamp(0.0, size.width - t.width);
      t.paint(canvas, Offset(dx, plot.bottom + 6));
    }

    // Auswahl: senkrechte Linie
    if (selected != null) {
      canvas.drawLine(
        Offset(x(selected!), plot.top),
        Offset(x(selected!), plot.bottom),
        Paint()
          ..color = inkStrong.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
    }

    // Linie, 2 px
    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    // Punkte: 8 px, Ring in Flächenfarbe; gewählter Punkt größer
    for (var i = 0; i < values.length; i++) {
      final r = i == selected ? 6.0 : 4.0;
      canvas.drawCircle(Offset(x(i), y(values[i])), r + 2, Paint()..color = surface);
      canvas.drawCircle(Offset(x(i), y(values[i])), r, Paint()..color = line);
    }
    if (selected != null) {
      final v = _text('${values[selected!].round()}', inkStrong, size: 12, weight: FontWeight.w700);
      final px = x(selected!), py = y(values[selected!]);
      final above = py - v.height - 12 >= plot.top - 2;
      v.paint(
        canvas,
        Offset((px - v.width / 2).clamp(plot.left, plot.right - v.width), above ? py - v.height - 10 : py + 10),
      );
    }
  }

  @override
  bool shouldRepaint(_ChartPainter o) =>
      o.values != values || o.selected != selected || o.lo != lo || o.hi != hi || o.line != line || o.avg != avg;
}
