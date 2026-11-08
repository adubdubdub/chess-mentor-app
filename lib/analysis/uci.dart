/// UCI-Ausgabe von Stockfish: Bewertung und Varianten.
library;

/// Bewertung aus Sicht der Seite am Zug, wie Stockfish sie meldet.
class Score {
  const Score.cp(int this.cp) : mate = null;
  const Score.mate(int this.mate) : cp = null;

  /// Seite am Zug ist matt (Endstellung).
  const Score.mated() : cp = null, mate = 0;

  final int? cp;

  /// Züge bis Matt: positiv = Seite am Zug setzt matt, negativ oder 0 = wird matt gesetzt.
  final int? mate;

  bool get isMate => mate != null;

  /// Dieselbe Bewertung aus Sicht der anderen Seite.
  Score get flipped {
    final m = mate;
    if (m == null) return Score.cp(-cp!);
    // "Matt 0" (Seite am Zug ist matt) ist aus Sicht des Gegners ein gegebenes Matt.
    if (m == 0) return const _MateGiven();
    return Score.mate(-m);
  }

  /// Zentibauern mit Matt als ±mateScore, wie python-chess `score(mate_score=10000)`.
  int centipawns({int mateScore = 10000}) {
    final m = mate;
    if (m == null) return cp!;
    return m > 0 ? mateScore - m : -mateScore - m;
  }

  Map<String, dynamic> toJson() => mate != null ? {'mate': mate} : {'cp': cp};

  @override
  String toString() => mate != null ? 'mate $mate' : 'cp $cp';
}

/// Matt ist bereits gegeben (Gegenstück zu [Score.mated]).
class _MateGiven extends Score {
  const _MateGiven() : super.mate(0);

  @override
  Score get flipped => const Score.mated();

  @override
  int centipawns({int mateScore = 10000}) => mateScore;

  @override
  Map<String, dynamic> toJson() => {'mateGiven': true};

  @override
  String toString() => 'mate given';
}

/// Eine Variante aus einer `info`-Zeile.
class PvLine {
  const PvLine({required this.multipv, required this.depth, required this.score, required this.pv});

  final int multipv;
  final int depth;
  final Score score;

  /// Züge in UCI-Schreibweise, Rochade als Königszug (e1g1).
  final List<String> pv;

  /// Wertet eine `info ... score ... pv ...`-Zeile aus, sonst null.
  static PvLine? parse(String line) {
    if (!line.startsWith('info ')) return null;
    final t = line.split(' ');
    final scoreAt = t.indexOf('score');
    final pvAt = t.indexOf('pv');
    if (scoreAt < 0 || pvAt < 0 || scoreAt + 2 >= t.length) return null;
    final value = int.tryParse(t[scoreAt + 2]);
    if (value == null) return null;
    final score = switch (t[scoreAt + 1]) {
      'cp' => Score.cp(value),
      'mate' => value == 0 ? const Score.mated() : Score.mate(value),
      _ => null,
    };
    if (score == null) return null;
    int field(String name, int fallback) {
      final i = t.indexOf(name);
      return i >= 0 && i + 1 < t.length ? int.tryParse(t[i + 1]) ?? fallback : fallback;
    }

    return PvLine(
      multipv: field('multipv', 1),
      depth: field('depth', 0),
      score: score,
      pv: t.sublist(pvAt + 1).where((m) => m.isNotEmpty).toList(),
    );
  }
}

/// Schnittstelle zur Engine: Stockfish auf dem Handy oder in Tests ein Prozess.
abstract class UciEngine {
  /// Neue Partie: Zwischenspeicher (Hash) leeren, damit jede Analyse wie mit frischer Engine rechnet.
  Future<void> newGame();

  /// Varianten nach Rang sortiert (beste zuerst). [moves] in UCI ab [rootFen].
  Future<List<PvLine>> analyse({
    required String rootFen,
    required List<String> moves,
    required int depth,
    required int multiPv,
  });
}
