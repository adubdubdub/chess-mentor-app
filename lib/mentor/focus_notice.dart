/// Texte der Wochenfokus-Benachrichtigungen (Schritt 6d), getrennt von der Planung, damit sie testbar sind.
library;

import '../ui/strings.dart';
import 'focus.dart';
import 'topic_texts.dart';

class FocusNotice {
  const FocusNotice(this.title, this.body);

  final String title;
  final String body;
}

/// Wochenanfang: Der Fokus läuft noch, ist am [at] schon abgelaufen, oder es gibt noch keinen.
/// Null, wenn es nichts Sinnvolles zu sagen gibt (kein Fokus und kein Vorschlag möglich).
FocusNotice? weeklyNotice(Tr tr, {FocusEntry? active, required DateTime at, required bool hasSuggestion}) {
  if (active != null && at.isBefore(active.endsAt)) {
    return FocusNotice(
      '🎯 ${tr.t('Wochenfokus', 'Weekly focus')}: ${tr.topicName(active.topic)}',
      tr.topicCheck(active.topic),
    );
  }
  if (!hasSuggestion) return null;
  return FocusNotice(
    '🎯 ${tr.t('Neuer Wochenfokus?', 'New weekly focus?')}',
    tr.t('Der Mentor hat einen Vorschlag für diese Woche.', 'The mentor has a suggestion for this week.'),
  );
}

/// Sofortmeldung, wenn ein Fokus entschieden ist. Null bei „abgelaufen“ und „abgebrochen“ (kein Urteil).
FocusNotice? verdictNotice(Tr tr, FocusEntry f, FocusStatus status) => switch (status) {
  FocusStatus.reached => FocusNotice(
    '✅ ${tr.t('Wochenfokus erreicht', 'Weekly focus reached')}',
    tr.t('Ziel zu „${tr.topicName(f.topic)}“ geschafft. Zeit für das nächste Thema?', 'Goal for “${tr.topicName(f.topic)}” reached. Time for the next topic?'),
  ),
  FocusStatus.missed => FocusNotice(
    '❌ ${tr.t('Wochenfokus verfehlt', 'Weekly focus missed')}',
    tr.t('Zu „${tr.topicName(f.topic)}“ gab es mehr Fehlzüge als erlaubt. Schau dir die Tipps an.', 'There were more mistakes than allowed on “${tr.topicName(f.topic)}”. Have a look at the tips.'),
  ),
  _ => null,
};
