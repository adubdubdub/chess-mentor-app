/// Persönlicher KI-Text zum Wochenfokus (Schritt 6d): warum das Thema bei diesem Nutzer wichtig ist, mit Hinweisen an
/// seinen eigenen Beispielzügen. Die Zahlen und Züge stammen aus den Fakten, die Prüfung verwirft alles andere.
library;

import 'dart:convert';

import '../analysis/analysis.dart';
import '../mentor/focus.dart';
import '../mentor/records.dart';
import '../mentor/topic_texts.dart';
import '../ui/strings.dart';
import 'prompts.dart';
import 'verify.dart';

/// Höchstens so viele eigene Beispielzüge gehen in den Prompt.
const focusExamples = 3;

class FocusFacts {
  const FocusFacts({required this.json, required this.moveTexts, required this.numbers, required this.cacheKey});

  /// Fakten als JSON-Text für den Prompt.
  final String json;

  /// Texte mit Zügen, die der Antworttext nennen darf, und erlaubte Zahlen.
  final List<String> moveTexts;
  final Set<int> numbers;

  /// Ändert sich, sobald sich Thema oder Datenlage ändern.
  final String cacheKey;
}

/// Fakten zum Fokusthema: Kennzahlen, Ziel und bis zu [focusExamples] Beispielzüge mit der größten Wirkung.
FocusFacts focusFacts(FocusSuggestion s, List<({GameRecord game, Moment moment})> examples, {required bool de}) {
  final tr = Tr(de);
  final ex = ([...examples]..sort((a, b) => b.moment.drop.compareTo(a.moment.drop))).take(focusExamples).toList();
  final stat = s.stat;
  final numbers = <int>{
    stat.count,
    stat.games,
    s.baselineGames,
    s.goalGames,
    s.target,
    stat.avgDrop.round(),
    stat.per100.round(),
    focusDays,
    100, // „je 100 Züge“
    for (var i = 0; i <= 10; i++) i, // kleine Zahlen wie „zwei Tipps“, „3 Partien“ sind unkritisch
  };
  final moveTexts = <String>[];
  final exampleJson = <Map<String, Object?>>[];
  for (final e in ex) {
    final m = e.moment;
    final facts = puzzleFacts(m, de: de);
    exampleJson.add({
      'zugnummer': m.moveNo,
      'phase': m.phase.name,
      'gespielt': facts['played'],
      'besser': facts['best'],
      'antwort_gegner': facts['reply_line'],
      'verlust_punkte': m.drop.round(),
    });
    moveTexts.addAll(factMoveTexts(m, de: de));
    numbers
      ..add(m.moveNo)
      ..add(m.drop.round());
    for (final n in RegExp(r'(\d+)\.').allMatches('${m.bestLine} ${m.replyLine}')) {
      numbers.add(int.parse(n.group(1)!));
    }
  }
  final json = const JsonEncoder.withIndent(' ').convert({
    'thema': tr.topicName(stat.topic),
    'bedeutung': tr.topicHint(stat.topic),
    'vorkommen': stat.count,
    'in_partien': stat.games,
    'analysierte_partien': s.baselineGames,
    'fehlzuege_je_100_zuege': double.parse(stat.per100.toStringAsFixed(1)),
    'durchschnittlicher_verlust_punkte': stat.avgDrop.round(),
    'ziel': {'partien': s.goalGames, 'hoechstens_fehlzuege': s.target},
    'beispiele': exampleJson,
  });
  return FocusFacts(
    json: json,
    moveTexts: moveTexts,
    numbers: numbers,
    cacheKey: 'focus:${stat.topic.name}:${stat.count}:${s.baselineGames}:${de ? 'de' : 'en'}:v$promptVersion',
  );
}

String focusPrompt(FocusFacts f, {required bool de, String level = defaultLevel}) {
  if (de) {
    return '''Du bist ein geduldiger Schachtrainer. Dein Schüler ($level) hat für die kommende Woche ein Schwerpunktthema
bekommen. Du bekommst die Fakten aus seinen eigenen Partien als JSON.

Schreibe einen persönlichen Text in höchstens 5 einfachen Sätzen, mit "du":
1. Warum dieses Thema bei dir gerade wichtig ist (nutze die Zahlen aus den Fakten).
2. Ein bis zwei konkrete Hinweise anhand der Beispiele: Was ist in dieser Art Stellung passiert, und worauf achtest du künftig?
3. Wie du das Thema diese Woche übst (Prüffrage vor jedem Zug, Fokus-Puzzles).

Regeln: Nutze AUSSCHLIESSLICH Züge und Zahlen aus dem JSON, erfinde keine eigenen Varianten und keine anderen Zahlen.
Deutsche Notation (S, L, T, D, K) wie im JSON; "6...Lc6" ist ein Zug von Schwarz, "7.f4" von Weiß. Keine Aufzählung,
keine Überschrift, kein Codeblock, nur Fließtext.

Fakten:
${f.json}''';
  }
  return '''You are a patient chess coach. Your student ($level) has been given a focus topic for the coming week.
You get facts from their own games as JSON.

Write a personal text in at most 5 simple sentences, addressing the student as "you":
1. Why this topic matters for you right now (use the numbers from the facts).
2. One or two concrete hints based on the examples: what happened in this kind of position and what to watch for next time.
3. How to practise the topic this week (check question before every move, focus puzzles).

Rules: use ONLY moves and numbers from the JSON, never invent your own lines or other numbers. Standard English notation as
in the JSON; "6...Bc6" is a Black move, "7.f4" a White move. No lists, no heading, no code block, plain prose only.

Facts:
${f.json}''';
}

/// Prüft den KI-Text: nur Züge und Zahlen aus den Fakten, nicht leer, nicht zu lang. Gibt den Text oder null zurück.
String? checkFocusText(String raw, FocusFacts f) {
  final text = raw.replaceAll(RegExp(r'^```\w*|```$'), '').trim();
  if (text.isEmpty || text.length > 1200) return null;
  if (unknownMoves(text, moveTokens(f.moveTexts)).isNotEmpty) return null;
  if (unknownNumbers(text, f.numbers).isNotEmpty) return null;
  return text;
}
