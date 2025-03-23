import 'package:flutter/material.dart';
import 'rgb_model.dart';
import 'cmyk_model.dart';

class ColorMixer {
  /// Mix colors using subtractive color model (pigment-based mixing)
  static Color mixSubtractive(List<Color> colors) {
    if (colors.isEmpty) return Colors.white;
    if (colors.length == 1) return colors.first;

    // Convert all colors to CMYK for subtractive mixing
    final cmykColors = colors.map((c) => CMYKColor.fromColor(c)).toList();

    // Average the CMYK values for subtractive mixing
    double cSum = 0, mSum = 0, ySum = 0, kSum = 0, opacitySum = 0;

    for (final color in cmykColors) {
      cSum += color.c;
      mSum += color.m;
      ySum += color.y;
      kSum += color.k;
      opacitySum += color.opacity;
    }

    final result = CMYKColor(
      c: cSum / cmykColors.length,
      m: mSum / cmykColors.length,
      y: ySum / cmykColors.length,
      k: kSum / cmykColors.length,
      opacity: opacitySum / cmykColors.length,
    );

    return result.toColor();
  }

  /// Mix colors using additive color model (light-based mixing)
  static Color mixAdditive(List<Color> colors) {
    if (colors.isEmpty) return Colors.black;
    if (colors.length == 1) return colors.first;

    // For additive mixing, we average the RGB values
    int rSum = 0, gSum = 0, bSum = 0;
    double opacitySum = 0;

    for (final color in colors) {
      rSum += color.red;
      gSum += color.green;
      bSum += color.blue;
      opacitySum += color.opacity;
    }

    return Color.fromRGBO(
      (rSum / colors.length).round(),
      (gSum / colors.length).round(),
      (bSum / colors.length).round(),
      opacitySum / colors.length,
    );
  }

  /// Get complementary color
  static Color getComplementary(Color color) {
    return Color.fromRGBO(255 - color.red, 255 - color.green, 255 - color.blue, color.opacity);
  }

  /// Get analogous colors
  static List<Color> getAnalogous(Color color, {int count = 3, double interval = 30}) {
    final List<Color> colors = [];
    final RGBColor rgb = RGBColor.fromColor(color);
    final HSVColor hsv = HSVColor.fromColor(color);

    // Include the original color
    colors.add(color);

    // Generate colors with hue shifts
    for (int i = 1; i < count; i++) {
      final newHue = (hsv.hue + interval * i) % 360;
      colors.add(HSVColor.fromAHSV(hsv.alpha, newHue, hsv.saturation, hsv.value).toColor());
    }

    return colors;
  }

  /// Get triadic colors
  static List<Color> getTriadic(Color color) {
    final HSVColor hsv = HSVColor.fromColor(color);

    return [
      color,
      HSVColor.fromAHSV(hsv.alpha, (hsv.hue + 120) % 360, hsv.saturation, hsv.value).toColor(),
      HSVColor.fromAHSV(hsv.alpha, (hsv.hue + 240) % 360, hsv.saturation, hsv.value).toColor(),
    ];
  }
}
