/// Texte des Mentors ohne Sprachmodell: Fragen, Tipps, Erklärungen und Lernpunkt aus den Engine-Fakten.
///
/// Gegenstück zu coach.py des Bots. Alle Züge und Varianten stammen aus der Analyse; Fragen und Tipps verraten den
/// besten Zug nicht.
library;

import 'package:dartchess/dartchess.dart';

import '../analysis/analysis.dart';
import '../analysis/chess_utils.dart' show GamePhase;
import '../analysis/judge.dart';
import '../ui/strings.dart';
import '../analysis/chess_utils.dart' as cu;
import 'move_facts.dart';

class CoachTexts {
  const CoachTexts(this.tr);

  final Tr tr;

  bool _has(Moment m, String code) => m.motifs.any((x) => x.code == code);
  int? _n(Moment m, String code) => m.motifs.where((x) => x.code == code).firstOrNull?.n;

  /// Frage zur Stellung VOR dem Partiezug, ohne den besten Zug zu nennen.
  String question(Moment m) {
    final last = m.opponentLast == null ? null : tr.san(m.opponentLast!);
    if (_has(m, 'mate_missed')) {
      return tr.t(
        'Hier kannst du die Partie entscheiden. Rechne alle Schachgebote genau durch – welches ist das stärkste?',
        'You can decide the game here. Calculate every check carefully – which one is strongest?',
      );
    }
    if (_has(m, 'allows_mate')) {
      return tr.t(
        'Bevor du ziehst: Welche Schachgebote und Drohungen hat dein Gegner gegen deinen König?',
        'Before you move: which checks and threats does your opponent have against your king?',
      );
    }
    if (_has(m, 'hangs_material')) {
      return last != null
          ? tr.t(
              'Nach $last: Welche deiner Figuren ist angreifbar oder ungedeckt, und wie sicherst du sie?',
              'After $last: which of your pieces can be attacked or is undefended, and how do you secure it?',
            )
          : tr.t(
              'Welche deiner Figuren ist angreifbar oder ungedeckt?',
              'Which of your pieces can be attacked or is undefended?',
            );
    }
    if (_has(m, 'wins_material') || _has(m, 'best_is_capture')) {
      return last != null
          ? tr.t(
              'Dein Gegner hat gerade $last gespielt. Gibt es jetzt etwas zu gewinnen?',
              'Your opponent just played $last. Is there something to win now?',
            )
          : tr.t('Gibt es hier etwas zu gewinnen?', 'Is there something to win here?');
    }
    if (_has(m, 'best_is_check')) {
      return tr.t(
        'Welche forcierenden Züge hast du – Schachs, Schlagzüge, Drohungen?',
        'What forcing moves do you have – checks, captures, threats?',
      );
    }
    return switch (m.phase) {
      GamePhase.opening => tr.t(
        'Wie entwickelst du hier am besten weiter? Denk an Zentrum, Figurenentwicklung und Königssicherheit.',
        'How do you best continue your development? Think about the centre, piece development and king safety.',
      ),
      GamePhase.endgame => tr.t(
        'Im Endspiel zählt jedes Tempo. Welcher Zug macht deine Stellung am aktivsten?',
        'In the endgame every tempo counts. Which move makes your position most active?',
      ),
      GamePhase.middlegame => tr.t(
        'Was droht dein Gegner, und was ist hier dein bester Plan?',
        'What is your opponent threatening, and what is your best plan here?',
      ),
    };
  }

  /// Konkreterer Hinweis: Figur des besten Zugs und ob er schlägt oder Schach gibt.
  String tip(Moment m) {
    final san = bareSan(m.best);
    if (san.startsWith('O-O')) return tr.t('Der stärkste Zug ist eine Rochade.', 'The strongest move is castling.');
    final piece = switch (san[0]) {
      'K' => tr.t('Königszug', 'king move'),
      'Q' => tr.t('Damenzug', 'queen move'),
      'R' => tr.t('Turmzug', 'rook move'),
      'B' => tr.t('Läuferzug', 'bishop move'),
      'N' => tr.t('Springerzug', 'knight move'),
      _ => tr.t('Bauernzug', 'pawn move'),
    };
    final capture = san.contains('x');
    final check = san.contains('+') || san.contains('#');
    final extra = switch ((capture, check)) {
      (true, true) => tr.t(', der schlägt und Schach gibt', ' that captures with check'),
      (true, false) => tr.t(', der etwas schlägt', ' that captures'),
      (false, true) => tr.t(', der Schach gibt', ' that gives check'),
      _ => '',
    };
    return tr.t('Der stärkste Zug ist ein $piece$extra.', 'The strongest move is a $piece$extra.');
  }

