import 'package:chess_mentor/mentor/focus.dart';
import 'package:chess_mentor/mentor/focus_keeper.dart';
import 'package:chess_mentor/mentor/focus_notice.dart';
import 'package:chess_mentor/mentor/level_texts_data.dart';
import 'package:chess_mentor/mentor/profile.dart';
import 'package:chess_mentor/mentor/strength.dart';
import 'package:chess_mentor/mentor/topic_info.dart';
import 'package:chess_mentor/mentor/topic_texts.dart';
import 'package:chess_mentor/mentor/topics.dart';
import 'package:chess_mentor/ui/focus_card.dart';
import 'package:chess_mentor/ui/strings.dart';
import 'package:chess_mentor/ui/topic_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {String lang = 'de'}) => MaterialApp(
  locale: Locale(lang),
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('de'), Locale('en')],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('Daten', () {
    test('jedes Thema hat vier Stufen, alle Texte gefüllt und unterschiedlich', () {
      for (final t in Topic.values) {
        final rows = levelTexts[t]!;
        expect(rows, hasLength(4), reason: t.name);
        for (final r in rows) {
          expect([r.stepDe, r.stepEn, r.checkDe, r.checkEn].every((x) => x.length > 20), isTrue, reason: t.name);
        }
        expect({for (final r in rows) r.stepDe}, hasLength(4), reason: '${t.name}: Schritte unterscheiden sich');
        expect({for (final r in rows) r.checkDe}, hasLength(4), reason: '${t.name}: Prüffragen unterscheiden sich');
        expect({for (final r in rows) r.checkEn}, hasLength(4));
      }
    });

    test('Prüffragen enden mit Fragezeichen', () {
      for (final t in Topic.values) {
        for (final r in levelTexts[t]!) {
          expect(r.checkDe.endsWith('?'), isTrue, reason: r.checkDe);
          expect(r.checkEn.endsWith('?'), isTrue, reason: r.checkEn);
        }
      }
    });
  });

  group('Info-Blätter und Prüffragen je Stufe', () {
    test('drei gemeinsame Schritte, der vierte richtet sich nach der Stufe', () {
      for (final de in [true, false]) {
        final tr = Tr(de);
        for (final t in Topic.values) {
          final general = tr.topicInfo(t);
          final byLevel = [for (final l in Level.values) tr.topicInfo(t, level: l)];
          for (final i in byLevel) {
            expect(i.how, hasLength(4));
            expect(i.how.take(3).toList(), general.how.take(3).toList());
          }
          expect({for (final i in byLevel) i.how.last}, hasLength(4), reason: t.name);
          expect(byLevel.first.how.last, tr.topicStepFor(t, Level.beginner));
        }
      }
    });

    test('ohne Stufe bleibt es beim bisherigen allgemeinen Inhalt', () {
      final tr = Tr(true);
      expect(tr.topicInfo(Topic.hangsPiece).practice, contains(tr.topicCheck(Topic.hangsPiece)));
      expect(tr.topicCheckFor(Topic.hangsPiece, null), tr.topicCheck(Topic.hangsPiece));
    });

    test('Training nennt die Prüffrage der Stufe', () {
      final tr = Tr(true);
      for (final l in Level.values) {
        expect(tr.topicInfo(Topic.missedMaterial, level: l).practice, contains(tr.topicCheckFor(Topic.missedMaterial, l)));
      }
    });

    testWidgets('Info-Blatt zeigt den Schritt der Stufe', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tr = Tr(true);
      await tester.pumpWidget(_wrap(SizedBox(height: 2500, child: TopicInfoView(topic: Topic.hangsPiece, level: Level.advanced))));
      expect(find.textContaining(tr.topicStepFor(Topic.hangsPiece, Level.advanced).substring(0, 30)), findsOneWidget);
      expect(find.textContaining(tr.topicStepFor(Topic.hangsPiece, Level.beginner).substring(0, 30)), findsNothing);
    });
  });

  group('Wochenfokus mit Stufe', () {
    final start = DateTime.utc(2026, 11, 16);
    final focus = FocusEntry(
      topic: Topic.missedMaterial,
      startedAt: start,
      endsAt: start.add(const Duration(days: 7)),
      goalGames: 3,
      target: 2,
      baselineCount: 6,
      baselineGames: 6,
    );

    test('Wochenmeldung nennt die Prüffrage der Stufe', () {
      final tr = Tr(true);
      final n = weeklyNotice(tr, active: focus, at: DateTime.utc(2026, 11, 20), hasSuggestion: true, level: Level.beginner)!;
      expect(n.body, tr.topicCheckFor(Topic.missedMaterial, Level.beginner));
      final other = weeklyNotice(tr, active: focus, at: DateTime.utc(2026, 11, 20), hasSuggestion: true, level: Level.advanced)!;
      expect(other.body, isNot(n.body));
    });

    testWidgets('Fokuskarte zeigt die Prüffrage der Stufe, ohne Stufe die allgemeine', (tester) async {
      final tr = Tr(true);
      final state = FocusState(
        active: focus,
        progress: const FocusProgress(games: 0, occurrences: 0, status: FocusStatus.active, daysLeft: 6),
      );
      await tester.pumpWidget(_wrap(FocusCard(state: state, suggestions: const [], profile: buildProfile(const []), level: Level.beginner)));
      expect(find.textContaining(tr.topicCheckFor(Topic.missedMaterial, Level.beginner)), findsOneWidget);
      await tester.pumpWidget(_wrap(FocusCard(state: state, suggestions: const [], profile: buildProfile(const []))));
      expect(find.textContaining(tr.topicCheck(Topic.missedMaterial)), findsOneWidget);
    });
  });
}
