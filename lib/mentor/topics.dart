/// Schwächen-Themen eines Fehlzugs (Schritt 6a). Alles wird aus vorhandenen Analysedaten abgeleitet, ohne neue Rechnung.
library;

import '../analysis/analysis.dart';

/// Ab welcher Gewinnchance vor dem Zug eine Stellung als „gut“ bzw. „schlecht“ gilt.
const goodWin = 65.0;
const badWin = 35.0;

/// Mindestverlust an Gewinnchance, damit ein Fehlzug als „Vorteil verspielt“ zählt.
const advantageDrop = 15.0;

enum Topic {
  /// Der Gegner gewinnt auf den Partiezug hin Material (Figur eingestellt).
  hangsPiece,

  /// Der Partiezug lässt ein Matt zu.
  allowsMate,

  /// Ein Matt war möglich und wurde verpasst.
  missedMate,

  /// Material war zu gewinnen (Schlagzug oder Gewinn laut Engine).
  missedMaterial,

  /// Der beste Zug war ein Schachgebot (ohne Matt).
  missedCheck,

  /// Gute Stellung (≥ [goodWin]) durch einen schweren Fehler verspielt.
  advantageLost,

  /// Fehler in einer schon schlechten Stellung (≤ [badWin]).
  whenWorse,
}

bool _has(Moment m, String code) => m.motifs.any((x) => x.code == code);

/// Themen eines Fehlzugs; ein Zug kann mehrere haben, manche haben keins (leer = „sonst ungenau“).
Set<Topic> topicsOf(Moment m) {
  final missedMate = _has(m, 'mate_missed');
  return {
    if (_has(m, 'hangs_material')) Topic.hangsPiece,
    if (_has(m, 'allows_mate')) Topic.allowsMate,
    if (missedMate) Topic.missedMate,
    if (_has(m, 'wins_material') || _has(m, 'best_is_capture')) Topic.missedMaterial,
    if (!missedMate && _has(m, 'best_is_check')) Topic.missedCheck,
    if (m.winBefore >= goodWin && m.drop >= advantageDrop) Topic.advantageLost,
    if (m.winBefore <= badWin) Topic.whenWorse,
  };
}
