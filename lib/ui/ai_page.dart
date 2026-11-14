import 'package:flutter/material.dart';

import '../ai/provider.dart';
import '../data/settings.dart';
import 'app_scope.dart';
import 'strings.dart';

/// Einstellungen für KI-Texte: Textbausteine, Heimserver (KI-Gateway) oder eigener Schlüssel.
class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final _url = TextEditingController();
  final _model = TextEditingController();
  final _key = TextEditingController();
  final _cfId = TextEditingController();
  final _cfSecret = TextEditingController();
  AiMode _mode = AiMode.templates;
  String? _test;
  bool _testing = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _mode = AppScope.of(context).settings.aiMode;
      _fill();
    }
  }

  @override
  void dispose() {
    for (final c in [_url, _model, _key, _cfId, _cfSecret]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fill() async {
    final scope = AppScope.of(context);
    _url.text = scope.settings.aiBaseUrl(_mode);
    _model.text = scope.settings.aiModel(_mode);
    _key.text = await scope.secrets.read(_mode.name, 'apiKey');
    _cfId.text = await scope.secrets.read(_mode.name, 'cfId');
    _cfSecret.text = await scope.secrets.read(_mode.name, 'cfSecret');
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final scope = AppScope.of(context);
    scope.settings.aiMode = _mode;
    if (_mode == AiMode.templates) return;
    scope.settings.setAiBaseUrl(_mode, _url.text);
    scope.settings.setAiModel(_mode, _model.text);
    await scope.secrets.write(_mode.name, 'apiKey', _key.text.trim());
    await scope.secrets.write(_mode.name, 'cfId', _cfId.text.trim());
    await scope.secrets.write(_mode.name, 'cfSecret', _cfSecret.text.trim());
  }

  Future<void> _runTest() async {
    final tr = Tr.of(context);
    setState(() {
      _testing = true;
      _test = null;
    });
    await _save();
    if (!mounted) return;
    String result;
    try {
      final provider = OpenAiCompatibleProvider(
        baseUrl: _url.text.trim(),
        model: _model.text.trim(),
        apiKey: _key.text.trim(),
        headers: {
          if (_cfId.text.trim().isNotEmpty) 'CF-Access-Client-Id': _cfId.text.trim(),
          if (_cfSecret.text.trim().isNotEmpty) 'CF-Access-Client-Secret': _cfSecret.text.trim(),
        },
        timeout: const Duration(seconds: 60),
      );
      await provider.complete('Antworte nur mit dem Wort: ok');
      result = tr.t('✅ Verbindung funktioniert.', '✅ Connection works.');
    } on AiException catch (e) {
      result = tr.t('❌ Fehlgeschlagen: ${e.message}', '❌ Failed: ${e.message}');
    } catch (e) {
      result = tr.t('❌ Ungültige Eingabe', '❌ Invalid input');
    }
    if (mounted) {
      setState(() {
        _testing = false;
        _test = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr.t('KI-Texte', 'AI texts'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr.t(
              'Die Analyse läuft immer auf dem Handy. KI formuliert nur Erklärungen; jeder genannte Zug wird gegen die '
                  'Stockfish-Fakten geprüft, sonst gelten die Textbausteine.',
              'Analysis always runs on your phone. AI only words the explanations; every move it mentions is checked '
                  'against the Stockfish facts, otherwise the built-in texts are used.',
            ),
          ),
          const SizedBox(height: 12),
          RadioGroup<AiMode>(
            groupValue: _mode,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _mode = v;
                _test = null;
              });
              AppScope.of(context).settings.aiMode = v;
              _fill();
            },
            child: Column(
              children: [
                RadioListTile(
                  value: AiMode.templates,
                  title: Text(tr.t('Textbausteine (offline)', 'Built-in texts (offline)')),
                ),
                RadioListTile(
                  value: AiMode.home,
                  title: Text(tr.t('Heimserver (KI-Gateway)', 'Home server (AI gateway)')),
                  subtitle: Text(tr.t('Nur für das eigene Handy', 'For your own phone only')),
                ),
                RadioListTile(
                  value: AiMode.ownKey,
                  title: Text(tr.t('Eigener API-Schlüssel', 'Own API key')),
                  subtitle: Text(tr.t('OpenAI-kompatibel, z. B. OpenRouter, Gemini, Ollama', 'OpenAI-compatible')),
                ),
              ],
            ),
          ),
          if (_mode != AiMode.templates) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: tr.t('Basis-URL (endet auf /v1)', 'Base URL (ends with /v1)'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _model,
              decoration: InputDecoration(labelText: tr.t('Modell', 'Model'), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              obscureText: true,
              decoration: InputDecoration(
                labelText: tr.t('Schlüssel / Token', 'Key / token'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_mode == AiMode.home) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _cfId,
                decoration: const InputDecoration(labelText: 'CF-Access-Client-Id', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cfSecret,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'CF-Access-Client-Secret', border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(onPressed: _save, child: Text(tr.t('Speichern', 'Save'))),
                OutlinedButton(
                  onPressed: _testing ? null : _runTest,
                  child: Text(tr.t('Verbindung testen', 'Test connection')),
                ),
                if (_testing) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            if (_test != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_test!)),
            const SizedBox(height: 16),
            Text(
              tr.t(
                'Schlüssel liegen im Android-Keystore und werden nicht gesichert. Ein Text wird einmal erzeugt und '
                    'dann gespeichert; ohne Netz gelten die Textbausteine.',
                'Keys are kept in the Android Keystore and are not backed up. Each text is generated once and then '
                    'stored; offline the built-in texts apply.',
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
