/// Partien und ihre Analysen in SQLite.
library;

import 'dart:convert';

import 'package:dartchess/dartchess.dart' show Side;
import 'package:sqflite/sqflite.dart';

import '../analysis/analysis.dart';
import '../puzzles/schedule.dart';

enum GameStatus { waitingColor, queued, analysing, done, error }

class StoredGame {
  StoredGame(Map<String, Object?> row)
    : id = row['id']! as int,
      added = DateTime.parse(row['added']! as String),
      pgn = row['pgn']! as String,
      white = row['white']! as String,
      black = row['black']! as String,
      result = row['result']! as String,
      date = row['date'] as String?,
      color = row['color'] == null ? null : Side.values.byName(row['color']! as String),
      status = GameStatus.values.byName(row['status']! as String),
      error = row['error'] as String?,
      analysis = row['analysis'] == null
          ? null
          : GameAnalysis.fromJson(jsonDecode(row['analysis']! as String) as Map<String, dynamic>);

  final int id;
  final DateTime added;
  final String pgn;
  final String white;
  final String black;
  final String result;
  final String? date;
  final Side? color;
  final GameStatus status;
  final String? error;
  final GameAnalysis? analysis;
}

class GameStore {
  GameStore._(this._db);

  final Database _db;

  static Future<GameStore> open() async {
    final db = await openDatabase(
      'games.db',
      version: 2,
      onCreate: (db, _) async {
        await db.execute(_gamesTable);
        await _createPuzzles(db);
      },
      onUpgrade: (db, from, _) async {
        if (from < 2) {
          await _createPuzzles(db);
          // Fehler aus schon analysierten Partien als Puzzles übernehmen
          for (final row in await db.query('games', where: 'analysis IS NOT NULL')) {
            final g = StoredGame(row);
            await _insertPuzzles(db, g.id, g.analysis!.puzzles);
          }
        }
      },
    );
    return GameStore._(db);
  }

  static const _gamesTable = '''
    CREATE TABLE games (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      added TEXT NOT NULL,
      pgn TEXT NOT NULL,
      moves_key TEXT NOT NULL UNIQUE,
      white TEXT NOT NULL,
      black TEXT NOT NULL,
      result TEXT NOT NULL,
      date TEXT,
      color TEXT,
      status TEXT NOT NULL,
      error TEXT,
      analysis TEXT
    )''';

  static Future<void> _createPuzzles(Database db) async {
    // level: Stufe im Wiederholungsplan, due: YYYY-MM-DD oder NULL = gemeistert
    await db.execute('''
      CREATE TABLE puzzles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        ply INTEGER NOT NULL,
        moment TEXT NOT NULL,
        level INTEGER NOT NULL DEFAULT 0,
        due TEXT,
        reps INTEGER NOT NULL DEFAULT 0,
        lapses INTEGER NOT NULL DEFAULT 0,
        UNIQUE (game_id, ply)
      )''');
    await db.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  }

