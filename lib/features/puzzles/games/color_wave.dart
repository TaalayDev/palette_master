import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge2d/forge2d.dart';
import 'package:palette_master/core/color_models/color_mixer.dart';
import 'package:vibration/vibration.dart';

/// The main color wave game widget
class ColorWaveGame extends ConsumerStatefulWidget {
  final Color targetColor;
  final List<Color> availableColors;
  final Function(Color) onColorMixed;
  final int level;
  final VoidCallback onReset;
  final ValueNotifier<Color?> selectedColorNotifier;

  const ColorWaveGame({
    super.key,
    required this.targetColor,
    required this.availableColors,
    required this.onColorMixed,
    required this.level,
    required this.onReset,
    required this.selectedColorNotifier,
  });

  @override
  ConsumerState<ColorWaveGame> createState() => _ColorWaveGameState();
}

class _ColorWaveGameState extends ConsumerState<ColorWaveGame> with TickerProviderStateMixin {
  // Physics world
  late World _world;
  final double _worldScale = 10.0;

  // Game state
  final List<WaveEmitter> _emitters = [];
  final List<WaveParticle> _particles = [];
  final List<ColorWave> _waves = [];
  final List<Obstacle> _obstacles = [];
  Color _currentMixedColor = Colors.white;
  double _similarity = 0.0;
  Color? _selectedColor;
  bool _isPlacing = false;
  Offset? _placementPosition;

  // Canvas size
  Size _canvasSize = Size.zero;

  // Animation controllers
  late AnimationController _backgroundController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveController;

  // Random generator
  final Random _random = Random();

  // Tutorial state
  bool _showTutorial = true;
  int _tutorialStep = 0;

  // Level config
  late LevelConfig _levelConfig;

  @override
  void initState() {
    super.initState();

    // Initialize physics world
    _world = World(Vector2(0, 0)); // No gravity in this game

    // Setup level configuration
    _levelConfig = _getLevelConfig(widget.level);

    // Initialize animation controllers
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

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

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60fps
    )..addListener(_updatePhysics);

    _waveController.repeat();

    // Set up initial emitters based on level
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLevel();

