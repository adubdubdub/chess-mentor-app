import 'package:flutter/material.dart';

import 'strings.dart';

/// Kleines Zeichen „✨ KI“ hinter Texten, die eine KI formuliert hat. Antippen erklärt, was das bedeutet.
class AiBadge extends StatelessWidget {
  const AiBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    return Tooltip(
      message: tr.t('Von einer KI formuliert', 'Written by an AI'),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showAiInfo(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '✨ ${tr.t('KI', 'AI')}',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
          ),
        ),
      ),
    );
  }
}

/// Text mit angehängtem KI-Zeichen, wenn [ai] gesetzt ist.
Widget aiAwareText(BuildContext context, String text, {required bool ai, TextStyle? style}) {
  if (!ai) return Text(text, style: style);
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(text: '$text '),
        const WidgetSpan(alignment: PlaceholderAlignment.middle, child: AiBadge()),
      ],
    ),
    style: style,
  );
}

/// Erklärt, was „KI“ hier heißt und was geprüft wird.
Future<void> showAiInfo(BuildContext context) {
  final tr = Tr.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('✨ ${tr.t('Von einer KI formuliert', 'Written by an AI')}'),
      content: Text(
        tr.t(
          'Dieser Text wurde von einem Sprachmodell geschrieben. Die Analyse selbst macht Stockfish auf deinem Handy: '
              'Alle Zahlen, Bewertungen und Züge stammen von der Engine. Die App prüft, dass der Text nur Züge und Zahlen '
              'aus dieser Analyse nennt, sonst zeigt sie den eingebauten Text. Ein Sprachmodell kann trotzdem '
              'ungenau formulieren; im Zweifel zählt die Engine-Analyse.',
          'This text was written by a language model. The analysis itself is done by Stockfish on your phone: all '
              'numbers, evaluations and moves come from the engine. The app checks that the text only mentions moves and '
              'numbers from that analysis, otherwise it shows the built-in text. A language model can still word things '
              'imprecisely; when in doubt, the engine analysis counts.',
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr.ok))],
    ),
  );
}
