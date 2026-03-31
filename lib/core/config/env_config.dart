import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../errors/app_exception.dart';

class EnvConfig {
  const EnvConfig._();
  static const String _defaultStorageBucket = 'explorer-files';

  static String get supabaseUrl => _readRequired('SUPABASE_URL');

  static String get supabaseAnonKey => _readRequired('SUPABASE_ANON_KEY');

  static String get storageBucket {
    final configuredBucket = dotenv.env['SUPABASE_STORAGE_BUCKET']?.trim();
    if (configuredBucket == null || configuredBucket.isEmpty) {
      return _defaultStorageBucket;
    }

    return _isValidStorageBucket(configuredBucket)
        ? configuredBucket
        : _defaultStorageBucket;
  }

  static String _readRequired(String key) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) {
      throw AppException(
        'Отсутствует значение переменной окружения "$key". Заполните его в .env.',
      );
    }
    return value;
  }

  static final RegExp _bucketAllowedChars = RegExp(r'^[a-z0-9][a-z0-9-]*[a-z0-9]$');

  static bool _isValidStorageBucket(String bucket) {
    if (bucket.length < 3 || bucket.length > 63) {
      return false;
    }

    if (!_bucketAllowedChars.hasMatch(bucket)) {
      return false;
    }

    if (bucket.contains('--')) {
      return false;
    }

    return true;
  }
}
