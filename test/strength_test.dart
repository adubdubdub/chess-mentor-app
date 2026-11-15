import 'dart:convert';

import 'package:chess_mentor/data/game_store.dart';
import 'package:chess_mentor/data/settings.dart';
import 'package:chess_mentor/fetch/ratings.dart';
import 'package:chess_mentor/mentor/strength.dart';
import 'package:chess_mentor/mentor/strength_service.dart';
import 'package:chess_mentor/ui/strength_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _now = DateTime.utc(2026, 11, 16, 10);

void main() {
  setUpAll(sqfliteFfiInit);

  group('Stufen', () {
    test('Grenzen und Rundung', () {
      expect(levelFor(999), Level.beginner);
      expect(levelFor(1000), Level.advancedBeginner);
      expect(levelFor(1399), Level.advancedBeginner);
      expect(levelFor(1400), Level.intermediate);
      expect(levelFor(1800), Level.advanced);
      expect(roundElo(1337), 1350);
      expect(roundElo(1324), 1300);
    });
  });

  group('Online-Schätzung', () {
    test('Gewicht: Partienzahl (höchstens 50), Spielart, vorläufig nur 20 %', () {
      expect(ratingWeight(const PerfRating(perf: 'rapid', rating: 1500, games: 30)), 30);
      expect(ratingWeight(const PerfRating(perf: 'rapid', rating: 1500, games: 500)), 50);
      expect(ratingWeight(const PerfRating(perf: 'blitz', rating: 1500, games: 10)), 8);
      expect(ratingWeight(const PerfRating(perf: 'rapid', rating: 1500, games: 10, provisional: true)), 2);
    });

    test('gewichteter Mittelwert, Chess.com wird auf die Lichess-Skala gesenkt', () {
      final e = onlineEstimate(
        lichess: const [PerfRating(perf: 'rapid', rating: 1400, games: 20)],
        chessCom: const [PerfRating(perf: 'rapid', rating: 1550, games: 20)],
      )!;
      expect(e.elo, closeTo(1400, 1e-9)); // 1550 − 150 = 1400
      expect(e.weight, 40);
      expect(onlineEstimate(), isNull);
    });

    test('vorläufige Wertungen ziehen den Mittelwert kaum', () {
      final e = onlineEstimate(
        lichess: const [
          PerfRating(perf: 'rapid', rating: 1000, games: 40),
          PerfRating(perf: 'classical', rating: 2000, games: 5, provisional: true),
        ],
      )!;
      expect(e.elo, lessThan(1100));
    });
  });

  group('Schätzung aus Partien', () {
    test('Genauigkeit wird linear in Elo umgerechnet, begrenzt', () {
      expect(eloFromAccuracy(80), 1200);
      expect(eloFromAccuracy(82.5), 1325);
      expect(eloFromAccuracy(10), 600);
      expect(eloFromAccuracy(99), 2300);
    });

    test('ohne Partien keine Schätzung, Gewicht wächst bis 20 Partien', () {
      expect(gamesEstimate(accuracy: null, games: 5), isNull);
      expect(gamesEstimate(accuracy: 80, games: 0), isNull);
      expect(gamesEstimate(accuracy: 80, games: 6)!.weight, 3);
      expect(gamesEstimate(accuracy: 80, games: 60)!.weight, 10);
    });
  });

  group('Gesamtschätzung', () {
    test('manuell hat Vorrang, Sicherheit hoch', () {
      final s = estimateStrength(manual: 1650, onlineElo: 1000, onlineWeight: 80, accuracy: 70, games: 12, now: _now);
      expect((s.elo, s.source, s.confidence), (1650, StrengthSource.manual, Confidence.high));
    });

    test('ohne Daten: Ausgangswert 1200, Quelle initial, niedrige Sicherheit', () {
      final s = estimateStrength(now: _now);
      expect((s.elo, s.source, s.confidence), (1200, StrengthSource.initial, Confidence.low));
    });

    test('hohe Online-Sicherheit gilt allein', () {
      final s = estimateStrength(onlineElo: 1700, onlineWeight: 60, accuracy: 70, games: 12, now: _now);
      expect((s.elo, s.source, s.confidence), (1700, StrengthSource.online, Confidence.high));
    });

    test('nur vorläufige Online-Wertung: Mischung mit Partien und Ausgangswert, niedrige bis mittlere Sicherheit', () {
      // vorläufig 1530 (Gewicht 2), Partien-Schätzung 1450 bei 85 % (Gewicht 3,5)
      final s = estimateStrength(onlineElo: 1530, onlineWeight: 2, accuracy: 85, games: 7, now: _now);
      expect(s.elo, inInclusiveRange(1250, 1400));
      expect(s.source, StrengthSource.games);
      expect(s.confidence, Confidence.low);
    });

    test('mittlere Sicherheit ab Gewicht 10 oder 8 Partien', () {
      expect(estimateStrength(onlineElo: 1500, onlineWeight: 15, now: _now).confidence, Confidence.medium);
      expect(estimateStrength(accuracy: 80, games: 8, now: _now).confidence, Confidence.medium);
    });

    test('Glättung: ein früherer automatischer Wert rückt nur zur Hälfte', () {
      final prev = Strength(elo: 1200, source: StrengthSource.games, confidence: Confidence.low, at: _now);
      final s = estimateStrength(onlineElo: 1800, onlineWeight: 60, previous: prev, now: _now);
      expect(s.elo, 1500);
      // nach manuellem Wert kein Glätten
      final manual = Strength(elo: 2000, source: StrengthSource.manual, confidence: Confidence.high, at: _now);
      expect(estimateStrength(onlineElo: 1800, onlineWeight: 60, previous: manual, now: _now).elo, 1800);
    });

    test('Strength JSON-Rundlauf', () {
      final s = estimateStrength(onlineElo: 1500, onlineWeight: 15, accuracy: 80, games: 5, now: _now);
      final back = Strength.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect((back.elo, back.source, back.confidence, back.games, back.onlineElo), (s.elo, s.source, s.confidence, 5, 1500));
    });
  });

  group('Stufenwechsel mit Hysterese', () {
    test('ohne Zustand: sofort die passende Stufe', () {
      expect(nextLevel(null, 1500).level, Level.intermediate);
    });

    test('knapp über der Grenze: keine Änderung', () {
      var st = const LevelState(level: Level.advancedBeginner);
      st = nextLevel(st, 1420); // nur 20 über 1400
      expect((st.level, st.pending), (Level.advancedBeginner, null));
    });

    test('deutlich darüber, zweimal in Folge: Wechsel', () {
      var st = const LevelState(level: Level.advancedBeginner);
      st = nextLevel(st, 1460);
      expect((st.level, st.pending, st.pendingCount), (Level.advancedBeginner, Level.intermediate, 1));
      st = nextLevel(st, 1470);
      expect(st.level, Level.intermediate);
      expect(st.pending, isNull);
    });

    test('Rückfall in die alte Stufe setzt den Zähler zurück', () {
      var st = nextLevel(const LevelState(level: Level.advancedBeginner), 1460);
      st = nextLevel(st, 1300);
      expect((st.level, st.pending, st.pendingCount), (Level.advancedBeginner, null, 0));
    });

    test('nach unten: 50 unter der Grenze nötig', () {
      var st = const LevelState(level: Level.intermediate);
      st = nextLevel(st, 1380); // nur 20 unter 1400
      expect(st.pending, isNull);
      st = nextLevel(st, 1340);
      st = nextLevel(st, 1330);
      expect(st.level, Level.advancedBeginner);
    });

    test('manuell wechselt sofort', () {
      expect(nextLevel(const LevelState(level: Level.beginner), 1900, immediate: true).level, Level.advanced);
    });

    test('Zustand als JSON', () {
      const st = LevelState(level: Level.beginner, pending: Level.advancedBeginner, pendingCount: 1);
      final back = LevelState.tryParse(jsonEncode(st.toJson()))!;
      expect((back.level, back.pending, back.pendingCount), (Level.beginner, Level.advancedBeginner, 1));
      expect(LevelState.tryParse('kaputt'), isNull);
    });
  });

  group('Wertungen lesen', () {
    test('Lichess: nur Spielarten mit Partien, vorläufig erkannt, Varianten ignoriert', () {
      final perfs = parseLichessPerfs({
        'perfs': {
          'rapid': {'games': 1, 'rating': 1530, 'prov': true},
          'classical': {'games': 5, 'rating': 1498, 'prov': true},
          'blitz': {'games': 0, 'rating': 1500, 'prov': true},
          'chess960': {'games': 9, 'rating': 1400},
          'puzzle': {'games': 50, 'rating': 1800},
        },
      });
      expect(perfs.map((p) => p.perf), ['rapid', 'classical']);
      expect(perfs.first.provisional, isTrue);
      expect(perfs.last.games, 5);
    });

    test('Chess.com: Partien aus der Bilanz, unter 10 vorläufig, ohne Bilanz ignoriert', () {
      final perfs = parseChessComStats({
        'chess_rapid': {'last': {'rating': 1200}, 'record': {'win': 8, 'loss': 5, 'draw': 2}},
        'chess_blitz': {'last': {'rating': 900}, 'record': {'win': 2, 'loss': 3, 'draw': 0}},
        'chess_bullet': {'last': {'rating': 800}},
        'tactics': {'highest': {'rating': 2000}},
        'chess_daily': {'last': {'rating': 1100}, 'record': {'win': 0, 'loss': 0, 'draw': 0}},
      });
      expect(perfs.map((p) => (p.perf, p.games, p.provisional)), [('rapid', 15, false), ('blitz', 5, true)]);
    });
  });

  group('Dienst', () {
    Future<(GameStore, Settings)> setup(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      return (
        await GameStore.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
        await Settings.load(),
      );
    }

    http.Client client() => MockClient((req) async {
      if (req.url.host == 'lichess.org') {
        return http.Response(
          jsonEncode({'perfs': {'rapid': {'games': 60, 'rating': 1650, 'prov': false}}}),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    test('mit Konto: Online-Wertung hoher Sicherheit gewinnt, Stufe gesetzt', () async {
      final (store, settings) = await setup({'lichessUser': 'tester'});
      final s = await StrengthService(store, settings, client: client()).refresh(online: true, now: _now);
      expect((s.elo, s.source, s.confidence), (1650, StrengthSource.online, Confidence.high));
      expect(settings.strength!.elo, 1650);
      expect(settings.level, Level.intermediate);
      // ohne Netz bleibt der zuletzt bekannte Online-Wert
      final again = await StrengthService(store, settings, client: MockClient((_) async => http.Response('', 500))).refresh(online: true, now: _now);
      expect(again.onlineElo, closeTo(1650, 1e-9));
    });

    test('manueller Modus überschreibt und wechselt die Stufe sofort', () async {
      final (store, settings) = await setup({'strengthManual': true, 'strengthManualElo': 900});
      await StrengthService(store, settings).refresh(now: _now);
      expect(settings.elo, 900);
      expect(settings.level, Level.beginner);
    });

    test('ohne alles: Ausgangswert und Stufe 2', () async {
      final (store, settings) = await setup({});
      expect(settings.elo, defaultElo);
      expect(settings.level, Level.advancedBeginner);
      await StrengthService(store, settings).refresh(now: _now);
      expect(settings.strength!.source, StrengthSource.initial);
    });
  });

  group('Ansicht', () {
    Widget wrap(Widget child, {String lang = 'de'}) => MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('de'), Locale('en')],
      home: Scaffold(body: child),
    );

    testWidgets('Schätzung mit Quelle, Stufe und Stufenliste', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = Strength(elo: 1337, source: StrengthSource.online, confidence: Confidence.medium, at: _now, games: 12);
      await tester.pumpWidget(wrap(StrengthView(strength: s, level: Level.advancedBeginner, manual: false, manualElo: 1200, toAi: true)));
      expect(find.text('ca. 1350 Elo'), findsOneWidget);
      expect(find.textContaining('Fortgeschrittener Anfänger (1000–1400)'), findsOneWidget);
      expect(find.textContaining('Online-Wertung · mittlere Sicherheit · 12 Partien'), findsOneWidget);
      expect(find.text('Einsteiger'), findsOneWidget);
    });

    testWidgets('manuell: Eingabe wird begrenzt und gemeldet, Schalter für die KI', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      int? saved;
      bool? toAi;
      await tester.pumpWidget(
        wrap(
          StrengthView(
            strength: null,
            level: Level.advancedBeginner,
            manual: true,
            manualElo: 1200,
            toAi: true,
            onManualElo: (v) => saved = v,
            onToAi: (v) => toAi = v,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '3500');
      await tester.tap(find.text('Speichern'));
      expect(saved, 2800);
      await tester.tap(find.byType(Switch));
      expect(toAi, isFalse);
    });

    testWidgets('automatisch: Neu schätzen, englisch, schmales Display', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.75, 740 * 2.75);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      var refreshed = false;
      await tester.pumpWidget(
        wrap(
          StrengthView(strength: null, level: Level.advancedBeginner, manual: false, manualElo: 1200, toAi: true, onRefresh: () => refreshed = true),
          lang: 'en',
        ),
      );
      expect(find.text('Estimate again'), findsOneWidget);
      await tester.tap(find.text('Estimate again'));
      expect(refreshed, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
