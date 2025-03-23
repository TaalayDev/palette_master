import 'dart:math';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:palette_master/core/color_models/color_mixer.dart';

part 'puzzle_provider.g.dart';

@riverpod
class PuzzleState extends _$PuzzleState {
  @override
  AsyncValue<Puzzle?> build(String puzzleId, int level) {
    // Load the puzzle based on ID and level
    return _loadPuzzle(puzzleId, level);
  }

  AsyncValue<Puzzle?> _loadPuzzle(String puzzleId, int level) {
    // In a real app, you would load this from a repository
    try {
      final puzzle = _getSamplePuzzle(puzzleId, level);
      return AsyncValue.data(puzzle);
    } catch (e) {
      return AsyncValue.error(e, StackTrace.current);
    }
  }

  Puzzle _getSamplePuzzle(String puzzleId, int level) {
    // Sample puzzles for different types
    switch (puzzleId) {
      case 'color_matching':
        return _createColorMatchingPuzzle(level);
      case 'complementary':
        return _createComplementaryPuzzle(level);
      case 'optical_illusion':
        return _createOpticalIllusionPuzzle(level);
      case 'color_harmony':
        return _createColorHarmonyPuzzle(level);
      default:
        throw Exception('Unknown puzzle type: $puzzleId');
    }
  }

  Puzzle _createColorMatchingPuzzle(int level) {
    // Define difficulty progression
    final difficultyTier = (level - 1) ~/ 5 + 1; // Tiers: 1 (levels 1-5), 2 (levels 6-10), etc.

    // Base colors - start with primaries, then add more as levels progress
    final List<Color> baseColors = [
      Colors.red,
      Colors.blue,
      Colors.yellow,
    ];

    // Add more colors as level increases
    if (difficultyTier >= 2) {
      baseColors.addAll([
        Colors.green,
        Colors.purple,
        Colors.orange,
      ]);
    }

    if (difficultyTier >= 3) {
      baseColors.addAll([
        Colors.pink,
        Colors.teal,
        Colors.lime,
      ]);
    }

    if (difficultyTier >= 4) {
      baseColors.addAll([
        Colors.indigo,
        Colors.amber,
        Colors.cyan,
      ]);
    }

    // Available colors - select a subset based on level
    List<Color> availableColors = [];
    int colorCount = (level <= 10) ? 3 : ((level <= 20) ? 4 : 5);

    // Choose colors for this level
    for (int i = 0; i < colorCount; i++) {
      final colorIndex = (level + i) % baseColors.length;
      availableColors.add(baseColors[colorIndex]);
    }

    // Create target color based on level difficulty
    late Color targetColor;

    if (level <= 5) {
      // Simple mix of two colors with clear dominance
      final color1 = availableColors[0];
      final color2 = availableColors[1];
      targetColor = ColorMixer.mixSubtractive([color1, color1, color2]);
    } else if (level <= 10) {
      // Mix of two equal colors
      final color1 = availableColors[0];
      final color2 = availableColors[1];
      targetColor = ColorMixer.mixSubtractive([color1, color2]);
    } else if (level <= 15) {
      // Mix of three colors with dominance
      final color1 = availableColors[0];
      final color2 = availableColors[1];
      final color3 = availableColors[2];
      targetColor = ColorMixer.mixSubtractive([color1, color1, color2, color3]);
    } else {
      // Complex mix of multiple colors
      final selectedColors = <Color>[];

      // Create a more balanced mix for higher levels
      for (int i = 0; i < colorCount - 1; i++) {
        selectedColors.add(availableColors[i]);

        // Add some colors twice for subtle dominance
        if (i % 2 == 0 && level > 20) {
          selectedColors.add(availableColors[i]);
        }
      }

      targetColor = ColorMixer.mixSubtractive(selectedColors);
    }

    // Adjust accuracy threshold based on level
    double accuracyThreshold = 1.0 - (difficultyTier * 0.05);
    accuracyThreshold = accuracyThreshold.clamp(0.75, 0.95);

    return Puzzle(
      id: 'color_matching',
      title: 'Level $level: Match This Color',
      description: _getLevelDescription(level),
      type: PuzzleType.colorMatching,
      level: level,
      availableColors: availableColors,
      targetColor: targetColor,
      maxAttempts: 5 + difficultyTier,
      accuracyThreshold: accuracyThreshold,
      additionalData: {
        'timerSeconds': level > 15 ? 60 : 0, // Add time limit for higher levels
        'pointsValue': level * 10,
      },
    );
  }

