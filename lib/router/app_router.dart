import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_master/features/puzzles/color_balance_screen.dart';
import 'package:palette_master/features/puzzles/color_bubble_screen.dart';
import 'package:palette_master/features/puzzles/color_memory_screen.dart';
import 'package:palette_master/features/puzzles/color_racer_screen.dart';
import 'package:palette_master/features/puzzles/color_wave_screen.dart';
import 'package:palette_master/features/puzzles/game_selection_screen.dart';
import 'package:palette_master/features/puzzles/games/color_wave.dart';
import 'package:palette_master/features/puzzles/models/game_type.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:palette_master/features/home/home_screen.dart';
import 'package:palette_master/features/puzzles/puzzle_screen.dart';
import 'package:palette_master/features/tutorials/tutorial_screen.dart';
import 'package:palette_master/features/achievements/achievements_screen.dart';
import 'package:palette_master/features/settings/settings_screen.dart';
import '../features/puzzles/color_mixing_screen.dart';
import 'routes.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  return GoRouter(
    initialLocation: AppRoutes.gameSelection.path,
    routes: [
      GoRoute(
        path: AppRoutes.home.path,
        name: AppRoutes.home.name,
        builder: (context, state) => const HomeScreen(),
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.gameSelection.path,
        name: AppRoutes.gameSelection.name,
        builder: (context, state) => const GameSelectionScreen(),
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const GameSelectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.elasticOut,
                reverseCurve: Curves.easeInCirc,
              )),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.puzzles.path,
        name: AppRoutes.puzzles.name,
        pageBuilder: (context, state) {
          final puzzleId = state.uri.queryParameters['id'];
          final level = int.tryParse(state.uri.queryParameters['level'] ?? '1') ?? 1;
          final gameType = state.uri.queryParameters['gameType'];

          final screen = PuzzleScreen(
            puzzleId: puzzleId,
            level: level,
            gameType: GameType.values.firstWhere(
              (type) => type.name == gameType,
              orElse: () => GameType.classicMixing,
            ),
          );

          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: screen,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.2),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutQuint,
                  )),
                  child: child,
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.tutorial.path,
        name: AppRoutes.tutorial.name,
        builder: (context, state) {
          final tutorialId = state.uri.queryParameters['id'];
          return TutorialScreen(tutorialId: tutorialId);
        },
      ),
      GoRoute(
        path: AppRoutes.achievements.path,
        name: AppRoutes.achievements.name,
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings.path,
        name: AppRoutes.settings.name,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.colorBubble.path,
        name: AppRoutes.colorBubble.name,
        builder: (context, state) {
          final puzzleId = state.uri.queryParameters['id'] ?? 'color_matching';
          final level = int.tryParse(state.uri.queryParameters['level'] ?? '1') ?? 1;

          return ColorBubbleScreen(
            puzzleId: puzzleId,
            level: level,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.classicMixing.path,
        name: AppRoutes.classicMixing.name,
        builder: (context, state) {
          final puzzleId = state.uri.queryParameters['id'] ?? 'color_matching';
          final level = int.tryParse(state.uri.queryParameters['level'] ?? '1') ?? 1;

          return ClassicMixingScreen(
            puzzleId: puzzleId,
            level: level,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.colorBalance.path,
        name: AppRoutes.colorBalance.name,
        builder: (context, state) {
          final puzzleId = state.uri.queryParameters['id'] ?? 'color_matching';
          final level = int.tryParse(state.uri.queryParameters['level'] ?? '1') ?? 1;

          return ColorBalanceScreen(
            puzzleId: puzzleId,
            level: level,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.colorWave.path,
        name: AppRoutes.colorWave.name,
        builder: (context, state) {
          final puzzleId = state.uri.queryParameters['id'] ?? 'color_matching';
          final level = int.tryParse(state.uri.queryParameters['level'] ?? '1') ?? 1;

          return ColorWaveScreen(
            puzzleId: puzzleId,
            level: level,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.colorRacer.path,
        name: AppRoutes.colorRacer.name,
        builder: (context, state) {
          final puzzleId = state.uri.queryParameters['id'] ?? 'color_matching';
          final level = int.tryParse(state.uri.queryParameters['level'] ?? '1') ?? 1;

          return ColorRacerScreen(
            puzzleId: puzzleId,
            level: level,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.colorMemory.path,
        name: AppRoutes.colorMemory.name,
        builder: (context, state) {
          final puzzleId = state.uri.queryParameters['id'] ?? 'color_matching';
          final level = int.tryParse(state.uri.queryParameters['level'] ?? '1') ?? 1;

          return ColorMemoryScreen(
            puzzleId: puzzleId,
            level: level,
          );
        },
      ),
    ],
  );
}
