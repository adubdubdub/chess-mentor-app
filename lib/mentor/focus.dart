/// Wochenfokus (Schritt 6c): ein Thema für sieben Tage, mit messbarem Ziel und automatischer Auswertung.
library;

import 'profile.dart';
import 'records.dart';
import 'strength.dart';
import 'topics.dart';

enum FocusStatus {
  /// Läuft noch.
  active,

  /// Ziel erreicht: in den Zielpartien höchstens [FocusEntry.target] Fehlzüge dieses Themas.
  reached,

  /// Ziel verfehlt: mehr Fehlzüge als erlaubt.
  missed,

  /// Sieben Tage vorbei, ohne dass genug Partien gespielt wurden (kein Urteil möglich).
  expired,

  /// Vom Nutzer beendet oder durch einen neuen Fokus ersetzt.
  cancelled,
}

/// Dauer eines Fokus und Zahl der Partien, über die das Ziel gemessen wird.
const focusDays = 7;
const focusGames = 3;

class FocusEntry {
  const FocusEntry({
    this.id,
    required this.topic,
    required this.startedAt,
    required this.endsAt,
    required this.goalGames,
    required this.target,
    required this.baselineCount,
    required this.baselineGames,
    this.status = FocusStatus.active,
    this.closedAt,
  });

  final int? id;
  final Topic topic;
  final DateTime startedAt;
  final DateTime endsAt;

  /// Über so viele Partien wird gemessen, und so viele Fehlzüge des Themas sind darin höchstens erlaubt.
  final int goalGames;
  final int target;

  /// Ausgangslage beim Start: Fehlzüge dieses Themas in so vielen Partien (zum Vergleich).
  final int baselineCount;
  final int baselineGames;
  final FocusStatus status;
  final DateTime? closedAt;

  FocusEntry copyWith({FocusStatus? status, DateTime? closedAt}) => FocusEntry(
    id: id,
    topic: topic,
    startedAt: startedAt,
    endsAt: endsAt,
    goalGames: goalGames,
    target: target,
    baselineCount: baselineCount,
    baselineGames: baselineGames,
    status: status ?? this.status,
    closedAt: closedAt ?? this.closedAt,
  );
}

/// Vorschlag für einen Fokus: das Thema mit seinen Kennzahlen und dem daraus abgeleiteten Ziel.
class FocusSuggestion {
  const FocusSuggestion({required this.stat, required this.target, required this.goalGames, required this.baselineGames});

  final TopicStat stat;
  final int target;
  final int goalGames;
  final int baselineGames;

  Topic get topic => stat.topic;
}

/// Faktor je Stufe für das Ziel: Anteil der bisherigen Fehlzüge, der in den Zielpartien noch erlaubt ist.
/// Anfänger bekommen ein milderes, Stärkere ein strengeres Ziel (Startwerte, nach der Testzeit nachjustieren).
const goalFactors = {Level.beginner: 0.6, Level.advancedBeginner: 0.5, Level.intermediate: 0.45, Level.advanced: 0.4};

/// Ohne Stufe gilt die Hälfte.
double goalFactor(Level? level) => level == null ? 0.5 : goalFactors[level]!;

/// Gewichte auf die Themen-Punktzahl je Stufe: unten zuerst Sicherheit im Taktischen, oben Vorteil verwerten und
/// Verteidigung (Startwerte). Nicht genannte Themen zählen 1,0.
const topicWeights = <Level, Map<Topic, double>>{
  Level.beginner: {
    Topic.hangsPiece: 1.5,
    Topic.allowsMate: 1.3,
    Topic.missedMaterial: 1.2,
    Topic.advantageLost: 0.6,
    Topic.whenWorse: 0.6,
  },
  Level.advancedBeginner: {Topic.hangsPiece: 1.2},
  Level.intermediate: {Topic.advantageLost: 1.2, Topic.whenWorse: 1.1},
  Level.advanced: {Topic.advantageLost: 1.5, Topic.whenWorse: 1.3, Topic.missedCheck: 0.8},
};

double topicWeight(Level? level, Topic topic) => level == null ? 1.0 : (topicWeights[level]?[topic] ?? 1.0);