  /// Warum der Partiezug schwach war und was der beste Zug erreicht (ohne Farbmarkierungen).
  String explanation(Moment m) => plain('${whyPlayedBad(m)} ${whyBestGood(m)}');

  /// Züge im Text markieren: p = Partiezug (rot), b = bester Zug (grün), a = dein Versuch (grau), o = Gegner.
  static String mark(String kind, String san) => '«$kind:$san»';

  /// Markierungen entfernen, nur der Zug bleibt.
  static String plain(String text) => text.replaceAllMapped(RegExp(r'«[pbao]:([^»]*)»'), (x) => x[1]!);

  Position _start(Moment m) => Chess.fromSetup(Setup.parseFen(m.fen));

  /// Warum der Partiezug nicht gut war: was der Gegner darauf macht und was es kostet.
  String whyPlayedBad(Moment m) => [..._playedProblems(m), _change(m.winBefore, m.winAfter)].join(' ');

  /// Kurzfassung für die Liste aller markierten Züge: der wichtigste Grund in einem Satz.
  String shortWhy(Moment m) => _playedProblems(m).first;

  List<String> _playedProblems(Moment m) {
    final pos = _start(m);
    final missed = lineMaterial(pos, m.bestMoves, pos.turn) - lineMaterial(pos, m.playedMoves, pos.turn);
    return _problems(
      pos,
      m.playedMoves,
      mark('p', tr.san(m.played)),
      allowsMate: _has(m, 'allows_mate'),
      missedMate: _n(m, 'mate_missed'),
      missedMaterial: missed,
    );
  }

  /// Veränderung der Stellung: gleiche Einschätzung wird als „bleibt“ benannt, sonst vorher/danach.
  String _change(double before, double after) {
    final b = before.round(), a = after.round();
    if (_standingWords(before) == _standingWords(after)) {
      return tr.t(
        'Die Einschätzung bleibt: ${_standingWords(after)}, die Gewinnchance sinkt aber von $b % auf $a %.',
        'The assessment stays the same: ${_standingWords(after)}, but your winning chance drops from $b % to $a %.',
      );
    }
    return tr.t(
      'Vorher: ${_standing(before)}. Danach: ${_standing(after)}.',
      'Before: ${_standing(before)}. After: ${_standing(after)}.',
    );
  }

  /// Warum der beste Zug stark ist: Schlagen, Schach, Gabel, Rettung, verhinderte Drohung, Materialgewinn.
  String whyBestGood(Moment m, {bool standing = true}) {
    final pos = _start(m);
    final b = mark('b', tr.san(m.best));
    final parts = <String>[];
    final mate = _n(m, 'mate_missed');
    if (mate != null) {
      parts.add(tr.t('$b führt zu Matt in $mate ${mate == 1 ? 'Zug' : 'Zügen'}.', '$b leads to mate in $mate.'));
    }
    parts.addAll(_strengths(pos, m.bestMoves, b, quietFallback: mate == null));
    // Verhindert der beste Zug den Verlust aus der Partie?
    final prob = Problem.of(pos, m.playedMoves);
    final lost = prob?.reply.captured;
    if (mate == null && lost != null && lineMaterial(pos, m.playedMoves, pos.turn) <= -1) {
      final bestReply = m.bestMoves.length >= 2 ? Problem.of(pos, m.bestMoves)?.reply.captured : null;
      if (bestReply?.square != lost.square) {
        parts.add(
          tr.t(
            'So verlierst du ${_acc(lost.role, true)} auf ${lost.square.name} nicht.',
            'This way you do not lose ${_acc(lost.role, true)} on ${lost.square.name}.',
          ),
        );
      }
    }
    if (standing) parts.add(tr.t('Danach: ${_standing(m.winBefore)}.', 'After that: ${_standing(m.winBefore)}.'));
    return parts.join(' ');
  }

