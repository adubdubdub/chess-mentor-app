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
