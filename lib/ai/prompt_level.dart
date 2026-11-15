/// Spielstärke im KI-Prompt (Elo-Anpassung E2): Beschreibung des Schülers und Stilvorgabe je Stufe.
library;

import '../mentor/strength.dart';

/// Ohne Angabe gilt der frühere Standard.
const defaultLevelText = 'ca. 1200 Elo, zwischen Einsteiger und Fortgeschritten';

class PromptLevel {
  const PromptLevel({required this.text, required this.style, required this.index});

  /// Der bisherige feste Text, ohne Stilvorgabe.
  const PromptLevel.fallback() : this(text: defaultLevelText, style: '', index: -1);

  /// So wird der Schüler im Prompt beschrieben, z. B. „ca. 1350 Elo, Stufe „Fortgeschrittener Anfänger““.
  final String text;

  /// Stilvorgabe für Wortwahl und Tiefe; leer = keine.
  final String style;

  /// Stufe für den Zwischenspeicher-Schlüssel (−1 = keine Stufe).
  final int index;

  /// Teil des Zwischenspeicher-Schlüssels: ändert sich die Stufe, werden Texte neu erzeugt.
  String get keyPart => index < 0 ? '' : ':l$index';
}

String _name(Level l, bool de) => switch (l) {
  Level.beginner => de ? 'Einsteiger' : 'Beginner',
  Level.advancedBeginner => de ? 'Fortgeschrittener Anfänger' : 'Advanced beginner',
  Level.intermediate => de ? 'Mittelstufe' : 'Intermediate',
  Level.advanced => de ? 'Fortgeschritten' : 'Advanced',
};

String levelStyle(Level l, {required bool de}) => switch ((l, de)) {
  (Level.beginner, true) =>
    'Sehr einfache Wörter, kurze Sätze, nur eine Idee je Satz. Erkläre Grundregeln (Figuren sichern, Schachs und '
        'Schlagzüge prüfen) und vermeide Fachbegriffe oder erkläre sie kurz.',
  (Level.beginner, false) =>
    'Very simple words, short sentences, one idea per sentence. Explain basic rules (keep pieces protected, check checks '
        'and captures) and avoid jargon or explain it briefly.',
  (Level.advancedBeginner, true) =>
    'Einfache Sprache. Nenne die Prüffragen (Schach, Schlag, Drohung) und einfache Taktikmuster wie Gabel und Fesselung '
        'beim Namen und erkläre sie in einem Halbsatz.',
  (Level.advancedBeginner, false) =>
    'Simple language. Name the check questions (check, capture, threat) and simple tactical patterns such as fork and pin, '
        'and explain them in half a sentence.',
  (Level.intermediate, true) =>
    'Du darfst Fachbegriffe wie Tempo, Initiative, Bauernstruktur oder offene Linien verwenden. Gehe auf Pläne und '
        'typische Muster ein, nicht nur auf den einzelnen Zug.',
  (Level.intermediate, false) =>
    'You may use terms such as tempo, initiative, pawn structure or open files. Address plans and typical patterns, not '
        'just the single move.',
  (Level.advanced, true) =>
    'Knapp und präzise. Gehe auf Pläne, Strukturen, Prophylaxe und das Abwägen von Alternativen ein; Grundregeln musst du '
        'nicht wiederholen.',
  (Level.advanced, false) =>
    'Concise and precise. Address plans, structures, prophylaxis and weighing alternatives; there is no need to repeat '
        'basic rules.',
};

/// Prompt-Beschreibung zur Stufe. Mit [sendElo] steht die auf 50 gerundete Zahl dabei, sonst nur die Stufe.
PromptLevel promptLevel({required Level level, required int elo, required bool sendElo, required bool de}) {
  final name = de ? 'Stufe „${_name(level, de)}“' : 'level “${_name(level, de)}”';
  return PromptLevel(
    text: sendElo ? (de ? 'ca. ${roundElo(elo)} Elo, $name' : 'about ${roundElo(elo)} Elo, $name') : name,
    style: levelStyle(level, de: de),
    index: level.index,
  );
}

/// Zeile mit der Stilvorgabe für den Prompt (leer ohne Vorgabe).
String styleLine(PromptLevel l, {required bool de}) =>
    l.style.isEmpty ? '' : '${de ? 'Stil für dieses Niveau' : 'Style for this level'}: ${l.style}\n\n';
