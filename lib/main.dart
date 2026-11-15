import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ai/mentor_ai.dart';
import 'ai/secrets.dart';
import 'data/game_store.dart';
import 'data/settings.dart';
import 'engine/analysis_service.dart';
import 'engine/net_manager.dart';
import 'fetch/fetch_service.dart';
import 'mentor/focus_keeper.dart';
import 'puzzles/reminders.dart';
import 'ui/app_scope.dart';
import 'ui/home_page.dart';
import 'ui/mentor_page.dart';
import 'ui/puzzle_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ChessgroundImages.instance.loadAll(PieceSet.cburnettAssets);
  final store = await GameStore.open();
  final settings = await Settings.load();
  final service = AnalysisService(store, settings, NetManager());
  final reminders = Reminders(store, settings);
  final secrets = SecretStore();
  final ai = MentorAi(settings, secrets, store);
  final fetch = FetchService(store, settings, service);
  await reminders.init();
  service.onAnalysed = () async {
    await reminders.reschedule();
    await FocusKeeper(store, onVerdict: reminders.showFocusResult).refresh(); // Wochenfokus nach jeder Analyse auswerten
    await reminders.rescheduleFocus();
  };
  settings.addListener(reminders.reschedule);
  reminders.onOpen = _openFromReminder;
  service.resume();
  runApp(
    AppScope(
      store: store,
      settings: settings,
      service: service,
      reminders: reminders,
      ai: ai,
      fetch: fetch,
      secrets: secrets,
      child: const ChessMentorApp(),
    ),
  );
  fetch.autoFetch(); // ohne await: Fehler (kein Netz) dürfen den Start nicht verzögern
  await reminders.requestPermission();
  await reminders.reschedule();
  final launch = await reminders.launchedFromReminder();
  if (launch != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromReminder(launch.payload));
  }
}

/// Navigator für das Öffnen der Puzzles aus einer Erinnerung heraus.
final navigatorKey = GlobalKey<NavigatorState>();

void _openPuzzles() => navigatorKey.currentState?.push(MaterialPageRoute<void>(builder: (_) => const PuzzlePage()));

/// Puzzle-Erinnerungen öffnen die Puzzles, Wochenfokus-Meldungen die Mentor-Seite.
void _openFromReminder(String? payload) => payload == mentorPayload
    ? navigatorKey.currentState?.push(MaterialPageRoute<void>(builder: (_) => const MentorPage()))
    : _openPuzzles();

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
