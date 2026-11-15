// Gibt das Schwächenprofil für eine echte Exportdatei aus (nur zur Sichtprüfung, Daten bleiben außerhalb des Repos):
//   PROFILE_EXPORT=/pfad/schach-mentor-….json flutter test test/profile_live_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/mentor/profile.dart';
import 'package:chess_mentor/mentor/records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final path = Platform.environment['PROFILE_EXPORT'];
  test('Profil aus Exportdatei', () {
    final data = jsonDecode(File(path!).readAsStringSync()) as Map<String, dynamic>;
    final records = <GameRecord>[];
    var id = 0;
    for (final g in (data['games'] as List).cast<Map<String, dynamic>>()) {
      if (g['analysis'] == null) continue;
      final pgn = g['pgn'] as String;
      final states = <int, PuzzleState>{};
      for (final p in (g['puzzles'] as List).cast<Map<String, dynamic>>()) {
        final att = (p['attempts'] as List).cast<Map<String, dynamic>>();
        states[p['ply'] as int] = PuzzleState(
          level: p['level'] as int,
          mastered: p['due'] == null,
          attempts: att.length,
          clean: att.where((a) => a['result'] == 'first').length,
        );
      }
      records.add(
        GameRecord.fromParts(
          id: id++,
          playedAt: GameRecord.playedAtFrom(pgn, DateTime.parse(g['added'] as String)),
          pgn: pgn,
          analysis: GameAnalysis.fromJson(g['analysis'] as Map<String, dynamic>),
          puzzles: states,
        ),
      );
    }
    final p = buildProfile(records);
    final out = StringBuffer()
      ..writeln('PROFIL ${p.games} Partien, ${p.ownMoves} eigene Züge, Genauigkeit ${p.accuracy?.toStringAsFixed(1)} %, genug Daten: ${p.enough}')
      ..writeln('PROFIL Fehlzüge: ${p.counts.entries.map((e) => '${e.key.name} ${e.value}').join(', ')}, ohne Thema: ${p.untagged}');
    for (final t in p.topics) {
      out.writeln(
        'PROFIL Thema ${t.topic.name}: ${t.count}× in ${t.games} Partien, ${t.per100.toStringAsFixed(1)}/100 Züge, '
        'Ø-Verlust ${t.avgDrop.toStringAsFixed(1)}, Trend ${t.trend?.toStringAsFixed(1) ?? '-'}, Puzzles ${t.mastered}/${t.puzzles}, '
        'Punkte ${t.score.toStringAsFixed(1)}, aussagekräftig: ${t.enough}',
      );
    }
    for (final ph in p.phases) {
      out.writeln('PROFIL Phase ${ph.phase.name}: ${ph.mistakes} Fehlzüge bei ${ph.moves} Zügen = ${ph.per100.toStringAsFixed(1)}/100');
    }
    for (final o in p.openings) {
      out.writeln('PROFIL Eröffnung ${o.name}: ${o.games} Partien, ${o.mistakes} Fehlzüge, Genauigkeit ${o.accuracy?.toStringAsFixed(0)}');
    }
    stdout.write(out);
  }, skip: path == null ? 'PROFILE_EXPORT nicht gesetzt' : false);
}
