import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge2d/forge2d.dart' hide Transform;
import 'package:palette_master/core/color_models/color_mixer.dart';
import 'package:vibration/vibration.dart';

// Scale factor to convert between Flutter pixels and Forge2D world units
const double _pixelsPerMeter = 100.0;

// Convert from screen coordinates to physics world coordinates
Vector2 _toWorld(Offset offset) {
  return Vector2(offset.dx / _pixelsPerMeter, offset.dy / _pixelsPerMeter);
}

// Convert from physics world coordinates to screen coordinates
Offset _toScreen(Vector2 vector) {
  return Offset(vector.x * _pixelsPerMeter, vector.y * _pixelsPerMeter);
}

class BubblePhysicsGame extends ConsumerStatefulWidget {
  final Color targetColor;
  final List<Color> availableColors;
  final Function(Color) onColorMixed;
  final int level;

  const BubblePhysicsGame({
    super.key,
    required this.targetColor,
    required this.availableColors,
    required this.onColorMixed,
    required this.level,
  });

  @override
  ConsumerState<BubblePhysicsGame> createState() => _BubblePhysicsGameState();
}

class _BubblePhysicsGameState extends ConsumerState<BubblePhysicsGame> with TickerProviderStateMixin {
  static const double _containerSize = 0.4; // Fraction of screen height

  // Forge2D world
  late World _world;

  // Game state
  final List<ColorBubble> _bubbles = [];
  final List<ColorEffect> _effects = [];
  Color _currentMixedColor = Colors.white;
  double _similarity = 0.0;
  Color? _selectedColor;

  // Animation controllers
  late AnimationController _backgroundController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Ticker _physicsTicker;

  // Touch interaction
  Offset? _dragStart;
  Offset? _dragCurrent;
  ColorBubble? _draggedBubble;

  // Game constraints
  int _maxBubbles = 10; // Increases with level
  int _forceMergeAt = 15; // Force merge bubbles when count exceeds this

  // Tutorial
  bool _showTutorial = true;
  int _tutorialStep = 0;
  String _tutorialText = 'Drag to create a bubble!';

  // Random generator
  final Random _random = Random();

  // Game metrics
  int _collisions = 0;
  int _merges = 0;