  /// Kurze Begründung für die Puzzle-Auswertung: Problem des Partiezugs und Stärke des besten Zugs, ohne Prozentwerte
  /// (die stehen in der Übersicht darüber).
  String puzzleWhy(Moment m) => plain('${_playedProblems(m).join(' ')} ${whyBestGood(m, standing: false)}')
      // Der Hinweis auf die Variantenansicht gilt nur in der Besprechung, nicht im Puzzle.
      .replaceAll(
        RegExp(r' (Blättere oben durch die Variante, dann siehst du, wie|Step through the line above to see how)\.'),
        '.',
      );

  /// Dein eigener Versuch in der Besprechung (grau): fast so gut wie der beste Zug oder was daran hakt.
  String aboutAttempt(Moment m, List<String> line, Verdict verdict, double win) {
    final pos = _start(m);
    if (line.isEmpty) return '';
    final move = cu.legalUci(pos, line.first);
    if (move == null) return '';
    final a = mark('a', tr.san(cu.numbered(pos, [move])));
    final parts = <String>[];
    if (verdict == Verdict.good) {
      parts.add(tr.t('$a ist fast genauso stark wie der beste Zug.', '$a is almost as strong as the best move.'));
      parts.addAll(_strengths(pos, line, a, quietFallback: false));
    } else {
      parts.addAll(_problems(pos, line, a, allowsMate: win < 3));
    }
    parts.add(tr.t('Danach: ${_standing(win)}.', 'After that: ${_standing(win)}.'));
    return parts.join(' ');
  }

  /// Was nach einem eigenen Zug schiefgeht ([line] beginnt mit dem Zug, [own] ist der markierte Zug).
  List<String> _problems(
    Position pos,
    List<String> line,
    String own, {
    required bool allowsMate,
    int? missedMate,
    int missedMaterial = 0,
  }) {
    final me = pos.turn;
    final parts = <String>[];
    final prob = Problem.of(pos, line);
    final mat = lineMaterial(pos, line, me);
    final r = prob == null ? null : mark('o', tr.san(lineSans(pos, line.take(2).toList()).last));
    if (allowsMate) {
      parts.add(
        tr.t('Nach $own kann dein Gegner mattsetzen', 'After $own your opponent can force mate') +
            (r != null ? tr.t(', es beginnt mit $r.', ', starting with $r.') : '.'),
      );
      return parts;
    }
    if (prob != null && r != null) {
      final reply = prob.reply;
      final cap = reply.captured;
      if (cap != null && mat <= -1) {
        final where = cap.square.name;
        if (prob.lostMovedPiece) {
          parts.add(
            tr.t(
              '$own stellt ${_acc(cap.role, true)} auf $where ${reply.capturedUndefended ? 'ungedeckt' : 'ungeschützt'} hin. Dein Gegner schlägt sofort mit $r.',
              '$own puts ${_acc(cap.role, true)} on $where where it is ${reply.capturedUndefended ? 'undefended' : 'not safe'}. Your opponent captures at once with $r.',
            ),
          );
        } else if (prob.threatIgnored) {
          parts.add(
            tr.t(
              '${_cap(_nom(cap.role, true))} auf $where war schon angegriffen, und $own ändert daran nichts. Dein Gegner schlägt mit $r.',
              '${_cap(_acc(cap.role, true))} on $where was already under attack, and $own does nothing about it. Your opponent captures with $r.',
            ),
          );
        } else if (prob.defenderLeft != null) {
          parts.add(
            tr.t(
              '$own zieht die Figur weg, die ${_acc(cap.role, true)} auf $where gedeckt hat. Dein Gegner schlägt mit $r.',
              '$own moves away the piece that protected ${_acc(cap.role, true)} on $where. Your opponent captures with $r.',
            ),
          );
        } else {
          parts.add(
            tr.t(
              'Nach $own schlägt dein Gegner mit $r ${_acc(cap.role, true)} auf $where.',
              'After $own your opponent captures ${_acc(cap.role, true)} on $where with $r.',
            ),
          );
        }
      } else if (reply.fork) {
        final hit = _list([for (final t in reply.targets.where((t) => t.role != Role.king)) _acc(t.role, true)]);
        parts.add(
          reply.check
              ? tr.t(
                  'Nach $own gibt dein Gegner mit $r Schach und greift gleichzeitig $hit an – eine Gabel.',
                  'After $own your opponent plays $r: check and an attack on $hit at the same time – a fork.',
                )
              : tr.t(
                  'Nach $own greift dein Gegner mit $r gleichzeitig $hit an – beides kannst du nicht retten.',
                  'After $own your opponent attacks $hit at once with $r – you cannot save both.',
                ),
        );
      } else if (reply.check) {
        parts.add(
          tr.t(
            'Nach $own antwortet dein Gegner mit dem Schach $r und übernimmt die Initiative.',
            'After $own your opponent answers with the check $r and takes the initiative.',
          ),
        );
      }
    }
    if (mat <= -1 && parts.isEmpty) {
      parts.add(
        tr.t(
          '$own kostet dich im weiteren Verlauf ${_amount(-mat, acc: true)}. Blättere oben durch die Variante, dann siehst du, wie.',
          '$own costs you ${_amount(-mat)} later on. Step through the line above to see how.',
        ),
      );
    } else if (mat <= -1) {
      parts.add(
        tr.t(
          'Am Ende der Variante fehlt dir ${_amount(-mat)}.',
          'At the end of the line you are ${_amount(-mat)} down.',
        ),
      );
    } else if (parts.isEmpty && missedMate != null) {
      parts.add(tr.t('$own verliert nichts, verpasst aber ein Matt.', '$own loses nothing, but misses a mate.'));
    } else if (parts.isEmpty && missedMaterial >= 2) {
      parts.add(
        tr.t(
          '$own verliert kein Material, lässt aber eine Chance aus: Mit dem besten Zug gewinnst du ${_amount(missedMaterial, acc: true)}.',
          '$own loses no material, but misses a chance: the best move wins ${_amount(missedMaterial)}.',
        ),
      );
    } else if (parts.isEmpty) {
      parts.add(
        tr.t(
          '$own verliert kein Material, aber dein Gegner bekommt danach das leichtere Spiel.',
          '$own loses no material, but afterwards your opponent has the easier game.',
        ),
      );
    }
    return parts;
  }

