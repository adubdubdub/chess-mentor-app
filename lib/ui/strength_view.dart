import 'package:flutter/material.dart';

import '../mentor/level_texts.dart';
import '../mentor/strength.dart';
import 'strings.dart';

/// Einstellungen zur Spielstärke: Schätzung mit Quelle und Sicherheit, automatisch oder manuell, Weitergabe an die KI.
class StrengthView extends StatefulWidget {
  const StrengthView({
    super.key,
    required this.strength,
    required this.level,
    required this.manual,
    required this.manualElo,
    required this.toAi,
    this.busy = false,
    this.message,
    this.onMode,
    this.onManualElo,
    this.onRefresh,
    this.onToAi,
  });

  final Strength? strength;
  final Level level;
  final bool manual;
  final int manualElo;
  final bool toAi;
  final bool busy;
  final String? message;
  final void Function(bool manual)? onMode;
  final void Function(int elo)? onManualElo;
  final VoidCallback? onRefresh;
  final void Function(bool value)? onToAi;

  @override
  State<StrengthView> createState() => _StrengthViewState();
}

class _StrengthViewState extends State<StrengthView> {
  late final TextEditingController _controller = TextEditingController(text: '${widget.manualElo}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final s = widget.strength;
    final elo = widget.manual ? widget.manualElo : (s?.elo ?? defaultElo);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.outlineVariant)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr.t('Geschätzte Spielstärke', 'Estimated strength'), style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text('ca. ${roundElo(elo)} Elo', style: theme.textTheme.headlineSmall),
                Text('${tr.levelName(widget.level)} (${tr.levelRange(widget.level)})', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  widget.manual
                      ? tr.sourceName(StrengthSource.manual)
                      : s == null
                      ? tr.sourceName(StrengthSource.initial)
                      : '${tr.sourceName(s.source)} · ${tr.confidenceName(s.confidence)}'
                            '${s.games > 0 ? ' · ${tr.t('${s.games} Partien', '${s.games} games')}' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tr.t(
            'Die Stärke bestimmt, wie die KI formuliert, welche Hinweise die Info-Blätter geben und welche Themen und Ziele '
                'der Wochenfokus vorschlägt. Online-Wertungen von Lichess und Chess.com zählen nach Partienzahl, vorläufige '
                'Wertungen wenig; dazu kommt eine grobe Schätzung aus deinen analysierten Partien.',
            'Your strength decides how the AI words things, which hints the info sheets give and which topics and goals the '
                'weekly focus suggests. Online ratings from Lichess and Chess.com count by number of games, provisional ones '
                'little; a rough estimate from your analysed games is added.',
          ),
        ),
        const SizedBox(height: 12),
        RadioGroup<bool>(
          groupValue: widget.manual,
          onChanged: (v) {
            if (v != null) widget.onMode?.call(v);
          },
          child: Column(
            children: [
              RadioListTile<bool>(value: false, title: Text(tr.t('Automatisch schätzen', 'Estimate automatically'))),
              RadioListTile<bool>(value: true, title: Text(tr.t('Selbst eintragen', 'Enter myself'))),
            ],
          ),
        ),
        if (widget.manual)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: tr.t('Elo (400 bis 2800)', 'Elo (400 to 2800)'), border: const OutlineInputBorder()),
                  onSubmitted: (v) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _submit, child: Text(tr.t('Speichern', 'Save'))),
            ],
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: widget.busy ? null : widget.onRefresh,
              icon: widget.busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(tr.t('Jetzt neu schätzen', 'Estimate again')),
            ),
          ),
        if (widget.message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(widget.message!)),
        const Divider(height: 32),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr.t('Spielstärke an die KI senden', 'Send strength to the AI')),
          subtitle: Text(
            tr.t(
              'An: gerundete Elo und Stufe, aus: nur die Stufe. Sonst geht nichts über dich an die KI.',
              'On: rounded Elo and level, off: level only. Nothing else about you goes to the AI.',
            ),
          ),
          value: widget.toAi,
          onChanged: widget.onToAi,
        ),
        const SizedBox(height: 8),
        Text(tr.t('Die Stufen', 'The levels'), style: theme.textTheme.titleSmall),
        for (final l in Level.values)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(l == widget.level ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 18),
            title: Text(tr.levelName(l)),
            trailing: Text(tr.levelRange(l)),
          ),
      ],
    );
  }

  void _submit() {
    final v = int.tryParse(_controller.text.trim());
    if (v == null) return;
    final clamped = v.clamp(400, 2800);
    _controller.text = '$clamped';
    widget.onManualElo?.call(clamped);
  }
}
