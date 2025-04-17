import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/services/local_storage_service.dart';

/// Game progress state class
class GameProgressState {
  final Map<String, int> progressMap;
  final int totalScore;
  final bool isLoading;

  const GameProgressState({
    required this.progressMap,
    required this.totalScore,
    this.isLoading = false,
  });

  GameProgressState copyWith({
    Map<String, int>? progressMap,
    int? totalScore,
    bool? isLoading,
  }) {
    return GameProgressState(
      progressMap: progressMap ?? this.progressMap,
      totalScore: totalScore ?? this.totalScore,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Get highest level for a specific puzzle type
  int getLevel(String puzzleId) {
    return progressMap[puzzleId] ?? 1;
  }

  /// Check if a specific level is unlocked
  bool isLevelUnlocked(String puzzleId, int level) {
    final highestLevel = getLevel(puzzleId);
    return level <= highestLevel;
  }
}

/// Provider for the game progress
final gameProgressProvider = StateNotifierProvider<GameProgressNotifier, GameProgressState>((ref) {
  final localStorage = ref.watch(localStorageProvider);
  return GameProgressNotifier(localStorage);
});

/// Notifier to manage game progress
class GameProgressNotifier extends StateNotifier<GameProgressState> {
  final LocalStorageService _localStorage;

  GameProgressNotifier(this._localStorage)
      : super(const GameProgressState(
          progressMap: {},
          totalScore: 0,
          isLoading: true,
        )) {
    _loadProgress();
  }

  /// Load progress from local storage
  Future<void> _loadProgress() async {
    state = state.copyWith(isLoading: true);

    try {
      final Map<String, int> progressMap = {};

      // Load progress for all game types
      progressMap['color_matching'] = await _localStorage.getGameProgress('color_matching');
      progressMap['complementary'] = await _localStorage.getGameProgress('complementary');
      progressMap['optical_illusion'] = await _localStorage.getGameProgress('optical_illusion');
      progressMap['color_harmony'] = await _localStorage.getGameProgress('color_harmony');

      // Load total score
      final totalScore = await _localStorage.getScore();

      state = state.copyWith(
        progressMap: progressMap,
        totalScore: totalScore,
        isLoading: false,
      );
    } catch (e) {
      // If there's an error, set initial values
      state = GameProgressState(
        progressMap: {
          'color_matching': 1,
          'complementary': 1,
          'optical_illusion': 1,
          'color_harmony': 1,
        },
        totalScore: 0,
        isLoading: false,
      );
    }
  }

  /// Update progress for a specific puzzle type
  Future<void> updateProgress(String puzzleId, int level) async {
    // Only update if new level is higher than current
    final currentLevel = state.progressMap[puzzleId] ?? 1;
    if (level <= currentLevel) return;

    // Update local state
    final updatedMap = Map<String, int>.from(state.progressMap);
    updatedMap[puzzleId] = level;

    state = state.copyWith(progressMap: updatedMap);

    // Save to storage
    await _localStorage.saveGameProgress(puzzleId, level);
  }

  /// Add points to the total score
  Future<void> addScore(int points) async {
    if (points <= 0) return;

    final newScore = state.totalScore + points;
    state = state.copyWith(totalScore: newScore);

    await _localStorage.saveScore(newScore);
  }

  /// Reset all progress
  Future<void> resetProgress() async {
    // Reset progress map
    final resetMap = {
      'color_matching': 1,
      'complementary': 1,
      'optical_illusion': 1,
      'color_harmony': 1,
    };

    state = state.copyWith(
      progressMap: resetMap,
      totalScore: 0,
    );

    // Save reset progress
    for (final entry in resetMap.entries) {
      await _localStorage.saveGameProgress(entry.key, entry.value);
    }

    await _localStorage.saveScore(0);
  }

  /// Get highest level for a puzzle
  int getHighestLevel(String puzzleId) {
    return state.progressMap[puzzleId] ?? 1;
  }

  /// Check if level is completed
  bool isLevelCompleted(String puzzleId, int level) {
    final highestLevel = state.progressMap[puzzleId] ?? 1;
    return level < highestLevel;
  }

  /// Check if level is unlocked
  bool isLevelUnlocked(String puzzleId, int level) {
    final highestLevel = state.progressMap[puzzleId] ?? 1;
    return level <= highestLevel;
  }
}
