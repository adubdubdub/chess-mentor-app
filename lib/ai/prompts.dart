/// Prompts für die KI-Texte (Vorlage: coach.py des Telegram-Bots).
library;

import 'dart:convert';

import '../analysis/analysis.dart';
import '../analysis/chess_utils.dart';
import 'prompt_level.dart';

const promptVersion = 3;

const defaultLevel = defaultLevelText;

String _san(String s, bool de) => de ? germanSan(s) : s;

/// Fakten zu einem Fehler als JSON für den Prompt. Züge stehen in der Notation der Sprache.
Map<String, Object?> puzzleFacts(Moment m, {required bool de}) => {
  'move_no': m.moveNo,
  'phase': m.phase.name,
  'opponent_last': m.opponentLast == null ? null : _san(m.opponentLast!, de),
  'played': _san(m.played, de),
  'best': _san(m.best, de),
  'best_line': _san(m.bestLine, de),
  'reply_line': _san(m.replyLine, de),
  'threat_reply': m.threatReply == null ? null : _san(m.threatReply!, de),
  'class': m.mistake.name,
  'motifs': [for (final x in m.motifs) x.toJson()],
  'alternatives': [
    for (final a in m.alternatives) {'san': _san(a.san, de), 'win': a.win.round()},
  ],
};

/// Alle Texte aus den Fakten, in denen Züge stehen dürfen (für die Prüfung).
List<String> factMoveTexts(Moment m, {required bool de}) {
  final f = puzzleFacts(m, de: de);
  return [
    for (final k in ['opponent_last', 'played', 'best', 'best_line', 'reply_line', 'threat_reply'])
      if (f[k] != null) f[k]! as String,
    for (final a in m.alternatives) _san(a.san, de),
  ];
}

String puzzlePrompt(Moment m, {required bool de, PromptLevel level = const PromptLevel.fallback()}) {
  final facts = const JsonEncoder.withIndent(' ').convert(puzzleFacts(m, de: de));
  if (de) {
    return '''Du bist ein geduldiger Schachtrainer. Dein Schüler (${level.text}) hat ein Puzzle aus einem eigenen Fehler gelöst
oder nicht gelöst. Du bekommst die Fakten der Stockfish-Analyse als JSON.

Regeln: Nutze AUSSCHLIESSLICH Züge, Varianten und Bewertungen aus dem JSON, erfinde keine eigenen Varianten.
Deutsche Notation (S, L, T, D, K) wie im JSON; "6...Lc6" ist ein Zug von Schwarz, "7.f4" von Weiß.
"reply_line" ist die erwartete Engine-Antwort nach dem Partiezug "played", "best_line" die Fortsetzung nach dem besten Zug.
Erkläre in höchstens 4 einfachen Sätzen, mit "du": warum der Partiezug schwach war (welche Folgen, laut reply_line),
und warum der beste Zug besser ist. Nenne KEINE Prozentzahlen: Gewinnchancen und die Folgevariante stehen schon in einer Tabelle darüber, wiederhole sie nicht.
Antworte nur mit dem Erklärtext, ohne Überschrift und ohne Codeblock.

${styleLine(level, de: true)}Fakten:
$facts''';
  }
  return '''You are a patient chess coach. Your student (${level.text}) worked on a puzzle made from one of their own mistakes.
You get the facts of a Stockfish analysis as JSON.

Rules: use ONLY moves, lines and evaluations from the JSON, never invent your own lines.
Standard English notation as in the JSON; "6...Bc6" is a Black move, "7.f4" a White move.
"reply_line" is the expected engine reply after the game move "played", "best_line" the continuation after the best move.
Explain in at most 4 simple sentences, addressing the student as "you": why the game move was weak (what follows, per
reply_line) and why the best move is better. Do NOT mention percentages: winning chances and the follow-up line are
already shown in a table above, do not repeat them.
Answer with the explanation text only, no heading and no code block.

${styleLine(level, de: false)}Facts:
$facts''';
}

/// Fakten zu einer ganzen Partie für die Besprechung (wie `_facts` in coach.py).
Map<String, Object?> reviewFacts(GameAnalysis a, {required bool de}) => {
  'color': a.color.name,
  'result': a.result,
  'opening': a.opening,
  'moves': a.moves,
  'accuracy': a.accuracy,
  'counts': {for (final e in a.counts.entries) e.key.name: e.value},
  'momente': [
    for (final m in a.moments) {'ply': m.ply, ...puzzleFacts(m, de: de)}..remove('move_no'),
  ],
};

/// Alle Texte aus den Fakten einer Partie, in denen Züge stehen dürfen.
List<String> reviewMoveTexts(GameAnalysis a, {required bool de}) => [
  for (final m in a.moments) ...factMoveTexts(m, de: de),
];

