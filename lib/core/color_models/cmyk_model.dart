import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'rgb_model.dart';

class CMYKColor extends Equatable {
  final double c;
  final double m;
  final double y;
  final double k;
  final double opacity;

  const CMYKColor({required this.c, required this.m, required this.y, required this.k, this.opacity = 1.0});

  RGBColor toRGB() {
    final r = 255 * (1 - c) * (1 - k);
    final g = 255 * (1 - m) * (1 - k);
    final b = 255 * (1 - y) * (1 - k);

    return RGBColor(
      r: r.round().clamp(0, 255),
      g: g.round().clamp(0, 255),
      b: b.round().clamp(0, 255),
      opacity: opacity,
    );
  }

  Color toColor() {
    return toRGB().toColor();
  }

  static CMYKColor fromRGB(RGBColor rgb) {
    final r = rgb.r / 255;
    final g = rgb.g / 255;
    final b = rgb.b / 255;

    final k = 1 - [r, g, b].reduce((max, value) => value > max ? value : max);

    final c = k == 1 ? 0 : (1 - r - k) / (1 - k);
    final m = k == 1 ? 0 : (1 - g - k) / (1 - k);
    final y = k == 1 ? 0 : (1 - b - k) / (1 - k);

    return CMYKColor(
      c: c.clamp(0.0, 1.0).toDouble(),
      m: m.clamp(0.0, 1.0).toDouble(),
      y: y.clamp(0.0, 1.0).toDouble(),
      k: k.clamp(0.0, 1.0),
      opacity: rgb.opacity,
    );
  }

  static CMYKColor fromColor(Color color) {
    return fromRGB(RGBColor.fromColor(color));
  }

  CMYKColor copyWith({double? c, double? m, double? y, double? k, double? opacity}) {
    return CMYKColor(c: c ?? this.c, m: m ?? this.m, y: y ?? this.y, k: k ?? this.k, opacity: opacity ?? this.opacity);
  }

  Map<String, dynamic> toMap() {
    return {'c': c, 'm': m, 'y': y, 'k': k, 'opacity': opacity};
  }

  factory CMYKColor.fromMap(Map<String, dynamic> map) {
    return CMYKColor(
      c: map['c'] ?? 0.0,
      m: map['m'] ?? 0.0,
      y: map['y'] ?? 0.0,
      k: map['k'] ?? 0.0,
      opacity: map['opacity'] ?? 1.0,
    );
  }

  @override
  List<Object> get props => [c, m, y, k, opacity];

  @override
  String toString() {
    return 'CMYK($c, $m, $y, $k, $opacity)';
  }
}
