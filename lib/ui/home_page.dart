import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartchess/dartchess.dart' show Side;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../analysis/analysis.dart';
import '../data/game_store.dart';
import '../engine/analysis_service.dart';
import 'app_scope.dart';
import 'engine_page.dart';
import 'game_page.dart';
import 'puzzle_page.dart';
import 'strings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<List<SharedMediaFile>>? _shareSub;
  AnalysisService? _service;
  List<StoredGame> _games = [];
  PuzzleStats? _stats;

  @override
  void initState() {
    super.initState();
    // Partien, die aus einer anderen App geteilt werden (Lichess: „PGN teilen“)
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(_onShared);
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _onShared(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service?.removeListener(_reload);
    _service = AppScope.of(context).service..addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _service?.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final store = AppScope.of(context).store;
    final games = await store.all();
    final stats = await store.puzzleStats();
    if (mounted) {
      setState(() {
        _games = games;
        _stats = stats;
      });
    }
  }

  Future<void> _onShared(List<SharedMediaFile> files) async {
    for (final f in files) {
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
        await _import(f.path);
      } else {
        final invalid = Tr.of(context).invalidPgn;
        try {
          await _import(await File(f.path).readAsString());
        } catch (_) {
          _snack(invalid);
        }
      }
    }
  }

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// PGN übernehmen: speichern, Farbe klären, Analyse starten, Partie öffnen.
  Future<void> _import(String pgn) async {
    final scope = AppScope.of(context);
    final tr = Tr.of(context);
    final parsed = ParsedGame.parse(pgn.trim());
    if (parsed == null) {
      _snack(tr.invalidPgn);
      return;
    }
    var color = parsed.guessColor();
    final (id, isNew) = await scope.store.add(pgn.trim(), parsed, color);
    if (!isNew) {
      _snack(tr.alreadyThere);
    } else {
      color ??= await askColor(context);
      if (color != null) {
        await scope.service.setColorAndAnalyse(id, color);
      }
    }
    await _reload();
    if (mounted) _open(id);
  }

  void _openPuzzles() =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PuzzlePage())).then((_) => _reload());

  void _open(int id) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GamePage(id: id))).then((_) => _reload());

  Future<void> _pasteDialog() async {
    final tr = Tr.of(context);
    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (!mounted) return;
    final controller = TextEditingController(text: ParsedGame.parse(clip.trim()) != null ? clip : '');
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr.paste),
        content: TextField(
          controller: controller,
          maxLines: 10,
          minLines: 4,
          decoration: const InputDecoration(hintText: '1. e4 e5 2. Nf3 …', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(tr.ok)),
        ],
      ),
    );
    if (text != null && text.trim().isNotEmpty) await _import(text);
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    await _import(utf8.decode(await files.single.readAsBytes(), allowMalformed: true));
  }

  Future<void> _addMenu() async {
    final tr = Tr.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: Text(tr.paste),
              onTap: () => Navigator.pop(context, 'paste'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(tr.openFile),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'paste') await _pasteDialog();
    if (choice == 'file') await _pickFile();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final service = AppScope.of(context).service;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: tr.t('Einstellungen', 'Settings'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EnginePage())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMenu,
        icon: const Icon(Icons.add),
        label: Text(tr.addGame),
      ),
      body: _games.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(tr.emptyHint, textAlign: TextAlign.center),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: _games.length + 1,
              separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
              itemBuilder: (context, i) => i == 0
                  ? _PuzzleCard(stats: _stats, onTap: _openPuzzles)
                  : _GameTile(
                      game: _games[i - 1],
                      progress: service.progress[_games[i - 1].id],
                      onTap: () => _open(_games[i - 1].id),
                    ),
            ),
    );
  }
}

/// Hinweis auf fällige Puzzles oben in der Partienliste.
class _PuzzleCard extends StatelessWidget {
  const _PuzzleCard({required this.stats, required this.onTap});

  final PuzzleStats? stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    if (s == null || s.total == 0) return const SizedBox.shrink();
    final tr = Tr.of(context);
    final perDay = AppScope.of(context).settings.puzzlesPerDay;
    final open = (perDay - s.doneToday).clamp(0, s.due);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: ListTile(
        leading: const Text('🧩', style: TextStyle(fontSize: 28)),
        title: Text(
          open > 0
              ? tr.t(
                  '$open ${open == 1 ? 'Puzzle' : 'Puzzles'} fällig',
                  '$open ${open == 1 ? 'puzzle' : 'puzzles'} due',
                )
              : tr.t('Heute keine Puzzles mehr', 'No more puzzles today'),
        ),
        subtitle: Text(
          tr.t(
            '${s.total} aus deinen Fehlern, ${s.mastered} gemeistert',
            '${s.total} from your mistakes, ${s.mastered} mastered',
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game, required this.progress, required this.onTap});

  final StoredGame game;
  final (int, int)? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final a = game.analysis;
    final p = progress;
    final subtitle = switch (game.status) {
      GameStatus.done when a != null =>
        '${tr.accuracy} ${a.accuracy ?? '–'} % · '
            '${MistakeClass.values.map((c) => '${a.counts[c] ?? 0}${c.glyph}').join(' ')}',
      GameStatus.analysing when p != null => tr.progress(p.$1, p.$2),
      GameStatus.waitingColor => tr.waitingColor,
      GameStatus.error => tr.error,
      _ => tr.queued,
    };
    return ListTile(
      leading: Icon(game.color == Side.black ? Icons.circle : Icons.circle_outlined),
      title: Text('${game.white} – ${game.black}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${game.result} · $subtitle'),
      trailing: game.status == GameStatus.analysing && p != null
          ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(value: p.$1 / p.$2, strokeWidth: 3))
          : null,
      onTap: onTap,
    );
  }
}

/// Fragt nach der eigenen Farbe (z. B. bei „Anonymous“ gegen „Anonymous“).
Future<Side?> askColor(BuildContext context) {
  final tr = Tr.of(context);
  return showDialog<Side>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr.whichColor),
      content: Row(
        children: [
          Expanded(
            child: FilledButton.tonal(onPressed: () => Navigator.pop(context, Side.white), child: Text(tr.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.tonal(onPressed: () => Navigator.pop(context, Side.black), child: Text(tr.black)),
          ),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr.cancel))],
    ),
  );
}
