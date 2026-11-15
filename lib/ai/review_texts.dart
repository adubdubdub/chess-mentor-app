/// KI-Texte einer Besprechung: Zusammenfassung, Lernpunkt und je Moment Frage, Tipp und Erklärung.
library;

import 'dart:convert';

import '../analysis/analysis.dart';
import '../analysis/chess_utils.dart';
import 'prompts.dart';
import 'verify.dart';

class MomentTexts {
  const MomentTexts({this.question, this.tip, this.explanation});

  final String? question;
  final String? tip;
  final String? explanation;

  Map<String, dynamic> toJson() => {'question': question, 'tip': tip, 'explanation': explanation};
  factory MomentTexts.fromJson(Map<String, dynamic> j) => MomentTexts(
    question: j['question'] as String?,
    tip: j['tip'] as String?,
    explanation: j['explanation'] as String?,
  );
}

class ReviewTexts {
  const ReviewTexts({this.summary, this.learning, this.moments = const {}});

  final String? summary;
  final String? learning;

  /// Nach ply.
  final Map<int, MomentTexts> moments;

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'learning': learning,
    'moments': {for (final e in moments.entries) '${e.key}': e.value.toJson()},
  };
  factory ReviewTexts.fromJson(Map<String, dynamic> j) => ReviewTexts(
    summary: j['summary'] as String?,
    learning: j['learning'] as String?,
    moments: {
      for (final e in (j['moments'] as Map<String, dynamic>).entries)
        int.parse(e.key): MomentTexts.fromJson(e.value as Map<String, dynamic>),
    },
  );
}

String _clean(String s) => s.replaceAll(RegExp(r'^```\w*|```$'), '').trim();

/// Liest die Antwort der KI und behält nur Texte, die die Prüfung bestehen:
/// nur Züge aus den Fakten, Frage und Tipp verraten den besten Zug nicht, keine leeren Felder.
/// Null, wenn gar nichts Brauchbares übrig bleibt.
ReviewTexts? parseReview(String raw, GameAnalysis a, {required bool de}) {
  final Map<String, dynamic> data;
  try {
    data = jsonDecode(_clean(raw)) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
  final allowed = moveTokens(reviewMoveTexts(a, de: de));
  String? ok(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty || unknownMoves(t, allowed).isNotEmpty ? null : t;
  }

  final byPly = <int, Map<String, dynamic>>{
    for (final m in (data['momente'] as List? ?? const []))
      if (m is Map<String, dynamic> && m['ply'] is int) m['ply'] as int: m,
  };
  final moments = <int, MomentTexts>{};
  for (final m in a.moments) {
    final j = byPly[m.ply];
    if (j == null) continue;
    final best = de ? germanSan(m.best) : m.best;
    String? hidden(Object? v) {
      final t = ok(v);
      if (t == null || revealsMove(t, best) || revealsMove(t, m.best)) return null;
      // Auch das Zielfeld des besten Zugs gilt als Verrat („Dame auf f7 schlagen“)
      final target = m.bestUci.substring(2, 4);
      return RegExp('(^|[^a-h0-9])$target(?![0-9])').hasMatch(t) ? null : t;
    }

    moments[m.ply] = MomentTexts(
      question: hidden(j['frage']),
      tip: hidden(j['tipp']),
      explanation: ok(j['erklaerung']),
    );
  }
  final texts = ReviewTexts(summary: ok(data['zusammenfassung']), learning: ok(data['lernpunkt']), moments: moments);
  final any =
      texts.summary != null ||
      texts.learning != null ||
      moments.values.any((m) => m.question != null || m.tip != null || m.explanation != null);
  return any ? texts : null;
}
