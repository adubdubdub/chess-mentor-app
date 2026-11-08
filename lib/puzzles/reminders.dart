/// Tägliche Erinnerung an fällige Puzzles, ganz ohne Server oder Hintergrunddienst.
///
/// Solange nichts gelöst wird, stehen die Fälligkeiten fest. Deshalb plant die App die Erinnerungen der nächsten
/// 14 Tage mit der jeweils fälligen Anzahl im Voraus und plant nach jeder Änderung neu.
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/game_store.dart';
import '../data/settings.dart';
import '../ui/strings.dart';
import 'schedule.dart';

const _firstId = 100;
const _days = 14;

class Reminders {
  Reminders(this.store, this.settings);

  final GameStore store;
  final Settings settings;
  final _plugin = FlutterLocalNotificationsPlugin();

  /// Wird aufgerufen, wenn eine Erinnerung angetippt wurde (auch beim Kaltstart).
  void Function()? onOpen;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (_) => onOpen?.call(),
    );
  }

  /// Wurde die App über eine Erinnerung gestartet?
  Future<bool> launchedFromReminder() async =>
      (await _plugin.getNotificationAppLaunchDetails())?.didNotificationLaunchApp ?? false;

  /// Ab Android 13 muss der Nutzer Benachrichtigungen erlauben.
  Future<void> requestPermission() async => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  /// Erinnerungen der nächsten 14 Tage neu planen.
  Future<void> reschedule() async {
    for (var i = 0; i < _days; i++) {
      await _plugin.cancel(id: _firstId + i);
    }
    if (!settings.reminders) return;
    final tr = Tr(PlatformDispatcher.instance.locale.languageCode == 'de');
    final dues = await store.openDueDates();
    final doneToday = await store.doneToday();
    final now = tz.TZDateTime.now(tz.local);
    final minutes = settings.reminderMinutes;
    for (var i = 0; i < _days; i++) {
      final at = tz.TZDateTime(tz.local, now.year, now.month, now.day + i, minutes ~/ 60, minutes % 60);
      if (!at.isAfter(now)) continue;
      var n = dueOn(dues, at, settings.puzzlesPerDay);
      if (i == 0) n = (settings.puzzlesPerDay - doneToday).clamp(0, n);
      if (n == 0) continue;
      await _plugin.zonedSchedule(
        id: _firstId + i,
        scheduledDate: at,
        title: tr.t('🧩 Puzzles aus deinen Partien', '🧩 Puzzles from your games'),
        body: n == 1
            ? tr.t('1 Puzzle ist fällig.', '1 puzzle is due.')
            : tr.t('$n Puzzles sind fällig.', '$n puzzles are due.'),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'puzzles',
            tr.t('Puzzle-Erinnerung', 'Puzzle reminder'),
            channelDescription: tr.t('Tägliche Erinnerung an fällige Puzzles', 'Daily reminder for due puzzles'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
