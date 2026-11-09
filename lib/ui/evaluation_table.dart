import 'package:flutter/material.dart';

import '../analysis/analysis.dart';
import 'strings.dart';

/// Gewinnchance je Zug als Tabelle: bester Zug zuerst, der Rest nach Gewinnchance absteigend.
///
/// Gemeinsame Darstellung für Puzzle, Besprechung und Partieansicht (und inhaltlich wie im Telegram-Bot):
/// Die Differenz wird aus den angezeigten, gerundeten Werten gebildet, sonst passen Zahl und Differenz nicht zusammen.
/// [ownSan] ist dein Zug mit Zugnummer, [ownWin] seine Gewinnchance.
class EvaluationTable extends StatelessWidget {
  const EvaluationTable({super.key, required this.moment, required this.tr, this.ownSan, this.ownWin});

  final Moment moment;
  final Tr tr;
  final String? ownSan;
  final double? ownWin;

  static const _green = Color(0xFF4CAF50), _red = Color(0xFFD64545), _grey = Color(0xFF9E9E9E);

  @override
  Widget build(BuildContext context) {
    final m = moment;
    final theme = Theme.of(context);
    String diff(double v) {
      final d = v.round() - m.winBefore.round();
      return d == 0 ? '±0 %' : '${d > 0 ? '+' : '−'}${d.abs()} %';
    }

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
          SizedBox(width: 64, child: Text(diff(win), textAlign: TextAlign.end)),
        ],
      ),
    );
    // Dein Zug nicht doppelt anzeigen, wenn er schon als bester Zug oder Partiezug in der Tabelle steht.
    final own = ownSan != null && ownWin != null && ownSan != m.best && ownSan != m.played ? ownSan : null;
    final alts = m.alternatives.where(
      (a) => a.uci != m.bestUci && m.winBefore - a.win < 5 && (own == null || a.san != own),
    );
    final others = <(Color, String, double)>[
      for (final a in alts)
        (_green.withAlpha(150), tr.t('Auch gut ${tr.san(a.san)}', 'Also good ${tr.san(a.san)}'), a.win),
      if (own != null) (_grey, tr.t('Dein Zug ${tr.san(own)}', 'Your move ${tr.san(own)}'), ownWin!),
      (
        _red,
        tr.t('Partiezug ${tr.san(m.played)}${m.mistake.glyph}', 'Game move ${tr.san(m.played)}${m.mistake.glyph}'),
        m.winAfter,
      ),
    ]..sort((x, y) => y.$3.compareTo(x.$3));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text(
            tr.t('Gewinnchance', 'Winning chance'),
            style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        row(_green, tr.t('Bester Zug ${tr.san(m.best)}', 'Best move ${tr.san(m.best)}'), m.winBefore, bold: true),
        for (final r in others) row(r.$1, r.$2, r.$3),
      ],
    );
  }
}