String reviewPrompt(GameAnalysis a, {required bool de, PromptLevel level = const PromptLevel.fallback()}) {
  final facts = const JsonEncoder.withIndent(' ').convert(reviewFacts(a, de: de));
  final color = de ? (a.color.name == 'white' ? 'Weiß' : 'Schwarz') : a.color.name;
  if (de) {
    return '''Du bist ein geduldiger, sokratischer Schachtrainer. Dein Schüler spielt ${level.text} und hat gerade
eine Partie gespielt (er hatte $color). Du bekommst die Fakten einer Stockfish-Analyse als JSON.

Regeln:
- Nutze AUSSCHLIESSLICH die Züge, Varianten und Bewertungen aus dem JSON. Erfinde keine eigenen Varianten
  und rechne nicht selbst; wenn ein Grund nicht aus den Fakten hervorgeht, beschreibe das Prinzip allgemein.
- Erwähne nur Züge, die wörtlich im JSON stehen. Deutsche Notation (S, L, T, D, K), so wie im JSON.
- Zugnummern zeigen die Seite: "7.f4" ist ein Zug von Weiß, "6...Lc6" ein Zug von Schwarz. Schreibe einen Zug nie
  der falschen Seite zu. "reply_line" beginnt mit der besten Antwort des Gegners auf den Partiezug, danach
  wechseln sich beide Seiten ab; es ist die Engine-Erwartung, nicht unbedingt der weitere Partieverlauf.
- Die Frage bezieht sich auf die Stellung VOR dem Partiezug "played"; der letzte Zug des Gegners davor steht
  in "opponent_last".
- Sprich den Schüler mit "du" an, einfache Sprache, keine Engine-Zahlen außer "klar besser" o. Ä.
- "frage": regt zum Nachdenken an, ohne den besten Zug zu verraten (z. B. auf eine Drohung, eine ungedeckte
  Figur oder einen Plan lenken). Höchstens 2 Sätze.
- "tipp": ein konkreterer Hinweis, verrät den Zug aber noch nicht. 1 Satz.
- STRENG für "frage" und "tipp": Nenne weder den besten Zug noch das Zielfeld des besten Zugs, und sage nicht,
  welche Figur ziehen oder schlagen soll. Lenke nur auf das Thema (z. B. "Gibt es ein Schachgebot?", "Welche
  gegnerische Figur ist schlecht geschützt?", "Wie sicher steht der gegnerische König?"), ohne Feld und Figur
  zu verbinden. Beispiel schlecht: "Kann deine Dame den Bauern auf f7 schlagen?" Besser: "Welche Schwächen
  hat die gegnerische Königsstellung?"
- "erklaerung": warum der Partiezug schwach war (Antwort des Gegners aus "reply_line") und was der beste Zug
  erreicht ("best_line"). Höchstens 4 Sätze. Keine Prozentzahlen.
- "zusammenfassung": 2–3 Sätze zur ganzen Partie, ermutigend und ehrlich.
- "lernpunkt": genau EIN konkreter Merksatz für die nächsten Partien, abgeleitet aus dem wichtigsten Fehler.

Antworte nur mit JSON in genau dieser Form, ohne Codeblock:
{"zusammenfassung": "...", "lernpunkt": "...", "momente": [{"ply": 0, "frage": "...", "tipp": "...", "erklaerung": "..."}]}

${styleLine(level, de: true)}Fakten:
$facts''';
  }
  return '''You are a patient, Socratic chess coach. Your student plays at ${level.text} and just played a game
(they had $color). You get the facts of a Stockfish analysis as JSON.

Rules:
- Use ONLY the moves, lines and evaluations from the JSON. Do not invent lines or calculate yourself; if a reason is
  not in the facts, describe the principle in general terms.
- Mention only moves that appear literally in the JSON, in standard English notation as in the JSON.
- Move numbers show the side: "7.f4" is a White move, "6...Bc6" a Black move. Never attribute a move to the wrong
  side. "reply_line" starts with the opponent's best reply to the game move "played", then the sides alternate; it is
  the engine's expectation, not necessarily what happened later in the game.
- The question refers to the position BEFORE the game move "played"; the opponent's previous move is "opponent_last".
- Address the student as "you", simple language, no engine numbers except "clearly better" or similar.
- "frage": makes them think without giving away the best move (point to a threat, a loose piece or a plan). At most 2 sentences.
- "tipp": a more concrete hint that still does not give away the move. 1 sentence.
- STRICT for "frage" and "tipp": name neither the best move nor its target square, and do not say which piece should
  move or capture. Point only to the theme (e.g. "Is there a check?", "Which enemy piece is poorly protected?",
  "How safe is the enemy king?") without combining a square and a piece. Bad example: "Can your queen take the pawn
  on f7?" Better: "What weaknesses does the enemy king position have?"
- "erklaerung": why the game move was weak (the opponent's reply from "reply_line") and what the best move achieves
  ("best_line"). At most 4 sentences. No percentages.
- "zusammenfassung": 2-3 sentences on the whole game, encouraging and honest.
- "lernpunkt": exactly ONE concrete takeaway for the next games, derived from the most important mistake.

Answer with JSON only, in exactly this form, no code block (keep the German key names):
{"zusammenfassung": "...", "lernpunkt": "...", "momente": [{"ply": 0, "frage": "...", "tipp": "...", "erklaerung": "..."}]}

${styleLine(level, de: false)}Facts:
$facts''';
}
