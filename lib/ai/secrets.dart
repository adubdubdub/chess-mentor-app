import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Schlüssel und Zugangsdaten für KI-Anbieter im Android-Keystore (nie in shared_preferences, nie im Backup).
class SecretStore {
  SecretStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  /// [mode] = Name des Wegs (home, ownKey); [field] = apiKey, cfId, cfSecret.
  Future<String> read(String mode, String field) async => await _s.read(key: 'ai.$mode.$field') ?? '';

  Future<void> write(String mode, String field, String value) => value.isEmpty
      ? _s.delete(key: 'ai.$mode.$field')
      : _s.write(key: 'ai.$mode.$field', value: value);
}
