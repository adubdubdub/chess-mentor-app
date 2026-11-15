/// Namen und Erklärungen der Schwächen-Themen (Deutsch und Englisch).
library;

import '../ui/strings.dart';
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
}
