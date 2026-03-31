import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/constants/app_colors.dart';
import 'state/app_providers.dart';
import 'ui/pages/explorer_page.dart';
import 'ui/pages/sign_in_page.dart';

class SteelExplorerApp extends ConsumerWidget {
  const SteelExplorerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Проводник Steel Group Laser',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.panel,
          primary: AppColors.accent,
          secondary: AppColors.accentStrong,
          onSurface: AppColors.textPrimary,
        ),
        textTheme: GoogleFonts.exo2TextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
        cardTheme: CardThemeData(
          color: AppColors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: authState.isLoading
            ? const _LoadingScreen()
            : authState.isAuthenticated
            ? ExplorerPage(key: ValueKey(authState.user?.id ?? 'user'))
            : const SignInPage(),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
