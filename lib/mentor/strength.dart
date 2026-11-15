/// Spielstärke des Nutzers (Elo-Anpassung E1): Online-Wertungen und eigene Partien, manuelle Eingabe, Stufen.
/// Alles reine Logik ohne Netz und Oberfläche. Die Zahlen für die Umrechnungen sind begründete Startwerte und werden
/// mit echten Daten nachjustiert.
library;

import 'dart:convert';
import 'dart:math' as math;

/// Ausgangswert ohne Daten (wie im Telegram-Bot).
const defaultElo = 1200;

/// Stufen für Textbausteine und Fokus.
enum Level {
  /// unter 1000
  beginner,

  /// 1000 bis 1400
  advancedBeginner,

  /// 1400 bis 1800
  intermediate,

  /// über 1800
  advanced,
}

/// Obergrenzen der Stufen (Elo), die letzte Stufe ist nach oben offen.
const levelLimits = [1000, 1400, 1800];

/// Stufe zu einer Elo-Zahl.
Level levelFor(int elo) {
  for (var i = 0; i < levelLimits.length; i++) {
    if (elo < levelLimits[i]) return Level.values[i];
  }
  return Level.advanced;
}

/// Auf 50 gerundet, so geht die Zahl in Texte und KI-Prompts.
int roundElo(int elo) => (elo / 50).round() * 50;

enum StrengthSource { initial, online, games, manual }

enum Confidence { low, medium, high }

/// Eine Wertung einer Spielart bei einem Dienst.
class PerfRating {
  const PerfRating({required this.perf, required this.rating, required this.games, this.provisional = false});

  final String perf;
  final int rating;
  final int games;

  /// Vorläufig: wenige Partien, die Wertung schwankt noch stark.
  final bool provisional;
}

/// Wie stark eine Spielart für die Spielstärke zählt: klassische und Rapid-Wertungen am meisten.
const perfFactors = {'classical': 1.0, 'rapid': 1.0, 'blitz': 0.8, 'bullet': 0.5, 'correspondence': 0.5, 'daily': 0.5};

/// Chess.com-Wertungen liegen im Schnitt über denen von Lichess. Grobe Umrechnung (Annahme).
const chessComOffset = 150;

/// Gewicht einer Wertung: Partienzahl (höchstens 50) × Spielart, vorläufig nur 20 %.
double ratingWeight(PerfRating r) => math.min(r.games, 50) * (perfFactors[r.perf] ?? 0.5) * (r.provisional ? 0.2 : 1.0);

/// Online-Schätzung aus den Wertungen beider Dienste: gewichteter Mittelwert (Lichess-Skala) und Gesamtgewicht.
/// Null ohne verwertbare Wertung.
({double elo, double weight})? onlineEstimate({
  List<PerfRating> lichess = const [],
  List<PerfRating> chessCom = const [],
}) {
  var sum = 0.0, w = 0.0;
  for (final r in lichess) {
    final x = ratingWeight(r);
    sum += r.rating * x;
    w += x;
  }
  for (final r in chessCom) {
    final x = ratingWeight(r);
    sum += (r.rating - chessComOffset) * x;
    w += x;
  }
  return w == 0 ? null : (elo: sum / w, weight: w);
}

/// Grobe Zuordnung durchschnittliche Genauigkeit (%) → Elo, linear dazwischen (Annahme, niedrige Sicherheit).
const _accuracyTable = [
  (60.0, 600),
  (70.0, 900),
  (75.0, 1000),
  (80.0, 1200),
  (85.0, 1450),
  (88.0, 1600),
  (90.0, 1800),
  (93.0, 2000),
  (96.0, 2300),
];

int eloFromAccuracy(double accuracy) {
  if (accuracy <= _accuracyTable.first.$1) return _accuracyTable.first.$2;
  if (accuracy >= _accuracyTable.last.$1) return _accuracyTable.last.$2;
  for (var i = 1; i < _accuracyTable.length; i++) {
    final (a1, e1) = _accuracyTable[i];
    final (a0, e0) = _accuracyTable[i - 1];
    if (accuracy <= a1) return (e0 + (e1 - e0) * (accuracy - a0) / (a1 - a0)).round();
  }
  return defaultElo;
}

/// Schätzung aus eigenen Partien: durchschnittliche Genauigkeit und Zahl der Partien; Gewicht wächst mit der Partienzahl.
({double elo, double weight})? gamesEstimate({required double? accuracy, required int games}) =>
    accuracy == null || games == 0
    ? null
    : (elo: eloFromAccuracy(accuracy).toDouble(), weight: math.min(games, 20) * 0.5);

/// Gewicht des Ausgangswerts 1200 in der Mischung.
const priorWeight = 5.0;

/// Das Ergebnis der Schätzung.
class Strength {
  const Strength({
    required this.elo,
    required this.source,
    required this.confidence,
    required this.at,
    this.games = 0,
    this.onlineElo,
    this.onlineWeight = 0,
  });

  final int elo;
  final StrengthSource source;
  final Confidence confidence;
  final DateTime at;

  /// Analysierte Partien, die in die Schätzung eingingen.
  final int games;

  /// Zuletzt abgerufene Online-Schätzung (zum Wiederverwenden ohne Netz).
  final double? onlineElo;
  final double onlineWeight;

