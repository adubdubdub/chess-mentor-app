/// Vordergrunddienst für Analysen: hält die App bei ausgeschaltetem Bildschirm am Laufen und zeigt den Fortschritt
/// als Benachrichtigung. Die Analyse selbst läuft weiter im Haupt-Isolate (AnalysisService); der Dienst hält nur den
/// Prozess und den Wake-Lock.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class BackgroundNotice {
  bool _inited = false;
  bool _running = false;
  String _last = '';

  void _init() {
    if (_inited) return;
    _inited = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'analysis',
        channelName: 'Analyse',
        channelDescription: 'Fortschritt laufender Partieanalysen',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Dienst starten oder die Benachrichtigung aktualisieren. Fehler (z. B. fehlende Berechtigung) stoppen die Analyse nicht.
  Future<void> show(String title, String text) async {
    if (text == _last && _running) return;
    _last = text;
    try {
      _init();
      if (_running) {
        await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text);
      } else {
        final r = await FlutterForegroundTask.startService(
          serviceId: 4711,
          serviceTypes: [ForegroundServiceTypes.dataSync],
          notificationTitle: title,
          notificationText: text,
        );
        _running = r is ServiceRequestSuccess;
        if (!_running) debugPrint('Vordergrunddienst nicht gestartet: $r');
      }
    } catch (e) {
      debugPrint('Vordergrunddienst: $e');
    }
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _last = '';
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      debugPrint('Vordergrunddienst beenden: $e');
    }
  }
}
