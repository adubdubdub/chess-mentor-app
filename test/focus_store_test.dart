import 'dart:convert';

import 'package:chess_mentor/analysis/analysis.dart';
import 'package:chess_mentor/analysis/chess_utils.dart';
import 'package:chess_mentor/data/backup.dart';
import 'package:chess_mentor/data/game_store.dart';
import 'package:chess_mentor/mentor/focus.dart';
import 'package:chess_mentor/mentor/focus_keeper.dart';
import 'package:chess_mentor/mentor/topics.dart';
import 'package:chess_mentor/puzzles/schedule.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _pgn = '[White "A"]\n[Black "B"]\n[Result "*"]\n[Date "2026.11.16"]\n\n1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *';

Moment _m(int ply, List<String> motifs, {double drop = 14}) => Moment(
  ply: ply,
  moveNo: ply ~/ 2 + 1,
  fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  lastMove: null,
  opponentLast: null,
  played: 'a3',
  playedUci: 'a2a3',
  alternatives: const [Alternative('Nxe5', 'g1e5', 50)],
  bestLine: '1.Nxe5',
  replyLine: '1...d6',
  threatReply: null,
  winBefore: 50,
  winAfter: 50 - drop,
  drop: drop,
  mistake: MistakeClass.forDrop(drop) ?? MistakeClass.inaccuracy,
  phase: GamePhase.middlegame,
  motifs: [for (final c in motifs) Motif(c)],
);

GameAnalysis _analysis(List<Moment> ms) => GameAnalysis(
  color: Side.white,
  white: 'A',
  black: 'B',
  result: '*',
  opening: '',
  moves: 6,
  accuracy: 80,
  counts: const {},
  moments: ms,
  puzzles: ms,
  evals: const [],
  engine: 'sf',
  depth: 12,
  flagged: ms,
);

Future<GameStore> _store() => GameStore.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);

FocusEntry _entry(Topic t, DateTime start) => FocusEntry(
  topic: t,
  startedAt: start,
  endsAt: start.add(const Duration(days: 7)),
  goalGames: 3,
  target: 1,
  baselineCount: 6,
  baselineGames: 6,
);

void main() {
  setUpAll(sqfliteFfiInit);

  test('Fokus: starten, ersetzen, beenden', () async {
    final s = await _store();
    expect(await s.activeFocus(), isNull);
    final a = await s.startFocus(_entry(Topic.hangsPiece, DateTime.utc(2026, 11, 16)));
    expect((await s.activeFocus())!.topic, Topic.hangsPiece);
    await s.startFocus(_entry(Topic.missedMaterial, DateTime.utc(2026, 11, 17)));
    expect((await s.activeFocus())!.topic, Topic.missedMaterial);
    final all = await s.focusHistory();
    expect(all.first.status, FocusStatus.cancelled); // der erste wurde ersetzt
    expect(all.first.id, a);
    await s.closeFocus((await s.activeFocus())!.id!, FocusStatus.reached, DateTime.utc(2026, 11, 20));
    expect(await s.activeFocus(), isNull);
    expect((await s.lastClosedFocus())!.status, FocusStatus.reached);
  });

  test('Puzzles zum Fokusthema kommen zuerst, Tagesgrenze bleibt', () async {
    final s = await _store();
    final (id, _) = await s.add(_pgn, ParsedGame.parse(_pgn)!, Side.white);
    await s.setAnalysis(id, _analysis([_m(2, const []), _m(4, ['wins_material']), _m(6, ['best_is_check'])]));
    await s.db.update('puzzles', {'due': isoDay(DateTime.now())});
    final plain = await s.duePuzzles(limit: 3);
    expect(plain.map((p) => p.moment.ply), [2, 4, 6]);
    final focused = await s.duePuzzles(limit: 3, focus: Topic.missedMaterial);
    expect(focused.map((p) => p.moment.ply), [4, 2, 6]);
    expect((await s.duePuzzles(limit: 1, focus: Topic.missedCheck)).single.moment.ply, 6);
    expect(await s.dueFocusPuzzles(Topic.missedMaterial), 1);
  });

  test('FocusKeeper wertet nach der Analyse aus und speichert das Ergebnis', () async {
    final s = await _store();
    final keeper = FocusKeeper(s);
    final start = DateTime.utc(2026, 11, 16, 8);
    await s.startFocus(
      FocusEntry(
        topic: Topic.missedMaterial,
        startedAt: start,
        endsAt: start.add(const Duration(days: 7)),
        goalGames: 1,
        target: 0,
        baselineCount: 4,
        baselineGames: 4,
      ),
    );
    var st = await keeper.refresh(now: DateTime.utc(2026, 11, 16, 20));
    expect(st.active, isNotNull);
    expect(st.progress!.games, 0);

    final (id, _) = await s.add(_pgn, ParsedGame.parse(_pgn)!, Side.white);
    await s.setAnalysis(id, _analysis([_m(4, ['wins_material'])]));
    st = await keeper.refresh(now: DateTime.utc(2026, 11, 16, 21));
    expect(st.active, isNull);
    expect(st.lastClosed!.status, FocusStatus.missed);
    expect(st.progress!.occurrences, 1);
    expect(await s.activeFocus(), isNull);
    // erneutes Auswerten ändert nichts
    st = await keeper.refresh(now: DateTime.utc(2026, 11, 17));
    expect(st.lastClosed!.status, FocusStatus.missed);
  });

  test('Export und Import enthalten den Fokus, ein laufender wird nicht doppelt aktiv', () async {
    final a = await _store();
    await a.startFocus(_entry(Topic.hangsPiece, DateTime.utc(2026, 11, 10)));
    await a.closeFocus((await a.activeFocus())!.id!, FocusStatus.reached, DateTime.utc(2026, 11, 14));
    await a.startFocus(_entry(Topic.missedCheck, DateTime.utc(2026, 11, 16)));
    final json = await Backup(a).export();
    expect((jsonDecode(json)['focus'] as List), hasLength(2));

    final b = await _store();
    await b.startFocus(_entry(Topic.whenWorse, DateTime.utc(2026, 11, 15))); // hier läuft schon einer
    await Backup(b).import(json);
    final hist = await b.focusHistory();
    expect(hist, hasLength(3));
    expect(hist.where((f) => f.status == FocusStatus.active).map((f) => f.topic), [Topic.whenWorse]);
    await Backup(b).import(json); // zweiter Import: nichts doppelt
    expect(await b.focusHistory(), hasLength(3));
  });
}
