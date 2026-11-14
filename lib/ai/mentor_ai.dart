/// KI-Texte für den Mentor: Anbieter wählen, Prompt bauen, Antwort gegen die Engine-Fakten prüfen, zwischenspeichern.
/// Bei jedem Problem (kein Netz, Fehler, erfundene Züge) liefert die Funktion null; dann gelten die Textbausteine.
library;

import 'package:flutter/foundation.dart';

import '../data/game_store.dart';
import '../data/settings.dart';
import 'prompts.dart';
import 'provider.dart';
import 'secrets.dart';
import 'verify.dart';

class MentorAi {
  MentorAi(this.settings, this.secrets, this.store);

  final Settings settings;
  final SecretStore secrets;
  final GameStore store;

  bool get enabled => settings.aiMode != AiMode.templates;

  Future<AiProvider?> _provider() async {
    final mode = settings.aiMode;
    if (mode == AiMode.templates) return null;
    final url = settings.aiBaseUrl(mode);
    final model = settings.aiModel(mode);
    if (url.isEmpty || model.isEmpty) return null;
    final cfId = await secrets.read(mode.name, 'cfId');
    final cfSecret = await secrets.read(mode.name, 'cfSecret');
    return OpenAiCompatibleProvider(
      baseUrl: url,
      model: model,
      apiKey: await secrets.read(mode.name, 'apiKey'),
      headers: {
        if (cfId.isNotEmpty) 'CF-Access-Client-Id': cfId,
        if (cfSecret.isNotEmpty) 'CF-Access-Client-Secret': cfSecret,
      },
    );
  }

  /// Erklärung zu einem Puzzle (Warum der Partiezug schwach war); null = Textbaustein verwenden.
  Future<String?> puzzleExplanation(StoredPuzzle p, {required bool de}) async {
    final key = 'puzzle:${p.id}:${de ? 'de' : 'en'}:v$promptVersion';
    final cached = await store.aiText(key);
    if (cached != null) return cached;
    final provider = await _provider();
    if (provider == null) return null;
    try {
      final raw = await provider.complete(puzzlePrompt(p.moment, de: de));
      final text = raw.replaceAll(RegExp(r'^```\w*|```$'), '').trim();
      final bad = unknownMoves(text, moveTokens(factMoveTexts(p.moment, de: de)));
      if (text.isEmpty || bad.isNotEmpty) {
        debugPrint('KI-Text verworfen (Züge nicht in den Fakten: $bad)');
        return null;
      }
      await store.putAiText(key, text);
      return text;
    } on AiException catch (e) {
      debugPrint('KI nicht verfügbar: $e');
      return null;
    }
  }
}
