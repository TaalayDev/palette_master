import 'dart:math';
import 'package:flutter/material.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';

/// Generator for Classic Mixing game levels
class ClassicMixingLevelGenerator {
  static final Random _random = Random();

  /// Generate a puzzle for a given level
  static Puzzle generateLevel(String puzzleId, int level) {
    // Determine difficulty based on level
    final int difficulty = _calculateDifficulty(level);

    // Generate level configuration
    final levelConfig = _getLevelConfig(level);

    return Puzzle(
      id: puzzleId,
      title: levelConfig.title,
      description: levelConfig.description,
      type: PuzzleType.colorMatching,
      level: level,
      availableColors: levelConfig.availableColors,
      targetColor: levelConfig.targetColor,
      maxAttempts: levelConfig.maxAttempts,
      accuracyThreshold: 0.90 - (difficulty * 0.01).clamp(0.0, 0.15),
      additionalData: {
        'difficulty': difficulty,
        'colorTheoryTip': levelConfig.colorTheoryTip,
        'pointsValue': 100 + (level * 20),
      },
    );
  }

  /// Calculate difficulty tier based on level
  static int _calculateDifficulty(int level) {
    if (level <= 3) return 1; // Beginner
    if (level <= 6) return 2; // Intermediate
    if (level <= 10) return 3; // Advanced
    return 4; // Expert
  }

  /// Get level configuration
  static LevelConfig _getLevelConfig(int level) {
    // Define base colors
    const Color red = Color(0xFFFF0000);
    const Color yellow = Color(0xFFFFFF00);
    const Color blue = Color(0xFF0000FF);
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);

    // Predefined secondary colors
    const Color orange = Color(0xFFFF7F00);
    const Color green = Color(0xFF00FF00);
    const Color purple = Color(0xFF8000FF);
    const Color pink = Color(0xFFFF69B4);
    const Color brown = Color(0xFF8B4513);
    const Color teal = Color(0xFF008080);
    const Color olive = Color(0xFF808000);

