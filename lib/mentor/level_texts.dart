/// Namen der Stufen und Texte zur Spielstärke (Deutsch und Englisch).
library;

import '../ui/strings.dart';
import 'strength.dart';

extension LevelTexts on Tr {
  String levelName(Level l) => switch (l) {
    Level.beginner => t('Einsteiger', 'Beginner'),
    Level.advancedBeginner => t('Fortgeschrittener Anfänger', 'Advanced beginner'),
    Level.intermediate => t('Mittelstufe', 'Intermediate'),
    Level.advanced => t('Fortgeschritten', 'Advanced'),
  };

  String levelRange(Level l) => switch (l) {
    Level.beginner => t('unter 1000', 'below 1000'),
    Level.advancedBeginner => '1000–1400',
    Level.intermediate => '1400–1800',
    Level.advanced => t('über 1800', 'above 1800'),
  };

  String sourceName(StrengthSource s) => switch (s) {
    StrengthSource.initial => t('Ausgangswert, noch keine Daten', 'default value, no data yet'),
    StrengthSource.online => t('Online-Wertung', 'online rating'),
    StrengthSource.games => t('eigene Partien', 'your games'),
    StrengthSource.manual => t('manuell eingetragen', 'entered manually'),
  };

  String confidenceName(Confidence c) => switch (c) {
    Confidence.low => t('niedrige Sicherheit', 'low confidence'),
    Confidence.medium => t('mittlere Sicherheit', 'medium confidence'),
    Confidence.high => t('hohe Sicherheit', 'high confidence'),
  };
}
