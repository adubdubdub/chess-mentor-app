/// Texte auf Deutsch und Englisch, abhängig von der Systemsprache.
library;

import 'package:flutter/widgets.dart';

import '../analysis/analysis.dart';
import '../analysis/chess_utils.dart';

class Tr {
  const Tr(this.de);

  final bool de;

  static Tr of(BuildContext context) => Tr(Localizations.localeOf(context).languageCode == 'de');

  String t(String de, String en) => this.de ? de : en;

  /// SAN in Landessprache (deutsch: S, L, T, D).
  String san(String s) => de ? germanSan(s) : s;

  String get appTitle => t('Schach-Mentor', 'Chess Mentor');
  String get games => t('Partien', 'Games');
  String get addGame => t('Partie hinzufügen', 'Add game');
  String get paste => t('PGN einfügen', 'Paste PGN');
  String get openFile => t('Datei öffnen', 'Open file');
  String get emptyHint => t(
    'Noch keine Partien.\n\nTeile eine Partie aus der Lichess-App („PGN teilen“) oder füge eine PGN ein.',
    'No games yet.\n\nShare a game from the Lichess app (“Share PGN”) or paste a PGN.',
  );
  String get invalidPgn => t('Keine gültige Partie gefunden.', 'No valid game found.');
  String get alreadyThere => t('Diese Partie ist schon da.', 'This game is already here.');
  String get whichColor => t('Welche Farbe hattest du?', 'Which side did you play?');
  String get white => t('Weiß', 'White');
  String get black => t('Schwarz', 'Black');
  String get cancel => t('Abbrechen', 'Cancel');
  String get ok => 'OK';
  String get delete => t('Löschen', 'Delete');
  String get analyse => t('Analysieren', 'Analyse');
  String get waitingColor => t('Farbe wählen', 'Choose side');
  String get queued => t('wartet auf Analyse', 'waiting for analysis');
  String get error => t('Fehler bei der Analyse', 'Analysis failed');
  String get accuracy => t('Genauigkeit', 'Accuracy');
  String get keyMoments => t('Schlüsselmomente', 'Key moments');
  String get noMistakes =>
      t('Keine Fehler ab Ungenauigkeit – stark gespielt!', 'No inaccuracies or worse – well played!');
  String get engine => 'Engine';
  String get played => t('Gespielt', 'Played');
  String get better => t('Besser', 'Better');
  String get bestLine => t('Beste Fortsetzung', 'Best line');
  String get replyLine => t('Nach deinem Zug', 'After your move');
  String get winChance => t('Gewinnchance', 'Winning chance');
  String get alternatives => t('Engine-Züge', 'Engine moves');
  String get puzzles => t('Puzzles', 'Puzzles');

  String progress(int done, int total) => t('Stellung $done von $total', 'Position $done of $total');
  String youPlayed(String side) => t('Du: $side', 'You: $side');

  /// Anzahl mit passender Mehrzahl: „1 Fehler“, „3 Ungenauigkeiten“, „2 Blunders“.
  String mistakeCount(MistakeClass c, int n) => switch (c) {
    MistakeClass.blunder => '$n ${t('Patzer', n == 1 ? 'Blunder' : 'Blunders')}',
    MistakeClass.mistake => '$n ${t('Fehler', n == 1 ? 'Mistake' : 'Mistakes')}',
    MistakeClass.inaccuracy =>
      '$n ${t(n == 1 ? 'Ungenauigkeit' : 'Ungenauigkeiten', n == 1 ? 'Inaccuracy' : 'Inaccuracies')}',
  };

  String mistake(MistakeClass c) => switch (c) {
    MistakeClass.blunder => t('Patzer', 'Blunder'),
    MistakeClass.mistake => t('Fehler', 'Mistake'),
    MistakeClass.inaccuracy => t('Ungenauigkeit', 'Inaccuracy'),
  };

  String phase(GamePhase p) => switch (p) {
    GamePhase.opening => t('Eröffnung', 'Opening'),
    GamePhase.middlegame => t('Mittelspiel', 'Middlegame'),
    GamePhase.endgame => t('Endspiel', 'Endgame'),
  };

  String motif(Motif m) => switch (m.code) {
    'mate_missed' => t('Matt in ${m.n} verpasst', 'Missed mate in ${m.n}'),
    'allows_mate' => t('Der Partiezug lässt Matt zu', 'Your move allows mate'),
    'hangs_material' => t('Der Partiezug stellt Material ein', 'Your move loses material'),
    'wins_material' => t(
      'Die beste Fortsetzung gewinnt etwa ${m.n} Bauerneinheiten',
      'The best line wins about ${m.n} pawns',
    ),
    'best_is_check' => t('Der beste Zug gibt Schach', 'The best move is a check'),
    'best_is_capture' => t('Der beste Zug schlägt', 'The best move is a capture'),
    _ => m.code,
  };

  // Engine-Seite
  String get net => t('Netz', 'Network');
  String get netLight => t('Klein (eingebaut, ~1 MB)', 'Small (built in, ~1 MB)');
  String get netFull => t('Groß (genauer, Download)', 'Large (stronger, download)');
  String netDownload(int mb) => t('Großes Netz laden ($mb MB)', 'Download large network ($mb MB)');
  String get netDelete => t('Großes Netz löschen', 'Delete large network');
  String get netWifiHint =>
      t('Lieber im WLAN laden. Quelle: tests.stockfishchess.org', 'Better use Wi-Fi. Source: tests.stockfishchess.org');
  String get depth => t('Suchtiefe', 'Search depth');
  String get threads => 'Threads';
  String get benchmark => t('Geschwindigkeit messen', 'Measure speed');
  String get benchmarkHint => t(
    'Rechnet 20 Stellungen der Opernpartie mit jedem verfügbaren Netz.',
    'Analyses 20 positions of the Opera game with every available network.',
  );
  String perPosition(double s) => t('${s.toStringAsFixed(2)} s je Stellung', '${s.toStringAsFixed(2)} s per position');
  String get busyHint => t('Während einer Analyse nicht möglich.', 'Not possible during an analysis.');
}