  Strength copyWith({int? elo, StrengthSource? source, Confidence? confidence, DateTime? at}) => Strength(
    elo: elo ?? this.elo,
    source: source ?? this.source,
    confidence: confidence ?? this.confidence,
    at: at ?? this.at,
    games: games,
    onlineElo: onlineElo,
    onlineWeight: onlineWeight,
  );

  Map<String, Object?> toJson() => {
    'elo': elo,
    'source': source.name,
    'confidence': confidence.name,
    'at': at.toIso8601String(),
    'games': games,
    'onlineElo': onlineElo,
    'onlineWeight': onlineWeight,
  };

  factory Strength.fromJson(Map<String, dynamic> j) => Strength(
    elo: j['elo'] as int,
    source: StrengthSource.values.byName(j['source'] as String),
    confidence: Confidence.values.byName(j['confidence'] as String),
    at: DateTime.parse(j['at'] as String),
    games: (j['games'] as int?) ?? 0,
    onlineElo: (j['onlineElo'] as num?)?.toDouble(),
    onlineWeight: ((j['onlineWeight'] as num?) ?? 0).toDouble(),
  );
}

/// Glättung: der neue Wert rückt um die Hälfte an die frische Schätzung heran.
int smoothElo(int previous, double estimate, {double alpha = 0.5}) =>
    (previous + (estimate - previous) * alpha).round();

/// Schätzt die Spielstärke.
///
/// - [manual] hat immer Vorrang (Sicherheit hoch).
/// - Online mit hoher Sicherheit (Gewicht ≥ 40) gilt allein.
/// - Sonst wird gemischt: Online-Wertung, eigene Partien und der Ausgangswert 1200, jeweils nach Gewicht.
/// - Ein früherer automatischer Wert glättet das Ergebnis ([smoothElo]).
Strength estimateStrength({
  int? manual,
  double? onlineElo,
  double onlineWeight = 0,
  double? accuracy,
  int games = 0,
  Strength? previous,
  required DateTime now,
}) {
  if (manual != null) {
    return Strength(
      elo: manual,
      source: StrengthSource.manual,
      confidence: Confidence.high,
      at: now,
      games: games,
      onlineElo: onlineElo,
      onlineWeight: onlineWeight,
    );
  }
  final g = gamesEstimate(accuracy: accuracy, games: games);
  final onW = onlineElo == null ? 0.0 : math.min(onlineWeight, 100.0);
  double raw;
  StrengthSource source;
  Confidence confidence;
  if (onlineElo != null && onW >= 40) {
    raw = onlineElo;
    source = StrengthSource.online;
    confidence = Confidence.high;
  } else {
    var sum = defaultElo * priorWeight, w = priorWeight;
    if (onlineElo != null) {
      sum += onlineElo * onW;
      w += onW;
    }
    if (g != null) {
      sum += g.elo * g.weight;
      w += g.weight;
    }
    raw = sum / w;
    final data = onW + (g?.weight ?? 0);
    source = data == 0
        ? StrengthSource.initial
        : (onW >= (g?.weight ?? 0) ? StrengthSource.online : StrengthSource.games);
    confidence = onW >= 10 || (g?.weight ?? 0) >= 4 ? Confidence.medium : Confidence.low;
  }
  final auto =
      previous != null && previous.source != StrengthSource.manual && previous.source != StrengthSource.initial;
  final elo = auto ? smoothElo(previous.elo, raw) : raw.round();
  return Strength(
    elo: elo.clamp(400, 2800),
    source: source,
    confidence: confidence,
    at: now,
    games: games,
    onlineElo: onlineElo,
    onlineWeight: onlineWeight,
  );
}

/// Stufe samt Zwischenstand der Hysterese: Die Stufe wechselt erst, wenn die Schätzung zweimal in Folge mindestens
/// [hysteresisMargin] Elo jenseits der Grenze liegt. Bei manueller Eingabe wechselt sie sofort.
const hysteresisMargin = 50;

class LevelState {
  const LevelState({required this.level, this.pending, this.pendingCount = 0});

  final Level level;
  final Level? pending;
  final int pendingCount;

  Map<String, Object?> toJson() => {'level': level.name, 'pending': pending?.name, 'pendingCount': pendingCount};

  factory LevelState.fromJson(Map<String, dynamic> j) => LevelState(
    level: Level.values.byName(j['level'] as String),
    pending: j['pending'] == null ? null : Level.values.byName(j['pending'] as String),
    pendingCount: (j['pendingCount'] as int?) ?? 0,
  );

  static LevelState? tryParse(String? text) {
    if (text == null) return null;
    try {
      return LevelState.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

LevelState nextLevel(LevelState? current, int elo, {bool immediate = false}) {
  final target = levelFor(elo);
  if (current == null || immediate) return LevelState(level: target);
  if (target == current.level) return LevelState(level: current.level);
  // Muss deutlich jenseits der Grenze zur neuen Stufe liegen, sonst bleibt es bei der alten
  final boundary = target.index > current.level.index ? levelLimits[current.level.index] : levelLimits[target.index];
  final beyond = target.index > current.level.index
      ? elo >= boundary + hysteresisMargin
      : elo < boundary - hysteresisMargin;
  if (!beyond) return LevelState(level: current.level);
  final count = current.pending == target ? current.pendingCount + 1 : 1;
  return count >= 2
      ? LevelState(level: target)
      : LevelState(level: current.level, pending: target, pendingCount: count);
}
