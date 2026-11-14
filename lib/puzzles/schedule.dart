/// Wiederholungsplan der Puzzles wie im Telegram-Bot (db.py: INTERVALS, grade).
library;

/// Tage bis zur nächsten Wiederholung je Stufe; nach der letzten Stufe gilt ein Puzzle als gemeistert.
const intervals = [1, 3, 7, 21, 60];

/// Kalendertag ohne Uhrzeit (lokal).
DateTime day(DateTime t) => DateTime(t.year, t.month, t.day);

String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Fälligkeit eines neuen Puzzles: morgen.
String firstDue(DateTime today) => isoDay(day(today).add(Duration(days: intervals.first)));

/// Neue Stufe und Fälligkeit nach einem Versuch; null = gemeistert.
/// Gelöst rückt eine Stufe weiter, falsch oder mit angezeigter Lösung beginnt es wieder bei Stufe 0 (morgen).
(int, String?) grade(int level, bool solved, DateTime today) {
  final next = solved ? level + 1 : 0;
  if (next >= intervals.length) return (next, null);
  return (next, isoDay(day(today).add(Duration(days: intervals[next]))));
}

/// Wie viele Puzzles an [date] fällig wären, wenn bis dahin keins gelöst wird (für die Erinnerungen), höchstens [perDay].
int dueOn(Iterable<String> dueDates, DateTime date, int perDay) {
  final key = isoDay(day(date));
  final n = dueDates.where((d) => d.compareTo(key) <= 0).length;
  return n < perDay ? n : perDay;
}

/// Ausgang eines Puzzle-Versuchs.
enum Attempt {
  /// Erster Versuch, ohne Tipp: das Puzzle steigt eine Stufe auf.
  first,

  /// Gelöst, aber mit Tipp oder erst im zweiten Versuch: bleibt auf seiner Stufe.
  second,

  /// Lösung angezeigt oder zweimal falsch: zurück auf morgen.
  shown,
}

/// Neue Stufe und Fälligkeit nach einem Versuch mit [result]; null = gemeistert.
(int, String?) gradeAttempt(int level, Attempt result, DateTime today) => switch (result) {
  Attempt.first => grade(level, true, today),
  Attempt.second => (level, isoDay(day(today).add(Duration(days: intervals[level.clamp(0, intervals.length - 1)])))),
  Attempt.shown => grade(level, false, today),
};
