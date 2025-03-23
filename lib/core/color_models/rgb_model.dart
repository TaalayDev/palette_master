import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class RGBColor extends Equatable {
  final int r;
  final int g;
  final int b;
  final double opacity;

  const RGBColor({required this.r, required this.g, required this.b, this.opacity = 1.0});

  Color toColor() {
    return Color.fromRGBO(r, g, b, opacity);
  }

  RGBColor copyWith({int? r, int? g, int? b, double? opacity}) {
    return RGBColor(r: r ?? this.r, g: g ?? this.g, b: b ?? this.b, opacity: opacity ?? this.opacity);
  }

  static RGBColor fromColor(Color color) {
    return RGBColor(r: color.red, g: color.green, b: color.blue, opacity: color.opacity);
  }

  Map<String, dynamic> toMap() {
    return {'r': r, 'g': g, 'b': b, 'opacity': opacity};
  }

  factory RGBColor.fromMap(Map<String, dynamic> map) {
    return RGBColor(r: map['r'] ?? 0, g: map['g'] ?? 0, b: map['b'] ?? 0, opacity: map['opacity'] ?? 1.0);
  }

  @override
  List<Object> get props => [r, g, b, opacity];

  @override
  String toString() {
    return 'RGB($r, $g, $b, $opacity)';
  }
}
