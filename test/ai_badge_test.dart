import 'package:chess_mentor/ui/ai_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {String lang = 'de'}) => MaterialApp(
  locale: Locale(lang),
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('de'), Locale('en')],
  home: Scaffold(body: Builder(builder: (c) => child)),
);

void main() {
  testWidgets('KI-Text trägt das Zeichen, eingebauter Text nicht', (tester) async {
    await tester.pumpWidget(_wrap(Builder(builder: (c) => aiAwareText(c, 'Ein Text', ai: true))));
    expect(find.textContaining('✨ KI'), findsOneWidget);
    await tester.pumpWidget(_wrap(Builder(builder: (c) => aiAwareText(c, 'Ein Text', ai: false))));
    expect(find.textContaining('✨ KI'), findsNothing);
    expect(find.text('Ein Text'), findsOneWidget);
  });

  testWidgets('Antippen erklärt, was geprüft wird', (tester) async {
    await tester.pumpWidget(_wrap(Builder(builder: (c) => aiAwareText(c, 'Ein Text', ai: true))));
    await tester.tap(find.textContaining('✨ KI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Alle Zahlen, Bewertungen und Züge stammen von der Engine'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Alle Zahlen'), findsNothing);
  });

  testWidgets('englisch: AI', (tester) async {
    await tester.pumpWidget(_wrap(Builder(builder: (c) => aiAwareText(c, 'A text', ai: true)), lang: 'en'));
    expect(find.textContaining('✨ AI'), findsOneWidget);
  });
}
