import 'package:chess_mentor/puzzles/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 8, 18, 30);

  test('neues Puzzle ist morgen fällig', () => expect(firstDue(today), '2026-11-09'));

  test('gelöst: Stufen 1 · 3 · 7 · 21 · 60 Tage, danach gemeistert', () {
    expect(grade(0, true, today), (1, '2026-11-11'));
    expect(grade(1, true, today), (2, '2026-11-15'));
    expect(grade(2, true, today), (3, '2026-11-29'));
    expect(grade(3, true, today), (4, '2027-01-07'));
    expect(grade(4, true, today), (5, null));
  });

  test('falsch: zurück auf Stufe 0, morgen wieder', () {
    expect(grade(3, false, today), (0, '2026-11-09'));
  });

  test('Vorschau der fälligen Anzahl je Tag, gedeckelt', () {
    final dues = ['2026-11-09', '2026-11-09', '2026-11-12', '2026-11-30'];
    expect(dueOn(dues, DateTime(2026, 11, 8), 5), 0);
    expect(dueOn(dues, DateTime(2026, 11, 9), 5), 2);
    expect(dueOn(dues, DateTime(2026, 11, 12), 5), 3);
    expect(dueOn(dues, DateTime(2026, 12, 1), 2), 2);
  });
}
