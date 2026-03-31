import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');

    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    runApp(const ProviderScope(child: SteelExplorerApp()));
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                kDebugMode
                    ? 'Ошибка запуска: ${_sanitizeStartupError(error)}'
                    : 'Ошибка запуска приложения. Проверьте настройки .env '
                          '(SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_STORAGE_BUCKET).',
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _sanitizeStartupError(Object error) {
  final text = error.toString();
  final jwtLikePattern = RegExp(
    r'[A-Za-z0-9\-_]{20,}\.[A-Za-z0-9\-_]{20,}\.[A-Za-z0-9\-_]{20,}',
  );
  return text.replaceAll(jwtLikePattern, '[hidden-token]');
}
