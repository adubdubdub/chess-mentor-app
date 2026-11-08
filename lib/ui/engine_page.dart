import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../analysis/analysis.dart';
import '../analysis/chess_utils.dart';
import '../engine/mobile_engine.dart';
import '../engine/net_manager.dart';
import 'app_scope.dart';
import 'strings.dart';

/// Opernpartie (Morphy 1858, gemeinfrei) für die Geschwindigkeitsmessung.
const _benchPgn =
    '1. e4 e5 2. Nf3 d6 3. d4 Bg4 4. dxe5 Bxf3 5. Qxf3 dxe5 6. Bc4 Nf6 7. Qb3 Qe7 8. Nc3 c6 '
    '9. Bg5 b5 10. Nxb5 cxb5 11. Bxb5+ Nbd7 12. O-O-O Rd8 13. Rxd7 Rxd7 14. Rd1 Qe6 15. Bxd7+ Nxd7 '
    '16. Qb8+ Nxb8 17. Rd8# 1-0';

/// Engine-Einstellungen: Netz wählen und laden, Suchtiefe, Threads, Geschwindigkeit messen.
class EnginePage extends StatefulWidget {
  const EnginePage({super.key});

  @override
  State<EnginePage> createState() => _EnginePageState();
}

class _EnginePageState extends State<EnginePage> {
  final _nets = NetManager();
  bool _installed = false;
  double? _download;
  String? _downloadError;
  bool _benching = false;
  final _bench = <String>[];

  @override
  void initState() {
    super.initState();
    _nets.installed().then((v) => setState(() => _installed = v));
  }

  Future<void> _startDownload() async {
    setState(() {
      _download = 0;
      _downloadError = null;
    });
    try {
      await _nets.download(onProgress: (r, t) => setState(() => _download = r / (t ?? NetManager.approxBytes)));
      _installed = true;
    } catch (e) {
      _downloadError = e.toString();
    }
    if (mounted) setState(() => _download = null);
  }

  Future<void> _deleteNet() async {
    final scope = AppScope.of(context);
    await scope.service.releaseEngine();
    await _nets.delete();
    scope.settings.net = EngineNet.light;
    setState(() => _installed = false);
  }

  /// Misst je verfügbarem Netz und Thread-Zahl die Zeit pro Stellung (20 Stellungen, Tiefe aus den Einstellungen).
  Future<void> _runBenchmark() async {
    final scope = AppScope.of(context);
    final tr = Tr.of(context);
    if (scope.service.busy) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr.busyHint)));
      return;
    }
    setState(() {
      _benching = true;
      _bench.clear();
    });
    await scope.service.releaseEngine();
    await WakelockPlus.enable();
    final game = ParsedGame.parse(_benchPgn)!;
    final uci = <List<String>>[];
    var pos = game.start;
    final moves = <String>[];
    for (final m in game.moves.take(20)) {
      uci.add([...moves]);
      moves.add(stdUci(pos, m));
      pos = pos.play(m);
    }
    final depth = scope.settings.depth;
    for (final net in [EngineNet.light, if (_installed) EngineNet.full]) {
      for (final threads in [1, 4]) {
        final engine = await MobileEngine.start(
          net,
          nnuePath: net == EngineNet.full ? (await _nets.file()).path : null,
          threads: threads,
        );
        await engine.newGame();
        final watch = Stopwatch()..start();
        for (final line in uci) {
          await engine.analyse(rootFen: game.start.fen, moves: line, depth: depth, multiPv: 3);
        }
        watch.stop();
        await engine.dispose();
        final perPos = watch.elapsedMilliseconds / 1000 / uci.length;
        if (!mounted) {
          await WakelockPlus.disable();
          return;
        }
        setState(
          () => _bench.add(
            '${net.name}, $threads Thread${threads > 1 ? 's' : ''}, ${tr.depth} $depth: '
            '${tr.perPosition(perPos)}',
          ),
        );
      }
    }
    await WakelockPlus.disable();
    if (mounted) setState(() => _benching = false);
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final settings = AppScope.of(context).settings;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr.t('Einstellungen', 'Settings'))),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr.net, style: theme.textTheme.titleMedium),
            RadioGroup<EngineNet>(
              groupValue: settings.net == EngineNet.full && _installed ? EngineNet.full : EngineNet.light,
              onChanged: (v) {
                if (v != null) settings.net = v;
              },
              child: Column(
                children: [
                  RadioListTile(value: EngineNet.light, title: Text(tr.netLight)),
                  RadioListTile(value: EngineNet.full, title: Text(tr.netFull), enabled: _installed),
                ],
              ),
            ),
            if (!_installed && _download == null) ...[
              FilledButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download),
                label: Text(tr.netDownload((NetManager.approxBytes / 1e6).round())),
              ),
              const SizedBox(height: 4),
              Text(tr.netWifiHint, style: theme.textTheme.bodySmall),
            ],
            if (_download != null) ...[
              LinearProgressIndicator(value: _download),
              const SizedBox(height: 4),
              Text('${(_download! * 100).toStringAsFixed(0)} %'),
            ],
            if (_downloadError != null) Text(_downloadError!, style: TextStyle(color: theme.colorScheme.error)),
            if (_installed)
              OutlinedButton.icon(onPressed: _deleteNet, icon: const Icon(Icons.delete), label: Text(tr.netDelete)),
            const Divider(height: 32),
            Text(tr.depth, style: theme.textTheme.titleMedium),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 12, label: Text('12')),
                ButtonSegment(value: 16, label: Text('16')),
                ButtonSegment(value: 20, label: Text('20')),
              ],
              selected: {settings.depth},
              onSelectionChanged: (s) => settings.depth = s.first,
            ),
            const SizedBox(height: 16),
            Text(tr.threads, style: theme.textTheme.titleMedium),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 4, label: Text('4')),
              ],
              selected: {settings.threads},
              onSelectionChanged: (s) => settings.threads = s.first,
            ),
            const Divider(height: 32),
            FilledButton.tonalIcon(
              onPressed: _benching ? null : _runBenchmark,
              icon: const Icon(Icons.speed),
              label: Text(tr.benchmark),
            ),
            const SizedBox(height: 4),
            Text(tr.benchmarkHint, style: theme.textTheme.bodySmall),
            if (_benching) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
            for (final line in _bench) Padding(padding: const EdgeInsets.only(top: 8), child: Text(line)),
            const Divider(height: 32),
            Text(tr.puzzles, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(tr.t('Pro Tag höchstens', 'At most per day')),
            const SizedBox(height: 4),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 5, label: Text('5')),
                ButtonSegment(value: 10, label: Text('10')),
              ],
              selected: {settings.puzzlesPerDay},
              onSelectionChanged: (s) => settings.puzzlesPerDay = s.first,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr.t('Tägliche Erinnerung', 'Daily reminder')),
              subtitle: Text(tr.t('Nur an Tagen mit fälligen Puzzles', 'Only on days with due puzzles')),
              value: settings.reminders,
              onChanged: (v) => settings.reminders = v,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: settings.reminders,
              title: Text(tr.t('Uhrzeit', 'Time')),
              trailing: Text(
                '${(settings.reminderMinutes ~/ 60).toString().padLeft(2, '0')}:'
                '${(settings.reminderMinutes % 60).toString().padLeft(2, '0')}',
                style: theme.textTheme.titleMedium,
              ),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: settings.reminderMinutes ~/ 60, minute: settings.reminderMinutes % 60),
                );
                if (t != null) settings.reminderMinutes = t.hour * 60 + t.minute;
              },
            ),
          ],
        ),
      ),
    );
  }
}
