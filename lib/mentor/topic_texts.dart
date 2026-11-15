/// Namen und Erklärungen der Schwächen-Themen (Deutsch und Englisch).
library;

import '../ui/strings.dart';
import 'level_texts_data.dart';
import 'strength.dart';
import 'topics.dart';

extension TopicTexts on Tr {
  String topicName(Topic t) => switch (t) {
    Topic.hangsPiece => this.t('Figur eingestellt', 'Piece left hanging'),
    Topic.allowsMate => this.t('Matt zugelassen', 'Allowed a mate'),
    Topic.missedMate => this.t('Matt verpasst', 'Missed a mate'),
    Topic.missedMaterial => this.t('Material verpasst', 'Missed material'),
    Topic.missedCheck => this.t('Schachgebot übersehen', 'Missed a check'),
    Topic.advantageLost => this.t('Vorteil verspielt', 'Advantage thrown away'),
    Topic.whenWorse => this.t('Fehler in schlechter Stellung', 'Mistakes in a worse position'),
  };

  String topicHint(Topic t) => switch (t) {
    Topic.hangsPiece => this.t(
      'Der Gegner gewinnt auf deinen Zug hin Material.',
      'Your opponent wins material after your move.',
    ),
    Topic.allowsMate => this.t('Dein Zug lässt ein Matt zu.', 'Your move allows a mate.'),
    Topic.missedMate => this.t('Es gab ein Matt, du hast es nicht gespielt.', 'There was a mate you did not play.'),
    Topic.missedMaterial => this.t(
      'Ein Schlagzug oder Materialgewinn war besser als dein Zug.',
      'A capture or material gain was better than your move.',
    ),
    Topic.missedCheck => this.t('Ein Schachgebot war der stärkste Zug.', 'A check was the strongest move.'),
    Topic.advantageLost => this.t(
      'Du standst gut und hast durch einen schweren Fehler viel abgegeben.',
      'You were better and gave a lot away with a serious mistake.',
    ),
    Topic.whenWorse => this.t(
      'Du standst schon schlechter und hast weitere Gewinnchance verloren.',
      'You were already worse and lost more winning chances.',
    ),
  };

  /// Merksatz zum Thema (Textbaustein).
  String topicRule(Topic t) => switch (t) {
    Topic.hangsPiece => this.t(
      'Vor jedem Zug fragen: Welche meiner Figuren wird danach ungedeckt oder angreifbar?',
      'Before every move ask: which of my pieces becomes undefended or attackable afterwards?',
    ),
    Topic.allowsMate => this.t(
      'Vor jedem Zug prüfen: Welche Schachs und Schlagzüge hat mein Gegner danach gegen meinen König?',
      'Before every move check: which checks and captures does my opponent have against my king afterwards?',
    ),
    Topic.missedMate => this.t(
      'Immer zuerst alle eigenen Schachgebote durchrechnen – manchmal steckt ein Matt dahinter.',
      'Always calculate all your checks first – sometimes there is a mate behind them.',
    ),
    Topic.missedMaterial => this.t(
      'Nach jedem gegnerischen Zug fragen: Steht jetzt etwas ungedeckt, das ich schlagen kann?',
      'After every opponent move ask: is something undefended now that I can capture?',
    ),
    Topic.missedCheck => this.t(
      'Schachs, Schlagzüge, Drohungen – in dieser Reihenfolge prüfen, bevor du ziehst.',
      'Checks, captures, threats – check them in that order before you move.',
    ),
    Topic.advantageLost => this.t(
      'Mit Vorteil nicht hastig werden: Gegenspiel des Gegners prüfen und lieber vereinfachen als Risiken eingehen.',
      'With an advantage do not rush: check your opponent\'s counterplay and simplify rather than take risks.',
    ),
    Topic.whenWorse => this.t(
      'In schlechter Stellung ruhig bleiben: Schwächen decken, nichts einstellen und auf einen Gegnerfehler warten.',
      'When worse stay calm: cover weaknesses, do not hang anything and wait for an opponent mistake.',
    ),
  };

  /// Kurze Prüffrage vor jedem Zug während des Fokus.
  String topicCheck(Topic t) => switch (t) {
    Topic.hangsPiece => this.t('Ist nach meinem Zug jede meiner Figuren gedeckt?', 'After my move, is every piece of mine protected?'),
    Topic.allowsMate => this.t('Hat mein Gegner danach ein Schach, das mich in Not bringt?', 'Does my opponent have a check afterwards that puts me in trouble?'),
    Topic.missedMate => this.t('Habe ich alle meine Schachgebote durchgerechnet?', 'Have I calculated all my checks?'),
    Topic.missedMaterial => this.t('Hat mein Gegner gerade etwas ungedeckt gelassen?', 'Did my opponent just leave something undefended?'),
    Topic.missedCheck => this.t('Welche Schachs, Schlagzüge und Drohungen habe ich?', 'Which checks, captures and threats do I have?'),
    Topic.advantageLost => this.t('Was ist das sicherste Weiterspielen mit meinem Vorteil?', 'What is the safest way to continue with my advantage?'),
    Topic.whenWorse => this.t('Was ist der ruhigste Zug, der nichts verschlechtert?', 'What is the calmest move that makes nothing worse?'),
  };

  /// Prüffrage passend zur Stufe (Elo-Anpassung); ohne Stufe die allgemeine [topicCheck].
  String topicCheckFor(Topic t, Level? level) {
    if (level == null) return topicCheck(t);
    final x = levelTexts[t]![level.index];
    return this.t(x.checkDe, x.checkEn);
  }

  /// Der stufenspezifische Schritt für das Info-Blatt.
  String topicStepFor(Topic t, Level level) {
    final x = levelTexts[t]![level.index];
    return this.t(x.stepDe, x.stepEn);
  }
}
