/// Export und Import aller Partien samt Lernstand als JSON (Format `schach-mentor-export`, Version 1).
///
/// Eine Partie enthält PGN, Farbe, optional die fertige Analyse und je Puzzle den Lernstand (Stufe, Fälligkeit,
/// Versuche) sowie gespeicherte KI-Texte. Ohne Analyse (z. B. Übernahme aus dem Telegram-Bot) wird die Partie neu
/// analysiert, und der Lernstand wird danach auf die entstehenden Puzzles übertragen (über die Zugnummer `ply`).
/// Neben den Partien enthält die Datei die Benutzernamen der Online-Konten (kein Passwort). Schlüssel und übrige
/// Einstellungen sind nie Teil des Exports.
library;

import 'dart:convert';

import 'package:dartchess/dartchess.dart' show Side;

import '../ai/prompts.dart';
import '../analysis/analysis.dart';
import 'game_store.dart';
import 'settings.dart';

const exportFormat = 'schach-mentor-export';
const exportVersion = 1;

class ImportResult {
  const ImportResult({this.added = 0, this.skipped = 0, this.invalid = 0, this.puzzles = 0});

  /// Neue Partien, schon vorhandene (übersprungen), unlesbare, übernommene Puzzle-Stände (nur mit Analyse sofort).
  final int added;
  final int skipped;
  final int invalid;
  final int puzzles;
}

/// Erkennt eine Exportdatei am Format-Feld (statt einer PGN).
bool looksLikeExport(String text) {
  final t = text.trimLeft();
  return t.startsWith('{') && t.contains('"$exportFormat"');
}

class Backup {
  Backup(this.store, {this.settings});

  final GameStore store;

  /// Für die Konten (Benutzernamen); ohne Einstellungen werden sie weder exportiert noch übernommen.
  final Settings? settings;

  /// Alle Partien mit Lernstand als JSON-Text.
  Future<String> export() async {
    final db = store.db;
    final games = <Map<String, Object?>>[];
    for (final g in await db.query('games', orderBy: 'added')) {
      final id = g['id']! as int;
      final puzzles = <Map<String, Object?>>[];
      for (final p in await db.query('puzzles', where: 'game_id = ?', whereArgs: [id], orderBy: 'ply')) {
        final pid = p['id']! as int;
        final attempts = await db.query('puzzle_attempts', where: 'puzzle_id = ?', whereArgs: [pid], orderBy: 'at');
        final ai = await db.query('ai_texts', where: "key LIKE ?", whereArgs: ['puzzle:$pid:%']);
        puzzles.add({
          'ply': p['ply'],
          'level': p['level'],
          'due': p['due'],
          'reps': p['reps'],
          'lapses': p['lapses'],
          'attempts': [
            for (final a in attempts)
              {'at': a['at'], 'result': a['result'], 'wrong': a['wrong'], 'hint': a['hint'] == 1},
          ],
          'ai': {for (final t in ai) (t['key']! as String).substring('puzzle:$pid:'.length): t['text']},
        });
      }
      final review = await db.query('ai_texts', where: 'key LIKE ?', whereArgs: ['review:$id:%']);
      games.add({
        'pgn': g['pgn'],
        'color': g['color'],
        'added': g['added'],
        'analysis': g['analysis'] == null ? null : jsonDecode(g['analysis']! as String),
        'puzzles': puzzles,
        'reviewTexts': {for (final t in review) (t['key']! as String).substring('review:$id:'.length): t['text']},
      });
    }
    return const JsonEncoder.withIndent(' ').convert({
      'format': exportFormat,
      'version': exportVersion,
      'exported': DateTime.now().toIso8601String(),
      if (settings != null)
        'accounts': {
          if (settings!.lichessUser.isNotEmpty) 'lichess': settings!.lichessUser,
          if (settings!.chesscomUser.isNotEmpty) 'chesscom': settings!.chesscomUser,
          if (settings!.lichessSince != null) 'lichessSince': settings!.lichessSince,
          if (settings!.chesscomSince != null) 'chesscomSince': settings!.chesscomSince,
        },
      'games': games,
    });
  }

  /// Exportdatei einlesen. Schon vorhandene Partien (gleiche Zugfolge) bleiben unverändert.
  /// [onQueued] bekommt die ids neuer, noch zu analysierender Partien.
  Future<ImportResult> import(String text, {void Function(int id)? onQueued}) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Keine gültige Exportdatei');
    }
    if (data['format'] != exportFormat) throw const FormatException('Keine Schach-Mentor-Exportdatei');
    if ((data['version'] as int? ?? 0) > exportVersion) {
      throw const FormatException('Exportdatei stammt von einer neueren App-Version');
    }
    // Konten übernehmen, aber vorhandene Eingaben nie überschreiben
    final acc = data['accounts'];
    final st = settings;
    if (acc is Map<String, dynamic> && st != null) {
      if (st.lichessUser.isEmpty && acc['lichess'] is String) {
        st.lichessUser = acc['lichess'] as String;
        if (acc['lichessSince'] is int) st.lichessSince = acc['lichessSince'] as int;
      }
      if (st.chesscomUser.isEmpty && acc['chesscom'] is String) {
        st.chesscomUser = acc['chesscom'] as String;
        if (acc['chesscomSince'] is int) st.chesscomSince = acc['chesscomSince'] as int;
      }
    }
    var added = 0, skipped = 0, invalid = 0, puzzles = 0;
    for (final raw in (data['games'] as List? ?? const [])) {
      try {
        final g = raw as Map<String, dynamic>;
        final pgn = (g['pgn'] as String).trim();
        final parsed = ParsedGame.parse(pgn);
        if (parsed == null) {
          invalid++;
          continue;
        }
        final color = g['color'] == null ? null : Side.values.byName(g['color'] as String);
        final (id, isNew) = await store.add(pgn, parsed, color);
        if (!isNew) {
          skipped++;
          continue;
        }
        added++;
        if (g['added'] != null) await store.db.update('games', {'added': g['added']}, where: 'id = ?', whereArgs: [id]);
        final states = (g['puzzles'] as List?) ?? const [];
        if (g['analysis'] != null) {
          await store.setAnalysis(id, GameAnalysis.fromJson(g['analysis'] as Map<String, dynamic>));
          puzzles += await GameStore.applyPuzzleStates(store.db, id, states);
        } else if (states.isNotEmpty) {
          // Noch keine Analyse: Lernstand merken, bis die Puzzles entstehen (GameStore._insertPuzzles)
          await store.db.insert('meta', {'key': 'pending:$id', 'value': jsonEncode(states)});
          if (color != null) onQueued?.call(id);
        } else if (color != null) {
          onQueued?.call(id);
        }
        for (final e in ((g['reviewTexts'] as Map<String, dynamic>?) ?? const {}).entries) {
          // Texte ohne Versionsangabe (z. B. aus dem Telegram-Bot) gelten für die aktuelle Prompt-Version
          final suffix = e.key.contains(':v') ? e.key : '${e.key}:v$promptVersion';
          await store.putAiText('review:$id:$suffix', e.value as String);
        }
      } catch (_) {
        invalid++;
      }
    }
    return ImportResult(added: added, skipped: skipped, invalid: invalid, puzzles: puzzles);
  }
}
