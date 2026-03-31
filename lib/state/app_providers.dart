import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env_config.dart';
import '../repositories/explorer_repository.dart';
import '../repositories/supabase_explorer_repository.dart';
import '../services/supabase_auth_service.dart';
import 'auth_controller.dart';
import 'explorer_controller.dart';
import 'explorer_state.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authServiceProvider = Provider<SupabaseAuthService>(
  (ref) => SupabaseAuthService(ref.watch(supabaseClientProvider)),
);

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthViewState>((ref) {
      return AuthController(ref.watch(authServiceProvider));
    });

final explorerRepositoryProvider = Provider<ExplorerRepository>((ref) {
  return SupabaseExplorerRepository(
    ref.watch(supabaseClientProvider),
    bucketName: EnvConfig.storageBucket,
  );
});

final explorerControllerProvider =
    StateNotifierProvider.autoDispose<ExplorerController, ExplorerState>((ref) {
      return ExplorerController(
        repository: ref.watch(explorerRepositoryProvider),
      );
    });
