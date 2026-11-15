/// Hält den Wochenfokus aktuell: wertet den laufenden Fokus gegen die Partien aus und speichert das Ergebnis.
library;

import '../data/game_store.dart';
import 'focus.dart';

class FocusState {
  const FocusState({this.active, this.progress, this.lastClosed});

  /// Laufender Fokus mit Zwischenstand, sonst null.
  final FocusEntry? active;
  final FocusProgress? progress;

  /// Zuletzt beendeter Fokus (erreicht, verfehlt, abgelaufen, abgebrochen) zur Anzeige des Ergebnisses.
  final FocusEntry? lastClosed;
}

class FocusKeeper {
  FocusKeeper(this.store, {this.onVerdict});

  final GameStore store;

  /// Wird einmal aufgerufen, wenn ein Fokus entschieden wurde (z. B. für eine Benachrichtigung).
  final Future<void> Function(FocusEntry focus, FocusStatus status)? onVerdict;

  /// Fokus auswerten; ein neu entschiedener Fokus (erreicht, verfehlt, abgelaufen) wird gespeichert und beendet.
  Future<FocusState> refresh({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final active = await store.activeFocus();
    if (active == null) return FocusState(lastClosed: await store.lastClosedFocus());
    final records = await store.mentorRecords();
    final progress = evaluateFocus(active, records, t);
    if (progress.status != FocusStatus.active) {
      await store.closeFocus(active.id!, progress.status, t);
      await onVerdict?.call(active, progress.status);
      return FocusState(lastClosed: (await store.lastClosedFocus()), progress: progress);
    }
    return FocusState(active: active, progress: progress, lastClosed: await store.lastClosedFocus());
  }
}
