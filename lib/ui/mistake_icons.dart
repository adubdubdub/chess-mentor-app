/// Farben und Symbole der Fehler-Einstufung, überall in der App gleich: Patzer rot (Achteck mit ×),
/// Fehler orange (Kreis mit !), Ungenauigkeit blau (Kreis mit ?).
library;

import 'package:flutter/material.dart';

import '../analysis/analysis.dart';

const classColors = {
  MistakeClass.blunder: Color(0xFFD64545),
  MistakeClass.mistake: Color(0xFFE08A2E),
  MistakeClass.inaccuracy: Color(0xFF5C9AD6),
};

const classIcons = {
  MistakeClass.blunder: Icons.dangerous_rounded,
  MistakeClass.mistake: Icons.error_rounded,
  MistakeClass.inaccuracy: Icons.help_rounded,
};

/// Symbol einer Einstufung in ihrer Farbe.
class MistakeBadge extends StatelessWidget {
  const MistakeBadge(this.mistake, {super.key, this.size = 24});

  final MistakeClass mistake;
  final double size;

  @override
  Widget build(BuildContext context) => Icon(classIcons[mistake], color: classColors[mistake], size: size);
}

/// Symbol als Teil eines Textes (Text.rich).
WidgetSpan mistakeSpan(MistakeClass c, {double size = 16}) => WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: MistakeBadge(c, size: size),
  ),
);
