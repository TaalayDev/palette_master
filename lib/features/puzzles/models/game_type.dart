import 'package:flutter/material.dart';

enum GameType {
  classicMixing,
  bubblePhysics,
  colorBalance,
  colorWave,
  colorRacer,
  colorMemory,
  // Add more game types here in the future
}

extension GameTypeExtension on GameType {
  String get displayName {
    switch (this) {
      case GameType.classicMixing:
        return 'Classic Mixing';
      case GameType.bubblePhysics:
        return 'Bubble Physics';
      case GameType.colorBalance:
        return 'Color Balance';
      case GameType.colorWave:
        return 'Color Wave';
      case GameType.colorRacer:
        return 'Color Racer';
      case GameType.colorMemory:
        return 'Color Memory';
      default:
        return 'Unknown Game';
    }
  }

  String get description {
    switch (this) {
      case GameType.classicMixing:
        return 'Mix colors by adding droplets to create the perfect shade';
      case GameType.bubblePhysics:
        return 'Play with bubble physics to mix colors through collisions';
      case GameType.colorBalance:
        return 'Adjust sliders to find the perfect color proportion balance';
      case GameType.colorWave:
        return 'Create waves of color to match gradient transitions';
      case GameType.colorRacer:
        return 'Race through color gates and mix colors at top speed';
      case GameType.colorMemory:
        return 'Test your color memory and recognition skills';
      default:
        return '';
    }
  }

  IconData get icon {
    switch (this) {
      case GameType.classicMixing:
        return Icons.palette;
      case GameType.bubblePhysics:
        return Icons.bubble_chart;
      case GameType.colorBalance:
        return Icons.balance;
      case GameType.colorWave:
        return Icons.waves;
      case GameType.colorRacer:
        return Icons.directions_car;
      case GameType.colorMemory:
        return Icons.memory;
      default:
        return Icons.games;
    }
  }
}