/// Ziel: die Fehlzüge dieses Themas halbieren. Erwartet werden bisher `count / games` je Partie; erlaubt sind in
/// [goalGames] Partien die Hälfte davon, abgerundet (bei seltenen Themen also null).
int targetFor(int count, int games, int goalGames, {double factor = 0.5}) =>
    games == 0 ? 0 : (count / games * goalGames * factor).floor();

/// Bis zu [count] Themen für den nächsten Fokus, das beste zuerst. Nur Themen mit genug Daten. Mit [level] gewichten
/// die Stufe die Themen ([topicWeights]) und bestimmen die Härte des Ziels ([goalFactors]).
/// Dasselbe Thema wie beim letzten Fokus rückt nach hinten, außer es wird gerade schlechter.
List<FocusSuggestion> suggestFocus(
  Profile p, {
  Topic? lastTopic,
  int goalGames = focusGames,
  int count = 3,
  Level? level,
}) {
  final candidates = [...p.candidates];
  bool repeat(TopicStat t) => lastTopic != null && t.topic == lastTopic && !((t.trend ?? 0) > 0.3);
  candidates.sort((a, b) {
    final ra = repeat(a) ? 1 : 0, rb = repeat(b) ? 1 : 0;
    if (ra != rb) return ra.compareTo(rb);
    return (b.score * topicWeight(level, b.topic)).compareTo(a.score * topicWeight(level, a.topic));
  });
  return [
    for (final t in candidates.take(count))
      FocusSuggestion(
        stat: t,
        target: targetFor(t.count, p.games, goalGames, factor: goalFactor(level)),
        goalGames: goalGames,
        baselineGames: p.games,
      ),
  ];
}

/// Neuer Fokus aus einem Vorschlag, beginnend [now].
FocusEntry startFocusFrom(FocusSuggestion s, DateTime now) => FocusEntry(
  topic: s.topic,
  startedAt: now,
  endsAt: now.add(const Duration(days: focusDays)),
  goalGames: s.goalGames,
  target: s.target,
  baselineCount: s.stat.count,
  baselineGames: s.baselineGames,
);

/// Auswertung eines Fokus gegen die gespielten Partien.
class FocusProgress {
  const FocusProgress({required this.games, required this.occurrences, required this.status, required this.daysLeft});

  /// Gezählte Partien (nach dem Start analysiert, höchstens bis zum Ende des Fokus) und darin die Fehlzüge des Themas.
  final int games;
  final int occurrences;
  final FocusStatus status;
  final int daysLeft;
}

DateTime _startOfDay(DateTime t) => DateTime.utc(t.year, t.month, t.day);

/// Wertet [f] aus. Gezählt werden Partien, die am Starttag oder später und vor dem Ende gespielt wurden.
/// Ein beendeter Fokus (nicht mehr aktiv) behält seinen Status.
///
/// Ablauf: Mehr Fehlzüge als erlaubt → verfehlt (sofort); [FocusEntry.goalGames] Partien gespielt → erreicht;
/// Zeit abgelaufen ohne genug Partien → abgelaufen (kein Urteil).
FocusProgress evaluateFocus(FocusEntry f, List<GameRecord> records, DateTime now) {
  final from = _startOfDay(f.startedAt.toUtc());
  final to = f.endsAt.toUtc();
  final games = [
    for (final r in records)
      if (!r.playedAt.isBefore(from) && r.playedAt.isBefore(to)) r,
  ];
  final counted = games.length > f.goalGames
      ? (games..sort((a, b) => a.playedAt.compareTo(b.playedAt))).take(f.goalGames).toList()
      : games;
  var occ = 0;
  for (final g in counted) {
    occ += g.analysis.flagged.where((m) => topicsOf(m).contains(f.topic)).length;
  }
  final left = f.endsAt.difference(now).inDays.clamp(0, focusDays);
  final FocusStatus status;
  if (f.status != FocusStatus.active) {
    status = f.status;
  } else if (occ > f.target) {
    status = FocusStatus.missed;
  } else if (counted.length >= f.goalGames) {
    status = FocusStatus.reached;
  } else if (!now.isBefore(f.endsAt)) {
    status = FocusStatus.expired;
  } else {
    status = FocusStatus.active;
  }
  return FocusProgress(games: counted.length, occurrences: occ, status: status, daysLeft: left);
}
