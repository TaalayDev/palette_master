import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum PuzzleType { colorMatching, complementary, opticalIllusion, colorHarmony }

class Puzzle extends Equatable {
  final String id;
  final String title;
  final String description;
  final PuzzleType type;
  final int level;
  final List<Color> availableColors;
  final Color targetColor;
  final int maxAttempts;
  final double accuracyThreshold;
  final Map<String, dynamic>? additionalData;

  const Puzzle({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.level,
    required this.availableColors,
    required this.targetColor,
    this.maxAttempts = 5,
    this.accuracyThreshold = 0.95,
    this.additionalData,
  });

  Puzzle copyWith({
    String? id,
    String? title,
    String? description,
    PuzzleType? type,
    int? level,
    List<Color>? availableColors,
    Color? targetColor,
    int? maxAttempts,
    double? accuracyThreshold,
    Map<String, dynamic>? additionalData,
  }) {
    return Puzzle(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      level: level ?? this.level,
      availableColors: availableColors ?? this.availableColors,
      targetColor: targetColor ?? this.targetColor,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      accuracyThreshold: accuracyThreshold ?? this.accuracyThreshold,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    type,
    level,
    availableColors,
    targetColor,
    maxAttempts,
    accuracyThreshold,
    additionalData,
  ];
}
