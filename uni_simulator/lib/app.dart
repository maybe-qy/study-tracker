import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/game_provider.dart';
import 'screens/init_screen.dart';
import 'screens/main_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/recalibration_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

final ProviderContainer appContainer = ProviderContainer();

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final game = appContainer.read(gameProvider).game;
    final started = game?.started ?? false;
    final location = state.matchedLocation;
    if (location == '/' && started) return '/game';
    if (location != '/' && location != '/settings' && !started) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const InitScreen()),
    GoRoute(path: '/game', builder: (context, state) => const MainScreen()),
    GoRoute(path: '/plan', builder: (context, state) => const PlanScreen()),
    GoRoute(
        path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(
      path: '/recalibrate',
      builder: (context, state) => const RecalibrationScreen(),
    ),
  ],
);

class UniSimulatorApp extends StatelessWidget {
  const UniSimulatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: appContainer,
      child: MaterialApp.router(
        title: '大学模拟器',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: appRouter,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}