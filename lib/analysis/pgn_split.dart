/// Zerlegt Text mit mehreren Partien (Lichess-Export, Chess.com-Archiv, Sammeldatei) in einzelne PGNs.
library;

/// Jede Partie beginnt mit einer Kopfzeile `[Event ...]` am Zeilenanfang; Text davor wird ignoriert.
/// Ein Text ohne Kopfzeilen (nur Züge) gilt als eine Partie.
List<String> splitPgn(String text) {
  final t = text.replaceAll('\r\n', '\n').trim();
  if (t.isEmpty) return const [];
  final starts = RegExp(r'^\[Event ', multiLine: true).allMatches(t).map((m) => m.start).toList();
  if (starts.isEmpty) return [t];
  return [
    for (var i = 0; i < starts.length; i++) t.substring(starts[i], i + 1 < starts.length ? starts[i + 1] : t.length).trim(),
  ];
}
