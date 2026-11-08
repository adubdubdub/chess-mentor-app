/// Partien und ihre Analysen in SQLite.
library;

import 'dart:convert';

import 'package:dartchess/dartchess.dart' show Side;
import 'package:sqflite/sqflite.dart';

import '../analysis/analysis.dart';

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
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
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
        )''');
      },
    );
    return GameStore._(db);
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

  Future<void> setAnalysis(int id, GameAnalysis analysis) =>
      _update(id, {'status': GameStatus.done.name, 'error': null, 'analysis': jsonEncode(analysis.toJson())});

  Future<void> delete(int id) => _db.delete('games', where: 'id = ?', whereArgs: [id]);

  Future<void> _update(int id, Map<String, Object?> values) =>
      _db.update('games', values, where: 'id = ?', whereArgs: [id]);
}
