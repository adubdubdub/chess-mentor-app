import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/backup.dart';
import 'app_scope.dart';
import 'strings.dart';

/// Exportdatei einlesen und eine Meldung für den Nutzer zurückgeben. Neue, noch nicht analysierte Partien starten die Analyse.
Future<String> importExportText(BuildContext context, String text) async {
  final tr = Tr.of(context);
  final scope = AppScope.of(context);
  try {
    final r = await Backup(scope.store).import(text);
    await scope.service.resume();
    return tr.t(
      '${r.added} Partien übernommen'
          '${r.skipped > 0 ? ', ${r.skipped} schon vorhanden' : ''}'
          '${r.invalid > 0 ? ', ${r.invalid} nicht lesbar' : ''}. '
          'Partien ohne Analyse werden jetzt analysiert, der Lernstand der Puzzles folgt danach.',
      '${r.added} games imported'
          '${r.skipped > 0 ? ', ${r.skipped} already there' : ''}'
          '${r.invalid > 0 ? ', ${r.invalid} unreadable' : ''}. '
          'Games without analysis are analysed now; puzzle progress follows afterwards.',
    );
  } on FormatException catch (e) {
    return tr.t('Import nicht möglich: ${e.message}', 'Import failed: ${e.message}');
  }
}

/// Export und Import aller Partien samt Lernstand.
class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  bool _busy = false;
  String? _message;

  Future<void> _export() async {
    final tr = Tr.of(context);
    final scope = AppScope.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    String msg;
    try {
      final json = await Backup(scope.store).export();
      final now = DateTime.now();
      final name =
          'schach-mentor-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';
      final saved = await FilePicker.saveFile(
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
      );
      msg = saved == null ? tr.t('Abgebrochen.', 'Cancelled.') : tr.t('Gespeichert: $name', 'Saved: $name');
    } catch (e) {
      msg = tr.t('Export fehlgeschlagen.', 'Export failed.');
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _message = msg;
      });
    }
  }

  Future<void> _import() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final text = utf8.decode(await files.single.readAsBytes(), allowMalformed: true);
    if (!mounted) return;
    final msg = looksLikeExport(text)
        ? await importExportText(context, text)
        : Tr.of(context).t('Das ist keine Exportdatei der App.', 'This is not an export file of the app.');
    if (mounted) {
      setState(() {
        _busy = false;
        _message = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr.t('Daten sichern und übernehmen', 'Back up and restore'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr.t(
              'Die Datei enthält alle Partien mit Analyse, den Lernstand der Puzzles (Stufe, Fälligkeit, Versuche) und '
                  'gespeicherte KI-Texte. Schlüssel und Einstellungen sind nicht enthalten. Die Datei ist nicht '
                  'verschlüsselt, bewahre sie sicher auf.',
              'The file contains all games with analysis, puzzle progress (level, due date, attempts) and stored AI '
                  'texts. Keys and settings are not included. The file is not encrypted, keep it safe.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.upload_file),
            label: Text(tr.t('Alles exportieren', 'Export everything')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.download),
            label: Text(tr.t('Exportdatei übernehmen', 'Import an export file')),
          ),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_message!)),
          const SizedBox(height: 16),
          Text(
            tr.t(
              'Schon vorhandene Partien (gleiche Zugfolge) bleiben unverändert. Wegen des deaktivierten Android-Backups '
                  'ist der Export der einzige Weg, Daten auf ein neues Handy mitzunehmen.',
              'Games that already exist (same moves) stay unchanged. Because Android backup is turned off, the export '
                  'is the only way to take your data to a new phone.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