  /// Was ein eigener Zug Gutes bewirkt ([line] beginnt mit dem Zug, [own] ist der markierte Zug).
  List<String> _strengths(Position pos, List<String> line, String own, {required bool quietFallback}) {
    final parts = <String>[];
    if (line.isEmpty) return parts;
    final f = MoveFacts.of(pos, line.first);
    if (f == null) return parts;
    final cap = f.captured;
    if (cap != null) {
      final what = '${_acc(cap.role, false)} auf ${cap.square.name}';
      final whatEn = '${_acc(cap.role, false)} on ${cap.square.name}';
      if (f.capturedUndefended) {
        parts.add(
          tr.t('$own schlägt $what – ungedeckt, also ein Geschenk.', '$own takes $whatEn – undefended, a free gift.'),
        );
      } else if (value(cap.role) > value(f.mover)) {
        parts.add(
          tr.t(
            '$own schlägt $what mit einer weniger wertvollen Figur – der Tausch lohnt sich.',
            '$own takes $whatEn with a less valuable piece – the trade pays off.',
          ),
        );
      } else {
        parts.add(tr.t('$own schlägt $what.', '$own takes $whatEn.'));
      }
    }
    if (f.fork) {
      final hit = _list([for (final t in f.targets.where((t) => t.role != Role.king)) _acc(t.role, false)]);
      parts.add(
        f.check
            ? tr.t(
                '$own gibt Schach und greift gleichzeitig $hit an – eine Gabel.',
                '$own gives check and attacks $hit at the same time – a fork.',
              )
            : tr.t(
                '$own greift $hit gleichzeitig an – beides kann dein Gegner nicht retten.',
                '$own attacks $hit at once – your opponent cannot save both.',
              ),
      );
    } else if (f.check && !f.mate) {
      parts.add(
        tr.t(
          '$own gibt Schach, dein Gegner muss zuerst darauf reagieren.',
          '$own gives check, so your opponent has to deal with that first.',
        ),
      );
    }
    if (f.rescued) {
      parts.add(
        tr.t('$own bringt ${_acc(f.mover, true)} aus der Gefahr.', '$own gets ${_acc(f.mover, true)} out of danger.'),
      );
    }
    final mat = lineMaterial(pos, line, pos.turn);
    if (mat >= 1) {
      parts.add(
        tr.t(
          'Am Ende der Variante hast du ${_amount(mat, acc: true)} mehr.',
          'At the end of the line you are ${_amount(mat)} up.',
        ),
      );
    }
    if (parts.isEmpty && quietFallback) {
      parts.add(switch (f) {
        _ when f.castles => tr.t(
          '$own bringt deinen König mit der Rochade in Sicherheit.',
          '$own castles and brings your king to safety.',
        ),
        _ when f.develops => tr.t('$own bringt eine weitere Figur ins Spiel.', '$own brings another piece into play.'),
        _ when f.centerPawn => tr.t('$own besetzt das Zentrum.', '$own takes the centre.'),
        _ => tr.t(
          '$own ist ein ruhiger Zug, der deine Stellung gesund hält.',
          '$own is a quiet move that keeps your position healthy.',
        ),
      });
    }
    return parts;
  }

