import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/game_store.dart';
import 'data/settings.dart';
import 'engine/analysis_service.dart';
import 'engine/net_manager.dart';
import 'ui/app_scope.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ChessgroundImages.instance.loadAll(PieceSet.cburnettAssets);
  final store = await GameStore.open();
  final settings = await Settings.load();
  final service = AnalysisService(store, settings, NetManager());
  service.resume();
  runApp(AppScope(store: store, settings: settings, service: service, child: const ChessMentorApp()));
}

class ChessMentorApp extends StatelessWidget {
  const ChessMentorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF4A7C59);
    return MaterialApp(
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
