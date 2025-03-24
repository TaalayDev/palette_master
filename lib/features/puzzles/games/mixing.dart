import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/color_models/color_mixer.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:palette_master/features/puzzles/providers/puzzle_provider.dart';
import 'package:palette_master/features/puzzles/widgets/color_preview.dart';
import 'package:vibration/vibration.dart';

class ClassicMixingGame extends ConsumerStatefulWidget {
  final Puzzle puzzle;
  final Color userColor;
  final Function(Color) onColorMixed;

  const ClassicMixingGame({
    super.key,
    required this.puzzle,
    required this.userColor,
    required this.onColorMixed,
  });

  @override
  ConsumerState<ClassicMixingGame> createState() => _ClassicMixingGameState();
}

class _ClassicMixingGameState extends ConsumerState<ClassicMixingGame> with TickerProviderStateMixin {
  final List<_DraggableColorDrop> _colorDrops = [];
  final List<_PaintSplash> _splashes = [];
  final GlobalKey _mixingAreaKey = GlobalKey();

  late AnimationController _splashAnimationController;
  late AnimationController _colorComparisonController;
  late Animation<double> _colorComparisonAnimation;

  Size _mixingAreaSize = Size.zero;
  Offset _mixingAreaPosition = Offset.zero;
  Color _currentMixedColor = Colors.white;
  double _similarity = 0.0;
  bool _animatingColorComparison = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers for animations
    _splashAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _colorComparisonController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _colorComparisonAnimation = CurvedAnimation(
      parent: _colorComparisonController,
      curve: Curves.easeInOut,
    );

