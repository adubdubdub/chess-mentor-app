import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/game_store.dart';
import 'data/settings.dart';
import 'engine/analysis_service.dart';
import 'engine/net_manager.dart';
import 'puzzles/reminders.dart';
import 'ui/app_scope.dart';
import 'ui/home_page.dart';
import 'ui/puzzle_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ChessgroundImages.instance.loadAll(PieceSet.cburnettAssets);
  final store = await GameStore.open();
  final settings = await Settings.load();
  final service = AnalysisService(store, settings, NetManager());
  final reminders = Reminders(store, settings);
  await reminders.init();
  service.onAnalysed = reminders.reschedule;
  settings.addListener(reminders.reschedule);
  reminders.onOpen = _openPuzzles;
  service.resume();
  runApp(
    AppScope(store: store, settings: settings, service: service, reminders: reminders, child: const ChessMentorApp()),
  );
  await reminders.requestPermission();
  await reminders.reschedule();
  if (await reminders.launchedFromReminder()) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPuzzles());
  }
}

/// Navigator für das Öffnen der Puzzles aus einer Erinnerung heraus.
final navigatorKey = GlobalKey<NavigatorState>();

void _openPuzzles() => navigatorKey.currentState?.push(MaterialPageRoute<void>(builder: (_) => const PuzzlePage()));

class ChessMentorApp extends StatelessWidget {
  const ChessMentorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF4A7C59);
    return MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateTitle: (context) =>
          Localizations.localeOf(context).languageCode == 'de' ? 'Schach-Mentor' : 'Chess Mentor',
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('de'), Locale('en')],
      home: const HomePage(),
    );
  }
}