      // Start with tutorial
      if (widget.level <= 3) {
        _showTutorialStep(0);
      }
    });

    // Listen for selected color changes
    widget.selectedColorNotifier.addListener(() {
      final selectedColor = widget.selectedColorNotifier.value;
      if (selectedColor != null) {
        _handleColorSelect(selectedColor);
      }
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _initializeLevel() {
    if (!mounted) return;

    setState(() {
      _emitters.clear();
      _waves.clear();
      _particles.clear();
      _obstacles.clear();
    });

    // Create canvas bounds
    _createBoundaries();

    // Add level-specific obstacles
    _addObstacles();

    // Add initial emitters if any
    for (final emitterConfig in _levelConfig.initialEmitters) {
      _addEmitter(
        position: emitterConfig.position,
        color: emitterConfig.color,
        fixed: emitterConfig.fixed,
      );
    }
  }

  void _createBoundaries() {
    if (_canvasSize == Size.zero) return;

    // Left wall
    _createBoundary(
      Vector2(-1, 0),
      Vector2(-1, _canvasSize.height / _worldScale),
    );

    // Right wall
    _createBoundary(
      Vector2(_canvasSize.width / _worldScale + 1, 0),
      Vector2(_canvasSize.width / _worldScale + 1, _canvasSize.height / _worldScale),
    );

    // Top wall
    _createBoundary(
      Vector2(0, -1),
      Vector2(_canvasSize.width / _worldScale, -1),
    );

    // Bottom wall
    _createBoundary(
      Vector2(0, _canvasSize.height / _worldScale + 1),
      Vector2(_canvasSize.width / _worldScale, _canvasSize.height / _worldScale + 1),
    );
  }

  void _createBoundary(Vector2 start, Vector2 end) {
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = Vector2(0, 0);

    final body = _world.createBody(bodyDef);
    final shape = EdgeShape()..set(start, end);

    final fixtureDef = FixtureDef(shape)
      ..restitution = 0.8
      ..density = 1.0
      ..friction = 0.3;

    body.createFixture(fixtureDef);
  }

  void _addObstacles() {
    for (final obstacleConfig in _levelConfig.obstacles) {
      final obstacle = Obstacle(
        position: obstacleConfig.position,
        radius: obstacleConfig.radius,
        reflective: obstacleConfig.reflective,
        absorptive: obstacleConfig.absorptive,
        color: obstacleConfig.color,
      );

      _createObstacleBody(obstacle);

      setState(() {
        _obstacles.add(obstacle);
      });
    }
  }

  void _createObstacleBody(Obstacle obstacle) {
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = Vector2(
        obstacle.position.dx / _worldScale,
        obstacle.position.dy / _worldScale,
      );

    final body = _world.createBody(bodyDef);
    obstacle.body = body;

    final shape = CircleShape()..radius = obstacle.radius / _worldScale;

    final fixtureDef = FixtureDef(shape)
      ..restitution = obstacle.reflective ? 0.9 : 0.2
      ..density = 1.0
      ..friction = obstacle.absorptive ? 0.9 : 0.1
      ..userData = obstacle;

    body.createFixture(fixtureDef);
  }

  void _addEmitter({
    required Offset position,
    required Color color,
    bool fixed = false,
  }) {
    final emitter = WaveEmitter(
      position: position,
      color: color,
      radius: 20.0,
      frequency: 1.5 + (_random.nextDouble() * 0.5),
      fixed: fixed,
    );

    if (!fixed) {
      _createEmitterBody(emitter);
    }

    setState(() {
      _emitters.add(emitter);
    });

    // Create ripple effect
    _createRippleEffect(position, color);

    // Progress tutorial if needed
    if (_showTutorial && _tutorialStep == 0 && _emitters.length > 1) {
      _showTutorialStep(1);
    }
  }

  void _createEmitterBody(WaveEmitter emitter) {
    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = Vector2(
        emitter.position.dx / _worldScale,
        emitter.position.dy / _worldScale,
      )
      ..linearDamping = 0.8
      ..angularDamping = 0.8
      ..fixedRotation = true;

    final body = _world.createBody(bodyDef);
    emitter.body = body;

    final shape = CircleShape()..radius = emitter.radius / _worldScale;

    final fixtureDef = FixtureDef(shape)
      ..restitution = 0.7
      ..density = 0.8
      ..friction = 0.3
      ..userData = emitter;

    body.createFixture(fixtureDef);
  }

  void _createRippleEffect(Offset position, Color color) {
    for (int i = 0; i < 16; i++) {
      final angle = i * (pi / 8);
      final distance = 30.0 + _random.nextDouble() * 20.0;
      final velocity = 0.5 + _random.nextDouble() * 0.5;

      final particle = WaveParticle(
        position: position,
        angle: angle,
        maxDistance: distance,
        velocity: velocity,
        color: color.withOpacity(0.7),
        size: 8.0 + _random.nextDouble() * 5.0,
      );

      setState(() {
        _particles.add(particle);
      });
    }

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 20, amplitude: 40);
      }
    });
  }

  void _removeEmitter(WaveEmitter emitter) {
    if (emitter.body != null) {
      _world.destroyBody(emitter.body!);
    }

    setState(() {
      _emitters.remove(emitter);
    });
  }

  void _updatePhysics() {
    if (!mounted) return;

    // Step the physics simulation
    _world.stepDt(1 / 60); // 60fps

    // Update emitter positions from physics bodies
    for (final emitter in _emitters) {
      if (emitter.body != null) {
        final bodyPosition = emitter.body!.position;
        emitter.position = Offset(
          bodyPosition.x * _worldScale,
          bodyPosition.y * _worldScale,
        );
      }

      // Emit waves at regular intervals
      emitter.timeSinceLastEmission += 1 / 60;
      if (emitter.timeSinceLastEmission >= 1 / emitter.frequency) {
        _emitWave(emitter);
        emitter.timeSinceLastEmission = 0;
      }
    }

    // Update wave propagation
    setState(() {
      // Update existing waves
      for (int i = _waves.length - 1; i >= 0; i--) {
        final wave = _waves[i];
        wave.radius += wave.speed;
        wave.opacity -= 0.005;

        // Check collision with obstacles
        for (final obstacle in _obstacles) {
          final distance = (obstacle.position - wave.position).distance;
          final collisionDistance = obstacle.radius + wave.radius;

          if (distance <= collisionDistance && !wave.collidedObstacles.contains(obstacle)) {
            wave.collidedObstacles.add(obstacle);

            if (obstacle.reflective) {
              // Create reflected wave
              _waves.add(ColorWave(
                position: obstacle.position,
                color: _mixColors([wave.color, obstacle.color]),
                radius: 5.0,
                speed: wave.speed * 0.9,
                opacity: wave.opacity * 0.9,
                collidedObstacles: [...wave.collidedObstacles],
              ));
            }

            if (obstacle.absorptive) {
              // Reduce wave speed and opacity
              wave.speed *= 0.7;
              wave.opacity *= 0.7;
            }
          }
        }

        // Check collision with other waves
        for (int j = i - 1; j >= 0; j--) {
          final otherWave = _waves[j];
          final distance = (otherWave.position - wave.position).distance;
          final collisionDistance = otherWave.radius + wave.radius;

          if (distance <= collisionDistance &&
              !wave.collidedWaves.contains(otherWave) &&
              !otherWave.collidedWaves.contains(wave)) {
            wave.collidedWaves.add(otherWave);
            otherWave.collidedWaves.add(wave);

            // Create interference wave at the collision point
            final collisionVector = otherWave.position - wave.position;
            final collisionPoint = wave.position + collisionVector * (wave.radius / collisionDistance);

            // Mix the colors
            final mixedColor = _mixColors([wave.color, otherWave.color]);

            // _waves.add(ColorWave(
            //   position: collisionPoint,
            //   color: mixedColor,
            //   radius: 5.0,
            //   speed: (wave.speed + otherWave.speed) / 2,
            //   opacity: (wave.opacity + otherWave.opacity) / 2,
            // ));
          }
        }

        // Remove faded waves
        if (wave.opacity <= 0) {
          _waves.removeAt(i);
        }
      }

      // Update particles
      for (int i = _particles.length - 1; i >= 0; i--) {
        final particle = _particles[i];
        particle.distance += particle.velocity;
        particle.opacity = 1.0 - (particle.distance / particle.maxDistance);

        if (particle.distance >= particle.maxDistance) {
          _particles.removeAt(i);
        }
      }
    });

    // Calculate mixed color
    _calculateMixedColor();
  }

  void _emitWave(WaveEmitter emitter) {
    final wave = ColorWave(
      position: emitter.position,
      color: emitter.color,
      radius: emitter.radius / 2,
      speed: 2.0,
      opacity: 0.7,
    );

    setState(() {
      _waves.add(wave);
    });
  }

  void _calculateMixedColor() {
    if (_waves.isEmpty) {
      _currentMixedColor = Colors.white;
      _similarity = 0.0;
      widget.onColorMixed(_currentMixedColor);
      return;
    }

    // Calculate the average color of all waves
    // Weighted by opacity to give prominence to more visible waves
    double totalWeight = 0;
    double r = 0, g = 0, b = 0;

    for (final wave in _waves) {
      final weight = wave.opacity;
      totalWeight += weight;

      r += wave.color.red * weight;
      g += wave.color.green * weight;
      b += wave.color.blue * weight;
    }

    if (totalWeight > 0) {
      r /= totalWeight;
      g /= totalWeight;
      b /= totalWeight;
    }

    final mixedColor = Color.fromRGBO(
      r.toInt().clamp(0, 255),
      g.toInt().clamp(0, 255),
      b.toInt().clamp(0, 255),
      1.0,
    );

    _currentMixedColor = mixedColor;
    widget.onColorMixed(mixedColor);

    // Calculate similarity to target
    _similarity = _calculateColorSimilarity(mixedColor, widget.targetColor);

    // Progress tutorial if needed
    if (_showTutorial && _tutorialStep == 1 && _similarity >= 0.7) {
      _showTutorialStep(2);
    }
  }

  Color _mixColors(List<Color> colors) {
    return ColorMixer.mixSubtractive(colors);
  }

  double _calculateColorSimilarity(Color a, Color b) {
    // Calculate color similarity (normalized between 0 and 1)
    final dr = (a.red - b.red) / 255.0;
    final dg = (a.green - b.green) / 255.0;
    final db = (a.blue - b.blue) / 255.0;

    // Human eyes are more sensitive to green, less to blue
    final distance = (dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11);

    return (1.0 - sqrt(distance)).clamp(0.0, 1.0);
  }

  void _handleColorSelect(Color color) {
    setState(() {
      _selectedColor = color;
      _isPlacing = true;
      _placementPosition = null;
    });
  }

  void _handlePanStart(DragStartDetails details) {
    if (!_isPlacing || _selectedColor == null) return;

    setState(() {
      _placementPosition = details.localPosition;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isPlacing || _selectedColor == null) return;

    setState(() {
      _placementPosition = details.localPosition;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isPlacing || _selectedColor == null || _placementPosition == null) return;

    // Check if placement is valid (not overlapping with existing emitters)
    bool isValidPlacement = true;
    for (final emitter in _emitters) {
      final distance = (_placementPosition! - emitter.position).distance;
      if (distance < emitter.radius * 2) {
        isValidPlacement = false;
        break;
      }
    }

    if (isValidPlacement) {
      _addEmitter(
        position: _placementPosition!,
        color: _selectedColor!,
      );
    }

    setState(() {
      _isPlacing = false;
      _selectedColor = null;
      _placementPosition = null;
    });
  }

  void _showTutorialStep(int step) {
    setState(() {
      _tutorialStep = step;
    });

    // Auto advance tutorial after delay
    if (step < 3) {
      Future.delayed(Duration(seconds: step == 0 ? 5 : 6), () {
        if (mounted && _showTutorial && _tutorialStep == step) {
          // Auto advance to next step if user hasn't progressed already
          if (step == 2) {
            _showTutorialStep(3);
            // End tutorial after last step
            Future.delayed(const Duration(seconds: 4), () {
              if (mounted && _showTutorial) {
                setState(() {
                  _showTutorial = false;
                });
              }
            });
          }
        }
      });
    }
  }

  LevelConfig _getLevelConfig(int level) {
    // Screen measurements are determined at build time
    final screenWidth = _canvasSize.width > 0 ? _canvasSize.width : 360;
    final screenHeight = _canvasSize.height > 0 ? _canvasSize.height : 600;

    final centerX = screenWidth / 2;
    final centerY = screenHeight / 2;

    switch (level) {
      case 1:
        return LevelConfig(
          difficulty: 'Beginner',
          description: 'Create your first wave interference pattern',
          initialEmitters: [
            EmitterConfig(
              position: Offset(centerX - 80, centerY + 50),
              color: Colors.red,
              fixed: true,
            ),
          ],
          obstacles: [],
        );

      case 2:
        return LevelConfig(
          difficulty: 'Beginner',
          description: 'Mix primary colors to create secondary colors',
          initialEmitters: [
            EmitterConfig(
              position: Offset(centerX - 100, centerY + 50),
              color: Colors.red,
              fixed: true,
            ),
            EmitterConfig(
              position: Offset(centerX + 100, centerY + 50),
              color: Colors.blue,
              fixed: true,
            ),
          ],
          obstacles: [],
        );

      case 3:
        return LevelConfig(
          difficulty: 'Beginner',
          description: 'Try adding a reflective obstacle',
          initialEmitters: [
            EmitterConfig(
              position: Offset(centerX - 120, centerY + 80),
              color: Colors.red,
              fixed: true,
            ),
          ],
          obstacles: [
            ObstacleConfig(
              position: Offset(centerX, centerY - 50),
              radius: 30,
              reflective: true,
              absorptive: false,
              color: Colors.white.withOpacity(0.7),
            ),
          ],
        );

      case 4:
        return LevelConfig(
          difficulty: 'Intermediate',
          description: 'Create a complex wave pattern with multiple emitters',
          initialEmitters: [],
          obstacles: [
            ObstacleConfig(
              position: Offset(centerX, centerY),
              radius: 35,
              reflective: true,
              absorptive: false,
              color: Colors.white.withOpacity(0.5),
            ),
            ObstacleConfig(
              position: Offset(centerX - 150, centerY - 80),
              radius: 25,
              reflective: false,
              absorptive: true,
              color: Colors.black.withOpacity(0.3),
            ),
            ObstacleConfig(
              position: Offset(centerX + 150, centerY - 80),
              radius: 25,
              reflective: false,
              absorptive: true,
              color: Colors.black.withOpacity(0.3),
            ),
          ],
        );

      case 5:
        return LevelConfig(
          difficulty: 'Intermediate',
          description: 'Navigate waves through an obstacle course',
          initialEmitters: [
            EmitterConfig(
              position: Offset(60, 60),
              color: Colors.red,
              fixed: true,
            ),
            EmitterConfig(
              position: Offset(screenWidth - 60, 60),
              color: Colors.blue,
              fixed: true,
            ),
          ],
          obstacles: [
            // Create a path of obstacles through the center
            for (int i = 0; i < 5; i++)
              ObstacleConfig(
                position: Offset(centerX, centerY - 100 + i * 50),
                radius: 20,
                reflective: i % 2 == 0,
                absorptive: i % 2 == 1,
                color: i % 2 == 0 ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.3),
              ),
          ],
        );

      case 6:
        return LevelConfig(
          difficulty: 'Advanced',
          description: 'Create harmony with reflection and absorption',
          initialEmitters: [
            EmitterConfig(
              position: Offset(60, centerY),
              color: Colors.red,
              fixed: true,
            ),
            EmitterConfig(
              position: Offset(screenWidth - 60, centerY),
              color: Colors.blue,
              fixed: true,
            ),
          ],
          obstacles: [
            // Create a circular arrangement of obstacles
            for (int i = 0; i < 8; i++)
              ObstacleConfig(
                position: Offset(
                  centerX + cos(i * pi / 4) * 100,
                  centerY + sin(i * pi / 4) * 100,
                ),
                radius: 20,
                reflective: i % 2 == 0,
                absorptive: i % 2 == 1,
                color: i % 2 == 0 ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.3),
              ),

            // Center obstacle
            ObstacleConfig(
              position: Offset(centerX, centerY),
              radius: 40,
              reflective: true,
              absorptive: false,
              color: Colors.amber.withOpacity(0.3),
            ),
          ],
        );

      case 7:
        return LevelConfig(
          difficulty: 'Advanced',
          description: 'Use color subtraction through absorptive obstacles',
          initialEmitters: [
            EmitterConfig(
              position: Offset(60, 60),
              color: Colors.white,
              fixed: true,
            ),
          ],
          obstacles: [
            // Color-filtering obstacles
            ObstacleConfig(
              position: Offset(centerX - 80, centerY),
              radius: 30,
              reflective: false,
              absorptive: true,
              color: Colors.red.withOpacity(0.5),
            ),
            ObstacleConfig(
              position: Offset(centerX + 80, centerY),
              radius: 30,
              reflective: false,
              absorptive: true,
              color: Colors.blue.withOpacity(0.5),
            ),
            ObstacleConfig(
              position: Offset(centerX, centerY + 80),
              radius: 30,
              reflective: false,
              absorptive: true,
              color: Colors.green.withOpacity(0.5),
            ),
            // Target zone
            ObstacleConfig(
              position: Offset(centerX, centerY - 80),
              radius: 40,
              reflective: true,
              absorptive: false,
              color: Colors.white.withOpacity(0.3),
            ),
          ],
        );

      case 8:
        return LevelConfig(
          difficulty: 'Expert',
          description: 'Create a complex harmonic pattern',
          initialEmitters: [],
          obstacles: [
            // Spiral pattern of obstacles
            for (int i = 0; i < 12; i++)
              ObstacleConfig(
                position: Offset(
                  centerX + cos(i * pi / 6) * (50 + i * 10),
                  centerY + sin(i * pi / 6) * (50 + i * 10),
                ),
                radius: 15 + (i % 3) * 5,
                reflective: i % 3 == 0,
                absorptive: i % 3 == 1,
                color: i % 3 == 0
                    ? Colors.white.withOpacity(0.6)
                    : i % 3 == 1
                        ? Colors.black.withOpacity(0.3)
                        : Colors.amber.withOpacity(0.4),
              ),
          ],
        );

      case 9:
        return LevelConfig(
          difficulty: 'Expert',
          description: 'Master wave interference in a complex environment',
          initialEmitters: [
            EmitterConfig(
              position: Offset(60, 60),
              color: Colors.red,
              fixed: true,
            ),
            EmitterConfig(
              position: Offset(screenWidth - 60, 60),
              color: Colors.blue,
              fixed: true,
            ),
            EmitterConfig(
              position: Offset(60, screenHeight - 60),
              color: Colors.green,
              fixed: true,
            ),
            EmitterConfig(
              position: Offset(screenWidth - 60, screenHeight - 60),
              color: Colors.yellow,
              fixed: true,
            ),
          ],
          obstacles: [
            // Complex pattern of obstacles
            ObstacleConfig(
              position: Offset(centerX, centerY),
              radius: 50,
              reflective: true,
              absorptive: false,
              color: Colors.white.withOpacity(0.5),
            ),
            for (int i = 0; i < 8; i++)
              ObstacleConfig(
                position: Offset(
                  centerX + cos(i * pi / 4) * 150,
                  centerY + sin(i * pi / 4) * 150,
                ),
                radius: 25,
                reflective: i % 2 == 0,
                absorptive: i % 2 == 1,
                color: i % 2 == 0 ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.2),
              ),
          ],
        );

      case 10:
        return LevelConfig(
          difficulty: 'Expert',
          description: 'The ultimate wave challenge',
          initialEmitters: [],
          obstacles: [
            // Center obstacle
            ObstacleConfig(
              position: Offset(centerX, centerY),
              radius: 60,
              reflective: true,
              absorptive: false,
              color: Colors.amber.withOpacity(0.3),
            ),
            // Surrounding obstacles in a pattern
            for (int ring = 0; ring < 2; ring++)
              for (int i = 0; i < 12; i++)
                ObstacleConfig(
                  position: Offset(
                    centerX + cos(i * pi / 6) * (150 + ring * 80),
                    centerY + sin(i * pi / 6) * (150 + ring * 80),
                  ),
                  radius: 20 - ring * 5,
                  reflective: (i + ring) % 3 == 0,
                  absorptive: (i + ring) % 3 == 1,
                  color: (i + ring) % 3 == 0
                      ? Colors.white.withOpacity(0.5)
                      : (i + ring) % 3 == 1
                          ? Colors.black.withOpacity(0.3)
                          : HSVColor.fromAHSV(0.5, (i * 30) % 360, 0.8, 0.8).toColor(),
                ),
          ],
        );

      default:
        // For higher levels, create procedurally generated challenges
        final obstacleCount = min(10 + (level - 10) * 2, 30);
        final List<ObstacleConfig> obstacles = [];

        // Add center obstacle
        obstacles.add(
          ObstacleConfig(
            position: Offset(centerX, centerY),
            radius: 40 + (_random.nextDouble() * 20),
            reflective: _random.nextBool(),
            absorptive: !_random.nextBool(),
            color: HSVColor.fromAHSV(0.5, _random.nextDouble() * 360, 0.7, 0.7).toColor(),
          ),
        );

        // Add random obstacles
        for (int i = 0; i < obstacleCount; i++) {
          final angle = _random.nextDouble() * pi * 2;
          final distance = 80 + _random.nextDouble() * (screenWidth / 2 - 100);

          obstacles.add(
            ObstacleConfig(
              position: Offset(
                centerX + cos(angle) * distance,
                centerY + sin(angle) * distance,
              ),
              radius: 15 + _random.nextDouble() * 20,
              reflective: _random.nextDouble() > 0.6,
              absorptive: _random.nextDouble() > 0.6,
              color: HSVColor.fromAHSV(
                0.5,
                _random.nextDouble() * 360,
                0.7,
                0.7,
              ).toColor(),
            ),
          );
        }

        return LevelConfig(
          difficulty: 'Procedural',
          description: 'Level $level: Mastery challenge',
          initialEmitters: [],
          obstacles: obstacles,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Store canvas size for physics calculations
        _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          child: Stack(
            children: [
              // Background
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _backgroundController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: WaveBackgroundPainter(
                        animation: _backgroundController.value,
                        baseColor: _currentMixedColor,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),

              // Waves
              ..._waves.map((wave) {
                return Positioned(
                  left: wave.position.dx - wave.radius,
                  top: wave.position.dy - wave.radius,
                  width: wave.radius * 2,
                  height: wave.radius * 2,
                  child: Opacity(
                    opacity: wave.opacity,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: wave.color,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Obstacles
              ..._obstacles.map((obstacle) {
                return Positioned(
                  left: obstacle.position.dx - obstacle.radius,
                  top: obstacle.position.dy - obstacle.radius,
                  width: obstacle.radius * 2,
                  height: obstacle.radius * 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: obstacle.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: obstacle.reflective ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: obstacle.reflective ? 2 : 0,
                        ),
                      ],
                      border: Border.all(
                        color: obstacle.reflective ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        obstacle.reflective ? Icons.blur_on : Icons.blur_circular,
                        color: obstacle.reflective ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.5),
                        size: obstacle.radius * 0.8,
                      ),
                    ),
                  ),
                );
              }),

              // Emitters
              ..._emitters.map((emitter) {
                return Positioned(
                  left: emitter.position.dx - emitter.radius,
                  top: emitter.position.dy - emitter.radius,
                  width: emitter.radius * 2,
                  height: emitter.radius * 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: emitter.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: emitter.color.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: emitter.radius * 0.5,
                        height: emitter.radius * 0.5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Ripple particles
              ..._particles.map((particle) {
                final position = particle.position +
                    Offset(
                      cos(particle.angle) * particle.distance,
                      sin(particle.angle) * particle.distance,
                    );

                return Positioned(
                  left: position.dx - particle.size / 2,
                  top: position.dy - particle.size / 2,
                  width: particle.size,
                  height: particle.size,
                  child: Opacity(
                    opacity: particle.opacity,
                    child: Container(
                      decoration: BoxDecoration(
                        color: particle.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),

              // Placement preview
              if (_isPlacing && _selectedColor != null && _placementPosition != null)
                Positioned(
                  left: _placementPosition!.dx - 20,
                  top: _placementPosition!.dy - 20,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _selectedColor!.withOpacity(0.7),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),

              // Tutorial overlay
              if (_showTutorial)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.7),
                    child: Center(
                      child: Container(
                        width: _canvasSize.width * 0.8,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade900,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.teal.shade300,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _tutorialStep == 0
                                  ? Icons.waves
                                  : _tutorialStep == 1
                                      ? Icons.touch_app
                                      : _tutorialStep == 2
                                          ? Icons.color_lens
                                          : Icons.check_circle,
                              color: Colors.teal.shade200,
                              size: 40,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _tutorialStep == 0
                                  ? 'Welcome to Color Waves!'
                                  : _tutorialStep == 1
                                      ? 'Create Wave Interactions'
                                      : _tutorialStep == 2
                                          ? 'Mix Colors with Waves'
                                          : 'Match the Target Color',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _tutorialStep == 0
                                  ? 'Select colors from the palette and place emitters on the canvas.'
                                  : _tutorialStep == 1
                                      ? 'Waves will propagate from emitters and interact when they collide.'
                                      : _tutorialStep == 2
                                          ? 'When waves interact, they create new colors. Try to match the target color.'
                                          : 'You\'ve got it! Keep experimenting with different placements to create beautiful patterns.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.teal.shade100,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _showTutorial = false;
                                });
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.teal.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Got it!'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A wave propagating from an emitter
class ColorWave {
  final Offset position;
  final Color color;
  double radius;
  double speed;
  double opacity;
  final List<Obstacle> collidedObstacles = [];
  final List<ColorWave> collidedWaves = [];

  ColorWave({
    required this.position,
    required this.color,
    required this.radius,
    required this.speed,
    required this.opacity,
    List<Obstacle>? collidedObstacles,
  }) {
    if (collidedObstacles != null) {
      this.collidedObstacles.addAll(collidedObstacles);
    }
  }
}

/// A wave emitter
class WaveEmitter {
  Offset position;
  final Color color;
  final double radius;
  final double frequency;
  double timeSinceLastEmission = 0;
  final bool fixed;
  Body? body;

  WaveEmitter({
    required this.position,
    required this.color,
    required this.radius,
    required this.frequency,
    required this.fixed,
    this.body,
  });
}

/// An obstacle that affects wave propagation
class Obstacle {
  final Offset position;
  final double radius;
  final bool reflective;
  final bool absorptive;
  final Color color;
  Body? body;

  Obstacle({
    required this.position,
    required this.radius,
    required this.reflective,
    required this.absorptive,
    required this.color,
    this.body,
  });
}

/// A particle used for visual effects
class WaveParticle {
  final Offset position;
  final double angle;
  double distance = 0;
  final double maxDistance;
  final double velocity;
  final Color color;
  final double size;
  double opacity = 1.0;

  WaveParticle({
    required this.position,
    required this.angle,
    required this.maxDistance,
    required this.velocity,
    required this.color,
    required this.size,
  });
}

/// Configuration for a level
class LevelConfig {
  final String difficulty;
  final String description;
  final List<EmitterConfig> initialEmitters;
  final List<ObstacleConfig> obstacles;

  LevelConfig({
    required this.difficulty,
    required this.description,
    required this.initialEmitters,
    required this.obstacles,
  });
}

/// Configuration for an emitter
class EmitterConfig {
  final Offset position;
  final Color color;
  final bool fixed;

  EmitterConfig({
    required this.position,
    required this.color,
    required this.fixed,
  });
}

/// Configuration for an obstacle
class ObstacleConfig {
  final Offset position;
  final double radius;
  final bool reflective;
  final bool absorptive;
  final Color color;

  ObstacleConfig({
    required this.position,
    required this.radius,
    required this.reflective,
    required this.absorptive,
    required this.color,
  });
}

/// Custom painter for the wave background
class WaveBackgroundPainter extends CustomPainter {
  final double animation;
  final Color baseColor;

  WaveBackgroundPainter({
    required this.animation,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Create gradient background
    final HSVColor hsvColor = HSVColor.fromColor(baseColor);
    final baseHue = hsvColor.hue;

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        HSVColor.fromAHSV(1.0, baseHue, 0.7, 0.3).toColor(),
        HSVColor.fromAHSV(1.0, (baseHue + 30) % 360, 0.8, 0.2).toColor(),
      ],
    );

    final rect = Rect.fromLTWH(0, 0, width, height);
    final paint = Paint()..shader = gradient.createShader(rect);

    canvas.drawRect(rect, paint);

    // Draw subtle wave patterns
    final wavePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // First wave
    final path1 = Path();
    path1.moveTo(0, height * 0.3);

    for (double x = 0; x <= width; x += 1) {
      final y = height * 0.3 + sin((x / width * 6 * pi) + (animation * 2 * pi)) * 20;
      path1.lineTo(x, y);
    }

    canvas.drawPath(path1, wavePaint);

    // Second wave
    final path2 = Path();
    path2.moveTo(0, height * 0.6);

    for (double x = 0; x <= width; x += 1) {
      final y = height * 0.6 + sin((x / width * 8 * pi) + (animation * 2 * pi * 1.5)) * 15;
      path2.lineTo(x, y);
    }

    canvas.drawPath(path2, wavePaint);

    // Add subtle particle effect
    final particlePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final random = Random(42); // Fixed seed for deterministic pattern

    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * width;
      final y = random.nextDouble() * height;
      final size = 1 + random.nextDouble() * 3;

      // Make particles move slightly with animation
      final offsetX = sin(animation * 2 * pi + i) * 5;
      final offsetY = cos(animation * 2 * pi + i) * 5;

      canvas.drawCircle(
        Offset(
          (x + offsetX) % width,
          (y + offsetY) % height,
        ),
        size,
        particlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveBackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.baseColor != baseColor;
  }
}
