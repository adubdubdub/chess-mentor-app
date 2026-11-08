/// Texte des Mentors ohne Sprachmodell: Fragen, Tipps, Erklärungen und Lernpunkt aus den Engine-Fakten.
///
/// Gegenstück zu coach.py des Bots. Alle Züge und Varianten stammen aus der Analyse; Fragen und Tipps verraten den
/// besten Zug nicht.
library;

import 'package:dartchess/dartchess.dart' show Side;

import '../analysis/analysis.dart';
import '../analysis/chess_utils.dart' show GamePhase;
import '../ui/strings.dart';

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

  /// Warum der Partiezug schwach war und was der beste Zug erreicht.
  String explanation(Moment m) {
    final parts = <String>[
      tr.t(
        '${tr.san(m.played)} (${tr.mistake(m.mistake)}): Deine Gewinnchance fiel von ${m.winBefore.round()} % auf ${m.winAfter.round()} %.',
        '${tr.san(m.played)} (${tr.mistake(m.mistake)}): your winning chance dropped from ${m.winBefore.round()} % to ${m.winAfter.round()} %.',
      ),
    ];
    if (_has(m, 'allows_mate')) {
      parts.add(tr.t('Danach kann dein Gegner mattsetzen.', 'After that your opponent can force mate.'));
    } else if (_has(m, 'hangs_material')) {
      parts.add(tr.t('Danach gewinnt dein Gegner Material.', 'After that your opponent wins material.'));
    }
    if (m.replyLine.isNotEmpty) {
      parts.add(tr.t('Die beste Antwort darauf: ${tr.san(m.replyLine)}.', 'The best reply: ${tr.san(m.replyLine)}.'));
    }
    parts.add(
      tr.t('Stärker war ${tr.san(m.best)}', 'Stronger was ${tr.san(m.best)}') +
          (m.bestLine.isNotEmpty
              ? tr.t(' mit der Fortsetzung ${tr.san(m.bestLine)}.', ', continuing ${tr.san(m.bestLine)}.')
              : '.'),
    );
    final mate = _n(m, 'mate_missed');
    final gain = _n(m, 'wins_material');
    if (mate != null) {
      parts.add(tr.t('Das führt zu Matt in $mate.', 'That leads to mate in $mate.'));
    } else if (gain != null) {
      parts.add(tr.t('Damit gewinnst du etwa $gain Bauerneinheiten.', 'That wins about $gain pawns.'));
    }
    return parts.join(' ');
  }

  /// Zwei Sätze zur ganzen Partie.
  String summary(GameAnalysis a) {
    final acc = a.accuracy ?? 0;
    final first = switch (acc) {
      >= 90 => tr.t('Sehr sauber gespielt.', 'Very cleanly played.'),
      >= 75 => tr.t('Eine solide Partie mit einigen Ungenauigkeiten.', 'A solid game with a few inaccuracies.'),
      >= 60 => tr.t('Eine Partie mit Höhen und Tiefen.', 'A game with ups and downs.'),
      _ => tr.t(
        'Eine schwierige Partie – genau daraus lernst du am meisten.',
        'A tough game – exactly the kind you learn most from.',
      ),
    };
    final blunders = a.counts[MistakeClass.blunder] ?? 0;
    final second = blunders == 0
        ? tr.t('Ohne Patzer – das ist die halbe Miete.', 'No blunders – that is half the battle.')
        : tr.t(
            '$blunders ${blunders == 1 ? 'Patzer hat' : 'Patzer haben'} die Partie am stärksten beeinflusst, die schauen wir uns an.',
            '$blunders ${blunders == 1 ? 'blunder' : 'blunders'} shaped the game the most – let’s look at ${blunders == 1 ? 'it' : 'them'}.',
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