    switch (level) {
      // Level 1: Red + Yellow = Orange
      case 1:
        return LevelConfig(
          title: 'Mix Red and Yellow',
          description: 'Create orange by mixing red and yellow',
          availableColors: [red, yellow],
          targetColor: orange,
          maxAttempts: 5,
          colorTheoryTip: 'Red and yellow are primary colors. When mixed, they create orange, a secondary color.',
        );

      // Level 2: Blue + Yellow = Green
      case 2:
        return LevelConfig(
          title: 'Mix Blue and Yellow',
          description: 'Create green by mixing blue and yellow',
          availableColors: [blue, yellow],
          targetColor: green,
          maxAttempts: 5,
          colorTheoryTip: 'Blue and yellow are primary colors. When mixed, they create green, a secondary color.',
        );

      // Level 3: Red + Blue = Purple
      case 3:
        return LevelConfig(
          title: 'Mix Red and Blue',
          description: 'Create purple by mixing red and blue',
          availableColors: [red, blue],
          targetColor: purple,
          maxAttempts: 5,
          colorTheoryTip: 'Red and blue are primary colors. When mixed, they create purple, a secondary color.',
        );

      // Level 4: Red + Green = Olive/Brown
      case 4:
        return LevelConfig(
          title: 'Mix Red and Green',
          description: 'Create an olive shade by mixing red and green',
          availableColors: [red, green, yellow],
          targetColor: olive,
          maxAttempts: 6,
          colorTheoryTip: 'When you mix red with green, you get an olive or brown tone, depending on the proportions.',
        );

      // Level 5: Red + White = Pink
      case 5:
        return LevelConfig(
          title: 'Create a Tint',
          description: 'Mix red with white to create pink',
          availableColors: [red, white, yellow],
          targetColor: pink,
          maxAttempts: 6,
          colorTheoryTip: 'Adding white to a color creates a tint. This is how we get pastel colors like pink.',
        );

      // Level 6: Blue + Green = Teal
      case 6:
        return LevelConfig(
          title: 'Mix Blue and Green',
          description: 'Create teal by mixing blue and green',
          availableColors: [blue, green, white],
          targetColor: teal,
          maxAttempts: 6,
          colorTheoryTip: 'Teal is created by mixing blue and green. It\'s a tertiary color in the color wheel.',
        );

      // Level 7: Complex Mix (Brown)
      case 7:
        return LevelConfig(
          title: 'Complex Mixing',
          description: 'Create brown using multiple colors',
          availableColors: [red, green, blue, yellow],
          targetColor: brown,
          maxAttempts: 7,
          colorTheoryTip: 'Brown is created by mixing multiple colors together. Try mixing complementary colors!',
        );

      // Level 8: Precise Mix with Proportions
      case 8:
        final targetHue = 120 + (_random.nextDouble() * 60);
        final targetSat = 0.6 + (_random.nextDouble() * 0.3);
        final targetVal = 0.6 + (_random.nextDouble() * 0.3);
        final customTarget = HSVColor.fromAHSV(1.0, targetHue, targetSat, targetVal).toColor();

        return LevelConfig(
          title: 'Precise Proportions',
          description: 'Create this specific green-blue shade',
          availableColors: [blue, green, white, yellow],
          targetColor: customTarget,
          maxAttempts: 7,
          colorTheoryTip: 'Precise colors require careful control of proportions. Try adding colors gradually.',
        );

      // Level 9: Create a Vibrant Purple
      case 9:
        final vibrantPurple = Color.fromARGB(255, 170, 0, 255);
        return LevelConfig(
          title: 'Vibrant Purple',
          description: 'Create a bright, vibrant purple',
          availableColors: [red, blue, pink, white],
          targetColor: vibrantPurple,
          maxAttempts: 7,
          colorTheoryTip: 'Vibrant colors have high saturation. Combine pure hues for maximum vibrance.',
        );

      // Level 10: Complex Earth Tone
      case 10:
        final earthTone = Color.fromARGB(255, 110, 70, 40);
        return LevelConfig(
          title: 'Earth Tone',
          description: 'Create this natural earth tone',
          availableColors: [red, yellow, green, blue, black, white],
          targetColor: earthTone,
          maxAttempts: 8,
          colorTheoryTip: 'Earth tones contain all three primary colors, with red and yellow dominating.',
        );

      // For higher levels, generate increasing challenges
      default:
        // For higher levels, create custom challenges with specific learning goals
        if (level % 3 == 0) {
          // Every 3rd level focuses on subtle shades
          return _generateSubtleShadeChallenge(level);
        } else if (level % 3 == 1) {
          // Every 1st level focuses on vibrant colors
          return _generateVibrantColorChallenge(level);
        } else {
          // Every 2nd level focuses on complex mixes
          return _generateComplexMixChallenge(level);
        }
    }
  }

  // Generate a challenge focused on subtle shades
  static LevelConfig _generateSubtleShadeChallenge(int level) {
    // Base colors available
    final allColors = [
      Colors.red,
      Colors.blue,
      Colors.yellow,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
      Colors.lime,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
      Colors.white,
      Colors.black,
      Colors.grey,
    ];

    // Select a subset of colors
    final colorCount = 5 + (level ~/ 3).clamp(0, 6);
    final shuffledColors = List<Color>.from(allColors)..shuffle(_random);
    final availableColors = shuffledColors.take(colorCount).toList();

    // Always ensure white and black are available for subtle adjustments
    if (!availableColors.contains(Colors.white)) {
      availableColors.add(Colors.white);
    }

    // Create a subtle target color
    final baseColor = shuffledColors.first;
    final targetColor = _createSubtleVariation(baseColor);

    return LevelConfig(
      title: 'Subtle Shade Challenge',
      description: 'Create this subtle variation of ${_getColorName(baseColor)}',
      availableColors: availableColors,
      targetColor: targetColor,
      maxAttempts: 8,
      colorTheoryTip: 'Subtle shades require careful mixing with white, black, or complementary colors.',
    );
  }

  // Generate a challenge focused on vibrant colors
  static LevelConfig _generateVibrantColorChallenge(int level) {
    // Create a vibrant target color
    final hue = _random.nextDouble() * 360;
    final saturation = 0.8 + (_random.nextDouble() * 0.2); // High saturation
    final value = 0.7 + (_random.nextDouble() * 0.3); // High value

    final targetColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();

    // Select colors that could be used to create this vibrant color
    final availableColors = _selectColorsForTarget(targetColor, level);

    return LevelConfig(
      title: 'Vibrant Color Challenge',
      description: 'Create this vibrant ${_getHueDescription(hue)} color',
      availableColors: availableColors,
      targetColor: targetColor,
      maxAttempts: 7 + (level ~/ 5),
      colorTheoryTip: 'Vibrant colors have high saturation. Layer pure hues to build intensity.',
    );
  }

  // Generate a challenge focused on complex color mixing
  static LevelConfig _generateComplexMixChallenge(int level) {
    // Create a complex, layered color
    Color targetColor;
    String description;
    String colorTheoryTip;

    final complexityType = _random.nextInt(3);
    switch (complexityType) {
      case 0:
        // Muted tone
        final hue = _random.nextDouble() * 360;
        final saturation = 0.3 + (_random.nextDouble() * 0.3); // Lower saturation
        final value = 0.4 + (_random.nextDouble() * 0.3); // Medium value
        targetColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
        description = 'Create this muted ${_getHueDescription(hue)} tone';
        colorTheoryTip = 'Muted colors are created by adding complementary colors or a small amount of black.';
        break;

      case 1:
        // Earth tone
        final redValue = 100 + _random.nextInt(100);
        final greenValue = 50 + _random.nextInt(70);
        final blueValue = 10 + _random.nextInt(50);
        targetColor = Color.fromRGBO(redValue, greenValue, blueValue, 1.0);
        description = 'Create this complex earth tone';
        colorTheoryTip = 'Earth tones often contain all three primary colors with red and yellow dominating.';
        break;

      case 2:
      default:
        // Metallic tone
        final baseValue = 100 + _random.nextInt(100);
        final variation = 10 + _random.nextInt(30);
        targetColor = Color.fromRGBO(baseValue, baseValue, baseValue + variation, 1.0);
        description = 'Create this metallic shade';
        colorTheoryTip = 'Metallic colors often have similar red and green values with slightly higher blue.';
        break;
    }

    // Select colors that could be used to create this complex color
    final availableColors = _selectColorsForTarget(targetColor, level);

    return LevelConfig(
      title: 'Complex Mix Challenge',
      description: description,
      availableColors: availableColors,
      targetColor: targetColor,
      maxAttempts: 8 + (level ~/ 4),
      colorTheoryTip: colorTheoryTip,
    );
  }

  // Create a subtle variation of a color
  static Color _createSubtleVariation(Color baseColor) {
    final hsvColor = HSVColor.fromColor(baseColor);

    // Slightly adjust hue, saturation and value
    final newHue = (hsvColor.hue + (_random.nextDouble() * 20) - 10) % 360;
    final newSaturation = (hsvColor.saturation + (_random.nextDouble() * 0.2) - 0.1).clamp(0.1, 1.0);
    final newValue = (hsvColor.value + (_random.nextDouble() * 0.2) - 0.1).clamp(0.3, 1.0);

    return HSVColor.fromAHSV(1.0, newHue, newSaturation, newValue).toColor();
  }

  // Select colors that could be used to create a target color
  static List<Color> _selectColorsForTarget(Color targetColor, int level) {
    final List<Color> result = [];
    final hsvTarget = HSVColor.fromColor(targetColor);

    // Always include primary colors that could create this hue
    if (hsvTarget.hue < 60 || hsvTarget.hue > 300) {
      result.add(Colors.red); // For red, pink, purple tones
    }

    if (hsvTarget.hue > 30 && hsvTarget.hue < 150) {
      result.add(Colors.yellow); // For yellow, green, orange tones
    }

    if (hsvTarget.hue > 90 && hsvTarget.hue < 270) {
      result.add(Colors.blue); // For blue, purple, teal tones
    }

    // Add secondary colors that would help
    if (hsvTarget.hue >= 30 && hsvTarget.hue <= 90) {
      result.add(Colors.orange); // For orange-yellow tones
    }

    if (hsvTarget.hue >= 60 && hsvTarget.hue <= 180) {
      result.add(Colors.green); // For green tones
    }

    if (hsvTarget.hue >= 240 && hsvTarget.hue <= 300) {
      result.add(Colors.purple); // For purple tones
    }

    // For earth tones and muted colors
    if (hsvTarget.saturation < 0.6) {
      result.add(Colors.brown);
    }

    // Add white to adjust lightness, but not for very dark colors
    if (hsvTarget.value > 0.4) {
      result.add(Colors.white);
    }

    // Add black for darker colors, but not for very light colors
    if (hsvTarget.value < 0.8) {
      result.add(Colors.black);
    }

    // Make sure we have enough colors
    final requiredColorCount = 4 + (level ~/ 3).clamp(0, 6);

    // If we don't have enough colors, add more
    if (result.length < requiredColorCount) {
      final additionalColors = [
        Colors.pink,
        Colors.teal,
        Colors.cyan,
        Colors.amber,
        Colors.indigo,
        Colors.lime,
        Colors.grey,
        Colors.deepOrange,
      ];

      additionalColors.shuffle(_random);
      for (final color in additionalColors) {
        if (!result.contains(color)) {
          result.add(color);
          if (result.length >= requiredColorCount) break;
        }
      }
    }

    // Shuffle the result to avoid giving too much of a clue
    result.shuffle(_random);

    return result;
  }

  // Get a description of a hue based on its angle
  static String _getHueDescription(double hue) {
    if (hue < 30) return 'red';
    if (hue < 60) return 'orange-red';
    if (hue < 90) return 'yellow-orange';
    if (hue < 120) return 'yellow';
    if (hue < 150) return 'yellow-green';
    if (hue < 180) return 'green';
    if (hue < 210) return 'blue-green';
    if (hue < 240) return 'teal';
    if (hue < 270) return 'blue';
    if (hue < 300) return 'purple';
    if (hue < 330) return 'magenta';
    return 'red-magenta';
  }

  // Get a common name for a color
  static String _getColorName(Color color) {
    // Simple mapping for common colors
    if (color == Colors.red) return 'red';
    if (color == Colors.green) return 'green';
    if (color == Colors.blue) return 'blue';
    if (color == Colors.yellow) return 'yellow';
    if (color == Colors.purple) return 'purple';
    if (color == Colors.orange) return 'orange';
    if (color == Colors.white) return 'white';
    if (color == Colors.black) return 'black';

    // For unknown colors, use hue-based description
    final hsvColor = HSVColor.fromColor(color);
    return _getHueDescription(hsvColor.hue);
  }
}

/// Configuration for a level
class LevelConfig {
  final String title;
  final String description;
  final List<Color> availableColors;
  final Color targetColor;
  final int maxAttempts;
  final String colorTheoryTip;

  LevelConfig({
    required this.title,
    required this.description,
    required this.availableColors,
    required this.targetColor,
    required this.maxAttempts,
    required this.colorTheoryTip,
  });
}

extension OffsetUtils on Offset {
  Offset normalize() {
    final length = this.distance;
    return Offset(dx / length, dy / length);
  }
}