  /// Einschätzung der Stellung in Worten mit Gewinnchance: „du stehst klar besser (72 %)“.
  String _standing(double win) => '${_standingWords(win)} (${win.round()} %)';

  String _standingWords(double win) => switch (win) {
    >= 85 => tr.t('du stehst auf Gewinn', 'you are winning'),
    >= 65 => tr.t('du stehst klar besser', 'you are clearly better'),
    >= 55 => tr.t('du stehst etwas besser', 'you are slightly better'),
    > 45 => tr.t('die Stellung ist ausgeglichen', 'the position is equal'),
    > 35 => tr.t('du stehst etwas schlechter', 'you are slightly worse'),
    > 15 => tr.t('du stehst klar schlechter', 'you are clearly worse'),
    _ => tr.t('die Partie ist praktisch verloren', 'the game is practically lost'),
  };

  /// Materialmenge in Worten.
  String _amount(int n, {bool acc = false}) => switch (n) {
    1 => tr.t(acc ? 'einen Bauern' : 'ein Bauer', 'a pawn'),
    2 => tr.t('etwa zwei Bauern', 'about two pawns'),
    3 || 4 => tr.t('etwa eine Figur', 'about a piece'),
    5 || 6 => tr.t(acc ? 'etwa einen Turm' : 'etwa ein Turm', 'about a rook'),
    >= 8 && <= 10 => tr.t('etwa eine Dame', 'about a queen'),
    _ => tr.t('etwa $n Bauerneinheiten', 'about $n pawns'),
  };

  String _name(Role r, {bool acc = false}) => switch (r) {
    Role.pawn => tr.t(acc ? 'Bauern' : 'Bauer', 'pawn'),
    Role.knight => tr.t('Springer', 'knight'),
    Role.bishop => tr.t('Läufer', 'bishop'),
    Role.rook => tr.t('Turm', 'rook'),
    Role.queen => tr.t('Dame', 'queen'),
    Role.king => tr.t('König', 'king'),
  };

  /// „deinen Springer“, „seine Dame“ (Akkusativ) bzw. „your knight“, „their queen“.
  String _acc(Role r, bool mine) => tr.de
      ? '${mine ? 'dein' : 'sein'}${r == Role.queen ? 'e' : 'en'} ${_name(r, acc: true)}'
      : '${mine ? 'your' : 'their'} ${_name(r)}';

  /// „dein Springer“, „deine Dame“ (Nominativ).
  String _nom(Role r, bool mine) => tr.de
      ? '${mine ? 'dein' : 'sein'}${r == Role.queen ? 'e' : ''} ${_name(r)}'
      : '${mine ? 'your' : 'their'} ${_name(r)}';

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _list(List<String> xs) => switch (xs.length) {
    0 => '',
    1 => xs.first,
    _ => '${xs.sublist(0, xs.length - 1).join(', ')} ${tr.t('und', 'and')} ${xs.last}',
  };

  /// Zwei Sätze zur ganzen Partie.
  /// Ein Satz für die Partieansicht (die Fehlerzahlen stehen dort schon daneben).
  String summaryShort(GameAnalysis a) => summary(a).split(RegExp(r'(?<=\.) ')).first;

