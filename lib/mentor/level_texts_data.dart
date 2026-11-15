/// Stufenspezifische Hinweise je Thema (Elo-Anpassung E3): ein Schritt für die Info-Blätter und eine Prüffrage.
/// Reihenfolge der Listen: Einsteiger, Fortgeschrittener Anfänger, Mittelstufe, Fortgeschritten (wie `Level`).
library;

import 'topics.dart';

typedef LevelText = ({String stepDe, String stepEn, String checkDe, String checkEn});

const Map<Topic, List<LevelText>> levelTexts = {
  Topic.hangsPiece: [
    (
      stepDe: 'Zähle vor dem Ziehen deine Figuren durch: Steht eine ohne Schutz, kann dein Gegner sie sofort schlagen. Bewege keine Figur, die eine andere schützt.',
      stepEn: 'Before moving, count your pieces: if one is unprotected, your opponent can take it right away. Do not move a piece that protects another.',
      checkDe: 'Steht jede meiner Figuren sicher, oder kann der Gegner eine einfach schlagen?',
      checkEn: 'Is every piece of mine safe, or can my opponent simply take one?',
    ),
    (
      stepDe: 'Prüfe bei jedem Zugkandidaten zwei Dinge: Wird eine meiner Figuren angegriffen, und ist sie gedeckt? Eine Figur, die ein Bauer angreift, kostet dich Material, selbst wenn sie gedeckt ist.',
      stepEn: 'For every candidate move check two things: is one of my pieces attacked, and is it protected? A piece attacked by a pawn costs you material even if it is protected.',
      checkDe: 'Wird nach meinem Zug eine Figur angegriffen, und ist sie gedeckt?',
      checkEn: 'After my move, is a piece attacked, and is it protected?',
    ),
    (
      stepDe: 'Denke in Verbindungen: Welche Figuren decken sich gegenseitig, und welcher Verteidiger ist überlastet, weil er zwei Aufgaben hat?',
      stepEn: 'Think in connections: which pieces protect each other, and which defender is overloaded because it has two jobs?',
      checkDe: 'Welche meiner Figuren hängt an einem einzigen Verteidiger?',
      checkEn: 'Which of my pieces depends on a single defender?',
    ),
    (
      stepDe: 'Prüfe Überlastung und Ablenkung: Wenn der Gegner einen Verteidiger wegzieht oder vertreibt, was fällt dann? Solche Zwischenzüge findest du nur, wenn du seine stärksten Forderungen durchrechnest.',
      stepEn: 'Check overload and deflection: if your opponent removes or chases away a defender, what falls? You only find such in-between moves by calculating his most forcing options.',
      checkDe: 'Welchen Verteidiger kann der Gegner ablenken oder vertreiben, und was fällt dann?',
      checkEn: 'Which defender can my opponent deflect or chase away, and what falls then?',
    ),
  ],
  Topic.allowsMate: [
    (
      stepDe: 'Prüfe, ob dein König nach dem Zug noch Felder zum Ausweichen hat. Gibt der Gegner Schach und es gibt kein freies Feld, ist es Matt.',
      stepEn: 'Check that your king still has squares to move to after your move. If your opponent checks and there is no free square, it is mate.',
      checkDe: 'Kann mein Gegner mir nach dem Zug Schach geben, und wohin kann mein König dann?',
      checkEn: 'After my move, can my opponent give me a check, and where can my king go?',
    ),
    (
      stepDe: 'Achte aufs Grundreihenmatt: Steht dein König hinter eigenen Bauern ohne Fluchtfeld, reicht ein Turm- oder Damenschach. Schaffe vorher mit einem Bauernzug Luft.',
      stepEn: 'Watch for back-rank mate: if your king sits behind its own pawns with no flight square, one rook or queen check is enough. Make room with a pawn move beforehand.',
      checkDe: 'Hat mein König nach dem Zug ein Fluchtfeld, und deckt eine Figur die Grundreihe?',
      checkEn: 'Does my king have a flight square after the move, and does a piece guard the back rank?',
    ),
    (
      stepDe: 'Beachte, wo dein Königsschutz schwächer wird: Wenn Bauern vor dem König gezogen wurden, prüfe Batterien aus Dame und Läufer auf der offenen Diagonale.',
      stepEn: 'Notice where your king\'s shelter gets weaker: if pawns in front of the king have moved, check queen-and-bishop batteries on the open diagonal.',
      checkDe: 'Wo wird mein Königsschutz schwächer, und welche Gegnerfigur kann dort eindringen?',
      checkEn: 'Where is my king\'s shelter getting weaker, and which enemy piece can break in there?',
    ),
    (
      stepDe: 'Rechne die Schachfolgen des Gegners mit Zwischenzügen durch: Reicht ein Opfer, um meinen Königsschutz zu sprengen? Vorbeugen ist besser als Verteidigen.',
      stepEn: 'Calculate your opponent\'s check sequences including in-between moves: is a sacrifice enough to blow up my king\'s shelter? Prevention beats defence.',
      checkDe: 'Welches Opfer oder welcher Durchbruch könnte meinen Königsschutz sprengen?',
      checkEn: 'Which sacrifice or breakthrough could blow up my king\'s shelter?',
    ),
  ],
  Topic.missedMate: [
    (
      stepDe: 'Schau bei jedem Zug, ob du Schach geben kannst. Hat der gegnerische König nur wenige freie Felder, kann ein Schach schon Matt sein.',
      stepEn: 'On every move look whether you can give check. If the enemy king has few free squares, a check can already be mate.',
      checkDe: 'Kann ich dem König Schach geben, und wohin kann er dann ziehen?',
      checkEn: 'Can I check the king, and where can it go then?',
    ),
    (
      stepDe: 'Rechne jedes Schach bis zum Ende: Welche Antworten hat der König, kann man das Schach schlagen oder blocken? Bleibt keine, ist es Matt.',
      stepEn: 'Calculate every check to the end: what replies does the king have, can the check be captured or blocked? If none remain, it is mate.',
      checkDe: 'Gibt es ein Schach, nach dem der König keine gute Antwort hat?',
      checkEn: 'Is there a check after which the king has no good reply?',
    ),
    (
      stepDe: 'Suche Mattmuster mehrere Züge voraus: Ein Opfer, das Fluchtfelder nimmt, führt oft in zwei oder drei Zügen zum Matt.',
      stepEn: 'Look for mating patterns several moves ahead: a sacrifice that takes away flight squares often leads to mate in two or three moves.',
      checkDe: 'Welche Fluchtfelder des Königs kann ich mit einem Opfer oder Schach nehmen?',
      checkEn: 'Which flight squares of the king can I take with a sacrifice or a check?',
    ),
    (
      stepDe: 'Zähle forcierte Varianten systematisch: erst Schachs, dann Mattdrohungen, dann ruhige Züge, die Matt erzwingen. Prüfe alle Königsantworten, bevor du die Variante verwirfst.',
      stepEn: 'Count forcing lines systematically: first checks, then mate threats, then quiet moves that force mate. Check all king replies before you discard a line.',
      checkDe: 'Wo führt eine forcierte Folge aus Schachs und Mattdrohungen zum Ziel?',
      checkEn: 'Where does a forcing sequence of checks and mate threats succeed?',
    ),
  ],
  Topic.missedMaterial: [
    (
      stepDe: 'Schau, ob eine Figur deines Gegners nicht gedeckt ist: Dann kannst du sie schlagen. Schlage nur, wenn danach deine eigene Figur sicher bleibt.',
      stepEn: 'Look whether one of your opponent\'s pieces is unprotected: then you can capture it. Only capture if your own piece stays safe afterwards.',
      checkDe: 'Steht beim Gegner eine Figur ungeschützt, die ich schlagen kann?',
      checkEn: 'Is one of my opponent\'s pieces unprotected so that I can take it?',
    ),
    (
      stepDe: 'Suche Gabeln: Greift ein Springer oder die Dame zwei Figuren gleichzeitig an, gewinnst du meist Material. Prüfe auch Fesselungen.',
      stepEn: 'Look for forks: if a knight or the queen attacks two pieces at once, you usually win material. Check pins as well.',
      checkDe: 'Kann eine meiner Figuren zwei Ziele gleichzeitig angreifen?',
      checkEn: 'Can one of my pieces attack two targets at once?',
    ),
    (
      stepDe: 'Suche Taktikmotive systematisch: Fesselung, Abzug, Ablenkung, Zwischenzug. Frage dich, welche gegnerische Figur überlastet ist.',
      stepEn: 'Search for tactical motifs systematically: pin, discovered attack, deflection, in-between move. Ask which enemy piece is overloaded.',
      checkDe: 'Welche Gegnerfigur ist überlastet oder gefesselt, und wie nutze ich das?',
      checkEn: 'Which enemy piece is overloaded or pinned, and how do I use that?',
    ),
    (
      stepDe: 'Prüfe Zwischenzüge und Zugumstellungen, die Material erzwingen, bevor du deinen Plan fortsetzt. Rechne die Variante bis zum ruhigen Ende, damit du den Wert eines Opfers richtig einschätzt.',
      stepEn: 'Check in-between moves and move-order tricks that force material before you continue your plan. Calculate the line to a quiet position to judge the value of a sacrifice correctly.',
      checkDe: 'Welcher Zwischenzug oder welche Zugumstellung gewinnt hier Material?',
      checkEn: 'Which in-between move or move-order trick wins material here?',
    ),
  ],
  Topic.missedCheck: [
    (
      stepDe: 'Sieh dir jedes Schach an, auch wenn es zuerst sinnlos wirkt. Oft muss der König ziehen, und du gewinnst Zeit oder Material.',
      stepEn: 'Look at every check, even if it seems pointless at first. Often the king has to move and you gain time or material.',
      checkDe: 'Welche Schachs habe ich in dieser Stellung?',
      checkEn: 'Which checks do I have in this position?',
    ),
    (
      stepDe: 'Suche Schach mit Gabel: Eine Dame oder ein Springer, der König und eine zweite Figur gleichzeitig angreift, gewinnt Material.',
      stepEn:
          'Look for check with a fork: a queen or knight attacking the king and a second piece at once wins material.',
      checkDe: 'Gibt es ein Schach, das gleichzeitig eine zweite Figur angreift?',
      checkEn: 'Is there a check that attacks a second piece at the same time?',
    ),
    (
      stepDe: 'Nutze Schachs, um Tempo zu gewinnen oder die Königsstellung zu zerstören, bevor du ruhig weiterspielst. Rechne aber nach, ob der König danach besser steht.',
      stepEn: 'Use checks to gain tempo or wreck the king\'s position before you play on quietly. But check whether the king ends up better placed.',
      checkDe: 'Verbessert oder verschlechtert ein Schach die Lage meines Gegners?',
      checkEn: 'Does a check improve or worsen my opponent\'s position?',
    ),
    (
      stepDe: 'Prüfe, ob ein Schach einen Verteidiger vertreibt oder eine Linie öffnet. Bevorzuge Schachs, die ein stärkeres Folgemotiv vorbereiten.',
      stepEn: 'Check whether a check chases away a defender or opens a line. Prefer checks that prepare a stronger follow-up motif.',
      checkDe: 'Welches Schach bereitet ein stärkeres Folgemotiv vor?',
      checkEn: 'Which check prepares a stronger follow-up motif?',
    ),
  ],
  Topic.advantageLost: [
    (
      stepDe:
          'Wenn du eine Figur mehr hast, tausche ab. Spiele keine riskanten Angriffe, solange du ohnehin vorne liegst.',
      stepEn: 'When you are a piece up, trade pieces. Do not play risky attacks while you are ahead anyway.',
      checkDe: 'Kann ich mit Tauschen sicher einfacher spielen?',
      checkEn: 'Can I play more simply and safely by trading?',
    ),
    (
      stepDe: 'Prüfe vor jedem Zug, was der Gegner mit seinem letzten Zug erreichen will. Ein Vorteil geht oft durch einen einzigen übersehenen Angriff verloren.',
      stepEn: 'Before every move check what your opponent wants to achieve with his last move. An advantage is often lost to a single overlooked attack.',
      checkDe: 'Was will mein Gegner mit seinem letzten Zug erreichen?',
      checkEn: 'What does my opponent want to achieve with his last move?',
    ),
    (
      stepDe: 'Wandle den Vorteil planvoll um: Tausche aktive Gegnerfiguren, nimm ihm das Gegenspiel und öffne erst dann Linien für deinen Angriff.',
      stepEn: 'Convert the advantage with a plan: trade the opponent\'s active pieces, take away his counterplay and only then open lines for your attack.',
      checkDe: 'Welche Gegnerfigur gibt ihm noch Gegenspiel, und kann ich sie tauschen?',
      checkEn: 'Which enemy piece still gives him counterplay, and can I trade it?',
    ),
    (
      stepDe: 'Vergleiche zwei Fortsetzungen nach ihrem Risiko: Die sichere Umwandlung ist meist besser als eine forcierte Variante mit offenem Ausgang. Beuge dem besten Gegnerplan vor.',
      stepEn: 'Compare two continuations by risk: the safe conversion is usually better than a forcing line with an open outcome. Prevent the opponent\'s best plan.',
      checkDe: 'Welche Fortsetzung hat bei gleichem Vorteil weniger Risiko?',
      checkEn: 'Which continuation carries less risk for the same advantage?',
    ),
  ],
  Topic.whenWorse: [
    (
      stepDe: 'Wenn du schlechter stehst: Stelle nichts ein und tausche nicht ohne Not. Warte, ob dein Gegner einen Fehler macht.',
      stepEn: 'When you are worse: do not hang anything and do not trade without need. Wait to see whether your opponent makes a mistake.',
      checkDe: 'Was ist der sicherste Zug, bei dem ich nichts verliere?',
      checkEn: 'What is the safest move that loses nothing?',
    ),
    (
      stepDe: 'Finde die stärkste Drohung deines Gegners und wehre genau diese ab. So findest du meist den besten Verteidigungszug.',
      stepEn: 'Find your opponent\'s strongest threat and parry exactly that. That usually leads you to the best defensive move.',
      checkDe: 'Was ist die stärkste Drohung meines Gegners, und wie wehre ich sie ab?',
      checkEn: 'What is my opponent\'s strongest threat, and how do I parry it?',
    ),
    (
      stepDe: 'Suche aktive Verteidigung: ein Gegenschach, den Tausch des stärksten Angreifers oder eine Stellung, in der er nicht weiterkommt.',
      stepEn: 'Look for active defence: a counter-check, trading the strongest attacker or a position where he cannot make progress.',
      checkDe: 'Wie kann ich die Stellung festigen oder Gegenspiel schaffen?',
      checkEn: 'How can I consolidate the position or create counterplay?',
    ),
    (
      stepDe: 'Zähle deine Ressourcen: Dauerschach, Festung, Gegenopfer. Spiele den Zug, der die Stellung am schwersten angreifbar macht, nicht den, der den schnellsten Ausgleich verspricht.',
      stepEn: 'Count your resources: perpetual check, fortress, counter-sacrifice. Play the move that makes the position hardest to attack, not the one that promises the quickest equality.',
      checkDe: 'Welche Ressource (Dauerschach, Festung, Gegenopfer) hält die Stellung?',
      checkEn: 'Which resource (perpetual check, fortress, counter-sacrifice) holds the position?',
    ),
  ],
};
