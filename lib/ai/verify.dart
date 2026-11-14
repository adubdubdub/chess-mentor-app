/// Prüft KI-Texte gegen die Engine-Fakten: Genannte Züge müssen in den Fakten vorkommen.
library;

final _numbered = RegExp(r'(\d+)\s*\.(\.\.)?\s*([^\s,;:.!?()]+)');
final _moveToken = RegExp(r'^(?:O-O(?:-O)?|[SLTDKNBRQ]?[a-h]?[1-8]?x?[a-h][1-8](?:=[SLTDNBRQ])?)[+#]?[!?]*$');

String _norm(String s) => s.replaceAll(RegExp(r'[+#!?]+$'), '');

/// Alle Zugnamen aus [facts] (Fließtext mit Varianten wie „6...Lc6 7.f4“ oder einzelne Züge).
Set<String> moveTokens(Iterable<String> facts) {
  final out = <String>{};
  for (final f in facts) {
    for (final w in f.split(RegExp(r'[\s,;()]+'))) {
      final t = w.replaceFirst(RegExp(r'^\d+\.(\.\.)?'), '');
      if (_moveToken.hasMatch(t)) out.add(_norm(t));
    }
  }
  return out;
}

/// Gibt die Züge zurück, die in [text] vorkommen, aber nicht in [allowed] stehen (leer = in Ordnung).
/// Streng geprüft werden nummerierte Züge („7.f4“) und alle Züge mit Figurenbuchstaben oder Schlagzeichen;
/// ein bloßes Feld („e4“) gilt als Feldangabe und wird nicht beanstandet.
List<String> unknownMoves(String text, Set<String> allowed) {
  final bad = <String>[];
  for (final m in _numbered.allMatches(text)) {
    final t = _norm(m.group(3)!);
    if (_moveToken.hasMatch(t) && !allowed.contains(t)) bad.add(t);
  }
  for (final w in text.split(RegExp(r'[\s,;:()!?]+'))) {
    final t = _norm(w.replaceAll(RegExp(r'\.+$'), '').replaceFirst(RegExp(r'^\d+\.(\.\.)?'), ''));
    if (!_moveToken.hasMatch(t)) continue;
    final strict = RegExp(r'^[SLTDK]').hasMatch(t) || t.contains('x') || t.startsWith('O-O');
    // „Sf3“ ist ein Zug, aber Wörter wie „Dame“ passen nicht auf das Muster (Feldziffer fehlt)
    if (strict && !allowed.contains(t)) bad.add(t);
  }
  return bad.toSet().toList();
}

/// Nennt [text] den Zug [san] (mit oder ohne Zugnummer, Schach-Zeichen ignoriert)? Für Fragen und Tipps,
/// die den besten Zug nicht verraten dürfen.
bool revealsMove(String text, String san) {
  final target = _norm(san);
  for (final w in text.split(RegExp(r'[\s,;:()!?]+'))) {
    final t = _norm(w.replaceAll(RegExp(r'\.+$'), '').replaceFirst(RegExp(r'^\d+\.(\.\.)?'), ''));
    if (t == target) return true;
  }
  return false;
}
