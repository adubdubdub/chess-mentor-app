import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/mobile_engine.dart';

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

  void _set(Future<bool> Function() write) {
    write();
    notifyListeners();
  }
}
