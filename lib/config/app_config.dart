import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';

  static String? get googleClientId {
    return _firstEnvValue(['GOOGLE_CLIENT_ID', 'NEXT_PUBLIC_GOOGLE_CLIENT_ID']);
  }

  static String? get googleServerClientId {
    return _firstEnvValue([
          'GOOGLE_SERVER_CLIENT_ID',
          'NEXT_PUBLIC_GOOGLE_SERVER_CLIENT_ID',
        ]) ??
        googleClientId;
  }

  static String? get omisePublicKey =>
      _firstEnvValue(['OMISE_PUBLIC_KEY', 'NEXT_PUBLIC_OMISE_PUBLIC_KEY']);

  static String? _firstEnvValue(List<String> keys) {
    for (final key in keys) {
      final value = dotenv.env[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
