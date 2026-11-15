import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'strength_view.dart';
import 'strings.dart';

/// Seite „Spielstärke“ in den Einstellungen.
class StrengthPage extends StatefulWidget {
  const StrengthPage({super.key});

  @override
  State<StrengthPage> createState() => _StrengthPageState();
}

class _StrengthPageState extends State<StrengthPage> {
  bool _busy = false;
  String? _message;

  Future<void> _refresh({bool online = true}) async {
    final scope = AppScope.of(context);
    final tr = Tr.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    final s = await scope.strength.refresh(online: online);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = tr.t('Neu geschätzt: ca. ${s.elo} Elo.', 'Estimated again: about ${s.elo} Elo.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final scope = AppScope.of(context);
    final settings = scope.settings;
    return Scaffold(
      appBar: AppBar(title: Text(tr.t('Spielstärke', 'Strength'))),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => StrengthView(
          strength: settings.strength,
          level: settings.level,
          manual: settings.strengthManual,
          manualElo: settings.strengthManualElo,
          toAi: settings.strengthToAi,
          busy: _busy,
          message: _message,
          onMode: (m) async {
            settings.strengthManual = m;
            await scope.strength.refresh();
          },
          onManualElo: (v) async {
            settings.strengthManualElo = v;
            await scope.strength.refresh();
          },
          onRefresh: _refresh,
          onToAi: (v) => settings.strengthToAi = v,
        ),
      ),
    );
  }
}
