import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/color_models/color_mixer.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:palette_master/features/puzzles/widgets/color_preview.dart';
import 'package:vibration/vibration.dart';

class ColorBalanceGame extends ConsumerStatefulWidget {
  final Puzzle puzzle;
  final Color userColor;
  final Function(Color) onColorMixed;

  const ColorBalanceGame({
    super.key,
    required this.puzzle,
    required this.userColor,
    required this.onColorMixed,
  });

  @override
  ConsumerState<ColorBalanceGame> createState() => _ColorBalanceGameState();
}

class _ColorBalanceGameState extends ConsumerState<ColorBalanceGame> with TickerProviderStateMixin {
  late List<ColorSlider> _colorSliders;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  Color _resultColor = Colors.white;
  double _similarity = 0.0;
  bool _isAutoBalancing = false;
  double _totalValue = 0.0;

  // Scale animation
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  // Harmony chart animation
  late AnimationController _chartController;
  late Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize color sliders based on available colors
    _initializeColorSliders();

    // Create pulse animation for visual feedback
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Create shake animation for error feedback
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.elasticIn,
      ),
    );

    // Create scale animation for the main interface
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );

    // Create harmony chart animation
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _chartAnimation = CurvedAnimation(
      parent: _chartController,
      curve: Curves.easeInOut,
    );

    // Start animations
    _scaleController.forward();
    _chartController.forward();

    // Calculate initial mixed color
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateMixedColor();
    });
  }

  void _initializeColorSliders() {
    final colors = widget.puzzle.availableColors;
    final random = Random();

    // Create a slider for each available color with random initial values
    _colorSliders = colors.map((color) {
      // Start with randomized values based on level
      // Higher levels have lower initial values to make it more challenging
      final maxInitialValue = max(0.1, 1.0 - (widget.puzzle.level / 50.0));
      final initialValue = random.nextDouble() * maxInitialValue;

      return ColorSlider(
        color: color,
        value: initialValue,
      );
    }).toList();

    // Calculate the total value
    _updateTotalValue();
  }

  void _updateTotalValue() {
    _totalValue = _colorSliders.fold(0.0, (sum, slider) => sum + slider.value);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _scaleController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  void _calculateMixedColor() {
    if (_colorSliders.isEmpty) {
      setState(() {
        _resultColor = Colors.white;
        _similarity = 0.0;
      });
      widget.onColorMixed(Colors.white);
      return;
    }

    // Calculate mixed color based on weighted proportions of sliders
    final List<Color> colors = [];
    final totalValue = _totalValue > 0 ? _totalValue : 1.0;

    for (var slider in _colorSliders) {
      final proportion = slider.value / totalValue;
      final weight = (proportion * 100).round();

      // Add color based on its weight (normalized)
      for (int i = 0; i < weight; i++) {
        colors.add(slider.color);
      }
    }

    // Ensure at least one color is added
    if (colors.isEmpty) {
      colors.add(Colors.white);
    }

    final mixedColor = ColorMixer.mixSubtractive(colors);

    setState(() {
      _resultColor = mixedColor;
    });

    widget.onColorMixed(mixedColor);

    // Calculate similarity to target
    _calculateSimilarity(mixedColor, widget.puzzle.targetColor);
  }

  void _calculateSimilarity(Color a, Color b) {
    // Calculate color similarity (normalized between 0 and 1)
    final dr = (a.red - b.red) / 255.0;
    final dg = (a.green - b.green) / 255.0;
    final db = (a.blue - b.blue) / 255.0;

    // Human eyes are more sensitive to green, less to blue
    final distance = (dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11);
    final similarity = (1.0 - sqrt(distance)).clamp(0.0, 1.0);

    setState(() {
      _similarity = similarity;
    });
  }

  void _updateSliderValue(int index, double value) {
    setState(() {
      _colorSliders[index].value = value;
      _updateTotalValue();
    });

    _calculateMixedColor();
  }

  void _balanceColorsEvenly() {
    // Distribute colors evenly among all sliders
    final evenValue = 1.0 / _colorSliders.length;

    setState(() {
      _isAutoBalancing = true;
    });

    // Animate to even values
    for (var i = 0; i < _colorSliders.length; i++) {
      _animateSliderTo(i, evenValue);
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isAutoBalancing = false;
        });
      }
    });
  }

  void _animateSliderTo(int index, double targetValue) {
    // Set up an animation to smoothly transition slider values
    final currentValue = _colorSliders[index].value;
    final steps = 10;

    for (int i = 1; i <= steps; i++) {
      Future.delayed(Duration(milliseconds: i * 30), () {
        if (mounted) {
          final newValue = currentValue + ((targetValue - currentValue) * (i / steps));
          _updateSliderValue(index, newValue);
        }
      });
    }
  }

  void _randomizeColors() {
    final random = Random();

    setState(() {
      _isAutoBalancing = true;
    });

    // Randomize each slider with animation
    for (var i = 0; i < _colorSliders.length; i++) {
      final randomValue = random.nextDouble();
      _animateSliderTo(i, randomValue);
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isAutoBalancing = false;
        });
      }
    });

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 50, amplitude: 128);
      }
    });
  }

  void _resetColors() {
    setState(() {
      for (var i = 0; i < _colorSliders.length; i++) {
        _colorSliders[i].value = 0.0;
      }
      _updateTotalValue();
    });

    _calculateMixedColor();
  }

  void _tryAutoSolve() {
    // Provide feedback that this is a helper feature
    _shakeController.reset();
    _shakeController.forward();

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 100, amplitude: 64);
      }
    });

    // Show educational dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Learning Opportunity!'),
        content: const Text('The auto-solve feature is designed to help you learn. '
            'Would you like to see a hint about how to balance colors, '
            'or would you prefer to try solving it yourself?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('I\'ll Keep Trying'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showColorHint();
            },
            child: const Text('Show Hint'),
          ),
        ],
      ),
    );
  }

  void _showColorHint() {
    // Analyze the target color to provide a meaningful hint
    final targetColor = widget.puzzle.targetColor;
    final hsvTarget = HSVColor.fromColor(targetColor);

    // Find the closest color in our palette
    Color closestColor = Colors.white;
    double smallestDistance = double.infinity;

    for (var slider in _colorSliders) {
      final hsvSlider = HSVColor.fromColor(slider.color);

      // Calculate weighted distance in HSV space
      final hueDiff = min((hsvTarget.hue - hsvSlider.hue).abs(), 360 - (hsvTarget.hue - hsvSlider.hue).abs()) / 180.0;
      final satDiff = (hsvTarget.saturation - hsvSlider.saturation).abs();
      final valDiff = (hsvTarget.value - hsvSlider.value).abs();

      final distance = hueDiff * 0.6 + satDiff * 0.3 + valDiff * 0.1;

      if (distance < smallestDistance) {
        smallestDistance = distance;
        closestColor = slider.color;
      }
    }

    // Provide a hint based on the analysis
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Color Balance Hint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Try emphasizing ${_getColorName(closestColor)} in your mix.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: closestColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: targetColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Remember: color balance is about the proportion of each color. '
              'Try adjusting the sliders to get the right mix!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  String _getColorName(Color color) {
    // A simple way to identify common colors by name
    final colorNames = {
      Colors.red: 'Red',
      Colors.green: 'Green',
      Colors.blue: 'Blue',
      Colors.yellow: 'Yellow',
      Colors.orange: 'Orange',
      Colors.purple: 'Purple',
      Colors.pink: 'Pink',
      Colors.teal: 'Teal',
      Colors.cyan: 'Cyan',
      Colors.indigo: 'Indigo',
      Colors.amber: 'Amber',
      Colors.brown: 'Brown',
      Colors.lime: 'Lime',
    };

    // Find the closest named color
    Color closestColor = Colors.white;
    double smallestDistance = double.infinity;

    colorNames.forEach((namedColor, name) {
      final dr = (color.red - namedColor.red).abs();
      final dg = (color.green - namedColor.green).abs();
      final db = (color.blue - namedColor.blue).abs();

      final distance = dr + dg + db;

      if (distance < smallestDistance) {
        smallestDistance = distance.toDouble();
        closestColor = namedColor;
      }
    });

    return colorNames[closestColor] ?? 'this color';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Column(
            children: [
              // Color preview section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Target color with pulse animation when close
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _similarity >= 0.95 ? _pulseAnimation.value : 1.0,
                        child: ColorPreview(
                          color: widget.puzzle.targetColor,
                          label: 'Target Color',
                          size: 90,
                        ),
                      );
                    },
                  ),

                  // Similarity indicator
                  Column(
                    children: [
                      Icon(
                        _similarity >= widget.puzzle.accuracyThreshold ? Icons.check_circle : Icons.balance,
                        color: _getSimilarityColor(),
                        size: 30,
                      ),
                      Text(
                        '${(_similarity * 100).toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getSimilarityColor(),
                        ),
                      ),
                    ],
                  ),

                  // Current mixed color
                  ColorPreview(
                    color: _resultColor,
                    label: 'Current Mix',
                    size: 90,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Color balance visualization
              SizedBox(
                height: 80,
                child: AnimatedBuilder(
                  animation: _chartAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ColorBalanceChartPainter(
                        colorSliders: _colorSliders,
                        targetColor: widget.puzzle.targetColor,
                        animation: _chartAnimation.value,
                        similarity: _similarity,
                      ),
                      size: Size(MediaQuery.of(context).size.width, 80),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Vertical slider controls
              Expanded(
                child: AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        _shakeController.isAnimating ? _shakeAnimation.value * 5.0 : 0.0,
                        0.0,
                      ),
                      child: child,
                    );
                  },
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.tune,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Color Balance',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _totalValue > 1.5
                                      ? Theme.of(context).colorScheme.errorContainer
                                      : Theme.of(context).colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Total: ${(_totalValue * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _totalValue > 1.5
                                        ? Theme.of(context).colorScheme.error
                                        : Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _buildVerticalSliders(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Control buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: Icons.refresh,
                      label: 'Reset',
                      onPressed: _resetColors,
                      color: Theme.of(context).colorScheme.errorContainer,
                    ),
                    _buildControlButton(
                      icon: Icons.shuffle,
                      label: 'Random',
                      onPressed: _randomizeColors,
                      color: Theme.of(context).colorScheme.secondaryContainer,
                    ),
                    _buildControlButton(
                      icon: Icons.balance,
                      label: 'Balance',
                      onPressed: _balanceColorsEvenly,
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                    ),
                    _buildControlButton(
                      icon: Icons.auto_fix_high,
                      label: 'Hint',
                      onPressed: _tryAutoSolve,
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerticalSliders() {
    // Wrap in a horizontal ListView for scrolling if needed
    return ListView(
      scrollDirection: Axis.horizontal,
      children: List.generate(_colorSliders.length, (index) {
        final slider = _colorSliders[index];
        return _buildVerticalColorSlider(index, slider);
      }),
    );
  }

  Widget _buildVerticalColorSlider(int index, ColorSlider slider) {
    // Calculate percentage value for display
    final percentage = (slider.value * 100).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: [
          // Color indicator at top
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: slider.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: slider.color.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Percentage value
          Container(
            width: 36,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$percentage%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),

          // Vertical slider
          Expanded(
            child: RotatedBox(
              quarterTurns: 3, // Rotate to make it vertical
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                  activeTrackColor: slider.color,
                  inactiveTrackColor: slider.color.withOpacity(0.2),
                  thumbColor: slider.color,
                  overlayColor: slider.color.withOpacity(0.2),
                ),
                child: Slider(
                  value: slider.value,
                  min: 0.0,
                  max: 1.0,
                  onChanged: _isAutoBalancing ? null : (value) => _updateSliderValue(index, value),
                ),
              ),
            ),
          ),

          // Min/Max labels
          const Text(
            '0%',
            style: TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Color _getSimilarityColor() {
    if (_similarity >= widget.puzzle.accuracyThreshold) {
      return Colors.green;
    } else if (_similarity >= 0.8) {
      return Colors.orange;
    } else {
      return Theme.of(context).colorScheme.error;
    }
  }
}

// Helper class to store color slider data
class ColorSlider {
  final Color color;
  double value;

  ColorSlider({required this.color, this.value = 0.0});
}

// Custom painter for the color balance chart
class ColorBalanceChartPainter extends CustomPainter {
  final List<ColorSlider> colorSliders;
  final Color targetColor;
  final double animation;
  final double similarity;

  ColorBalanceChartPainter({
    required this.colorSliders,
    required this.targetColor,
    required this.animation,
    required this.similarity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 4, size.height / 2) * animation;

    // Calculate total value for normalization
    final totalValue = colorSliders.fold(0.0, (sum, slider) => sum + slider.value);

    if (totalValue <= 0) {
      // Draw empty circle if no colors are selected
      final emptyPaint = Paint()
        ..color = Colors.grey.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, emptyPaint);
      return;
    }

    // Draw pie slices for each color
    double startAngle = -pi / 2; // Start from top

    for (final slider in colorSliders) {
      final sliderProportion = slider.value / totalValue;
      final sweepAngle = 2 * pi * sliderProportion * animation;

      final paint = Paint()
        ..color = slider.color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Add subtle border
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    }

    // Draw target color circle around the chart
    final targetPaint = Paint()
      ..color = targetColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, radius + 8, targetPaint);

    // Draw similarity gauge
    final gaugeWidth = size.width * 0.8;
    final gaugeHeight = 8.0;
    final gaugeRect = Rect.fromLTWH(
      center.dx - gaugeWidth / 2,
      size.height - gaugeHeight - 5,
      gaugeWidth,
      gaugeHeight,
    );

    // Draw chart center
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 8 * animation, centerPaint);

    // Add shadow to center
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, 8 * animation, shadowPaint);

    // Background
    // final bgPaint = Paint()
    //   ..color = Colors.grey.withOpacity(0.3)
    //   ..style = PaintingStyle.fill;

    // canvas.drawRRect(
    //   RRect.fromRectAndRadius(gaugeRect, const Radius.circular(4)),
    //   bgPaint,
    // );

    // // Filled portion
    // final filledWidth = gaugeWidth * similarity * animation;
    // final filledRect = Rect.fromLTWH(
    //   gaugeRect.left,
    //   gaugeRect.top,
    //   filledWidth,
    //   gaugeHeight,
    // );

    // Color gaugeColor;
    // if (similarity >= 0.9) {
    //   gaugeColor = Colors.green;
    // } else if (similarity >= 0.7) {
    //   gaugeColor = Colors.orange;
    // } else {
    //   gaugeColor = Colors.red;
    // }

    // final filledPaint = Paint()
    //   ..color = gaugeColor
    //   ..style = PaintingStyle.fill;

    // canvas.drawRRect(
    //   RRect.fromRectAndRadius(filledRect, const Radius.circular(4)),
    //   filledPaint,
    // );
  }

  @override
  bool shouldRepaint(covariant ColorBalanceChartPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.similarity != similarity ||
        oldDelegate.colorSliders != colorSliders;
  }
}
