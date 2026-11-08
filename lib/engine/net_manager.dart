/// Großes Stockfish-Netz: Download vom offiziellen Server, Prüfung über SHA-256, Ablage im App-Ordner.
library;

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:multistockfish/multistockfish.dart';
import 'package:path_provider/path_provider.dart';

class NetManager {
  static const name = Stockfish.latestNNUE;

  /// Größe laut Server (06.11.2026), nur für den Hinweis vor dem Download.
  static const approxBytes = 98511183;
  static final url = Uri.parse('https://tests.stockfishchess.org/api/nn/$name');

  Future<File> file() async => File('${(await getApplicationSupportDirectory()).path}/$name');

  Future<bool> installed() async => (await file()).exists();

  Future<void> delete() async {
    final f = await file();
    if (await f.exists()) await f.delete();
  }

  /// Lädt das Netz und prüft es: Die ersten 12 Zeichen des SHA-256 sind Teil des Dateinamens (`nn-<hash>.nnue`).
  Future<void> download({void Function(int received, int? total)? onProgress}) async {
    final target = await file();
    final part = File('${target.path}.part');
    final client = http.Client();
    try {
      final request = http.Request('GET', url)..headers['User-Agent'] = 'chess-mentor-app';
      final response = await client.send(request);
      if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}', uri: url);
      final total = response.contentLength;
      final sink = part.openWrite();
      final digestOut = _DigestSink();
      final hash = sha256.startChunkedConversion(digestOut);
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        hash.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.close();
      hash.close();
      final expected = name.substring(3, 15);
      if (!digestOut.value.toString().startsWith(expected)) {
        await part.delete();
        throw const FormatException('Prüfsumme des Netzes stimmt nicht');
      }
      await part.rename(target.path);
    } finally {
      client.close();
      if (await part.exists()) await part.delete();
    }
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