  Puzzle _createComplementaryPuzzle(int level) {
    // Create a complementary colors puzzle
    final baseColor = HSVColor.fromAHSV(1.0, (level * 30) % 360, 0.8, 0.8).toColor();
    final complementaryColor = ColorMixer.getComplementary(baseColor);

    return Puzzle(
      id: 'complementary',
      title: 'Find the Complement',
      description: 'Create the complementary color for the given color.',
      type: PuzzleType.complementary,
      level: level,
      availableColors: [
        Colors.red,
        Colors.green,
        Colors.blue,
        Colors.cyan,
        Color(0xFFFD3DB5),
        Colors.yellow,
      ],
      targetColor: complementaryColor,
      maxAttempts: 3 + level,
    );
  }

  Puzzle _createOpticalIllusionPuzzle(int level) {
    // Placeholder for optical illusion puzzles
    return Puzzle(
      id: 'optical_illusion',
      title: 'Optical Illusion Challenge',
      description: 'Test your perception with this optical illusion.',
      type: PuzzleType.opticalIllusion,
      level: level,
      availableColors: [Colors.black, Colors.white],
      targetColor: Colors.grey,
    );
  }

  Puzzle _createColorHarmonyPuzzle(int level) {
    // Placeholder for color harmony puzzles
    final baseColor = HSVColor.fromAHSV(1.0, (level * 40) % 360, 0.7, 0.9).toColor();
    final harmonicColors = ColorMixer.getAnalogous(baseColor);

    return Puzzle(
      id: 'color_harmony',
      title: 'Create Color Harmony',
      description: 'Mix colors to create a harmonious color palette.',
      type: PuzzleType.colorHarmony,
      level: level,
      availableColors: [Colors.red, Colors.blue, Colors.yellow, Colors.green, Colors.purple, Colors.orange],
      targetColor: harmonicColors[0],
      additionalData: {
        'targetPalette': harmonicColors,
      },
    );
  }

  String _getLevelDescription(int level) {
    if (level <= 5) {
      return 'Mix colors to match the target. Try mixing two colors together.';
    } else if (level <= 10) {
      return 'Create an equal mix of colors to match the target shade.';
    } else if (level <= 15) {
      return 'This one is tricky! Try mixing three colors with different proportions.';
    } else if (level <= 20) {
      return 'Expert level: Create a precise color mixture with multiple colors.';
    } else {
      return 'Master challenge: Perfect your color mixing skills with subtle variations.';
    }
  }

  // Methods to handle user interactions
  void resetPuzzle() {
    state = _loadPuzzle(state.value?.id ?? '', state.value?.level ?? 1);
  }

  void nextLevel() {
    if (state.value != null) {
      state = _loadPuzzle(state.value!.id, state.value!.level + 1);
    }
  }
}

@riverpod
class UserMixedColor extends _$UserMixedColor {
  @override
  Color build() {
    // Start with white (no colors mixed)
    return Colors.white;
  }

  void mixColor(Color color) {
    // Mix the current color with the new color
    state = ColorMixer.mixSubtractive([state, color]);
  }

  void setColor(Color color) {
    // Directly set the color (for use with the fluid mixing container)
    state = color;
  }

  void reset() {
    state = Colors.white;
  }
}

@riverpod
class PuzzleResult extends _$PuzzleResult {
  @override
  AsyncValue<bool?> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> checkResult(Color userColor, Color targetColor, double threshold) async {
    state = const AsyncValue.loading();

    // Add a small delay for animation purposes
    await Future.delayed(const Duration(milliseconds: 300));

    // Calculate color similarity (this is a simplified version)
    final similarity = _calculateColorSimilarity(userColor, targetColor);

    // Check if the similarity is above the threshold
    final success = similarity >= threshold;

    state = AsyncValue.data(success);
    return success;
  }

  double _calculateColorSimilarity(Color a, Color b) {
    // Improved color similarity calculation using weighted RGB differences
    final dr = (a.red - b.red) / 255.0;
    final dg = (a.green - b.green) / 255.0;
    final db = (a.blue - b.blue) / 255.0;

    // Human eyes are more sensitive to green, less to blue
    final distance = (dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11);
    return 1.0 - sqrt(distance).clamp(0.0, 1.0);
  }
}

@riverpod
class GameProgress extends _$GameProgress {
  @override
  Map<String, int> build() {
    // Store the highest level reached for each puzzle type
    return {
      'color_matching': 1,
      'complementary': 1,
      'optical_illusion': 1,
      'color_harmony': 1,
    };
  }

  void updateProgress(String puzzleId, int level) {
    state = {...state};
    if ((state[puzzleId] ?? 0) < level) {
      state[puzzleId] = level;
    }
  }

  void resetProgress() {
    state = {
      'color_matching': 1,
      'complementary': 1,
      'optical_illusion': 1,
      'color_harmony': 1,
    };
  }
}
