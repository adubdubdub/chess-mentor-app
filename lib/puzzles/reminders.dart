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
import '../mentor/focus.dart';
import '../mentor/focus_notice.dart';
import '../mentor/profile.dart';
import '../ui/strings.dart';
import 'schedule.dart';

const _firstId = 100;
const _days = 14;
const _weeklyFirstId = 200;
const _weeks = 4;
const _resultId = 300;

/// Nutzlast von Benachrichtigungen, die die Mentor-Seite öffnen sollen.
const mentorPayload = 'mentor';

class Reminders {
  Reminders(this.store, this.settings);

  final GameStore store;
  final Settings settings;
  final _plugin = FlutterLocalNotificationsPlugin();

  /// Wird aufgerufen, wenn eine Erinnerung angetippt wurde (auch beim Kaltstart); [payload] ist [mentorPayload] oder null.
  void Function(String? payload)? onOpen;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) => onOpen?.call(r.payload),
    );
  }

  /// Wurde die App über eine Erinnerung gestartet? Dann die Nutzlast ([mentorPayload] oder leer), sonst null.
  Future<({String? payload})?> launchedFromReminder() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    return d?.didNotificationLaunchApp == true ? (payload: d?.notificationResponse?.payload) : null;
  }

  /// Ab Android 13 muss der Nutzer Benachrichtigungen erlauben.
  Future<void> requestPermission() async => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  /// Alle Erinnerungen neu planen: Puzzles und Wochenfokus.
  Future<void> reschedule() async {
    await _reschedulePuzzles();
    await rescheduleFocus();
  }

  NotificationDetails _focusDetails(Tr tr) => NotificationDetails(
    android: AndroidNotificationDetails(
      'focus',
      tr.t('Wochenfokus', 'Weekly focus'),
      channelDescription: tr.t('Wochenfokus und Ergebnis des Mentors', 'Weekly focus and result from the mentor'),
    ),
  );

  /// Montag 9:00 der nächsten Wochen: Fokus läuft oder neuer Vorschlag. Der Text entsteht beim Planen und wird nach
  /// jeder Änderung (Analyse, Fokus gewählt oder beendet) neu geplant.
  Future<void> rescheduleFocus() async {
    for (var i = 0; i < _weeks; i++) {
      await _plugin.cancel(id: _weeklyFirstId + i);
    }
    if (!settings.focusReminders) return;
    final tr = Tr(PlatformDispatcher.instance.locale.languageCode == 'de');
    final active = await store.activeFocus();
    final hasSuggestion = suggestFocus(buildProfile(await store.mentorRecords())).isNotEmpty;
    final now = tz.TZDateTime.now(tz.local);
    var monday = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    monday = monday.add(Duration(days: (DateTime.monday - monday.weekday + 7) % 7));
    if (!monday.isAfter(now)) monday = monday.add(const Duration(days: 7));
    for (var i = 0; i < _weeks; i++) {
      final at = tz.TZDateTime(tz.local, monday.year, monday.month, monday.day + 7 * i, 9);
      final notice = weeklyNotice(tr, active: active, at: at, hasSuggestion: hasSuggestion, level: settings.level);
      if (notice == null) continue;
      await _plugin.zonedSchedule(
        id: _weeklyFirstId + i,
        scheduledDate: at,
        title: notice.title,
        body: notice.body,
        payload: mentorPayload,
        notificationDetails: _focusDetails(tr),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// Sofort melden, dass ein Fokus entschieden ist (erreicht oder verfehlt).
  Future<void> showFocusResult(FocusEntry f, FocusStatus status) async {
    if (!settings.focusReminders) return;
    final tr = Tr(PlatformDispatcher.instance.locale.languageCode == 'de');
    final notice = verdictNotice(tr, f, status);
    if (notice == null) return;
    await _plugin.show(
      id: _resultId,
      title: notice.title,
      body: notice.body,
      payload: mentorPayload,
      notificationDetails: _focusDetails(tr),
    );
  }

  /// Erinnerungen der nächsten 14 Tage neu planen.
  Future<void> _reschedulePuzzles() async {
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
