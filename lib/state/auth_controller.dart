import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_auth_service.dart';

class AuthViewState {
  const AuthViewState({
    required this.user,
    required this.isLoading,
    this.errorMessage,
  });

  const AuthViewState.initial()
    : user = null,
      isLoading = true,
      errorMessage = null;

  final User? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => user != null;

  AuthViewState copyWith({
    User? user,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthViewState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthController extends StateNotifier<AuthViewState> {
  AuthController(this._authService) : super(const AuthViewState.initial()) {
    _initialize();
    _subscription = _authService.authStateChanges.listen((authState) {
      state = state.copyWith(
        user: authState.session?.user,
        isLoading: false,
        clearError: true,
      );
    });
  }

  final SupabaseAuthService _authService;
  late final StreamSubscription<AuthState> _subscription;

  Future<void> _initialize() async {
    state = state.copyWith(
      user: _authService.currentUser,
      isLoading: false,
      clearError: true,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authService.signIn(email: email, password: password);
      state = state.copyWith(
        user: _authService.currentUser,
        isLoading: false,
        clearError: true,
      );
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authService.signUp(email: email, password: password);
      state = state.copyWith(
        user: _authService.currentUser,
        isLoading: false,
        errorMessage:
            'Registration created. Confirm email if your Supabase project requires it.',
      );
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authService.signOut();
      state = state.copyWith(user: null, isLoading: false, clearError: true);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
