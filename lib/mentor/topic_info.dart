/// Ausführliche Erklärung zu einem Schwächen-Thema: worum es geht, warum es passiert, wie man es besser macht.
library;

import '../ui/strings.dart';
import 'topic_texts.dart';
import 'topics.dart';

class TopicInfo {
  const TopicInfo({required this.what, required this.why, required this.how, required this.practice});

  final String what;
  final String why;

  /// Konkrete Schritte, die man vor und während des Zuges anwendet.
  final List<String> how;

  /// Wie man das Thema in der Woche trainiert.
  final String practice;
}

extension TopicInfoTexts on Tr {
  TopicInfo topicInfo(Topic t) {
    final practice = this.t(
      'Löse die Fokus-Puzzles zu diesem Thema und achte bei jeder Auflösung auf die Antwort des Gegners. In deinen Partien '
          'stellst du vor jedem Zug die Prüffrage: „${topicCheck(t)}“',
      'Solve the focus puzzles on this topic and watch your opponent\'s reply in every solution. In your games, ask the '
          'check question before every move: “${topicCheck(t)}”',
    );
    return switch (t) {
      Topic.hangsPiece => TopicInfo(
        what: this.t(
          'Du ziehst, und danach kann dein Gegner eine deiner Figuren gewinnen, weil sie ungedeckt steht oder von einer weniger wertvollen Figur angegriffen wird.',
          'You move, and afterwards your opponent can win one of your pieces because it is undefended or attacked by a less valuable piece.',
        ),
        why: this.t(
          'Beim Ziehen denkt man meist an den eigenen Plan und prüft nicht, was der Zug zurücklässt: eine Figur, die bisher von der gezogenen Figur gedeckt war, oder ein neues Angriffsziel.',
          'When moving you usually think about your own plan and do not check what the move leaves behind: a piece that was protected by the moved piece, or a new target.',
        ),
        how: [
          this.t(
            'Lies zuerst den letzten Zug deines Gegners: Was greift er an, was hat er geöffnet?',
            'First read your opponent\'s last move: what does it attack, what did it open?',
          ),
          this.t(
            'Frage vor jedem Zug: Welche meiner Figuren steht danach ungedeckt oder wird von einer billigeren Figur angegriffen?',
            'Before every move ask: which of my pieces is undefended afterwards or attacked by a cheaper piece?',
          ),
          this.t(
            'Prüfe, welche Figur die bewegte bisher gedeckt hat. Wird dadurch eine andere Figur ungeschützt?',
            'Check which piece the moved piece used to protect. Does that leave another piece undefended?',
          ),
          this.t(
            'Im Zweifel wähle den Zug, der Figuren verbindet und deckt, statt eines riskanten Angriffs.',
            'When in doubt choose the move that connects and protects your pieces rather than a risky attack.',
          ),
        ],
        practice: practice,
      ),
      Topic.allowsMate => TopicInfo(
        what: this.t(
          'Dein Zug lässt ein Matt zu, meist durch ein Schach, das du nicht eingeplant hast.',
          'Your move allows a mate, usually through a check you did not account for.',
        ),
        why: this.t(
          'Der eigene König gerät bei der Planung aus dem Blick, besonders bei Angriffen auf der anderen Brettseite oder wenn Figuren den Königsschutz verlassen.',
          'Your own king drops out of view while planning, especially when attacking on the other side or when pieces leave the king\'s shelter.',
        ),
        how: [
          this.t(
            'Zähle vor jedem Zug alle gegnerischen Schachs und Schlagzüge gegen deinen König auf.',
            'Before every move list all your opponent\'s checks and captures against your king.',
          ),
          this.t(
            'Zähle die Fluchtfelder: Hat dein König nach dem Zug noch ein sicheres Feld? Matt droht dort, wo es keins gibt.',
            'Count flight squares: does your king still have a safe square afterwards? Mate threatens where there is none.',
          ),
          this.t(
            'Bewege Bauern und Figuren vor dem König nur, wenn du die Folgen für die Königsstellung geprüft hast.',
            'Move pawns and pieces in front of your king only after checking the consequences for its safety.',
          ),
          this.t(
            'Bring den König früh in Sicherheit (Rochade) und halte die Grundreihe im Blick.',
            'Get your king to safety early (castling) and keep an eye on the back rank.',
          ),
        ],
        practice: practice,
      ),
      Topic.missedMate => TopicInfo(
        what: this.t(
          'Es gab ein Matt oder eine Mattfolge, und du hast einen anderen Zug gespielt.',
          'There was a mate or a mating sequence and you played a different move.',
        ),
        why: this.t(
          'Schachgebote werden nicht systematisch durchgerechnet, oder die Rechnung wird zu früh abgebrochen, weil der erste Versuch nicht aufgeht.',
          'Checks are not calculated systematically, or the calculation stops too early because the first attempt does not work.',
        ),
        how: [
          this.t(
            'Sieh dir immer zuerst alle Schachgebote an, auch scheinbar sinnlose.',
            'Always look at all checks first, even seemingly pointless ones.',
          ),
          this.t(
            'Frage bei jedem Schach: Wohin kann der König? Gibt es nur eine Antwort? Dann rechne dort weiter.',
            'For every check ask: where can the king go? Is there only one reply? Then continue calculating there.',
          ),
          this.t(
            'Kenne die typischen Mattbilder (Grundreihe, Dame mit Läufer, Erstickungsmatt) und suche danach.',
            'Know the typical mating patterns (back rank, queen and bishop, smothered mate) and look for them.',
          ),
          this.t(
            'Hat der gegnerische König wenige Felder, rechne gründlicher, bevor du ein ruhiges Angriffsmanöver wählst.',
            'When the enemy king has few squares, calculate more carefully before choosing a quiet attacking move.',
          ),
        ],
        practice: practice,
      ),
      Topic.missedMaterial => TopicInfo(
        what: this.t(
          'Ein Schlagzug oder eine Folge, die Material gewinnt, war besser als dein Zug. Du hast die Chance nicht genutzt.',
          'A capture or a sequence that wins material was better than your move. You did not take the chance.',
        ),
        why: this.t(
          'Nach dem gegnerischen Zug wird nicht gefragt, was er ungedeckt gelassen oder geöffnet hat. Man spielt den eigenen Plan weiter, statt die Stellung neu zu lesen.',
          'After the opponent\'s move you do not ask what it left undefended or opened. You continue your own plan instead of reading the position anew.',
        ),
        how: [
          this.t(
            'Frage nach jedem gegnerischen Zug: Was steht jetzt ungedeckt? Was wurde angegriffen?',
            'After every opponent move ask: what is undefended now? What is attacked?',
          ),
          this.t(
            'Gehe vor deinem eigenen Plan alle Schlagzüge kurz durch: Lohnt sich einer?',
            'Before your own plan, run through all captures briefly: is one worth it?',
          ),
          this.t(
            'Prüfe, ob die Figur wirklich gedeckt ist: Zähle Angreifer gegen Verteidiger und beachte den Wert der Figuren.',
            'Check whether the piece is really protected: count attackers against defenders and mind the piece values.',
          ),
          this.t(
            'Suche Zwischenzüge (Schach) und Gabeln, die Material erzwingen.',
            'Look for in-between moves (checks) and forks that force material.',
          ),
        ],
        practice: practice,
      ),
      Topic.missedCheck => TopicInfo(
        what: this.t(
          'Der stärkste Zug war ein Schachgebot, du hast einen ruhigeren Zug gespielt.',
          'The strongest move was a check and you played a quieter move.',
        ),
        why: this.t(
          'Schachs werden als „Verschwendung“ abgetan, dabei gewinnen sie oft Tempo, Material oder führen zu Matt.',
          'Checks are dismissed as “wasted”, yet they often win tempo or material or lead to mate.',
        ),
        how: [
          this.t(
            'Prüfe in dieser Reihenfolge: Schachs, Schlagzüge, Drohungen.',
            'Check in this order: checks, captures, threats.',
          ),
          this.t(
            'Frage bei jedem Schach: Wohin kann der König, und was gewinne ich danach?',
            'For every check ask: where can the king go and what do I win afterwards?',
          ),
          this.t(
            'Suche Schachs mit Gabel: Greift die schachbietende Figur gleichzeitig eine zweite Figur an?',
            'Look for checks with a fork: does the checking piece attack a second piece at the same time?',
          ),
          this.t(
            'Spiele nicht jedes Schach, sondern nur, wenn ein konkreter Nutzen sichtbar ist.',
            'Do not play every check, only when a concrete gain is visible.',
          ),
        ],
        practice: practice,
      ),
      Topic.advantageLost => TopicInfo(
        what: this.t(
          'Du standest klar besser und hast durch einen schweren Fehler viel abgegeben.',
          'You were clearly better and gave a lot away with a serious mistake.',
        ),
        why: this.t(
          'Mit Vorteil wird oft hastig oder zu risikofreudig gespielt, oder man übersieht Gegenspiel, weil man nur den eigenen Gewinnplan sieht.',
          'With an advantage people often play hastily or take too many risks, or miss counterplay because they only see their own winning plan.',
        ),
        how: [
          this.t(
            'Frage zuerst: Was ist der Plan meines Gegners, und wie verhindere ich ihn?',
            'First ask: what is my opponent\'s plan and how do I prevent it?',
          ),
          this.t(
            'Strebe Tausche an, vor allem von Figuren, die dem Gegner Gegenspiel geben (Dame, aktive Figuren).',
            'Aim for trades, especially of pieces that give the opponent counterplay (queen, active pieces).',
          ),
          this.t(
            'Wähle den sicheren Zug vor dem spektakulären. Ein Vorteil gewinnt sich durch Geduld.',
            'Choose the safe move over the spectacular one. An advantage is converted with patience.',
          ),
          this.t(
            'Wende die Prüffragen (Schach, Schlag, Drohung) mit besonderer Sorgfalt auch für den Gegner an.',
            'Apply the check questions (check, capture, threat) with extra care, also for your opponent.',
          ),
        ],
        practice: practice,
      ),
      Topic.whenWorse => TopicInfo(
        what: this.t(
          'Du standest schon schlechter und hast die Stellung durch weitere Fehler noch verschlechtert.',
          'You were already worse and made the position worse with further mistakes.',
        ),
        why: this.t(
          'Unter Druck wird schneller oder verzweifelter gespielt, oder man gibt innerlich auf. Kleine Fehler summieren sich dann.',
          'Under pressure people play faster or more desperately, or give up inside. Small mistakes then add up.',
        ),
        how: [
          this.t(
            'Bleib ruhig und suche den besten verteidigenden Zug, nicht einen Befreiungsschlag.',
            'Stay calm and look for the best defensive move, not a desperate break.',
          ),
          this.t(
            'Decke Schwächen, verbinde die Figuren und sichere den König.',
            'Cover weaknesses, connect your pieces and secure your king.',
          ),
          this.t(
            'Vermeide Tausche, die den Gegner entlasten, und warte auf einen Gegnerfehler.',
            'Avoid trades that relieve your opponent and wait for an opponent mistake.',
          ),
          this.t(
            'Nimm dir in schlechter Stellung bewusst mehr Zeit und prüfe jeden Zug auf Verluste.',
            'In a worse position deliberately take more time and check every move for losses.',
          ),
        ],
        practice: practice,
      ),
    };
  }
}
