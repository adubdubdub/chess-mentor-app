/// Prompts für die KI-Texte (Vorlage: coach.py des Telegram-Bots).
library;

import 'dart:convert';

import '../analysis/analysis.dart';
import '../analysis/chess_utils.dart';

const promptVersion = 1;

const defaultLevel = 'ca. 1200 Elo, zwischen Einsteiger und Fortgeschritten';

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

String puzzlePrompt(Moment m, {required bool de, String level = defaultLevel}) {
  final facts = const JsonEncoder.withIndent(' ').convert(puzzleFacts(m, de: de));
  if (de) {
    return '''Du bist ein geduldiger Schachtrainer. Dein Schüler ($level) hat ein Puzzle aus einem eigenen Fehler gelöst
oder nicht gelöst. Du bekommst die Fakten der Stockfish-Analyse als JSON.

Regeln: Nutze AUSSCHLIESSLICH Züge, Varianten und Bewertungen aus dem JSON, erfinde keine eigenen Varianten.
Deutsche Notation (S, L, T, D, K) wie im JSON; "6...Lc6" ist ein Zug von Schwarz, "7.f4" von Weiß.
"reply_line" ist die erwartete Engine-Antwort nach dem Partiezug "played", "best_line" die Fortsetzung nach dem besten Zug.
Erkläre in höchstens 4 einfachen Sätzen, mit "du": warum der Partiezug schwach war (welche Folgen, laut reply_line),
und warum der beste Zug besser ist. Nenne KEINE Prozentzahlen: Gewinnchancen und die Folgevariante stehen schon in einer Tabelle darüber, wiederhole sie nicht.
Antworte nur mit dem Erklärtext, ohne Überschrift und ohne Codeblock.

Fakten:
$facts''';
  }
  return '''You are a patient chess coach. Your student ($level) worked on a puzzle made from one of their own mistakes.
You get the facts of a Stockfish analysis as JSON.

Rules: use ONLY moves, lines and evaluations from the JSON, never invent your own lines.
Standard English notation as in the JSON; "6...Bc6" is a Black move, "7.f4" a White move.
"reply_line" is the expected engine reply after the game move "played", "best_line" the continuation after the best move.
Explain in at most 4 simple sentences, addressing the student as "you": why the game move was weak (what follows, per
reply_line) and why the best move is better. Do NOT mention percentages: winning chances and the follow-up line are
already shown in a table above, do not repeat them.
Answer with the explanation text only, no heading and no code block.

Facts:
$facts''';
}
