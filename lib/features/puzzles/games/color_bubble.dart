import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/color_models/color_mixer.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:palette_master/features/puzzles/widgets/color_preview.dart';
import 'package:vibration/vibration.dart';

class ColorBubblePhysicsGame extends ConsumerStatefulWidget {
  final Puzzle puzzle;
  final Color userColor;
  final Function(Color) onColorMixed;

  const ColorBubblePhysicsGame({
    super.key,
    required this.puzzle,
    required this.userColor,
    required this.onColorMixed,
  });

  @override
  ConsumerState<ColorBubblePhysicsGame> createState() => _BubblePhysicsGameState();
}

class _BubblePhysicsGameState extends ConsumerState<ColorBubblePhysicsGame> with TickerProviderStateMixin {
  final List<ColorBubble> _bubbles = [];
  final GlobalKey _canvasKey = GlobalKey();
  final Random _random = Random();

  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Size _canvasSize = Size.zero;
  Color _resultColor = Colors.white;
  double _similarity = 0.0;
  ColorBubble? _selectedBubble;
  bool _isCreatingNewBubble = false;

  @override
  void initState() {
    super.initState();

    // Setup continuous animation controller for physics simulation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    // Setup pulsing animation for target color
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Add initial bubbles after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCanvasSize();
      _addInitialBubbles();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _updateCanvasSize() {
    final RenderBox? renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _canvasSize = renderBox.size;
      });
    }
  }

  void _addInitialBubbles() {
    // Clear any existing bubbles
    _bubbles.clear();

    // Get available colors from the puzzle
    final availableColors = widget.puzzle.availableColors;

    // Determine number of initial bubbles based on level
    final initialBubbleCount = min(availableColors.length, 3 + (widget.puzzle.level ~/ 5));

    // Create bubbles for each color
    for (int i = 0; i < initialBubbleCount; i++) {
      final color = availableColors[i % availableColors.length];
      final size = 50.0 + _random.nextDouble() * 30;

      // Position bubbles with some spacing
      final xPos = size + _random.nextDouble() * (_canvasSize.width - size * 2);
      final yPos = size + _random.nextDouble() * (_canvasSize.height - size * 2);

      final bubble = ColorBubble(
        id: i,
        color: color,
        position: Offset(xPos, yPos),
        velocity: Offset(
          (_random.nextDouble() - 0.5) * 2,
          (_random.nextDouble() - 0.5) * 2,
        ),
        radius: size / 2,
      );

      _bubbles.add(bubble);
    }

    // Update the mixed color
    _calculateMixedColor();
  }

  void _calculateMixedColor() {
    if (_bubbles.isEmpty) {
      setState(() {
        _resultColor = Colors.white;
        _similarity = 0.0;
      });
      widget.onColorMixed(Colors.white);
      return;
    }

    // Generate the mixed color using weighted average based on bubble sizes
    double totalArea = 0;
    List<Color> weightedColors = [];

    for (var bubble in _bubbles) {
      final area = pi * bubble.radius * bubble.radius;
      totalArea += area;

      // Add color multiple times based on relative area
      final weight = (area / 100).round().clamp(1, 10);
      for (int i = 0; i < weight; i++) {
        weightedColors.add(bubble.color);
      }
    }

    final mixedColor = ColorMixer.mixSubtractive(weightedColors);

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

  void _mergeBubbles(ColorBubble bubble1, ColorBubble bubble2) {
    // Calculate new properties based on both bubbles
    final combinedArea = pi * bubble1.radius * bubble1.radius + pi * bubble2.radius * bubble2.radius;
    final newRadius = sqrt(combinedArea / pi);

    // Weight colors by bubble area
    final area1 = pi * bubble1.radius * bubble1.radius;
    final area2 = pi * bubble2.radius * bubble2.radius;

    // Create weighted list of colors
    List<Color> colors = [];
    final weight1 = (area1 / 50).round().clamp(1, 20);
    final weight2 = (area2 / 50).round().clamp(1, 20);

    for (int i = 0; i < weight1; i++) colors.add(bubble1.color);
    for (int i = 0; i < weight2; i++) colors.add(bubble2.color);

    final newColor = ColorMixer.mixSubtractive(colors);

    // Calculate center point between bubbles, weighted by size
    final newPosition = Offset(
      (bubble1.position.dx * area1 + bubble2.position.dx * area2) / (area1 + area2),
      (bubble1.position.dy * area1 + bubble2.position.dy * area2) / (area1 + area2),
    );

    // Average velocity, weighted by mass
    final newVelocity = Offset(
      (bubble1.velocity.dx * area1 + bubble2.velocity.dx * area2) / (area1 + area2),
      (bubble1.velocity.dy * area1 + bubble2.velocity.dy * area2) / (area1 + area2),
    );

    // Create new bubble
    final newBubble = ColorBubble(
      id: _random.nextInt(10000),
      color: newColor,
      position: newPosition,
      velocity: newVelocity,
      radius: newRadius,
    );

    // Trigger haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 40, amplitude: 180);
      }
    });

    // Remove old bubbles and add new one
    setState(() {
      _bubbles.remove(bubble1);
      _bubbles.remove(bubble2);
      _bubbles.add(newBubble);

      // Add merge animation particle effect
      for (int i = 0; i < 8; i++) {
        final angle = i * (pi / 4);
        final particleRadius = newRadius * 0.3;
        final distance = newRadius * 1.2;

        final particleBubble = ColorBubble(
          id: _random.nextInt(100000),
          color: Color.lerp(bubble1.color, bubble2.color, _random.nextDouble())!,
          position: Offset(
            newPosition.dx + cos(angle) * distance,
            newPosition.dy + sin(angle) * distance,
          ),
          velocity: Offset(
            cos(angle) * (2 + _random.nextDouble() * 3),
            sin(angle) * (2 + _random.nextDouble() * 3),
          ),
          radius: particleRadius,
          isParticle: true,
          lifetime: 1.0,
        );

        _bubbles.add(particleBubble);
      }
    });

    // Update the mixed color
    _calculateMixedColor();
  }

  void _splitBubble(ColorBubble bubble) {
    // Only split bubbles that are large enough
    if (bubble.radius < 30) return;

    // Determine new radius (smaller than original)
    final newRadius = bubble.radius * 0.7071; // sqrt(0.5) to make two bubbles with half the area

    // Create two new bubbles
    final splitAngle = _random.nextDouble() * pi;
    final offset1 = Offset(cos(splitAngle), sin(splitAngle)) * (newRadius * 0.5);
    final offset2 = Offset(-cos(splitAngle), -sin(splitAngle)) * (newRadius * 0.5);

    final bubble1 = ColorBubble(
      id: _random.nextInt(10000),
      color: bubble.color,
      position: bubble.position + offset1,
      velocity: bubble.velocity + Offset(offset1.dx * 0.5, offset1.dy * 0.5),
      radius: newRadius,
    );

    final bubble2 = ColorBubble(
      id: _random.nextInt(10000),
      color: bubble.color,
      position: bubble.position + offset2,
      velocity: bubble.velocity + Offset(offset2.dx * 0.5, offset2.dy * 0.5),
      radius: newRadius,
    );

    // Trigger haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 20, amplitude: 40);
      }
    });

    // Update bubbles list
    setState(() {
      _bubbles.remove(bubble);
      _bubbles.add(bubble1);
      _bubbles.add(bubble2);

      // Add split particle effects
      for (int i = 0; i < 6; i++) {
        final angle = i * (pi / 3);
        final particleRadius = newRadius * 0.2;
        final distance = newRadius;

        final particleBubble = ColorBubble(
          id: _random.nextInt(100000),
          color: bubble.color.withOpacity(0.7),
          position: Offset(
            bubble.position.dx + cos(angle) * distance,
            bubble.position.dy + sin(angle) * distance,
          ),
          velocity: Offset(
            cos(angle) * (1 + _random.nextDouble() * 2),
            sin(angle) * (1 + _random.nextDouble() * 2),
          ),
          radius: particleRadius,
          isParticle: true,
          lifetime: 0.8,
        );

        _bubbles.add(particleBubble);
      }
    });
  }

  void _createNewColorBubble(Color color, Offset position) {
    // Don't allow creating bubbles if already doing so
    if (_isCreatingNewBubble) return;

    final newBubble = ColorBubble(
      id: _random.nextInt(10000),
      color: color,
      position: position,
      velocity: Offset.zero,
      radius: 0, // Start with zero radius and animate
      isGrowing: true,
    );

    setState(() {
      _bubbles.add(newBubble);
      _isCreatingNewBubble = true;
    });

    // Animate bubble growing in
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isCreatingNewBubble = false;
        });
      }
    });
  }

  void _handleDragStart(ColorBubble bubble) {
    setState(() {
      _selectedBubble = bubble;
      bubble.isDragging = true;
      bubble.velocity = Offset.zero; // Reset velocity when grabbed
    });
  }

  void _handleDragUpdate(Offset position) {
    if (_selectedBubble == null) return;

    // Calculate velocity based on movement
    final oldPos = _selectedBubble!.position;

    setState(() {
      _selectedBubble!.position = position;
      _selectedBubble!.velocity = (position - oldPos) * 0.5; // Scale down for better physics
    });
  }

  void _handleDragEnd() {
    setState(() {
      if (_selectedBubble != null) {
        _selectedBubble!.isDragging = false;
        _selectedBubble = null;
      }
    });
  }

  void _handleTap(Offset position) {
    // Find if we tapped on any bubble
    for (var bubble in _bubbles.toList()) {
      if (!bubble.isParticle && (bubble.position - position).distance <= bubble.radius) {
        _splitBubble(bubble);
        return;
      }
    }

    // If we didn't tap on any bubble, find the closest color
    if (_bubbles.isNotEmpty && widget.puzzle.availableColors.isNotEmpty) {
      final closestColor = widget.puzzle.availableColors.first;
      _createNewColorBubble(closestColor, position);
    }
  }

  void _reset() {
    setState(() {
      _bubbles.clear();
      _selectedBubble = null;
    });
    _addInitialBubbles();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Color preview and comparison section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Target color with pulsing animation
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
                    _similarity >= widget.puzzle.accuracyThreshold ? Icons.check_circle : Icons.arrow_forward,
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
        ),

        const SizedBox(height: 16),

        // Game instructions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap to split bubbles, drag to move them, and let them collide to mix colors!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Main physics canvas
        Expanded(
          child: Container(
            key: _canvasKey,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              onTapDown: (details) => _handleTap(details.localPosition),
              onPanStart: (details) {
                // Find if we're starting to drag on a bubble
                for (var bubble in _bubbles.toList()) {
                  if (!bubble.isParticle && (bubble.position - details.localPosition).distance <= bubble.radius) {
                    _handleDragStart(bubble);
                    return;
                  }
                }
              },
              onPanUpdate: (details) => _handleDragUpdate(details.localPosition),
              onPanEnd: (_) => _handleDragEnd(),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _updateBubblePhysics());

                  return CustomPaint(
                    painter: BubblePhysicsPainter(_bubbles),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Control panel
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add New Colors',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.puzzle.availableColors.length + 1, // +1 for reset button
                  itemBuilder: (context, index) {
                    if (index == widget.puzzle.availableColors.length) {
                      // Reset button
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: InkWell(
                          onTap: _reset,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer,
                              shape: BoxShape.circle,
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
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        childWhenDragging: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.3),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                        ),
                        onDragEnd: (details) {
                          if (details.wasAccepted && _canvasKey.currentContext != null) {
                            final RenderBox renderBox = _canvasKey.currentContext!.findRenderObject() as RenderBox;
                            final localPosition = renderBox.globalToLocal(details.offset);

                            if (localPosition.dx >= 0 &&
                                localPosition.dx <= _canvasSize.width &&
                                localPosition.dy >= 0 &&
                                localPosition.dy <= _canvasSize.height) {
                              _createNewColorBubble(color, localPosition);
                            }
                          }
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 4,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.add,
                            color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                                ? Colors.white70
                                : Colors.black45,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _updateBubblePhysics() {
    final List<ColorBubble> bubblesToRemove = [];

    // Update each bubble position and handle physics
    for (var bubble in _bubbles) {
      // Skip bubbles being dragged
      if (bubble.isDragging) continue;

      // Handle particle lifetime
      if (bubble.isParticle) {
        bubble.lifetime = (bubble.lifetime - 0.02).clamp(0.0, 1.0);
        if (bubble.lifetime <= 0) {
          bubblesToRemove.add(bubble);
          continue;
        }
      }

      // Handle growing animation for new bubbles
      if (bubble.isGrowing) {
        bubble.radius = min(bubble.radius + 2.0, 25.0);
        if (bubble.radius >= 25.0) bubble.isGrowing = false;
      }

      // Apply gravity
      bubble.velocity += const Offset(0, 0.05);

      // Apply damping (air resistance)
      bubble.velocity *= 0.98;

      // Update position
      bubble.position += bubble.velocity;

      // Boundary collision - bounce off the edges of the canvas
      if (bubble.position.dx - bubble.radius < 0) {
        bubble.position = Offset(bubble.radius, bubble.position.dy);
        bubble.velocity = Offset(-bubble.velocity.dx * 0.8, bubble.velocity.dy);
      } else if (bubble.position.dx + bubble.radius > _canvasSize.width) {
        bubble.position = Offset(_canvasSize.width - bubble.radius, bubble.position.dy);
        bubble.velocity = Offset(-bubble.velocity.dx * 0.8, bubble.velocity.dy);
      }

      if (bubble.position.dy - bubble.radius < 0) {
        bubble.position = Offset(bubble.position.dx, bubble.radius);
        bubble.velocity = Offset(bubble.velocity.dx, -bubble.velocity.dy * 0.8);
      } else if (bubble.position.dy + bubble.radius > _canvasSize.height) {
        bubble.position = Offset(bubble.position.dx, _canvasSize.height - bubble.radius);
        bubble.velocity = Offset(bubble.velocity.dx, -bubble.velocity.dy * 0.8);
      }
    }

    // Check for bubble collisions
    for (int i = 0; i < _bubbles.length; i++) {
      final bubble1 = _bubbles[i];
      if (bubble1.isParticle) continue; // Particles don't collide

      for (int j = i + 1; j < _bubbles.length; j++) {
        final bubble2 = _bubbles[j];
        if (bubble2.isParticle) continue; // Particles don't collide

        final distance = (bubble1.position - bubble2.position).distance;
        final minDistance = bubble1.radius + bubble2.radius;

        if (distance < minDistance) {
          // Merge bubbles if they're significantly overlapping
          if (distance < minDistance * 0.7) {
            _mergeBubbles(bubble1, bubble2);
            break;
          }

          // Otherwise, calculate collision response
          final direction = (bubble2.position - bubble1.position) / distance;
          final overlap = minDistance - distance;

          // Move bubbles apart
          bubble1.position -= direction * overlap * 0.5;
          bubble2.position += direction * overlap * 0.5;

          // Calculate mass (proportional to area)
          final m1 = bubble1.radius * bubble1.radius;
          final m2 = bubble2.radius * bubble2.radius;
          final totalMass = m1 + m2;

          // Calculate impact speed
          final v1 = bubble1.velocity;
          final v2 = bubble2.velocity;
          final impactSpeed = (v1 - v2).dot(direction);

          // No collision response if bubbles are moving apart
          if (impactSpeed < 0) continue;

          // Calculate impulse
          final impulse = 2 * impactSpeed / totalMass;

          // Apply impulse
          bubble1.velocity -= direction * impulse * m2;
          bubble2.velocity += direction * impulse * m1;
        }
      }
    }

    // Remove any bubbles marked for removal
    if (bubblesToRemove.isNotEmpty) {
      _bubbles.removeWhere((bubble) => bubblesToRemove.contains(bubble));
      _calculateMixedColor();
    }
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

// Helper class to represent a bubble with all its properties
class ColorBubble {
  final int id;
  final Color color;
  Offset position;
  Offset velocity;
  double radius;
  bool isDragging;
  bool isParticle;
  double lifetime;
  bool isGrowing;

  ColorBubble({
    required this.id,
    required this.color,
    required this.position,
    required this.velocity,
    required this.radius,
    this.isDragging = false,
    this.isParticle = false,
    this.lifetime = 1.0,
    this.isGrowing = false,
  });
}

// Custom painter for rendering the bubbles
class BubblePhysicsPainter extends CustomPainter {
  final List<ColorBubble> bubbles;

  BubblePhysicsPainter(this.bubbles);

  @override
  void paint(Canvas canvas, Size size) {
    // Sort bubbles so larger ones appear behind smaller ones
    final sortedBubbles = List<ColorBubble>.from(bubbles)..sort((a, b) => b.radius.compareTo(a.radius));

    for (var bubble in sortedBubbles) {
      // Skip rendering if radius is zero
      if (bubble.radius <= 0) continue;

      final paint = Paint()
        ..color = bubble.isParticle ? bubble.color.withOpacity(bubble.lifetime) : bubble.color.withOpacity(0.85)
        ..style = PaintingStyle.fill;

      // Draw main bubble
      canvas.drawCircle(bubble.position, bubble.radius, paint);

      // Add inner highlight for 3D effect (only for non-particles)
      if (!bubble.isParticle) {
        final highlightPaint = Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.fill;

        final highlightOffset = Offset(-bubble.radius * 0.3, -bubble.radius * 0.3);
        final highlightRadius = bubble.radius * 0.4;

        canvas.drawCircle(
          bubble.position + highlightOffset,
          highlightRadius,
          highlightPaint,
        );
      }

      // Add subtle outline
      final outlinePaint = Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(bubble.position, bubble.radius, outlinePaint);

      // Add movement trail for fast-moving bubbles
      if (!bubble.isParticle && bubble.velocity.distance > 3) {
        final trailPaint = Paint()
          ..color = bubble.color.withOpacity(0.2)
          ..style = PaintingStyle.fill;

        final trailLength = min(bubble.velocity.distance * 3, bubble.radius * 2);
        final trailDirection = -bubble.velocity.normalized();

        final trailPath = Path();
        trailPath.moveTo(
          bubble.position.dx,
          bubble.position.dy,
        );
        trailPath.lineTo(
          bubble.position.dx + trailDirection.dx * trailLength - trailDirection.dy * bubble.radius,
          bubble.position.dy + trailDirection.dy * trailLength + trailDirection.dx * bubble.radius,
        );
        trailPath.lineTo(
          bubble.position.dx + trailDirection.dx * trailLength + trailDirection.dy * bubble.radius,
          bubble.position.dy + trailDirection.dy * trailLength - trailDirection.dx * bubble.radius,
        );
        trailPath.close();

        canvas.drawPath(trailPath, trailPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BubblePhysicsPainter oldDelegate) => true;
}

// Extension to help with vector operations
extension OffsetExtension on Offset {
  Offset normalized() {
    final distance = this.distance;
    if (distance == 0) return Offset.zero;
    return this / distance;
  }

  double dot(Offset other) {
    return dx * other.dx + dy * other.dy;
  }
}
