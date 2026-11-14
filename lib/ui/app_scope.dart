import 'package:flutter/widgets.dart';

import '../ai/mentor_ai.dart';
import '../ai/secrets.dart';
import '../data/game_store.dart';
import '../data/settings.dart';
import '../engine/analysis_service.dart';
import '../puzzles/reminders.dart';

/// Gemeinsame Dienste für alle Seiten.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.store,
    required this.settings,
    required this.service,
    required this.reminders,
    required this.ai,
    required this.secrets,
    required super.child,
  });

  final GameStore store;
  final Settings settings;
  final AnalysisService service;
  final Reminders reminders;
  final MentorAi ai;
  final SecretStore secrets;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
