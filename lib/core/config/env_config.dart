import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../errors/app_exception.dart';

class EnvConfig {
  const EnvConfig._();

  static String get supabaseUrl => _readRequired('SUPABASE_URL');

  static String get supabaseAnonKey => _readRequired('SUPABASE_ANON_KEY');

  static String get storageBucket {
    final bucket =
        dotenv.env['SUPABASE_STORAGE_BUCKET']?.trim().isNotEmpty == true
        ? dotenv.env['SUPABASE_STORAGE_BUCKET']!.trim()
        : 'explorer-files';
    _validateStorageBucket(bucket);
    return bucket;
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

  static void _validateStorageBucket(String bucket) {
    if (bucket.length < 3 || bucket.length > 63) {
      throw AppException(
        'Некорректное имя бакета "$bucket". '
        'Имя должно быть длиной от 3 до 63 символов.',
      );
    }

    if (!_bucketAllowedChars.hasMatch(bucket)) {
      throw AppException(
        'Некорректное имя бакета "$bucket". '
        'Используйте только строчные буквы, цифры и дефисы. '
        'Имя не должно начинаться или заканчиваться дефисом.',
      );
    }

    if (bucket.contains('--')) {
      throw AppException(
        'Некорректное имя бакета "$bucket". '
        'Имя бакета не должно содержать подряд два дефиса.',
      );
    }
  }
}