  String summary(GameAnalysis a) {
    final acc = a.accuracy ?? 0;
    final blunders = a.counts[MistakeClass.blunder] ?? 0;
    // Viele Patzer passen nicht zu „solide“ oder „sauber“, auch wenn die Genauigkeit hoch ist
    final first = switch (acc) {
      >= 75 when blunders >= 2 => tr.t(
        'Über weite Strecken ordentlich gespielt, aber einzelne Züge haben viel gekostet.',
        'Decent play for long stretches, but a few moves cost a lot.',
      ),
      >= 90 => tr.t('Sehr sauber gespielt.', 'Very cleanly played.'),
      >= 75 => tr.t('Eine solide Partie mit einigen Ungenauigkeiten.', 'A solid game with a few inaccuracies.'),
      >= 60 => tr.t('Eine Partie mit Höhen und Tiefen.', 'A game with ups and downs.'),
      _ => tr.t(
        'Eine schwierige Partie – genau daraus lernst du am meisten.',
        'A tough game – exactly the kind you learn most from.',
      ),
    };
    final second = blunders == 0
        ? tr.t('Ohne Patzer – das ist die halbe Miete.', 'No blunders – that is half the battle.')
        : tr.t(
            '$blunders ${blunders == 1 ? 'Patzer hat' : 'Patzer haben'} die Partie am stärksten beeinflusst.',
            '$blunders ${blunders == 1 ? 'blunder' : 'blunders'} shaped the game the most.',
          );
    return '$first $second';
  }

  /// Ein Merksatz für die nächsten Partien, abgeleitet aus dem folgenreichsten Fehler.
  String learningPoint(GameAnalysis a) {
    if (a.moments.isEmpty) {
      return tr.t(
        'Weiter so: Vor jedem Zug kurz prüfen, was der Gegner droht – das hat heute gut funktioniert.',
        'Keep it up: briefly check your opponent’s threats before every move – it worked well today.',
      );
    }
    final worst = a.moments.reduce((x, y) => y.drop > x.drop ? y : x);
    if (_has(worst, 'allows_mate')) {
      return tr.t(
        'Vor jedem Zug prüfen: Welche Schachs und Schlagzüge hat mein Gegner danach gegen meinen König?',
        'Before every move, check: which checks and captures does my opponent have against my king afterwards?',
      );
    }
    if (_has(worst, 'hangs_material')) {
      return tr.t(
        'Vor jedem Zug fragen: Welche meiner Figuren wird danach ungedeckt oder angreifbar?',
        'Before every move ask: which of my pieces becomes undefended or attackable afterwards?',
      );
    }
    if (_has(worst, 'mate_missed')) {
      return tr.t(
        'Immer zuerst alle eigenen Schachgebote durchrechnen – manchmal steckt ein Matt dahinter.',
        'Always calculate all your checks first – sometimes there is a mate behind them.',
      );
    }
    if (_has(worst, 'wins_material') || _has(worst, 'best_is_capture')) {
      return tr.t(
        'Nach jedem gegnerischen Zug fragen: Steht jetzt etwas ungedeckt, das ich schlagen kann?',
        'After every opponent move ask: is something undefended now that I can capture?',
      );
    }
    if (_has(worst, 'best_is_check')) {
      return tr.t(
        'Schachs, Schlagzüge, Drohungen – in dieser Reihenfolge prüfen, bevor du ziehst.',
        'Checks, captures, threats – check them in that order before you move.',
      );
    }
    return switch (worst.phase) {
      GamePhase.opening => tr.t(
        'In der Eröffnung: Figuren entwickeln, Zentrum besetzen, früh rochieren.',
        'In the opening: develop your pieces, control the centre, castle early.',
      ),
      GamePhase.endgame => tr.t(
        'Im Endspiel den König aktivieren und Freibauern vorantreiben.',
        'In the endgame: activate your king and push passed pawns.',
      ),
      GamePhase.middlegame => tr.t(
        'Vor jedem Zug prüfen: Was droht der Gegner, und welche meiner Figuren ist ungedeckt?',
        'Before every move check: what does my opponent threaten, and which of my pieces is undefended?',
      ),
    };
  }

  /// „Weiß am Zug“ bzw. „Schwarz am Zug“.
  String toMove(Side side) =>
      tr.t('${side == Side.white ? 'Weiß' : 'Schwarz'} am Zug', '${side == Side.white ? 'White' : 'Black'} to move');

  /// SAN ohne Zugnummer: "12...Nf6" → "Nf6".
  static String bareSan(String numbered) => numbered.replaceFirst(RegExp(r'^\d+\.(\.\.)?'), '');
}
