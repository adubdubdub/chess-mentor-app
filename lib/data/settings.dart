import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/mobile_engine.dart';

/// Woher die Texte kommen: Textbausteine (offline), Heimserver (KI-Gateway) oder eigener Schlüssel.
enum AiMode { templates, home, ownKey }

/// Einstellungen der App (shared_preferences).
class Settings extends ChangeNotifier {
  Settings._(this._prefs);

  final SharedPreferences _prefs;

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  EngineNet get net => EngineNet.values.byName(_prefs.getString('net') ?? EngineNet.light.name);
  set net(EngineNet v) => _set(() => _prefs.setString('net', v.name));

  /// Suchtiefe je Stellung; der Bot nutzt 16.
  int get depth => _prefs.getInt('depth') ?? 16;
  set depth(int v) => _set(() => _prefs.setInt('depth', v));

  int get threads => _prefs.getInt('threads') ?? 1;
  set threads(int v) => _set(() => _prefs.setInt('threads', v));

  /// Höchstens so viele Puzzles pro Tag (Bot: 5).
  int get puzzlesPerDay => _prefs.getInt('puzzlesPerDay') ?? 5;
  set puzzlesPerDay(int v) => _set(() => _prefs.setInt('puzzlesPerDay', v));

  /// Analysen im Hintergrund weiterrechnen (Vordergrunddienst mit Benachrichtigung, auch bei ausgeschaltetem Bildschirm).
  bool get backgroundAnalysis => _prefs.getBool('backgroundAnalysis') ?? true;
  set backgroundAnalysis(bool v) => _set(() => _prefs.setBool('backgroundAnalysis', v));

  /// Benutzernamen für den Abruf von Online-Partien und Zeitpunkt (ms) der zuletzt geholten Partie je Dienst.
  String get lichessUser => _prefs.getString('lichessUser') ?? '';
  set lichessUser(String v) => _set(() => _prefs.setString('lichessUser', v.trim()));
  String get chesscomUser => _prefs.getString('chesscomUser') ?? '';
  set chesscomUser(String v) => _set(() => _prefs.setString('chesscomUser', v.trim()));
  int? get lichessSince => _prefs.getInt('lichessSince');
  set lichessSince(int? v) => _set(() => v == null ? _prefs.remove('lichessSince') : _prefs.setInt('lichessSince', v));
  int? get chesscomSince => _prefs.getInt('chesscomSince');
  set chesscomSince(int? v) => _set(() => v == null ? _prefs.remove('chesscomSince') : _prefs.setInt('chesscomSince', v));

  /// Beim Start höchstens einmal am Tag abrufen.
  bool get autoFetch => _prefs.getBool('autoFetch') ?? true;
  set autoFetch(bool v) => _set(() => _prefs.setBool('autoFetch', v));
  DateTime? get lastFetch => DateTime.tryParse(_prefs.getString('lastFetch') ?? '');
  set lastFetch(DateTime? v) => _set(() => v == null ? _prefs.remove('lastFetch') : _prefs.setString('lastFetch', v.toIso8601String()));

  /// Benachrichtigungen zum Wochenfokus (Wochenanfang, Ergebnis).
  bool get focusReminders => _prefs.getBool('focusReminders') ?? true;
  set focusReminders(bool v) => _set(() => _prefs.setBool('focusReminders', v));

  bool get reminders => _prefs.getBool('reminders') ?? true;
  set reminders(bool v) => _set(() => _prefs.setBool('reminders', v));

  /// Uhrzeit der Erinnerung in Minuten nach Mitternacht (Bot: 18:00).
  int get reminderMinutes => _prefs.getInt('reminderMinutes') ?? 18 * 60;
  set reminderMinutes(int v) => _set(() => _prefs.setInt('reminderMinutes', v));

  /// Filter der Liste „Alle markierten Züge“: review (besprochen), blunder, mistake, inaccuracy.
  Set<String> get momentFilter => (_prefs.getStringList('momentFilter') ?? const ['review']).toSet();
  set momentFilter(Set<String> v) => _set(() => _prefs.setStringList('momentFilter', v.toList()));

  /// Hinweis zur Bedienung des Verlaufs schon gesehen (nach erstem Antippen oder Zoomen).
  bool get chartHintSeen => _prefs.getBool('chartHintSeen') ?? false;
  set chartHintSeen(bool v) => _set(() => _prefs.setBool('chartHintSeen', v));

  AiMode get aiMode => AiMode.values.byName(_prefs.getString('aiMode') ?? AiMode.templates.name);
  set aiMode(AiMode v) => _set(() => _prefs.setString('aiMode', v.name));

  /// Basis-URL und Modell je Weg (Schlüssel liegen im Android-Keystore, siehe SecretStore).
  String aiBaseUrl(AiMode m) => _prefs.getString('aiBaseUrl.${m.name}') ?? '';
  void setAiBaseUrl(AiMode m, String v) => _set(() => _prefs.setString('aiBaseUrl.${m.name}', v.trim()));

  String aiModel(AiMode m) => _prefs.getString('aiModel.${m.name}') ?? (m == AiMode.home ? 'sonnet' : '');
  void setAiModel(AiMode m, String v) => _set(() => _prefs.setString('aiModel.${m.name}', v.trim()));

  void _set(Future<bool> Function() write) {
    write();
    notifyListeners();
  }
}