  static Future<void> _insertPuzzles(DatabaseExecutor db, int gameId, List<Moment> moments) async {
    final due = firstDue(DateTime.now());
    for (final m in moments) {
      await db.insert('puzzles', {
        'game_id': gameId,
        'ply': m.ply,
        'moment': jsonEncode(m.toJson()),
        'due': due,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Neue Partie speichern; ist dieselbe Zugfolge schon da, deren id. Zweiter Wert: neu angelegt?
  Future<(int, bool)> add(String pgn, ParsedGame game, Side? color) async {
    final key = '${game.start.fen}|${game.moves.map((m) => m.uci).join(' ')}';
    final existing = await _db.query('games', columns: ['id'], where: 'moves_key = ?', whereArgs: [key]);
    if (existing.isNotEmpty) return (existing.first['id']! as int, false);
    final h = game.headers;
    final id = await _db.insert('games', {
      'added': DateTime.now().toIso8601String(),
      'pgn': pgn,
      'moves_key': key,
      'white': h['White'] ?? '?',
      'black': h['Black'] ?? '?',
      'result': h['Result'] ?? '*',
      'date': h['Date'],
      'color': color?.name,
      'status': (color == null ? GameStatus.waitingColor : GameStatus.queued).name,
    });
    return (id, true);
  }

  Future<List<StoredGame>> all() async =>
      (await _db.query('games', orderBy: 'added DESC')).map(StoredGame.new).toList();

  Future<StoredGame?> get(int id) async {
    final rows = await _db.query('games', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : StoredGame(rows.first);
  }

  Future<void> setColor(int id, Side color) => _update(id, {'color': color.name, 'status': GameStatus.queued.name});

  Future<void> setStatus(int id, GameStatus status, {String? error}) =>
      _update(id, {'status': status.name, 'error': error});

  /// Analyse speichern; eigene Fehler ab „Fehler“ werden zu Puzzles (bestehende bleiben unverändert).
  Future<void> setAnalysis(int id, GameAnalysis analysis) => _db.transaction((tx) async {
    await tx.update(
      'games',
      {'status': GameStatus.done.name, 'error': null, 'analysis': jsonEncode(analysis.toJson())},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _insertPuzzles(tx, id, analysis.puzzles);
  });

  Future<void> delete(int id) => _db.transaction((tx) async {
    await tx.delete('puzzles', where: 'game_id = ?', whereArgs: [id]);
    await tx.delete('games', where: 'id = ?', whereArgs: [id]);
  });

  // ── Puzzles ──────────────────────────────────────────────────────────────────

  /// Fällige Puzzles (älteste zuerst) mit den Spielernamen ihrer Partie.
  Future<List<StoredPuzzle>> duePuzzles({int limit = 50}) async => (await _db.rawQuery(
    'SELECT p.*, g.white, g.black FROM puzzles p JOIN games g ON g.id = p.game_id '
    'WHERE p.due IS NOT NULL AND p.due <= ? ORDER BY p.due, p.id LIMIT ?',
    [isoDay(DateTime.now()), limit],
  )).map(StoredPuzzle.new).toList();

  /// Das nächste noch nicht fällige Puzzle (zum Vorziehen).
  Future<StoredPuzzle?> nextPuzzle() async => (await _db.rawQuery(
    'SELECT p.*, g.white, g.black FROM puzzles p JOIN games g ON g.id = p.game_id '
    'WHERE p.due IS NOT NULL ORDER BY p.due, p.id LIMIT 1',
  )).map(StoredPuzzle.new).firstOrNull;

  /// Fälligkeitsdaten aller offenen Puzzles (für die Vorausplanung der Erinnerungen).
  Future<List<String>> openDueDates() async => [
    for (final r in await _db.query('puzzles', columns: ['due'], where: 'due IS NOT NULL')) r['due']! as String,
  ];

  Future<PuzzleStats> puzzleStats() async {
    final today = isoDay(DateTime.now());
    final r = (await _db.rawQuery(
      'SELECT count(*) AS total, sum(due IS NOT NULL AND due <= ?) AS due, sum(due IS NULL) AS mastered, '
      'min(CASE WHEN due > ? THEN due END) AS next_due FROM puzzles',
      [today, today],
    )).first;
    return PuzzleStats(
      total: r['total'] as int? ?? 0,
      due: r['due'] as int? ?? 0,
      mastered: r['mastered'] as int? ?? 0,
      nextDue: r['next_due'] as String?,
      doneToday: await doneToday(),
    );
  }

  /// Ergebnis eintragen; gibt die neue Fälligkeit zurück (null = gemeistert).
  Future<String?> gradePuzzle(int id, bool solved) => _db.transaction((tx) async {
    final row = (await tx.query('puzzles', where: 'id = ?', whereArgs: [id])).first;
    final (level, due) = grade(row['level']! as int, solved, DateTime.now());
    await tx.rawUpdate('UPDATE puzzles SET level = ?, due = ?, reps = reps + 1, lapses = lapses + ? WHERE id = ?', [
      level,
      due,
      solved ? 0 : 1,
      id,
    ]);
    final key = 'puzzles:${isoDay(DateTime.now())}';
    final done =
        int.tryParse(
          (await tx.query('meta', where: 'key = ?', whereArgs: [key])).firstOrNull?['value'] as String? ?? '',
        ) ??
        0;
    await tx.insert('meta', {'key': key, 'value': '${done + 1}'}, conflictAlgorithm: ConflictAlgorithm.replace);
    return due;
  });

  Future<int> doneToday() async {
    final r = await _db.query('meta', where: 'key = ?', whereArgs: ['puzzles:${isoDay(DateTime.now())}']);
    return int.tryParse(r.firstOrNull?['value'] as String? ?? '') ?? 0;
  }

  Future<void> _update(int id, Map<String, Object?> values) =>
      _db.update('games', values, where: 'id = ?', whereArgs: [id]);
}

class StoredPuzzle {
  StoredPuzzle(Map<String, Object?> row)
    : id = row['id']! as int,
      gameId = row['game_id']! as int,
      moment = Moment.fromJson(jsonDecode(row['moment']! as String) as Map<String, dynamic>),
      level = row['level']! as int,
      due = row['due'] as String?,
      lapses = row['lapses']! as int,
      white = row['white'] as String? ?? '?',
      black = row['black'] as String? ?? '?';

  final int id;
  final int gameId;
  final Moment moment;
  final int level;
  final String? due;
  final int lapses;
  final String white;
  final String black;
}

class PuzzleStats {
  const PuzzleStats({
    required this.total,
    required this.due,
    required this.mastered,
    required this.nextDue,
    required this.doneToday,
  });

  final int total;
  final int due;
  final int mastered;
  final String? nextDue;
  final int doneToday;
}