    // Get the mixing area dimensions after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMixingAreaDimensions();
    });
  }

  @override
  void dispose() {
    _splashAnimationController.dispose();
    _colorComparisonController.dispose();
    super.dispose();
  }

  void _updateMixingAreaDimensions() {
    final RenderBox? renderBox = _mixingAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _mixingAreaSize = renderBox.size;
        _mixingAreaPosition = renderBox.localToGlobal(Offset.zero);
      });
    }
  }

  void _addColorDrop(Color color, Offset position) {
    // Create a physics simulation for the drop
    final random = Random();
    final dropSize = random.nextDouble() * 20 + 40;
    final initialVelocity = Offset(
      (random.nextDouble() - 0.5) * 200,
      (random.nextDouble() - 0.5) * 200,
    );

    final drop = _DraggableColorDrop(
      color: color,
      position: position,
      size: dropSize,
      velocity: initialVelocity,
    );

    setState(() {
      _colorDrops.add(drop);
    });

    // Trigger haptic feedback if available
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 20, amplitude: 40);
      }
    });

    // Update the mixed color
    _updateMixedColor();
  }

  void _updateMixedColor() {
    if (_colorDrops.isEmpty) {
      setState(() {
        _currentMixedColor = Colors.white;
      });
      widget.onColorMixed(Colors.white);
      return;
    }

    // Mix all colors using the color mixer
    final colors = _colorDrops.map((drop) => drop.color).toList();
    final mixedColor = ColorMixer.mixSubtractive(colors);

    setState(() {
      _currentMixedColor = mixedColor;
    });

    widget.onColorMixed(mixedColor);

    // Calculate similarity to target color
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

  void _addSplash(Offset position, Color color) {
    final splash = _PaintSplash(
      position: position,
      color: color,
      startRadius: 0,
      endRadius: 30 + Random().nextDouble() * 30,
      spikes: 5 + Random().nextInt(3),
      rotation: Random().nextDouble() * pi,
    );

    setState(() {
      _splashes.add(splash);
    });

    _splashAnimationController.reset();
    _splashAnimationController.forward().then((_) {
      setState(() {
        _splashes.remove(splash);
      });
    });
  }

  void _compareColors() {
    setState(() {
      _animatingColorComparison = true;
    });

    _colorComparisonController.reset();
    _colorComparisonController.forward().whenComplete(() {
      setState(() {
        _animatingColorComparison = false;
      });
    });
  }

  void _reset() {
    setState(() {
      _colorDrops.clear();
      _splashes.clear();
      _currentMixedColor = Colors.white;
      _similarity = 0.0;
    });
    widget.onColorMixed(Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Color preview section with target and current colors
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Target color preview
              _buildTargetColorPreview(),

              // Arrow indicator showing similarity
              _buildSimilarityIndicator(),

              // Current mixed color preview
              ColorPreview(
                color: _currentMixedColor,
                label: 'Your Mix',
                size: 100,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Color mixing canvas area
        Expanded(
          child: Stack(
            children: [
              // Mixing container
              Container(
                key: _mixingAreaKey,
                decoration: BoxDecoration(
                  color: _currentMixedColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Canvas for custom painting
                      SizedBox.expand(
                        child: CustomPaint(
                          painter: _MixingCanvasPainter(
                            colorDrops: _colorDrops,
                            splashes: _splashes,
                            splashAnimation: _splashAnimationController,
                          ),
                          child: GestureDetector(
                            onTapDown: (details) {
                              final localPosition = details.localPosition;
                              // Add a small splash on tap
                              _addSplash(localPosition, Colors.white.withOpacity(0.3));
                            },
                          ),
                        ),
                      ),

                      // Drag target for new colors
                      SizedBox.expand(
                        child: DragTarget<Color>(
                          builder: (context, candidateItems, rejectedItems) {
                            return const SizedBox.expand();
                          },
                          onAcceptWithDetails: (details) {
                            final color = details.data;
                            final position = details.offset - _mixingAreaPosition;
                            _addColorDrop(color, position);
                            _addSplash(position, color);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Success indicator (shows when colors are very close)
              if (_similarity >= widget.puzzle.accuracyThreshold && !_animatingColorComparison)
                Positioned.fill(
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 24 * value,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Great Match!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Available colors palette
        _buildColorPalette(),
      ],
    );
  }

  Widget _buildTargetColorPreview() {
    return GestureDetector(
      onTap: _compareColors,
      child: AnimatedScale(
        scale: _animatingColorComparison ? 1.0 + (_colorComparisonAnimation.value * 0.1) : 1.0,
        duration: const Duration(milliseconds: 300),
        child: ColorPreview(
          color: widget.puzzle.targetColor,
          label: 'Target Color',
          size: 100,
        ),
      ),
    );
  }

  Widget _buildSimilarityIndicator() {
    return AnimatedBuilder(
      animation: _colorComparisonController,
      builder: (context, child) {
        final isAnimating = _animatingColorComparison;
        final animationValue = _colorComparisonAnimation.value;
        final displaySimilarity = isAnimating ? _similarity * animationValue : _similarity;

        // Determine color based on similarity
        Color arrowColor;
        IconData arrowIcon;

        if (displaySimilarity >= widget.puzzle.accuracyThreshold) {
          arrowColor = Colors.green;
          arrowIcon = Icons.check_circle;
        } else if (displaySimilarity >= 0.8) {
          arrowColor = Colors.orange;
          arrowIcon = Icons.arrow_right_alt;
        } else {
          arrowColor = Colors.red.withOpacity(max(0.3, displaySimilarity));
          arrowIcon = Icons.arrow_right_alt;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              arrowIcon,
              color: arrowColor,
              size: 30 + (isAnimating ? (10 * sin(animationValue * pi)) : 0),
            ),
            const SizedBox(height: 4),
            if (isAnimating || displaySimilarity > 0)
              Text(
                '${(displaySimilarity * 100).toInt()}%',
                style: TextStyle(
                  color: arrowColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildColorPalette() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Colors',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.puzzle.availableColors.length + 1, // +1 for reset button
              itemBuilder: (context, index) {
                if (index == widget.puzzle.availableColors.length) {
                  // Reset button at the end
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: GestureDetector(
                      onTap: _reset,
                      child: Container(
                        width: 60,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.refresh,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  );
                }

                final color = widget.puzzle.availableColors[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Draggable<Color>(
                    data: color,
                    feedback: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class to represent a color drop with physics properties
class _DraggableColorDrop {
  Color color;
  Offset position;
  double size;
  Offset velocity;
  double opacity;

  _DraggableColorDrop({
    required this.color,
    required this.position,
    required this.size,
    required this.velocity,
    this.opacity = 0.7,
  });
}

// Helper class to represent a paint splash effect
class _PaintSplash {
  final Offset position;
  final Color color;
  final double startRadius;
  final double endRadius;
  final int spikes;
  final double rotation;

  _PaintSplash({
    required this.position,
    required this.color,
    required this.startRadius,
    required this.endRadius,
    required this.spikes,
    required this.rotation,
  });
}

// Custom painter for the mixing canvas
class _MixingCanvasPainter extends CustomPainter {
  final List<_DraggableColorDrop> colorDrops;
  final List<_PaintSplash> splashes;
  final AnimationController splashAnimation;

  _MixingCanvasPainter({
    required this.colorDrops,
    required this.splashes,
    required this.splashAnimation,
  }) : super(repaint: splashAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    // Update positions of all drops based on physics
    for (var drop in colorDrops) {
      // Apply gravity
      drop.velocity += const Offset(0, 0.2);

      // Update position
      drop.position += drop.velocity;

      // Bounce off walls
      if (drop.position.dx <= 0 || drop.position.dx >= size.width) {
        drop.velocity = Offset(-drop.velocity.dx * 0.8, drop.velocity.dy);
        // Ensure drop stays within bounds
        drop.position = Offset(
          drop.position.dx.clamp(0, size.width),
          drop.position.dy,
        );
      }

      if (drop.position.dy <= 0 || drop.position.dy >= size.height) {
        drop.velocity = Offset(drop.velocity.dx, -drop.velocity.dy * 0.8);
        // Ensure drop stays within bounds
        drop.position = Offset(
          drop.position.dx,
          drop.position.dy.clamp(0, size.height),
        );
      }

      // Apply friction
      drop.velocity = drop.velocity * 0.98;

      // Paint the drop
      final paint = Paint()
        ..color = drop.color.withOpacity(drop.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(drop.position, drop.size / 2, paint);

      // Add highlight
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(
          drop.position.dx - drop.size / 8,
          drop.position.dy - drop.size / 8,
        ),
        drop.size / 6,
        highlightPaint,
      );
    }

    // Draw splashes
    for (var splash in splashes) {
      final animValue = splashAnimation.value;
      final currentRadius = lerpDouble(
        splash.startRadius,
        splash.endRadius,
        animValue,
      )!;

      final opacity = (1 - animValue);

      final paint = Paint()
        ..color = splash.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(splash.position.dx, splash.position.dy);
      canvas.rotate(splash.rotation);

      final path = Path();
      final angleStep = 2 * pi / (splash.spikes * 2);

      path.moveTo(currentRadius, 0);

      for (int i = 1; i < splash.spikes * 2; i++) {
        final radius = i.isEven ? currentRadius : currentRadius * 0.5;
        final angle = angleStep * i;
        path.lineTo(
          cos(angle) * radius,
          sin(angle) * radius,
        );
      }

      path.close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MixingCanvasPainter oldDelegate) {
    return true; // Always repaint to update physics
  }
}
