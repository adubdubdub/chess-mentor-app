import 'package:chess_mentor/mentor/topic_info.dart';
import 'package:chess_mentor/mentor/topics.dart';
import 'package:chess_mentor/ui/accuracy_chart.dart';
import 'package:chess_mentor/ui/profile_view.dart';
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

List<AccuracyPoint> _series(List<int> values) => [
  for (var i = 0; i < values.length; i++)
    (at: DateTime.utc(2026, 11, 1 + i), accuracy: values[i], gameId: 100 + i, title: 'A$i – B$i'),
];

void main() {
  test('Balkenskala: nie ein voller Balken, mindestens 10', () {
    expect(barScale(7.1), 10); // 7,1 füllt 71 %
    expect(barScale(0), 10);
    expect(barScale(29.2), 45); // 29,2 × 1,4 = 40,9 -> 45
    expect(7.1 / barScale(7.1), lessThan(0.8));
    expect(29.2 / barScale(29.2), lessThan(0.7));
  });

  testWidgets('Genauigkeitsdiagramm: Tippen wählt die nächste Partie und zeigt Datum, Wert, Partie', (tester) async {
    int? opened;
    await tester.pumpWidget(_wrap(AccuracyChart(series: _series([70, 85, 60, 90, 80]), onOpen: (id) => opened = id)));
    expect(find.textContaining('Tippe oder wische'), findsOneWidget);
    final box = tester.getRect(find.byType(CustomPaint).last);
    // ganz rechts tippen -> letzte Partie
    await tester.tapAt(Offset(box.right - 12, box.center.dy));
    await tester.pump();
    expect(find.textContaining('05.11. · 80 % · A4 – B4'), findsOneWidget);
    await tester.tap(find.text('Partie öffnen'));
    expect(opened, 104);
    // ganz links -> erste Partie
    await tester.tapAt(Offset(box.left + 40, box.center.dy));
    await tester.pump();
    expect(find.textContaining('01.11. · 70 % · A0 – B0'), findsOneWidget);
  });

  testWidgets('Diagramm mit zwei Partien und schmalem Display ohne Überlauf', (tester) async {
    tester.view.physicalSize = const Size(360 * 2.75, 740 * 2.75);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    for (final lang in ['de', 'en']) {
      await tester.pumpWidget(_wrap(AccuracyChart(series: _series([88, 91])), lang: lang));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Info-Blatt: Erklärung, Warum, vier Schritte und Training für jedes Thema', (tester) async {
    for (final t in Topic.values) {
      await tester.pumpWidget(_wrap(SizedBox(height: 900, child: TopicInfoView(topic: t))));
      expect(find.text('Warum passiert das?'), findsOneWidget, reason: t.name);
      expect(find.text('So machst du es besser'), findsOneWidget);
      expect(find.text('So trainierst du es'), findsOneWidget);
      expect(find.text('4'), findsOneWidget, reason: '${t.name}: vier Schritte');
    }
  });

  testWidgets('Info-Texte vollständig, deutsch und englisch', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(_wrap(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    for (final de in [true, false]) {
      final tr = Tr(de);
      for (final t in Topic.values) {
        final i = tr.topicInfo(t);
        expect([i.what, i.why, i.practice].every((x) => x.length > 20), isTrue, reason: '${t.name} $de');
        expect(i.how.length, 4);
        expect(i.how.every((x) => x.length > 20), isTrue);
      }
    }
    expect(ctx, isNotNull);
  });

  testWidgets('showTopicInfo öffnet das Blatt', (tester) async {
    await tester.pumpWidget(
      _wrap(Builder(builder: (c) => TextButton(onPressed: () => showTopicInfo(c, Topic.missedMaterial), child: const Text('info')))),
    );
    await tester.tap(find.text('info'));
    await tester.pumpAndSettle();
    expect(find.text('Material verpasst'), findsOneWidget);
    expect(find.text('So machst du es besser'), findsOneWidget);
  });
}
