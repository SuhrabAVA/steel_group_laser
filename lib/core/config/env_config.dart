import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../errors/app_exception.dart';

class EnvConfig {
  const EnvConfig._();

  static String get supabaseUrl => _readRequired('SUPABASE_URL');

  static String get supabaseAnonKey => _readRequired('SUPABASE_ANON_KEY');

  static String get storageBucket =>
      dotenv.env['SUPABASE_STORAGE_BUCKET']?.trim().isNotEmpty == true
      ? dotenv.env['SUPABASE_STORAGE_BUCKET']!.trim()
      : 'explorer-files';

  static String _readRequired(String key) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) {
      throw AppException(
        'Environment value "$key" is missing. Fill it in .env.',
      );
    }
    return value;
  }
}
