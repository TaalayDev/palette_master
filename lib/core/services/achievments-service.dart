import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/services/local_storage_service.dart';

/// Achievement model class
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isEpic;
  final int rewardPoints;
  final double progress;
  final bool isUnlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isEpic = false,
    required this.rewardPoints,
    this.progress = 0.0,
    this.isUnlocked = false,
  });

  Achievement copyWith({
    String? title,
    String? description,
    IconData? icon,
    bool? isEpic,
    int? rewardPoints,
    double? progress,
    bool? isUnlocked,
  }) {
    return Achievement(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      isEpic: isEpic ?? this.isEpic,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      progress: progress ?? this.progress,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

/// Achievements state class
class AchievementsState {
  final List<Achievement> achievements;
  final int totalPoints;
  final bool isLoading;

  const AchievementsState({
    required this.achievements,
    required this.totalPoints,
    this.isLoading = false,
  });

  AchievementsState copyWith({
    List<Achievement>? achievements,
    int? totalPoints,
    bool? isLoading,
  }) {
    return AchievementsState(
      achievements: achievements ?? this.achievements,
      totalPoints: totalPoints ?? this.totalPoints,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Get number of unlocked achievements
  int get unlockedCount => achievements.where((a) => a.isUnlocked).length;

  /// Get user rank based on points
  String get userRank {
    if (totalPoints >= 1000) return 'Master';
    if (totalPoints >= 500) return 'Expert';
    if (totalPoints >= 250) return 'Advanced';
    if (totalPoints >= 100) return 'Intermediate';
    return 'Beginner';
  }
}

/// Provider for the achievements service
final achievementsProvider = StateNotifierProvider<AchievementsNotifier, AchievementsState>((ref) {
  final localStorage = ref.watch(localStorageProvider);
  return AchievementsNotifier(localStorage);
});

/// Notifier to manage achievements
class AchievementsNotifier extends StateNotifier<AchievementsState> {
  final LocalStorageService _localStorage;

  AchievementsNotifier(this._localStorage)
      : super(const AchievementsState(
          achievements: [],
          totalPoints: 0,
          isLoading: true,
        )) {
    _initializeAchievements();
  }

  /// Initialize achievements list and load saved progress
  Future<void> _initializeAchievements() async {
    state = state.copyWith(isLoading: true);

    try {
      // Define all achievements
      final List<Achievement> achievements = [
        // Color Mixing category
        Achievement(
          id: 'color_apprentice',
          title: 'Color Apprentice',
          description: 'Complete 5 color mixing puzzles',
          icon: Icons.palette,
          rewardPoints: 100,
        ),
        Achievement(
          id: 'mixing_master',
          title: 'Mixing Master',
          description: 'Create 20 perfect color matches',
          icon: Icons.auto_awesome,
          rewardPoints: 250,
        ),
        Achievement(
          id: 'pigment_virtuoso',
          title: 'Pigment Virtuoso',
          description: 'Mix 5 colors to create a complex shade',
          icon: Icons.color_lens,
          rewardPoints: 500,
        ),

        // Color Theory category
        Achievement(
          id: 'complementary_expert',
          title: 'Complementary Expert',
          description: 'Complete all complementary color challenges',
          icon: Icons.contrast,
          rewardPoints: 300,
        ),
        Achievement(
          id: 'harmony_seeker',
          title: 'Harmony Seeker',
          description: 'Create 10 perfect color harmonies',
          icon: Icons.vibration,
          rewardPoints: 400,
        ),
        Achievement(
          id: 'color_wheel_navigator',
          title: 'Color Wheel Navigator',
          description: 'Identify all tertiary colors correctly',
          icon: Icons.track_changes,
          rewardPoints: 350,
        ),

        // Perception category
        Achievement(
          id: 'optical_illusion_master',
          title: 'Optical Illusion Master',
          description: 'Complete 5 optical illusion puzzles',
          icon: Icons.remove_red_eye,
          rewardPoints: 400,
        ),
        Achievement(
          id: 'after_image_observer',
          title: 'After-Image Observer',
          description: 'Successfully predict color after-images',
          icon: Icons.filter_center_focus,
          rewardPoints: 350,
        ),

        // Mastery category
        Achievement(
          id: 'color_theory_guru',
          title: 'Color Theory Guru',
          description: 'Complete all puzzles with perfect scores',
          icon: Icons.emoji_events,
          isEpic: true,
          rewardPoints: 1000,
        ),
        Achievement(
          id: 'speed_mixer',
          title: 'Speed Mixer',
          description: 'Complete any level in under 30 seconds',
          icon: Icons.speed,
          rewardPoints: 500,
        ),
        Achievement(
          id: 'perfectly_balanced',
          title: 'Perfectly Balanced',
          description: 'Create an exact match with no color adjustments',
          icon: Icons.balance,
          isEpic: true,
          rewardPoints: 750,
        ),
      ];

      // Load achievement progress from storage
      final List<Achievement> updatedAchievements = [];
      int totalPoints = 0;

      for (final achievement in achievements) {
        final isUnlocked = await _localStorage.getAchievement(achievement.id);
        final progress = await _getAchievementProgress(achievement.id);

        final updatedAchievement = achievement.copyWith(
          isUnlocked: isUnlocked,
          progress: progress,
        );

        updatedAchievements.add(updatedAchievement);

        if (isUnlocked) {
          totalPoints += achievement.rewardPoints;
        }
      }

      state = AchievementsState(
        achievements: updatedAchievements,
        totalPoints: totalPoints,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Error initializing achievements: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Get achievement progress from storage
  Future<double> _getAchievementProgress(String achievementId) async {
    try {
      final String progressKey = 'achievement_progress_$achievementId';
      return await _localStorage.getSetting(progressKey, defaultValue: '0.0').then((value) => double.parse(value));
    } catch (e) {
      return 0.0;
    }
  }

  /// Update achievement progress
  Future<void> updateProgress(String achievementId, double progress) async {
    if (progress < 0 || progress > 1.0) return;

    // Find the achievement index
    final index = state.achievements.indexWhere((a) => a.id == achievementId);
    if (index == -1) return;

    final achievement = state.achievements[index];

    // Don't update if already unlocked or progress would decrease
    if (achievement.isUnlocked || progress < achievement.progress) return;

    final updatedAchievement = achievement.copyWith(progress: progress);
    final updatedAchievements = List<Achievement>.from(state.achievements);
    updatedAchievements[index] = updatedAchievement;

    state = state.copyWith(achievements: updatedAchievements);

    // Save progress to storage
    final progressKey = 'achievement_progress_${achievementId}';
    await _localStorage.setSetting(progressKey, progress.toString());

    // Check if achievement should be unlocked
    if (progress >= 1.0) {
      await unlockAchievement(achievementId);
    }
  }

  /// Unlock an achievement
  Future<void> unlockAchievement(String achievementId) async {
    // Find the achievement index
    final index = state.achievements.indexWhere((a) => a.id == achievementId);
    if (index == -1) return;

    final achievement = state.achievements[index];

    // Don't update if already unlocked
    if (achievement.isUnlocked) return;

    // Update achievement
    final updatedAchievement = achievement.copyWith(
      isUnlocked: true,
      progress: 1.0,
    );

    final updatedAchievements = List<Achievement>.from(state.achievements);
    updatedAchievements[index] = updatedAchievement;

    // Update total points
    final newTotalPoints = state.totalPoints + achievement.rewardPoints;

    state = state.copyWith(
      achievements: updatedAchievements,
      totalPoints: newTotalPoints,
    );

    // Save to storage
    await _localStorage.saveAchievement(achievementId, true);
    final progressKey = 'achievement_progress_${achievementId}';
    await _localStorage.setSetting(progressKey, '1.0');
  }

  /// Reset all achievements
  Future<void> resetAchievements() async {
    final resetAchievements = state.achievements.map((a) => a.copyWith(isUnlocked: false, progress: 0.0)).toList();

    state = state.copyWith(
      achievements: resetAchievements,
      totalPoints: 0,
    );

    // Reset in storage
    for (final achievement in resetAchievements) {
      await _localStorage.saveAchievement(achievement.id, false);
      final progressKey = 'achievement_progress_${achievement.id}';
      await _localStorage.setSetting(progressKey, '0.0');
    }
  }

  /// Record a color match
  Future<void> recordColorMatch(bool isPerfectMatch, double similarity, int attemptCount) async {
    // Update "Mixing Master" achievement
    if (isPerfectMatch && similarity >= 0.95) {
      final matchCount = await _incrementCounterValue('perfect_matches');
      final progress = matchCount / 20.0; // Need 20 perfect matches
      await updateProgress('mixing_master', progress.clamp(0.0, 1.0));
    }

    // Update "Perfectly Balanced" achievement
    if (isPerfectMatch && similarity >= 0.99 && attemptCount == 1) {
      await unlockAchievement('perfectly_balanced');
    }
  }

  /// Record a level completion
  Future<void> recordLevelCompletion(String puzzleType, int level, int timeSeconds) async {
    // Update Color Apprentice achievement
    if (puzzleType == 'color_matching') {
      final levelCount = await _incrementCounterValue('color_mixing_levels');
      final progress = levelCount / 5.0; // Need 5 levels
      await updateProgress('color_apprentice', progress.clamp(0.0, 1.0));
    }

    // Update Complementary Expert achievement
    if (puzzleType == 'complementary') {
      final levelCount = await _incrementCounterValue('complementary_levels');
      final progress = levelCount / 10.0; // Need all 10 levels
      await updateProgress('complementary_expert', progress.clamp(0.0, 1.0));
    }

    // Update Optical Illusion Master achievement
    if (puzzleType == 'optical_illusion') {
      final levelCount = await _incrementCounterValue('optical_illusion_levels');
      final progress = levelCount / 5.0; // Need 5 levels
      await updateProgress('optical_illusion_master', progress.clamp(0.0, 1.0));
    }

    // Update Speed Mixer achievement
    if (timeSeconds < 30) {
      await unlockAchievement('speed_mixer');
    }
  }

  /// Record a color mixing action
  Future<void> recordColorMixing(int colorCount) async {
    // Update Pigment Virtuoso achievement (mixing 5+ colors)
    if (colorCount >= 5) {
      await unlockAchievement('pigment_virtuoso');
    }
  }

  /// Increment a counter value in storage
  Future<int> _incrementCounterValue(String counterKey) async {
    final currentValue = int.tryParse(await _localStorage.getSetting('counter_$counterKey', defaultValue: '0')) ?? 0;

    final newValue = currentValue + 1;
    await _localStorage.setSetting('counter_$counterKey', newValue.toString());

    return newValue;
  }
}
