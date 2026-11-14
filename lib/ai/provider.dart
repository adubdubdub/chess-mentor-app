/// KI-Anbieter für Texte. Technisch genügt ein Typ: OpenAI-kompatibel (Basis-URL + Schlüssel).
/// Das gilt für das KI-Gateway auf dem Heimserver genauso wie für OpenRouter, Gemini, Ollama oder OpenAI.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

abstract class AiProvider {
  /// Antwort auf [prompt] als Text; wirft bei Netz- oder Serverfehlern.
  Future<String> complete(String prompt);
}

class AiException implements Exception {
  const AiException(this.message);
  final String message;
  @override
  String toString() => 'AiException: $message';
}

class OpenAiCompatibleProvider implements AiProvider {
  OpenAiCompatibleProvider({
    required this.baseUrl,
    required this.model,
    this.apiKey = '',
    this.headers = const {},
    this.timeout = const Duration(seconds: 90),
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// z. B. https://api.openai.com/v1 (ohne /chat/completions).
  final String baseUrl;
  final String model;
  final String apiKey;

  /// Zusätzliche Kopfzeilen, z. B. CF-Access-Client-Id/-Secret für Cloudflare Access.
  final Map<String, String> headers;
  final Duration timeout;
  final http.Client _client;

  Uri get _uri => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions');

  @override
  Future<String> complete(String prompt) async {
    final http.Response r;
    try {
      r = await _client
          .post(
            _uri,
            headers: {
              'Content-Type': 'application/json',
              if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
              ...headers,
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(timeout);
    } catch (e) {
      throw AiException('Keine Verbindung (${e.runtimeType})');
    }
    if (r.statusCode != 200) throw AiException('HTTP ${r.statusCode}');
    try {
      final text = ((jsonDecode(utf8.decode(r.bodyBytes)) as Map)['choices'] as List).first['message']['content'];
      if (text is String && text.trim().isNotEmpty) return text.trim();
    } catch (_) {}
    throw const AiException('Antwort nicht lesbar');
  }
}
