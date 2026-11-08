/// Farben für Züge, farbig markierter Text und ein Brett zum Durchklicken der Varianten.
library;

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../analysis/chess_utils.dart';
import '../coach/move_facts.dart' show lineSans;
import 'strings.dart';

/// Partiezug rot, bester Zug grün, dein Versuch grau.
const playedColor = Color(0xFFD64545);
const bestColor = Color(0xFF15781B);
const attemptColor = Color(0xFF6E6E6E);

Arrow arrow(String uci, Color color) {
  final m = Move.parse(uci) as NormalMove;
  return Arrow(color: color.withValues(alpha: 0.8), orig: m.from, dest: m.to);
}

/// Text mit Markierungen aus CoachTexts.mark: «p:…» rot, «b:…» grün, «a:…» grau, «o:…» fett.
class MoveText extends StatelessWidget {
  const MoveText(this.text, {super.key, this.style, this.maxLines});

  final String text;
  final TextStyle? style;
  final int? maxLines;

  static final _re = RegExp(r'«([pbao]):([^»]*)»');

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final spans = <InlineSpan>[];
    var pos = 0;
    for (final m in _re.allMatches(text)) {
      if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
      final color = switch (m[1]) {
        'p' => playedColor,
        'b' => bestColor,
        'a' => attemptColor,
        _ => null,
      };
      spans.add(
        TextSpan(
          text: m[2],
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      );
      pos = m.end;
    }
    if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

/// Erklärungsabschnitt mit farbigem Rand: Überschrift und markierter Text.
class ColoredSection extends StatelessWidget {
  const ColoredSection({super.key, required this.color, required this.title, required this.text});

  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoveText(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          MoveText(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Eine Variante zum Durchklicken: Name, Farbe, Züge (Standard-UCI ab der Ausgangsstellung), Einschätzung.
class LineOption {
  const LineOption({required this.label, required this.color, required this.moves, this.win});

  final String label;
  final Color color;
  final List<String> moves;

  /// Gewinnchance nach dem ersten Zug aus Sicht des Nutzers.
  final double? win;
}

/// Brett mit Auswahl der Variante und Vor/Zurück. Schritt 0 zeigt die Ausgangsstellung mit allen Pfeilen.
class LineViewer extends StatefulWidget {
  const LineViewer({
    super.key,
    required this.fen,
    required this.orientation,
    required this.lastMove,
    required this.options,
    this.initial = 0,
  });

  final String fen;
  final Side orientation;
  final String? lastMove;
  final List<LineOption> options;
  final int initial;

  @override
  State<LineViewer> createState() => _LineViewerState();
}

class _LineViewerState extends State<LineViewer> {
  late int _line = widget.initial.clamp(0, widget.options.length - 1);
  int _step = 0;

  LineOption get _opt => widget.options[_line];
  Position get _start => Chess.fromSetup(Setup.parseFen(widget.fen));

  /// Legale Züge der gewählten Variante mit den Stellungen danach.
  List<(NormalMove, Position)> get _played {
    final out = <(NormalMove, Position)>[];
    var p = _start;
    for (final uci in _opt.moves) {
      final m = legalUci(p, uci);
      if (m == null) break;
      p = p.play(m);
      out.add((m, p));
    }
    return out;
  }

  @override
  void didUpdateWidget(LineViewer old) {
    super.didUpdateWidget(old);
    if (old.options.length != widget.options.length || old.fen != widget.fen) {
      _line = widget.initial.clamp(0, widget.options.length - 1);
      _step = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final played = _played;
    final step = _step.clamp(0, played.length);
    final pos = step == 0 ? _start : played[step - 1].$2;
    final Set<Shape> shapes = step == 0
        ? {
            for (final o in widget.options.reversed)
              if (o.moves.isNotEmpty) arrow(o.moves.first, o.color),
          }
        : {arrow(_opt.moves[step - 1], _opt.color)};
    final sans = lineSans(_start, _opt.moves);
    final mat = step == 0 ? 0 : material(pos, _start.turn) - material(_start, _start.turn);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -100) _go(step + 1, played.length);
            if (v > 100) _go(step - 1, played.length);
          },
          child: StaticChessboard(
            size: width,
            orientation: widget.orientation,
            fen: pos.fen,
            lastMove: step == 0 ? (widget.lastMove == null ? null : Move.parse(widget.lastMove!)) : played[step - 1].$1,
            shapes: shapes,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < widget.options.length; i++)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: widget.options[i].color, radius: 6),
                  label: Text(widget.options[i].label),
                  selected: i == _line,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    _line = i;
                    _step = 1;
                  }),
                ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.first_page), onPressed: step > 0 ? () => _go(0, played.length) : null),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: step > 0 ? () => _go(step - 1, played.length) : null,
            ),
            Expanded(
              child: Text(
                step == 0
                    ? tr.t(
                        'Ausgangsstellung – blättere durch die Variante',
                        'Starting position – step through the line',
                      )
                    : tr.t('Zug $step von ${played.length}', 'Move $step of ${played.length}'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: step < played.length ? () => _go(step + 1, played.length) : null,
            ),
            IconButton(
              icon: const Icon(Icons.last_page),
              onPressed: step < played.length ? () => _go(played.length, played.length) : null,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 2,
            runSpacing: 2,
            children: [
              for (var i = 0; i < sans.length; i++)
                InkWell(
                  onTap: () => setState(() => _step = i + 1),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: i + 1 == step ? _opt.color.withValues(alpha: 0.2) : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tr.san(sans[i]),
                      style: TextStyle(
                        fontWeight: i == 0 || i + 1 == step ? FontWeight.bold : FontWeight.normal,
                        color: i == 0 ? _opt.color : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (step > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              [
                if (mat != 0)
                  tr.t(
                    'Material bisher: ${mat > 0 ? '+' : ''}$mat für dich',
                    'Material so far: ${mat > 0 ? '+' : ''}$mat for you',
                  ),
                if (step == played.length && _opt.win != null)
                  tr.t(
                    'Erwartung: ${_opt.win!.round()} % Gewinnchance',
                    'Expected: ${_opt.win!.round()} % winning chance',
                  ),
                if (pos.isCheckmate) tr.t('Schachmatt!', 'Checkmate!'),
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  void _go(int step, int max) => setState(() => _step = step.clamp(0, max));
}