  @override
  void initState() {
    super.initState();

    // Adjust game parameters based on level
    _maxBubbles = 6 + widget.level;

    // Initialize Forge2D world with downward gravity
    _world = World(Vector2(0, 9.8)); // Standard Earth gravity

    // Background animation
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Setup physics simulation loop
    _setupPhysicsLoop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Create container bounds (walls)
      _createWorldBounds();

      // Show tutorial based on level
      if (widget.level <= 2) {
        _showFirstTimeTutorial();
      } else {
        _showTutorial = false;
      }
    });
  }

  @override
  void dispose() {
    _physicsTicker.dispose();
    _backgroundController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _setupPhysicsLoop() {
    // Create ticker for physics updates
    _physicsTicker = createTicker((elapsed) {
      // Update the physics world
      _world.stepDt(1 / 60); // 60 FPS physics simulation

      // Update bubble positions from physics bodies
      _updateBubblesFromPhysics();

      // Update visual effects
      _updateEffects();

      // Calculate the mixed color
      _calculateMixedColor();

      // Check for bubble merging
      _checkForMerges();

      // Enforce max bubbles limit
      if (_bubbles.length > _forceMergeAt) {
        _forceMergeBubbles();
      }
    });

    _physicsTicker.start();
  }

  void _createWorldBounds() {
    // Get container size
    final size = MediaQuery.of(context).size;
    final containerWidth = size.width / _pixelsPerMeter;
    final containerHeight = (size.height * _containerSize) / _pixelsPerMeter;

    // Create ground (bottom wall)
    final groundBodyDef = BodyDef()
      ..type = BodyType.static
      ..position.setValues(0, containerHeight);

    final groundBody = _world.createBody(groundBodyDef);

    final groundShape = EdgeShape()..set(Vector2(0, 0), Vector2(containerWidth, 0));

    final groundFixtureDef = FixtureDef(groundShape)
      ..restitution = 0.7 // Elasticity
      ..friction = 0.3;

    groundBody.createFixture(groundFixtureDef);

    // Create left wall
    final leftWallBodyDef = BodyDef()
      ..type = BodyType.static
      ..position.setValues(0, 0);

    final leftWallBody = _world.createBody(leftWallBodyDef);

    final leftWallShape = EdgeShape()..set(Vector2(0, 0), Vector2(0, containerHeight));

    final leftWallFixtureDef = FixtureDef(leftWallShape)
      ..restitution = 0.7
      ..friction = 0.3;

    leftWallBody.createFixture(leftWallFixtureDef);

    // Create right wall
    final rightWallBodyDef = BodyDef()
      ..type = BodyType.static
      ..position.setValues(containerWidth, 0);

    final rightWallBody = _world.createBody(rightWallBodyDef);

    final rightWallShape = EdgeShape()..set(Vector2(0, 0), Vector2(0, containerHeight));

    final rightWallFixtureDef = FixtureDef(rightWallShape)
      ..restitution = 0.7
      ..friction = 0.3;

    rightWallBody.createFixture(rightWallFixtureDef);

    // Create ceiling (top wall)
    final ceilingBodyDef = BodyDef()
      ..type = BodyType.static
      ..position.setValues(0, 0);

    final ceilingBody = _world.createBody(ceilingBodyDef);

    final ceilingShape = EdgeShape()..set(Vector2(0, 0), Vector2(containerWidth, 0));

    final ceilingFixtureDef = FixtureDef(ceilingShape)
      ..restitution = 0.7
      ..friction = 0.3;

    ceilingBody.createFixture(ceilingFixtureDef);
  }

  void _updateBubblesFromPhysics() {
    // Update bubble positions from their physics bodies
    for (var bubble in _bubbles) {
      if (bubble.body != null && bubble != _draggedBubble) {
        bubble.position = _toScreen(bubble.body!.position);
        bubble.velocity =
            Offset(bubble.body!.linearVelocity.x * _pixelsPerMeter, bubble.body!.linearVelocity.y * _pixelsPerMeter);
      }
    }
  }

  void _updateEffects() {
    setState(() {
      // Update effects and remove completed ones
      for (int i = _effects.length - 1; i >= 0; i--) {
        _effects[i].update();
        if (_effects[i].isDone) {
          _effects.removeAt(i);
        }
      }
    });
  }

  void _checkForMerges() {
    // Check for collisions between bubbles that might trigger color mixing
    for (int i = 0; i < _bubbles.length; i++) {
      for (int j = i + 1; j < _bubbles.length; j++) {
        final bubble1 = _bubbles[i];
        final bubble2 = _bubbles[j];

        // Skip if either bubble is being dragged
        if (bubble1 == _draggedBubble || bubble2 == _draggedBubble) continue;

        // Skip if bubbles don't have bodies yet
        if (bubble1.body == null || bubble2.body == null) continue;

        // Calculate distance between bubbles
        final distance = (bubble1.position - bubble2.position).distance;
        final minDistance = bubble1.radius + bubble2.radius;

        // Check if bubbles are close enough and moving towards each other
        if (distance < minDistance) {
          final relativeVelocity = (bubble1.velocity - bubble2.velocity).distance;

          // Increment collision counter
          _collisions++;

          // Create collision effect
          final midpoint = (bubble1.position + bubble2.position) / 2;
          _addCollisionEffect(midpoint, bubble1.color, bubble2.color);

          // Provide haptic feedback
          _provideHapticFeedback(20, 30);

          // Try to mix colors based on velocity
          _tryMixBubbles(bubble1, bubble2, relativeVelocity);
        }
      }
    }
  }

  void _tryMixBubbles(ColorBubble bubble1, ColorBubble bubble2, double relativeVelocity) {
    // Only mix if bubbles are different colors and moving fast enough
    if (bubble1.color != bubble2.color && relativeVelocity > 100.0) {
      // Probability of mixing increases with higher velocities
      final mixProbability = relativeVelocity * 0.001;

      if (_random.nextDouble() < mixProbability) {
        // Mix the colors using the color mixer
        final mixedColor = ColorMixer.mixSubtractive([bubble1.color, bubble2.color]);

        // Calculate the new bubble radius (conserve area)
        final newRadius = sqrt(bubble1.radius * bubble1.radius + bubble2.radius * bubble2.radius);

        // Create a new bubble with mixed color
        final midPoint = (bubble1.position + bubble2.position) / 2;

        // Average velocities
        final avgVelocity = (bubble1.velocity + bubble2.velocity) / 2;

        // Create the new bubble at the midpoint
        final newBubble = _createBubble(
          midPoint,
          mixedColor,
          initialRadius: newRadius.clamp(10.0, 40.0),
          initialVelocity: avgVelocity,
        );

        // Add merge effect
        _addMergeEffect(midPoint, bubble1.color, bubble2.color, mixedColor);

        // Remove the original bubbles
        _removeBubble(bubble1);
        _removeBubble(bubble2);

        // Track merge
        _merges++;

        // Provide stronger haptic feedback for merge
        _provideHapticFeedback(50, 80);

        // Progress tutorial if needed
        if (_showTutorial && _tutorialStep == 1) {
          setState(() {
            _tutorialStep = 2;
            _tutorialText = 'Great! Keep mixing to match the target color!';
          });
        }
      }
    }
  }

  void _forceMergeBubbles() {
    // Find two closest bubbles to merge
    ColorBubble? bubble1;
    ColorBubble? bubble2;
    double closestDistance = double.infinity;

    for (int i = 0; i < _bubbles.length; i++) {
      for (int j = i + 1; j < _bubbles.length; j++) {
        final distance = (_bubbles[i].position - _bubbles[j].position).distance;
        if (distance < closestDistance) {
          closestDistance = distance;
          bubble1 = _bubbles[i];
          bubble2 = _bubbles[j];
        }
      }
    }

    if (bubble1 != null && bubble2 != null) {
      // Mix the colors
      final mixedColor = ColorMixer.mixSubtractive([bubble1.color, bubble2.color]);

      // Calculate the new bubble radius
      final newRadius = sqrt(bubble1.radius * bubble1.radius + bubble2.radius * bubble2.radius);

      // Create a new bubble with mixed color at the midpoint
      final midPoint = (bubble1.position + bubble2.position) / 2;

      // Average velocities
      final avgVelocity = (bubble1.velocity + bubble2.velocity) / 2;

      // Create the new bubble
      _createBubble(
        midPoint,
        mixedColor,
        initialRadius: newRadius.clamp(10.0, 40.0),
        initialVelocity: avgVelocity,
      );

      // Add merge effect
      _addMergeEffect(midPoint, bubble1.color, bubble2.color, mixedColor);

      // Remove the original bubbles
      _removeBubble(bubble1);
      _removeBubble(bubble2);

      // Track merge
      _merges++;
    }
  }

  void _calculateMixedColor() {
    if (_bubbles.isEmpty) {
      setState(() {
        _currentMixedColor = Colors.white;
        _similarity = 0.0;
      });
      widget.onColorMixed(_currentMixedColor);
      return;
    }

    // Calculate a weighted average based on bubble sizes
    final List<Color> allBubbleColors = [];

    // Add each bubble's color weighted by its area (proportional to radius squared)
    for (var bubble in _bubbles) {
      final weight = (bubble.radius * bubble.radius).round();
      for (int i = 0; i < weight; i++) {
        allBubbleColors.add(bubble.color);
      }
    }

    // Use the color mixer to blend all colors
    final mixedColor = ColorMixer.mixSubtractive(allBubbleColors);

    // Calculate similarity with target color
    final similarity = _calculateColorSimilarity(mixedColor, widget.targetColor);

    setState(() {
      _currentMixedColor = mixedColor;
      _similarity = similarity;
    });

    // Update parent
    widget.onColorMixed(mixedColor);

    // Progress tutorial if needed
    if (_showTutorial && _tutorialStep == 2 && _similarity >= 0.8) {
      setState(() {
        _tutorialStep = 3;
        _tutorialText = 'Perfect! Now check your result!';
      });
    }
  }

  double _calculateColorSimilarity(Color a, Color b) {
    // Calculate similarity between colors (0.0 to 1.0)
    final dr = (a.red - b.red) / 255.0;
    final dg = (a.green - b.green) / 255.0;
    final db = (a.blue - b.blue) / 255.0;

    // Human eyes are more sensitive to green, less to blue
    final distance = (dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11);

    return (1.0 - sqrt(distance)).clamp(0.0, 1.0);
  }

  ColorBubble _createBubble(Offset position, Color color, {double? initialRadius, Offset? initialVelocity}) {
    // Don't create more bubbles if at max capacity
    if (_bubbles.length >= _maxBubbles) {
      // Show warning
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $_maxBubbles bubbles reached! Try merging some.'),
          duration: const Duration(seconds: 2),
        ),
      );
      // Return a dummy bubble that won't be added to the game
      return ColorBubble(
        position: position,
        radius: initialRadius ?? 20.0,
        color: color,
      );
    }

    final radius = initialRadius ?? (20.0 + _random.nextDouble() * 15.0);
    final velocity = initialVelocity ?? Offset.zero;

    // Create a new bubble
    final bubble = ColorBubble(
      position: position,
      radius: radius,
      color: color,
      velocity: velocity,
    );

    // Create a physics body for the bubble
    _createBubbleBody(bubble);

    setState(() {
      _bubbles.add(bubble);
    });

    // Add creation effect
    _addCreationEffect(position, color, radius);

    // Progress tutorial if needed
    if (_showTutorial && _tutorialStep == 0) {
      setState(() {
        _tutorialStep = 1;
        _tutorialText = 'Now create another bubble and make them collide!';
      });
    }

    return bubble;
  }

  void _createBubbleBody(ColorBubble bubble) {
    // Create body definition
    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = _toWorld(bubble.position)
      ..linearVelocity = Vector2(bubble.velocity.dx / _pixelsPerMeter, bubble.velocity.dy / _pixelsPerMeter)
      ..bullet = true // Enable continuous collision detection for fast-moving objects
      ..userData = bubble; // Store reference to the bubble for collision handling

    // Create body
    final body = _world.createBody(bodyDef);

    // Create circle shape
    final circleShape = CircleShape()..radius = bubble.radius / _pixelsPerMeter;

    // Calculate density based on radius (smaller bubbles are denser)
    final density = 1.0; // Base density

    // Create fixture
    final fixtureDef = FixtureDef(circleShape)
      ..density = density
      ..friction = 0.3
      ..restitution = 0.8 // Elasticity/bounciness
      ..filter.groupIndex = -1; // Negative group index means objects in this group never collide

    body.createFixture(fixtureDef);

    // Store reference to body in bubble
    bubble.body = body;

    // Setup contact listener for this body

    // body.setContactCallback(BubbleContactCallback(onBeginContact: (otherBody) {
    //   // Logic for beginning of contact
    // }, onEndContact: (otherBody) {
    //   // Logic for end of contact
    // }));
  }

  void _removeBubble(ColorBubble bubble) {
    // Remove physics body
    if (bubble.body != null) {
      _world.destroyBody(bubble.body!);
    }

    // Remove from list
    setState(() {
      _bubbles.remove(bubble);
    });
  }

  void _addCreationEffect(Offset position, Color color, double radius) {
    // Add expanding ring effect
    final effect = RingEffect(
      position: position,
      color: color,
      initialRadius: radius,
      maxRadius: radius * 3,
      duration: 30,
    );

    setState(() {
      _effects.add(effect);
    });
  }

  void _addCollisionEffect(Offset position, Color color1, Color color2) {
    // Add particle burst effect
    final particleCount = 8 + _random.nextInt(5);

    for (int i = 0; i < particleCount; i++) {
      final angle = i * (2 * pi / particleCount);
      final speed = 1.0 + _random.nextDouble() * 2.0;
      final velocity = Offset(cos(angle), sin(angle)) * speed;
      final useColor1 = _random.nextBool();

      final particle = ParticleEffect(
        position: position,
        velocity: velocity,
        color: useColor1 ? color1 : color2,
        size: 3.0 + _random.nextDouble() * 3.0,
        duration: 20 + _random.nextInt(10),
      );

      setState(() {
        _effects.add(particle);
      });
    }
  }

  void _addMergeEffect(Offset position, Color color1, Color color2, Color mixedColor) {
    // Add expanding ring with gradient
    final ringEffect = GradientRingEffect(
      position: position,
      color1: color1,
      color2: color2,
      initialRadius: 10.0,
      maxRadius: 60.0,
      duration: 40,
    );

    // Add mixed color stars
    final starCount = 5 + _random.nextInt(3);

    for (int i = 0; i < starCount; i++) {
      final angle = i * (2 * pi / starCount);
      final distance = 20.0 + _random.nextDouble() * 20.0;
      final pos = position + Offset(cos(angle), sin(angle)) * distance;

      final star = StarEffect(
        position: pos,
        color: mixedColor,
        size: 10.0 + _random.nextDouble() * 10.0,
        duration: 30 + _random.nextInt(20),
      );

      setState(() {
        _effects.add(star);
      });
    }

    setState(() {
      _effects.add(ringEffect);
    });
  }

  void _provideHapticFeedback(int duration, int amplitude) {
    // Only provide feedback if device supports it
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: duration, amplitude: amplitude);
      }
    });
  }

  void _handleColorSelect(Color color) {
    setState(() {
      _selectedColor = color;
    });

    // Show tutorial based on level
    if (_showTutorial && _tutorialStep == 0) {
      setState(() {
        _tutorialText = 'Great! Now drag on the surface to create a bubble!';
      });
    }
  }

  void _handlePanStart(DragStartDetails details) {
    // Check if creating a new bubble or dragging existing
    final bubble = _getBubbleAtPosition(details.localPosition);

    if (bubble != null) {
      // Start dragging existing bubble
      setState(() {
        _draggedBubble = bubble;
        _dragStart = details.localPosition;

        // Set bubble body to static during dragging to disable physics
        if (bubble.body != null) {
          bubble.body!.setType(BodyType.kinematic);
          bubble.body!.linearVelocity = Vector2.zero();
        }
      });
    } else if (_selectedColor != null) {
      // Start creating a new bubble
      setState(() {
        _dragStart = details.localPosition;
        _dragCurrent = details.localPosition;
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_draggedBubble != null) {
      // Update dragged bubble position
      setState(() {
        _draggedBubble!.position = details.localPosition;

        // Update physics body position
        if (_draggedBubble!.body != null) {
          _draggedBubble!.body!.setTransform(_toWorld(details.localPosition), 0);
        }
      });
    } else if (_dragStart != null && _selectedColor != null) {
      // Update drag for new bubble creation
      setState(() {
        _dragCurrent = details.localPosition;
      });
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_draggedBubble != null) {
      // Calculate velocity from drag speed
      final velocity = details.velocity.pixelsPerSecond;
      final normalizedVelocity = velocity / 1000; // Scale down for reasonable physics

      // Re-enable physics and apply velocity
      if (_draggedBubble!.body != null) {
        _draggedBubble!.body!.setType(BodyType.dynamic);
        _draggedBubble!.body!.linearVelocity =
            (Vector2(normalizedVelocity.dx / _pixelsPerMeter, normalizedVelocity.dy / _pixelsPerMeter));
      }

      setState(() {
        _draggedBubble!.velocity = normalizedVelocity;
        _draggedBubble = null;
        _dragStart = null;
      });
    } else if (_dragStart != null && _dragCurrent != null && _selectedColor != null) {
      // Create new bubble with velocity from drag
      final dragVector = _dragCurrent! - _dragStart!;
      final velocity = dragVector / 10; // Scale for reasonable initial velocity

      _createBubble(
        _dragStart!,
        _selectedColor!,
        initialVelocity: velocity,
      );

      // Reset drag state
      setState(() {
        _dragStart = null;
        _dragCurrent = null;
      });
    }
  }

  ColorBubble? _getBubbleAtPosition(Offset position) {
    // Check if position is inside any bubble
    for (var bubble in _bubbles) {
      if ((bubble.position - position).distance <= bubble.radius) {
        return bubble;
      }
    }
    return null;
  }

  void _resetGame() {
    // Clear all physics bodies
    for (var bubble in _bubbles) {
      if (bubble.body != null) {
        _world.destroyBody(bubble.body!);
      }
    }

    setState(() {
      _bubbles.clear();
      _effects.clear();
      _currentMixedColor = Colors.white;
      _similarity = 0.0;
      _collisions = 0;
      _merges = 0;
    });

    widget.onColorMixed(Colors.white);
  }

  void _showFirstTimeTutorial() {
    setState(() {
      _showTutorial = true;
      _tutorialStep = 0;
      _tutorialText = 'Select a color from the palette below!';
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final containerHeight = size.height * _containerSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Game metrics
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Bubble count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bubble_chart, color: Colors.blue, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Bubbles: ${_bubbles.length}/$_maxBubbles',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Match percentage
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getSimilarityColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _similarity >= 0.9 ? Icons.check_circle : Icons.color_lens,
                      color: _getSimilarityColor(),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Match: ${(_similarity * 100).toInt()}%',
                      style: TextStyle(
                        color: _getSimilarityColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Interactions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.purple, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Merges: $_merges',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Color targets
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              // Target color
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Target Color',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _similarity >= 0.9 ? _pulseAnimation.value : 1.0,
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: widget.targetColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.targetColor.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Current mix
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Your Mix',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: _currentMixedColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _currentMixedColor.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _bubbles.isEmpty
                            ? const Text(
                                'Create bubbles!',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              )
                            : Text(
                                'RGB(${_currentMixedColor.red}, ${_currentMixedColor.green}, ${_currentMixedColor.blue})',
                                style: TextStyle(
                                  color: _getContrastColor(_currentMixedColor),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Game area
        GestureDetector(
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          child: Container(
            height: containerHeight,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blue.shade300.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CustomPaint(
                painter: BubbleGamePainter(
                  bubbles: _bubbles,
                  effects: _effects,
                  dragStart: _dragStart,
                  dragCurrent: _dragCurrent,
                  draggedBubble: _draggedBubble,
                  selectedColor: _selectedColor,
                  animationValue: _backgroundController.value,
                ),
                child: Stack(
                  children: [
                    // Tutorial overlay
                    if (_showTutorial)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade800.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.blue.shade300,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _tutorialStep == 0
                                      ? Icons.touch_app
                                      : _tutorialStep == 1
                                          ? Icons.swipe
                                          : _tutorialStep == 2
                                              ? Icons.auto_awesome
                                              : Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _tutorialText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showTutorial = false;
                                    });
                                  },
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Color palette
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade900.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border.all(
                color: Colors.blue.shade700.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Color Palette',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _resetGame,
                      icon: const Icon(Icons.refresh, size: 16, color: Colors.redAccent),
                      label: const Text('Reset'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Color grid
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: widget.availableColors.length,
                    itemBuilder: (context, index) {
                      final color = widget.availableColors[index];
                      final isSelected = _selectedColor == color;

                      return GestureDetector(
                        onTap: () => _handleColorSelect(color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.5),
                                blurRadius: isSelected ? 8 : 4,
                                spreadRadius: isSelected ? 2 : 0,
                              ),
                            ],
                          ),
                          child: Center(
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Level-specific tip
                // Container(
                //   padding: const EdgeInsets.all(12),
                //   margin: const EdgeInsets.only(top: 8),
                //   decoration: BoxDecoration(
                //     color: Colors.blue.shade800.withOpacity(0.3),
                //     borderRadius: BorderRadius.circular(12),
                //     border: Border.all(
                //       color: Colors.blue.shade300.withOpacity(0.3),
                //       width: 1,
                //     ),
                //   ),
                //   child: Row(
                //     children: [
                //       const Icon(
                //         Icons.lightbulb,
                //         color: Colors.amber,
                //         size: 20,
                //       ),
                //       const SizedBox(width: 8),
                //       Expanded(
                //         child: Text(
                //           _getLevelTip(),
                //           style: const TextStyle(
                //             color: Colors.white,
                //             fontSize: 12,
                //           ),
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getSimilarityColor() {
    if (_similarity >= 0.9) return Colors.green;
    if (_similarity >= 0.7) return Colors.orange;
    return Colors.red;
  }

  Color _getContrastColor(Color color) {
    // Returns black or white text color based on background
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  String _getLevelTip() {
    // Return different tips based on level
    switch (widget.level) {
      case 1:
        return 'Try mixing two primary colors to create a secondary color. Drag bubbles to collide them!';
      case 2:
        return 'More collisions between bubbles increases the chance of them mixing colors.';
      case 3:
        return 'Try creating bubbles with different sizes for different color proportions.';
      case 4:
        return 'Higher velocity collisions have a greater chance of merging bubbles.';
      case 5:
        return 'For complex colors, try mixing in steps: create intermediate colors first.';
      case 6:
        return 'When bubbles get too large, try creating smaller ones to fine-tune your mix.';
      default:
        return 'Experiment with different color combinations and collision patterns.';
    }
  }
}

// Class for physics bubble
class ColorBubble {
  Offset position;
  Offset velocity;
  final double radius;
  final Color color;
  Body? body; // Forge2D physics body

  ColorBubble({
    required this.position,
    required this.radius,
    required this.color,
    this.velocity = Offset.zero,
    this.body,
  });
}

// Callback for handling physics contacts between bodies
class BubbleContactCallback implements ContactListener {
  final Function(Body)? onBeginContact;
  final Function(Body)? onEndContact;

  BubbleContactCallback({
    this.onBeginContact,
    this.onEndContact,
  });

  @override
  void beginContact(Contact contact) {
    final fixtureA = contact.fixtureA;
    final fixtureB = contact.fixtureB;

    if (fixtureA != null && fixtureB != null) {
      final bodyA = fixtureA.body;
      final bodyB = fixtureB.body;

      if (onBeginContact != null) {
        if (bodyA.userData is ColorBubble) {
          onBeginContact!(bodyB);
        } else if (bodyB.userData is ColorBubble) {
          onBeginContact!(bodyA);
        }
      }
    }
  }

  @override
  void endContact(Contact contact) {
    final fixtureA = contact.fixtureA;
    final fixtureB = contact.fixtureB;

    if (fixtureA != null && fixtureB != null) {
      final bodyA = fixtureA.body;
      final bodyB = fixtureB.body;

      if (onEndContact != null) {
        if (bodyA.userData is ColorBubble) {
          onEndContact!(bodyB);
        } else if (bodyB.userData is ColorBubble) {
          onEndContact!(bodyA);
        }
      }
    }
  }

  @override
  void preSolve(Contact contact, Manifold oldManifold) {}
  @override
  void postSolve(Contact contact, ContactImpulse impulse) {}
}

// Base class for visual effects
abstract class ColorEffect {
  Offset position;
  Color color;
  int duration;
  int age = 0;
  bool get isDone => age >= duration;

  ColorEffect({
    required this.position,
    required this.color,
    required this.duration,
  });

  void update() {
    age++;
  }

  void render(Canvas canvas);
}

// Expanding ring effect
class RingEffect extends ColorEffect {
  final double initialRadius;
  final double maxRadius;

  RingEffect({
    required super.position,
    required super.color,
    required this.initialRadius,
    required this.maxRadius,
    required super.duration,
  });

  @override
  void render(Canvas canvas) {
    final progress = age / duration;
    final radius = initialRadius + (maxRadius - initialRadius) * progress;
    final opacity = 1.0 - progress;

    final paint = Paint()
      ..color = color.withOpacity(opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(position, radius, paint);
  }
}

// Particle effect
class ParticleEffect extends ColorEffect {
  Offset velocity;
  double size;

  ParticleEffect({
    required super.position,
    required this.velocity,
    required super.color,
    required this.size,
    required super.duration,
  });

  @override
  void update() {
    super.update();
    position += velocity;
    velocity *= 0.95; // Apply drag
    size *= 0.97; // Shrink over time
  }

  @override
  void render(Canvas canvas) {
    final progress = age / duration;
    final opacity = 1.0 - progress;

    final paint = Paint()
      ..color = color.withOpacity(opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(position, size, paint);
  }
}

// Gradient ring effect
class GradientRingEffect extends ColorEffect {
  final Color color1;
  final Color color2;
  final double initialRadius;
  final double maxRadius;

  GradientRingEffect({
    required super.position,
    required this.color1,
    required this.color2,
    required this.initialRadius,
    required this.maxRadius,
    required super.duration,
  }) : super(color: color1);

  @override
  void render(Canvas canvas) {
    final progress = age / duration;
    final radius = initialRadius + (maxRadius - initialRadius) * progress;
    final opacity = 1.0 - progress;

    final rect = Rect.fromCircle(center: position, radius: radius);
    final gradient = SweepGradient(
      colors: [color1, color2, color1],
      stops: const [0.0, 0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0)
      ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0));

    canvas.drawCircle(position, radius, paint);
  }
}

// Star effect
class StarEffect extends ColorEffect {
  final double size;
  double rotation = 0.0;

  StarEffect({
    required super.position,
    required super.color,
    required this.size,
    required super.duration,
  });

  @override
  void update() {
    super.update();
    rotation += 0.05;
  }

  @override
  void render(Canvas canvas) {
    final progress = age / duration;
    final opacity = 1.0 - progress;
    final currentSize = size * (1.0 - progress * 0.3);

    final paint = Paint()
      ..color = color.withOpacity(opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);

    final path = Path();
    final outerRadius = currentSize;
    final innerRadius = currentSize * 0.4;
    final points = 5;

    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = i * pi / points;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);

    // Add glow
    final glowPaint = Paint()
      ..color = color.withOpacity(opacity.clamp(0.0, 0.3))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    canvas.drawPath(path, glowPaint);

    canvas.restore();
  }
}

// Custom painter for the physics game
class BubbleGamePainter extends CustomPainter {
  final List<ColorBubble> bubbles;
  final List<ColorEffect> effects;
  final double animationValue;
  final Offset? dragStart;
  final Offset? dragCurrent;
  final ColorBubble? draggedBubble;
  final Color? selectedColor;

  BubbleGamePainter({
    required this.bubbles,
    required this.effects,
    required this.animationValue,
    this.dragStart,
    this.dragCurrent,
    this.draggedBubble,
    this.selectedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background pattern
    _drawBackground(canvas, size);

    // Draw drag indicator
    if (dragStart != null && dragCurrent != null && selectedColor != null) {
      _drawDragIndicator(canvas, dragStart!, dragCurrent!, selectedColor!);
    }

    // Draw effects
    for (var effect in effects) {
      effect.render(canvas);
    }

    // Draw bubbles
    for (var bubble in bubbles) {
      _drawBubble(canvas, bubble);
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    // Draw subtle grid pattern
    final gridPaint = Paint()
      ..color = Colors.blue.shade200.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const gridSize = 20.0;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Draw a few floating particles
    final random = Random(animationValue.toInt() * 1000);
    final particlePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 1.0 + random.nextDouble() * 2.0;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        particlePaint,
      );
    }
  }

  void _drawBubble(Canvas canvas, ColorBubble bubble) {
    // Gradient for bubble
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 0.9,
      colors: [
        Color.lerp(bubble.color, Colors.white, 0.25)!,
        bubble.color,
      ],
      stops: const [0.0, 1.0],
    );

    final rect = Rect.fromCircle(center: bubble.position, radius: bubble.radius);

    // Main bubble fill
    final bubblePaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(bubble.position, bubble.radius, bubblePaint);

    // Highlight/reflection
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(
        bubble.position.dx - bubble.radius * 0.3,
        bubble.position.dy - bubble.radius * 0.3,
      ),
      bubble.radius * 0.2,
      highlightPaint,
    );

    // Edge glow for dragged bubble
    if (bubble == draggedBubble) {
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawCircle(bubble.position, bubble.radius + 3, glowPaint);
    }
  }

  void _drawDragIndicator(Canvas canvas, Offset start, Offset end, Color color) {
    // Line connecting start and end
    final linePaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, linePaint);

    // Arrow at the end
    final vector = end - start;
    final angle = atan2(vector.dy, vector.dx);

    final arrowSize = 10.0;
    final arrowAngle1 = angle - pi * 0.8;
    final arrowAngle2 = angle + pi * 0.8;

    final arrowPoint1 = end - Offset(cos(arrowAngle1), sin(arrowAngle1)) * arrowSize;
    final arrowPoint2 = end - Offset(cos(arrowAngle2), sin(arrowAngle2)) * arrowSize;

    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(arrowPoint1.dx, arrowPoint1.dy)
      ..lineTo(arrowPoint2.dx, arrowPoint2.dy)
      ..close();

    final arrowPaint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, arrowPaint);

    // Dot at start
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(start, 5.0, dotPaint);

    // Velocity indicator text
    final speed = vector.distance.clamp(0.0, 200.0);
    final speedText = (speed / 20).toStringAsFixed(1);

    final textStyle = TextStyle(
      color: color,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );

    final textSpan = TextSpan(
      text: speedText,
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final midpoint = (start + end) / 2;
    textPainter.paint(
      canvas,
      midpoint - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(BubbleGamePainter oldDelegate) {
    return true; // Always repaint for smooth animation
  }
}
