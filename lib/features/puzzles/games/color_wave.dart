import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge2d/forge2d.dart' hide Transform;
import 'package:palette_master/core/color_models/color_mixer.dart';
import 'package:vibration/vibration.dart';

extension on Offset {
  Offset normalize() {
    final length = sqrt(dx * dx + dy * dy);
    return Offset(dx / length, dy / length);
  }
}

/// The main color wave game widget with enhanced visual effects and gameplay
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
  final List<CollisionEffect> _collisionEffects = [];
  final List<Obstacle> _obstacles = [];
  Color _currentMixedColor = Colors.white;
  double _similarity = 0.0;
  Color? _selectedColor;
  bool _isPlacing = false;
  Offset? _placementPosition;

  // Game mechanics
  int _combo = 0;
  int _comboTimer = 0;
  bool _isPowerUpActive = false;
  PowerUpType? _activePowerUp;
  final List<PowerUp> _availablePowerUps = [];

  // Canvas size
  Size _canvasSize = Size.zero;

  // Animation controllers
  late AnimationController _backgroundController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Random generator
  final Random _random = Random();

  // Tutorial state
  bool _showTutorial = true;
  int _tutorialStep = 0;

  // Performance management
  int _maxWaves = 100;
  bool _isLowPerformanceMode = false;
  int _frameSkip = 0;
  int _currentFrame = 0;

  // Level config
  late LevelConfig _levelConfig;

  // Hint system
  bool _showPlacementHints = true;
  List<PlacementHint> _placementHints = [];

  bool _isLowMemoryMode = false;
  int _frameCounter = 0;
  int _lastCleanupTime = 0;
  final int _cleanupInterval = 120; // Cleanup every 2 seconds at 60fps
  final int _maxParticles = 80;
  int _waveCreationThrottle = 0;
  bool _didShowPerformanceWarning = false;
  double _lastMemoryUsage = 0;
  final Map<String, int> _lastPositionHashes = {};

  @override
  void initState() {
    super.initState();

    _detectDeviceCapabilities();

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

    _waveController.repeat();

    // Determine performance mode based on level complexity
    _setPerformanceMode();

    // Initialize power-ups based on level
    _initPowerUps();

    // Generate placement hints
    _generatePlacementHints();

    // Set up initial emitters based on level
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLevel();

      // Start with tutorial for early levels
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
    _shakeController.dispose();
    super.dispose();
  }

  // Add a method to detect device capabilities:
  void _detectDeviceCapabilities() {
    // In a real implementation, you would check the device specs
    // For this example, we'll use a conservative approach

    // Lower performance for higher levels which have more objects
    if (widget.level > 8) {
      _isLowPerformanceMode = true;
      _maxWaves = 60;
      _frameSkip = 1;
    } else if (widget.level > 5) {
      // Medium performance mode
      _isLowPerformanceMode = false;
      _maxWaves = 80;
      _frameSkip = 0;
    } else {
      // Full performance for early levels
      _isLowPerformanceMode = false;
      _maxWaves = 100;
      _frameSkip = 0;
    }
  }

  void _monitorPerformance() {
    // Track frame rate
    _frameCounter++;
    if (_frameCounter % 60 == 0) {
      // Check memory growth rate - simplified example
      double estimatedMemory = _waves.length * 40 + _particles.length * 16 + _emitters.length * 60;
      double memoryGrowthRate = estimatedMemory - _lastMemoryUsage;
      _lastMemoryUsage = estimatedMemory;

      // Auto-enable low memory mode if memory growth is too rapid
      if (memoryGrowthRate > 1000 && _waves.length > 50 && !_isLowMemoryMode) {
        _isLowMemoryMode = true;
        _maxWaves = 40; // Reduce max waves in low memory mode

        // Remove some waves to free memory immediately
        if (_waves.length > _maxWaves) {
          _waves.removeRange(0, _waves.length - _maxWaves);
        }

        // Show performance warning if not shown before
        if (!_didShowPerformanceWarning && mounted) {
          _didShowPerformanceWarning = true;

          // Show a subtle performance warning
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Optimizing performance for smoother experience',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.teal.shade800,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    // Periodically clean up unused objects
    if (_frameCounter - _lastCleanupTime > _cleanupInterval) {
      _lastCleanupTime = _frameCounter;
      _cleanupUnusedObjects();
    }
  }

// Add this method to clean up unused objects:
  void _cleanupUnusedObjects() {
    // Remove distant, low-opacity waves
    _waves.removeWhere((wave) => wave.opacity < 0.1 && wave.radius > _canvasSize.width);

    // Limit particles
    if (_particles.length > _maxParticles) {
      // Remove oldest particles first
      _particles.removeRange(0, _particles.length - _maxParticles);
    }

    // Clean up collision effects that might have been missed
    _collisionEffects.removeWhere((effect) => effect.lifetime <= 0);

    // Force garbage collection by clearing and recreating certain data structures
    if (_isLowMemoryMode) {
      // Clear wave collision tracking which can grow large
      for (final wave in _waves) {
        if (wave.collidedWaves.length > 10) {
          wave.collidedWaves.clear();
        }
      }
    }
  }

  void _setPerformanceMode() {
    // Adjust performance parameters based on level complexity
    if (widget.level > 10) {
      _isLowPerformanceMode = true;
      _maxWaves = 60;
      _frameSkip = 1; // Process physics every other frame
    } else {
      _isLowPerformanceMode = false;
      _maxWaves = 100;
      _frameSkip = 0;
    }
  }

  void _initPowerUps() {
    // Clear existing power-ups
    _availablePowerUps.clear();

    // Add default power-ups
    _availablePowerUps.add(PowerUp(
      type: PowerUpType.speedBoost,
      name: 'Speed Boost',
      description: 'Increases wave propagation speed',
      icon: Icons.speed,
      color: Colors.amber,
    ));

    _availablePowerUps.add(PowerUp(
      type: PowerUpType.wideWaves,
      name: 'Wide Waves',
      description: 'Creates wider waves for better coverage',
      icon: Icons.waves,
      color: Colors.blue,
    ));

    // Add advanced power-ups for higher levels
    if (widget.level >= 5) {
      _availablePowerUps.add(PowerUp(
        type: PowerUpType.multiEmit,
        name: 'Multi-Emit',
        description: 'Emits multiple waves simultaneously',
        icon: Icons.grain,
        color: Colors.purple,
      ));
    }

    if (widget.level >= 8) {
      _availablePowerUps.add(PowerUp(
        type: PowerUpType.colorIntensity,
        name: 'Color Intensity',
        description: 'Increases color intensity for stronger mixing',
        icon: Icons.palette,
        color: Colors.green,
      ));
    }
  }

  void _generatePlacementHints() {
    _placementHints.clear();

    // Create hints based on level configuration and target color
    if (widget.level <= 3) {
      // For beginner levels, provide clear hints
      final center = Offset(_canvasSize.width / 2, _canvasSize.height / 2);

      // First hint - place a complementary color emitter opposite existing emitters
      if (_levelConfig.initialEmitters.isNotEmpty) {
        final existingEmitter = _levelConfig.initialEmitters.first;
        final existingColor = existingEmitter.color;
        final complementaryColor = ColorMixer.getComplementary(existingColor);

        // Find the closest available color to the complementary color
        Color closestColor = widget.availableColors.first;
        double minDistance = _calculateColorDistance(complementaryColor, closestColor);

        for (final color in widget.availableColors) {
          final distance = _calculateColorDistance(complementaryColor, color);
          if (distance < minDistance) {
            minDistance = distance;
            closestColor = color;
          }
        }

        // Position the hint opposite to the existing emitter
        final oppositePosition = Offset(
          center.dx * 2 - existingEmitter.position.dx,
          center.dy * 2 - existingEmitter.position.dy,
        );

        _placementHints.add(PlacementHint(
          position: oppositePosition,
          color: closestColor,
          radius: 30,
          pulsing: true,
        ));
      }
    } else if (widget.level <= 6) {
      // For intermediate levels, provide less explicit hints
      // Create a hint near a reflective obstacle if one exists
      for (final obstacle in _levelConfig.obstacles) {
        if (obstacle.reflective) {
          // Find a strategic position near the reflective obstacle
          final angle = _random.nextDouble() * 2 * pi;
          final distance = obstacle.radius * 2.5;
          final hintPosition = Offset(
            obstacle.position.dx + cos(angle) * distance,
            obstacle.position.dy + sin(angle) * distance,
          );

          // Choose a color that would help create the target color
          Color suggestedColor = _getSuggestedColor();

          _placementHints.add(PlacementHint(
            position: hintPosition,
            color: suggestedColor,
            radius: 25,
            pulsing: true,
          ));

          break;
        }
      }
    }
    // For advanced levels, let players figure it out themselves (no hints)
  }

  Color _getSuggestedColor() {
    // Logic to suggest a color that would help create the target color
    // For simplicity, we'll just return a color from available colors
    // In a more sophisticated implementation, this would analyze existing emitters
    // and suggest a color that would help achieve the target color
    return widget.availableColors[_random.nextInt(widget.availableColors.length)];
  }

  double _calculateColorDistance(Color a, Color b) {
    final dr = (a.red - b.red) / 255.0;
    final dg = (a.green - b.green) / 255.0;
    final db = (a.blue - b.blue) / 255.0;

    return sqrt(dr * dr + dg * dg + db * db);
  }

  void _initializeLevel() {
    if (!mounted) return;

    setState(() {
      _emitters.clear();
      _waves.clear();
      _particles.clear();
      _obstacles.clear();
      _collisionEffects.clear();
      _combo = 0;
      _comboTimer = 0;
      _isPowerUpActive = false;
      _activePowerUp = null;
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
    bool isPowerUp = false,
  }) {
    // Check if we're too close to another emitter
    for (final emitter in _emitters) {
      final distance = (position - emitter.position).distance;
      if (distance < emitter.radius * 1.5) {
        // Provide feedback that this is too close
        _createRippleEffect(position, Colors.red.withOpacity(0.5), isError: true);
        return;
      }
    }

    // Prevent too many emitters which hurt performance
    final maxEmitters = _isLowMemoryMode ? 5 : 8;
    if (_emitters.length >= maxEmitters) {
      // Remove the oldest non-fixed emitter
      for (int i = 0; i < _emitters.length; i++) {
        if (!_emitters[i].fixed) {
          if (_emitters[i].body != null) {
            _world.destroyBody(_emitters[i].body!);
          }
          _emitters.removeAt(i);
          break;
        }
      }

      // If we couldn't remove any (all fixed), show error feedback
      if (_emitters.length >= maxEmitters) {
        _createRippleEffect(position, Colors.red.withOpacity(0.5), isError: true);

        // Show message about too many emitters
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Maximum number of emitters reached',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // Create emitter with enhanced properties
    final emitter = WaveEmitter(
      position: position,
      color: color,
      radius: isPowerUp ? 25.0 : 20.0,
      frequency: 1.5 + (_random.nextDouble() * 0.5),
      fixed: fixed,
      isPowerUp: isPowerUp,
      // Add pulsing effect for more visual appeal
      pulseFactor: 1.0,
      pulseSpeed: 0.5 + _random.nextDouble() * 0.5,
    );

    if (!fixed) {
      _createEmitterBody(emitter);
    }

    setState(() {
      _emitters.add(emitter);
    });

    // Create enhanced ripple effect
    _createRippleEffect(position, color, particleCount: _isLowMemoryMode ? 8 : 16);

    // Provide stronger haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 30, amplitude: 60);
      }
    });

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

  void _createRippleEffect(Offset position, Color color, {bool isError = false, int? particleCount}) {
    // Use provided particle count or determine based on performance mode
    final count = particleCount ?? (_isLowMemoryMode ? 8 : (_isLowPerformanceMode ? 12 : 16));

    for (int i = 0; i < count; i++) {
      final angle = i * (2 * pi / count);
      final distance = 30.0 + _random.nextDouble() * 20.0;
      final velocity = 0.5 + _random.nextDouble() * 0.5;

      final particle = WaveParticle(
        position: position,
        angle: angle,
        maxDistance: distance,
        velocity: velocity,
        color: isError ? Colors.red.withOpacity(0.7) : color.withOpacity(0.7),
        size: 8.0 + _random.nextDouble() * 5.0,
        // Add glowing effect for better visual appeal, but not in low memory mode
        glowing: !_isLowMemoryMode,
      );

      setState(() {
        _particles.add(particle);
      });
    }

    // Add an expanding ring effect if not in low memory mode
    if (!_isLowMemoryMode) {
      setState(() {
        _particles.add(WaveParticle(
          position: position,
          angle: 0, // Not used for ring
          maxDistance: 60.0,
          velocity: 1.2,
          color: isError ? Colors.red.withOpacity(0.3) : color.withOpacity(0.3),
          size: 10.0,
          isRing: true,
        ));
      });
    }

    // Provide haptic feedback
    if (!isError) {
      Vibration.hasVibrator().then((hasVibrator) {
        if (hasVibrator ?? false) {
          Vibration.vibrate(duration: 20, amplitude: 40);
        }
      });
    } else {
      Vibration.hasVibrator().then((hasVibrator) {
        if (hasVibrator ?? false) {
          // Double pulse for error
          Vibration.vibrate(pattern: [0, 20, 30, 20]);
        }
      });
    }
  }

  // Add a new method to detect and handle memory pressure:
  void _checkMemoryPressure() {
    // This would be a more advanced implementation in a real app
    // For now, we'll use simple heuristics based on object counts

    if (_waves.length > 60 || _particles.length > 120 || _collisionEffects.length > 30) {
      // High memory pressure detected
      if (!_isLowMemoryMode) {
        setState(() {
          _isLowMemoryMode = true;
          _maxWaves = 40;
        });

        // Perform immediate memory cleanup
        _waves.removeWhere((wave) => wave.opacity < 0.3);
        if (_waves.length > _maxWaves) {
          _waves.removeRange(0, _waves.length - _maxWaves);
        }

        if (_particles.length > _maxParticles) {
          _particles.removeRange(0, _particles.length - _maxParticles);
        }

        // Clear collision effects
        _collisionEffects.clear();
      }
    } else if (_isLowMemoryMode && _waves.length < 20 && _particles.length < 40) {
      // Memory pressure reduced
      setState(() {
        _isLowMemoryMode = false;
        _maxWaves = _isLowPerformanceMode ? 60 : 100;
      });
    }
  }

  void _removeEmitter(WaveEmitter emitter) {
    if (emitter.body != null) {
      _world.destroyBody(emitter.body!);
    }

    setState(() {
      _emitters.remove(emitter);
    });
  }

  void _activatePowerUp(PowerUpType type) {
    setState(() {
      _isPowerUpActive = true;
      _activePowerUp = type;
    });

    // Power-up duration
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isPowerUpActive = false;
          _activePowerUp = null;
        });
      }
    });

    // Visual feedback for power-up activation
    final center = Offset(_canvasSize.width / 2, _canvasSize.height / 2);
    _createPowerUpActivationEffect(center, type);
  }

  void _createPowerUpActivationEffect(Offset position, PowerUpType type) {
    // Create particles in a spiral pattern
    final particleCount = 30;
    final Color powerUpColor;

    // Set color based on power-up type
    switch (type) {
      case PowerUpType.speedBoost:
        powerUpColor = Colors.amber;
        break;
      case PowerUpType.wideWaves:
        powerUpColor = Colors.blue;
        break;
      case PowerUpType.multiEmit:
        powerUpColor = Colors.purple;
        break;
      case PowerUpType.colorIntensity:
        powerUpColor = Colors.green;
        break;
    }

    for (int i = 0; i < particleCount; i++) {
      final progress = i / particleCount;
      final angle = progress * 4 * pi; // 2 full rotations
      final distance = progress * 150; // Spiral out to 150 pixels

      final particlePosition = Offset(
        position.dx + cos(angle) * distance,
        position.dy + sin(angle) * distance,
      );

      final particle = WaveParticle(
        position: particlePosition,
        angle: angle,
        maxDistance: 50 + _random.nextDouble() * 30,
        velocity: 0.8 + _random.nextDouble() * 0.4,
        color: powerUpColor.withOpacity(0.7),
        size: 10.0 + _random.nextDouble() * 8.0,
        glowing: true,
      );

      setState(() {
        _particles.add(particle);
      });
    }

    // Add expanding ring
    setState(() {
      _particles.add(WaveParticle(
        position: position,
        angle: 0,
        maxDistance: 200.0,
        velocity: 2.0,
        color: powerUpColor.withOpacity(0.3),
        size: 10.0,
        isRing: true,
      ));
    });

    // Screen shake effect
    _shakeController.forward(from: 0.0);

    // Haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 100, amplitude: 80);
      }
    });
  }

  void _updatePhysics() {
    if (!mounted) return;

    _monitorPerformance();

    // Skip frames if in low performance mode
    if (_isLowPerformanceMode) {
      _currentFrame = (_currentFrame + 1) % (_frameSkip + 1);
      if (_currentFrame != 0) return;
    }

    // Update combo timer
    if (_comboTimer > 0) {
      _comboTimer--;
      if (_comboTimer == 0) {
        setState(() {
          _combo = 0;
        });
      }
    }

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

      // Update pulsing effect
      emitter.pulsePhase += emitter.pulseSpeed / 60;
      emitter.currentPulseFactor = 1.0 + sin(emitter.pulsePhase * 2 * pi) * 0.1 * emitter.pulseFactor;

      // Emit waves at regular intervals
      emitter.timeSinceLastEmission += 1 / 60;
      final emitFrequency = _isPowerUpActive && _activePowerUp == PowerUpType.speedBoost
          ? emitter.frequency * 1.5 // Faster emission with speed boost
          : emitter.frequency;

      if (emitter.timeSinceLastEmission >= 1 / emitFrequency) {
        if (_isPowerUpActive && _activePowerUp == PowerUpType.multiEmit) {
          // Emit multiple waves with the multi-emit power-up
          for (int i = 0; i < 3; i++) {
            final angle = i * (2 * pi / 3);
            final offset = Offset(cos(angle) * 10, sin(angle) * 10);
            _emitWave(emitter, positionOffset: offset);
          }
        } else {
          _emitWave(emitter);
        }
        emitter.timeSinceLastEmission = 0;
      }
    }

    // Update wave propagation
    setState(() {
      // Limit total waves for performance
      while (_waves.length > _maxWaves) {
        _waves.removeAt(0);
      }

      // Update existing waves
      for (int i = _waves.length - 1; i >= 0; i--) {
        final wave = _waves[i];

        // Skip processing every few frames for older waves to improve performance
        if (_isLowMemoryMode && i < _waves.length / 2 && _frameCounter % 2 != 0) {
          continue;
        }

        // Adjust speed based on power-ups
        double speedMultiplier = 1.0;
        if (_isPowerUpActive) {
          if (_activePowerUp == PowerUpType.speedBoost) {
            speedMultiplier = 1.5;
          }
        }

        wave.radius += wave.speed * speedMultiplier;
        wave.opacity -= 0.005;

        // Apply color intensity power-up
        if (_isPowerUpActive && _activePowerUp == PowerUpType.colorIntensity) {
          // Make colors more vibrant with less opacity reduction
          wave.opacity = max(wave.opacity, wave.opacity + 0.002);
        }

        // Check collision with obstacles
        for (final obstacle in _obstacles) {
          final distance = (obstacle.position - wave.position).distance;
          final collisionDistance = obstacle.radius + wave.radius;

          if (distance <= collisionDistance && !wave.collidedObstacles.contains(obstacle)) {
            wave.collidedObstacles.add(obstacle);

            // Create collision effect
            _createCollisionEffect(wave, obstacle.position);

            if (obstacle.reflective) {
              // Create reflected wave with enhanced effects
              _waves.add(ColorWave(
                position: obstacle.position,
                color: _mixColors([wave.color, obstacle.color]),
                radius: 5.0,
                speed: wave.speed * 0.9,
                opacity: wave.opacity * 0.9,
                collidedObstacles: [...wave.collidedObstacles],
                glowing: true, // Add glow effect to reflected waves
              ));
            }

            if (obstacle.absorptive) {
              // Reduce wave speed and opacity
              wave.speed *= 0.7;
              wave.opacity *= 0.7;
            }
          }
        }

        // Check collision with other waves - improved collision detection
        for (int j = i - 1; j >= 0; j--) {
          final otherWave = _waves[j];

          final dx = (otherWave.position.dx - wave.position.dx).abs();
          final dy = (otherWave.position.dy - wave.position.dy).abs();

          // Skip if obviously too far apart (Manhattan distance)
          if (dx + dy > otherWave.radius + wave.radius + 10) {
            continue;
          }

          final distance = (otherWave.position - wave.position).distance;
          final collisionDistance = otherWave.radius + wave.radius;
          final radiiDifference = (otherWave.radius - wave.radius).abs();

          // Check if the wave fronts are actually intersecting (not just circles overlapping)
          if (distance <= collisionDistance &&
              distance >= collisionDistance - 4 && // Wave fronts are within 4px
              !wave.collidedWaves.contains(otherWave) &&
              !otherWave.collidedWaves.contains(wave)) {
            wave.collidedWaves.add(otherWave);
            otherWave.collidedWaves.add(wave);

            // Calculate collision point more accurately
            final direction = (otherWave.position - wave.position).normalize();
            final collisionPoint = wave.position + direction * wave.radius;

            // Create enhanced collision effect
            //  _createWaveCollisionEffect(wave, otherWave, collisionPoint);

            // Mix the colors with improved blending
            final mixedColor = _mixColors([wave.color, otherWave.color]);

            // Create a new wave at the collision point
            _waves.add(ColorWave(
              position: collisionPoint,
              color: mixedColor,
              radius: 5.0,
              speed: (wave.speed + otherWave.speed) / 2,
              opacity: (wave.opacity + otherWave.opacity) / 2,
              glowing: true, // Add glow effect for better visibility
            ));

            // Update combo system
            setState(() {
              _combo++;
              _comboTimer = 180; // 3 seconds at 60fps

              // Activate power-up at certain combo thresholds
              if (_combo == 5 && !_isPowerUpActive) {
                _activatePowerUp(PowerUpType.speedBoost);
              } else if (_combo == 10 && !_isPowerUpActive) {
                _activatePowerUp(PowerUpType.wideWaves);
              } else if (_combo == 15 && !_isPowerUpActive && widget.level >= 5) {
                _activatePowerUp(PowerUpType.multiEmit);
              } else if (_combo == 20 && !_isPowerUpActive && widget.level >= 8) {
                _activatePowerUp(PowerUpType.colorIntensity);
              }
            });
          }
        }

        // Remove faded waves
        if (wave.opacity <= 0) {
          _waves.removeAt(i);
        }
      }

      // Update collision effects
      for (int i = _collisionEffects.length - 1; i >= 0; i--) {
        final effect = _collisionEffects[i];
        effect.lifetime -= 1;
        effect.radius += 0.5;

        if (effect.lifetime <= 0) {
          _collisionEffects.removeAt(i);
        }
      }

      // Update particles with enhanced effects
      for (int i = _particles.length - 1; i >= 0; i--) {
        final particle = _particles[i];

        if (particle.isRing) {
          // Update expanding ring
          particle.ringRadius = particle.distance;
          particle.ringWidth = max(1.0, 10.0 * (1 - particle.distance / particle.maxDistance));
        } else {
          // Update normal particle
          particle.position = particle.initialPosition +
              Offset(
                cos(particle.angle) * particle.distance,
                sin(particle.angle) * particle.distance,
              );
        }

        particle.distance += particle.velocity;
        particle.opacity = 1.0 - (particle.distance / particle.maxDistance);

        if (particle.distance >= particle.maxDistance) {
          _particles.removeAt(i);
        }
      }
    });

    // Calculate mixed color with improved algorithm
    _calculateMixedColor();
  }

  void _emitWave(WaveEmitter emitter, {Offset? positionOffset}) {
    // Limit total waves for performance
    if (_waves.length >= _maxWaves) {
      // Only allow new waves every few frames when near max capacity
      if (_waves.length >= _maxWaves * 0.9) {
        _waveCreationThrottle++;
        if (_waveCreationThrottle % 3 != 0) {
          return; // Skip wave creation this frame
        }
      }

      // Remove oldest wave to make room for new one
      _waves.removeAt(0);
    }

    // Prevent creating waves at nearly identical positions too frequently
    final position = positionOffset != null ? emitter.position + positionOffset : emitter.position;

    final positionHash = '${(position.dx / 5).round()}_${(position.dy / 5).round()}';
    if (_lastPositionHashes.containsKey(positionHash) && _frameCounter - _lastPositionHashes[positionHash]! < 15) {
      // Too many waves at nearly the same position, skip creating another
      return;
    }
    _lastPositionHashes[positionHash] = _frameCounter;

    // Apply wide waves power-up
    final baseRadius = _isPowerUpActive && _activePowerUp == PowerUpType.wideWaves
        ? emitter.radius * 0.7 // Wider base radius
        : emitter.radius * 0.5;

    // Apply color intensity power-up
    final baseOpacity = _isPowerUpActive && _activePowerUp == PowerUpType.colorIntensity
        ? 0.85 // Higher opacity for more intense colors
        : 0.7;

    final wave = ColorWave(
      position: position,
      color: emitter.color,
      radius: baseRadius,
      speed: 2.0,
      opacity: baseOpacity,
      glowing: emitter.isPowerUp, // Power-up emitters create glowing waves
    );

    setState(() {
      _waves.add(wave);
    });
  }

  void _createCollisionEffect(ColorWave wave, Offset position) {
    // Create a visually appealing collision effect
    final effect = CollisionEffect(
      position: position,
      color: wave.color,
      radius: 5.0,
      lifetime: 20, // 20 frames
    );

    setState(() {
      _collisionEffects.add(effect);
    });

    // Create particles for more visual impact
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4;

      setState(() {
        _particles.add(WaveParticle(
          position: position,
          angle: angle,
          maxDistance: 20.0 + _random.nextDouble() * 10.0,
          velocity: 0.7 + _random.nextDouble() * 0.5,
          color: wave.color.withOpacity(0.6),
          size: 5.0 + _random.nextDouble() * 3.0,
          glowing: true,
        ));
      });
    }
  }

  void _createWaveCollisionEffect(ColorWave wave1, ColorWave wave2, Offset position) {
    // Create a more dramatic effect when waves collide
    final mixedColor = _mixColors([wave1.color, wave2.color]);

    final effect = CollisionEffect(
      position: position,
      color: mixedColor,
      radius: 8.0,
      lifetime: 30, // Longer lifetime for wave collisions
    );

    setState(() {
      _collisionEffects.add(effect);
    });

    // Create more particles for wave collisions
    for (int i = 0; i < 12; i++) {
      final angle = i * pi / 6;

      _particles.add(WaveParticle(
        position: position,
        angle: angle,
        maxDistance: 30.0 + _random.nextDouble() * 15.0,
        velocity: 0.8 + _random.nextDouble() * 0.7,
        color: mixedColor.withOpacity(0.7),
        size: 6.0 + _random.nextDouble() * 4.0,
        glowing: true,
      ));
    }

    setState(() {});

    // Add expanding ring effect
    setState(() {
      _particles.add(WaveParticle(
        position: position,
        angle: 0,
        maxDistance: 40.0,
        velocity: 1.0,
        color: mixedColor.withOpacity(0.3),
        size: 5.0,
        isRing: true,
      ));
    });
  }

  void _calculateMixedColor() {
    if (_waves.isEmpty) {
      _currentMixedColor = Colors.white;
      _similarity = 0.0;
      widget.onColorMixed(_currentMixedColor);
      return;
    }

    // Improved color mixing with emphasis on wave interactions
    double totalWeight = 0;
    double r = 0, g = 0, b = 0;

    for (final wave in _waves) {
      // Use both opacity and radius for weighting to give more importance to larger waves
      final weight = wave.opacity * (wave.radius / 100).clamp(0.1, 2.0);
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

    // Apply color intensity power-up
    if (_isPowerUpActive && _activePowerUp == PowerUpType.colorIntensity) {
      // Enhance color saturation while preserving relative RGB values
      final hsv = HSVColor.fromColor(Color.fromRGBO(
        r.toInt().clamp(0, 255),
        g.toInt().clamp(0, 255),
        b.toInt().clamp(0, 255),
        1.0,
      ));

      final enhancedHsv = HSVColor.fromAHSV(
        hsv.alpha,
        hsv.hue,
        (hsv.saturation * 1.3).clamp(0.0, 1.0), // Increase saturation
        hsv.value,
      );

      final enhancedColor = enhancedHsv.toColor();

      r = enhancedColor.red.toDouble();
      g = enhancedColor.green.toDouble();
      b = enhancedColor.blue.toDouble();
    }

    final mixedColor = Color.fromRGBO(
      r.toInt().clamp(0, 255),
      g.toInt().clamp(0, 255),
      b.toInt().clamp(0, 255),
      1.0,
    );

    _currentMixedColor = mixedColor;
    widget.onColorMixed(mixedColor);

    // Calculate similarity to target using improved algorithm
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
    // Improved color similarity calculation using weighted RGB differences
    // Human eyes are more sensitive to green, less to blue
    final dr = (a.red - b.red) / 255.0;
    final dg = (a.green - b.green) / 255.0;
    final db = (a.blue - b.blue) / 255.0;

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
      if (distance < emitter.radius * 1.5) {
        isValidPlacement = false;
        break;
      }
    }

    // Check if placement is within canvas bounds with some margin
    final margin = 20.0;
    if (_placementPosition!.dx < margin ||
        _placementPosition!.dx > _canvasSize.width - margin ||
        _placementPosition!.dy < margin ||
        _placementPosition!.dy > _canvasSize.height - margin) {
      isValidPlacement = false;
    }

    if (isValidPlacement) {
      _addEmitter(
        position: _placementPosition!,
        color: _selectedColor!,
      );
    } else {
      // Visual feedback for invalid placement
      _createRippleEffect(_placementPosition!, Colors.red.withOpacity(0.7), isError: true);
    }

    setState(() {
      _isPlacing = false;
      _placementPosition = null;
    });

    // Reset selected color in parent
    widget.selectedColorNotifier.value = null;
  }

  void _showTutorialStep(int step) {
    setState(() {
      _tutorialStep = step;
      _showTutorial = true;
    });

    // Auto advance tutorial after delay
    if (step < 3) {
      Future.delayed(Duration(seconds: step == 0 ? 6 : 7), () {
        if (mounted && _showTutorial && _tutorialStep == step) {
          // Auto advance to next step if user hasn't progressed already
          if (step == 2) {
            _showTutorialStep(3);
            // End tutorial after last step
            Future.delayed(const Duration(seconds: 5), () {
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

        // Add random obstacles with deliberate patterns
        final patternType = _random.nextInt(3);

        if (patternType == 0) {
          // Circular pattern
          for (int i = 0; i < obstacleCount; i++) {
            final angle = i * (2 * pi / obstacleCount);
            final distance = 80 + _random.nextDouble() * (screenWidth / 3);

            obstacles.add(
              ObstacleConfig(
                position: Offset(
                  centerX + cos(angle) * distance,
                  centerY + sin(angle) * distance,
                ),
                radius: 15 + _random.nextDouble() * 20,
                reflective: _random.nextDouble() > 0.5,
                absorptive: _random.nextDouble() > 0.5,
                color: HSVColor.fromAHSV(
                  0.5,
                  (i * 30) % 360, // Color based on position in the circle
                  0.7,
                  0.7,
                ).toColor(),
              ),
            );
          }
        } else if (patternType == 1) {
          // Grid pattern
          final rows = sqrt(obstacleCount).ceil();
          final cols = (obstacleCount / rows).ceil();
          final cellWidth = screenWidth * 0.8 / cols;
          final cellHeight = screenHeight * 0.8 / rows;
          final startX = centerX - (cellWidth * cols / 2) + cellWidth / 2;
          final startY = centerY - (cellHeight * rows / 2) + cellHeight / 2;

          int count = 0;
          for (int r = 0; r < rows && count < obstacleCount; r++) {
            for (int c = 0; c < cols && count < obstacleCount; c++) {
              // Skip some grid positions randomly
              if (_random.nextDouble() < 0.3) continue;

              obstacles.add(
                ObstacleConfig(
                  position: Offset(
                    startX + c * cellWidth + _random.nextDouble() * 20 - 10,
                    startY + r * cellHeight + _random.nextDouble() * 20 - 10,
                  ),
                  radius: 15 + _random.nextDouble() * 15,
                  reflective: (r + c) % 3 == 0,
                  absorptive: (r + c) % 3 == 1,
                  color: HSVColor.fromAHSV(
                    0.5,
                    ((r * cols + c) * 20) % 360,
                    0.7,
                    0.7,
                  ).toColor(),
                ),
              );
              count++;
            }
          }
        } else {
          // Spiral pattern
          for (int i = 0; i < obstacleCount; i++) {
            final t = i / obstacleCount * 6 * pi; // 3 rotations
            final distance = 30 + t * 10;

            obstacles.add(
              ObstacleConfig(
                position: Offset(
                  centerX + cos(t) * distance,
                  centerY + sin(t) * distance,
                ),
                radius: 15 + _random.nextDouble() * 10,
                reflective: i % 3 == 0,
                absorptive: i % 3 == 1,
                color: HSVColor.fromAHSV(
                  0.5,
                  (i * 15) % 360,
                  0.7,
                  0.7,
                ).toColor(),
              ),
            );
          }
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

        return AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            // Apply screen shake effect
            return Transform.translate(
              offset: _shakeController.isAnimating
                  ? Offset(_shakeAnimation.value * 5, _shakeAnimation.value * 3)
                  : Offset.zero,
              child: GestureDetector(
                onPanStart: _handlePanStart,
                onPanUpdate: _handlePanUpdate,
                onPanEnd: _handlePanEnd,
                child: Stack(
                  children: [
                    // Background with animated gradient
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _backgroundController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: WaveBackgroundPainter(
                              animation: _backgroundController.value,
                              baseColor: _currentMixedColor,
                              targetColor: widget.targetColor,
                              similarity: _similarity,
                            ),
                            size: Size.infinite,
                          );
                        },
                      ),
                    ),

                    // Placement hints
                    if (_showPlacementHints)
                      ..._placementHints.map((hint) {
                        return Positioned(
                          left: hint.position.dx - hint.radius,
                          top: hint.position.dy - hint.radius,
                          width: hint.radius * 2,
                          height: hint.radius * 2,
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              final scale = hint.pulsing ? _pulseAnimation.value : 1.0;
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: hint.color.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: hint.color.withOpacity(0.5),
                                      width: 2,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.add,
                                      color: hint.color.withOpacity(0.7),
                                      size: hint.radius * 0.7,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),

                    // Collision effects - rendered below waves
                    ..._collisionEffects.map((effect) {
                      return Positioned(
                        left: effect.position.dx - effect.radius,
                        top: effect.position.dy - effect.radius,
                        width: effect.radius * 2,
                        height: effect.radius * 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: effect.color.withOpacity(0.3),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: effect.color.withOpacity(0.5),
                                blurRadius: effect.radius,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Waves
                    ..._waves.map((wave) {
                      return Positioned(
                        left: wave.position.dx - wave.radius,
                        top: wave.position.dy - wave.radius,
                        width: wave.radius * 2,
                        height: wave.radius * 2,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: wave.color.withOpacity(wave.opacity),
                              width: 2,
                            ),
                            boxShadow: wave.glowing
                                ? [
                                    BoxShadow(
                                      color: wave.color.withOpacity(wave.opacity * 0.5),
                                      blurRadius: 5,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }),

                    // Obstacles with improved visuals
                    ..._obstacles.map((obstacle) {
                      return Positioned(
                        left: obstacle.position.dx - obstacle.radius,
                        top: obstacle.position.dy - obstacle.radius,
                        width: obstacle.radius * 2,
                        height: obstacle.radius * 2,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            // Apply subtle pulse to reflective obstacles
                            final scale =
                                obstacle.reflective ? 1.0 + sin(_backgroundController.value * 4 * pi) * 0.05 : 1.0;

                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: obstacle.color,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: obstacle.reflective
                                          ? Colors.white.withOpacity(0.5)
                                          : Colors.black.withOpacity(0.3),
                                      blurRadius: obstacle.reflective ? 10 : 5,
                                      spreadRadius: obstacle.reflective ? 2 : 0,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: obstacle.reflective
                                        ? Colors.white.withOpacity(0.8)
                                        : Colors.black.withOpacity(0.5),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    obstacle.reflective ? Icons.blur_on : Icons.blur_circular,
                                    color: obstacle.reflective
                                        ? Colors.white.withOpacity(0.8)
                                        : Colors.black.withOpacity(0.5),
                                    size: obstacle.radius * 0.8,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),

                    // Emitters with pulsing effect
                    ..._emitters.map((emitter) {
                      return Positioned(
                        left: emitter.position.dx - emitter.radius * emitter.currentPulseFactor,
                        top: emitter.position.dy - emitter.radius * emitter.currentPulseFactor,
                        width: emitter.radius * 2 * emitter.currentPulseFactor,
                        height: emitter.radius * 2 * emitter.currentPulseFactor,
                        child: Container(
                          decoration: BoxDecoration(
                            color: emitter.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: emitter.color.withOpacity(0.5),
                                blurRadius: emitter.isPowerUp ? 15 : 10,
                                spreadRadius: emitter.isPowerUp ? 3 : 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: emitter.radius * 0.5 * emitter.currentPulseFactor,
                              height: emitter.radius * 0.5 * emitter.currentPulseFactor,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // Particles with improved visuals
                    ..._particles.map((particle) {
                      if (particle.isRing) {
                        // Render as expanding ring
                        return Positioned(
                          left: particle.initialPosition.dx - particle.ringRadius,
                          top: particle.initialPosition.dy - particle.ringRadius,
                          width: particle.ringRadius * 2,
                          height: particle.ringRadius * 2,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: particle.color.withOpacity(particle.opacity),
                                width: particle.ringWidth,
                              ),
                            ),
                          ),
                        );
                      } else {
                        // Render as normal particle
                        return Positioned(
                          left: particle.position.dx - particle.size / 2,
                          top: particle.position.dy - particle.size / 2,
                          width: particle.size,
                          height: particle.size,
                          child: Opacity(
                            opacity: particle.opacity,
                            child: Container(
                              decoration: BoxDecoration(
                                color: particle.color,
                                shape: BoxShape.circle,
                                boxShadow: particle.glowing
                                    ? [
                                        BoxShadow(
                                          color: particle.color,
                                          blurRadius: 3,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        );
                      }
                    }),

                    // Placement preview with improved visual feedback
                    if (_isPlacing && _selectedColor != null && _placementPosition != null)
                      Positioned(
                        left: _placementPosition!.dx - 20,
                        top: _placementPosition!.dy - 20,
                        width: 40,
                        height: 40,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            // Create pulsing effect for better visibility
                            return Transform.scale(
                              scale: _pulseAnimation.value * 0.9,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _selectedColor!.withOpacity(0.7),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _selectedColor!.withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
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
                            );
                          },
                        ),
                      ),

                    // Combo indicator
                    if (_combo > 0)
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: _getComboColor(_combo),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _getComboColor(_combo).withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getComboIcon(_combo),
                                color: _getComboColor(_combo),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Combo x$_combo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Active power-up indicator
                    if (_isPowerUpActive && _activePowerUp != null)
                      Positioned(
                        top: _combo > 0 ? 70 : 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: _getPowerUpColor(_activePowerUp!),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _getPowerUpColor(_activePowerUp!).withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getPowerUpIcon(_activePowerUp!),
                                color: _getPowerUpColor(_activePowerUp!),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getPowerUpName(_activePowerUp!),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Tutorial overlay with improved guidance
                    if (_showTutorial)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.7),
                          child: Center(
                            child: Container(
                              width: _canvasSize.width * 0.85,
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
                                        ? 'Select colors from the palette and place emitters on the canvas to create waves.'
                                        : _tutorialStep == 1
                                            ? 'Waves will propagate and interact when they collide. Try creating multiple emitters!'
                                            : _tutorialStep == 2
                                                ? 'When waves interact, they mix colors. Experiment to match the target color shown at the top.'
                                                : 'Great job! Look for combos to unlock special power-ups. Keep experimenting with different placements.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.teal.shade100,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Interactive tutorial element
                                  if (_tutorialStep <= 2)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.teal.shade700,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: _tutorialStep == 0
                                                  ? Colors.red
                                                  : _tutorialStep == 1
                                                      ? Colors.blue
                                                      : Colors.purple,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (_tutorialStep == 0
                                                          ? Colors.red
                                                          : _tutorialStep == 1
                                                              ? Colors.blue
                                                              : Colors.purple)
                                                      .withOpacity(0.5),
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _tutorialStep == 0
                                                      ? 'Step 1: Select a Color'
                                                      : _tutorialStep == 1
                                                          ? 'Step 2: Place Emitters'
                                                          : 'Step 3: Watch Colors Mix',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _tutorialStep == 0
                                                      ? 'Choose a color from the palette at the bottom of the screen.'
                                                      : _tutorialStep == 1
                                                          ? 'Try placing emitters at different positions to see how waves interact.'
                                                          : 'Watch the colored waves expand and create new colors where they meet.',
                                                  style: TextStyle(
                                                    color: Colors.teal.shade100,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 20),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_tutorialStep > 0)
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _tutorialStep--;
                                            });
                                          },
                                          style: TextButton.styleFrom(
                                            backgroundColor: Colors.teal.shade800,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Previous'),
                                        ),
                                      const SizedBox(width: 10),
                                      ElevatedButton(
                                        onPressed: () {
                                          if (_tutorialStep < 3) {
                                            _showTutorialStep(_tutorialStep + 1);
                                          } else {
                                            setState(() {
                                              _showTutorial = false;
                                            });
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal.shade700,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: Text(_tutorialStep < 3 ? 'Next' : 'Got it!'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getComboColor(int combo) {
    if (combo >= 20) return Colors.purple;
    if (combo >= 15) return Colors.pink;
    if (combo >= 10) return Colors.orange;
    if (combo >= 5) return Colors.amber;
    return Colors.green;
  }

  IconData _getComboIcon(int combo) {
    if (combo >= 20) return Icons.flash_on;
    if (combo >= 15) return Icons.whatshot;
    if (combo >= 10) return Icons.local_fire_department;
    if (combo >= 5) return Icons.trending_up;
    return Icons.add_circle;
  }

  Color _getPowerUpColor(PowerUpType type) {
    switch (type) {
      case PowerUpType.speedBoost:
        return Colors.amber;
      case PowerUpType.wideWaves:
        return Colors.blue;
      case PowerUpType.multiEmit:
        return Colors.purple;
      case PowerUpType.colorIntensity:
        return Colors.green;
    }
  }

  IconData _getPowerUpIcon(PowerUpType type) {
    switch (type) {
      case PowerUpType.speedBoost:
        return Icons.speed;
      case PowerUpType.wideWaves:
        return Icons.waves;
      case PowerUpType.multiEmit:
        return Icons.grain;
      case PowerUpType.colorIntensity:
        return Icons.palette;
    }
  }

  String _getPowerUpName(PowerUpType type) {
    switch (type) {
      case PowerUpType.speedBoost:
        return 'Speed Boost';
      case PowerUpType.wideWaves:
        return 'Wide Waves';
      case PowerUpType.multiEmit:
        return 'Multi-Emit';
      case PowerUpType.colorIntensity:
        return 'Color Intensity';
    }
  }
}

/// A wave propagating from an emitter with enhanced visual properties
class ColorWave {
  final Offset position;
  final Color color;
  double radius;
  double speed;
  double opacity;
  final bool glowing;
  final List<Obstacle> collidedObstacles = [];
  final List<ColorWave> collidedWaves = [];

  ColorWave({
    required this.position,
    required this.color,
    required this.radius,
    required this.speed,
    required this.opacity,
    this.glowing = false,
    List<Obstacle>? collidedObstacles,
  }) {
    if (collidedObstacles != null) {
      this.collidedObstacles.addAll(collidedObstacles);
    }
  }
}

/// A wave emitter with enhanced properties
class WaveEmitter {
  Offset position;
  final Color color;
  final double radius;
  final double frequency;
  double timeSinceLastEmission = 0;
  final bool fixed;
  final bool isPowerUp;
  Body? body;

  // Pulsing animation properties
  double pulsePhase = 0.0;
  final double pulseFactor;
  final double pulseSpeed;
  double currentPulseFactor = 1.0;

  WaveEmitter({
    required this.position,
    required this.color,
    required this.radius,
    required this.frequency,
    required this.fixed,
    this.isPowerUp = false,
    this.body,
    this.pulseFactor = 0.0,
    this.pulseSpeed = 1.0,
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

/// A visual effect for wave collisions
class CollisionEffect {
  final Offset position;
  final Color color;
  double radius;
  int lifetime;

  CollisionEffect({
    required this.position,
    required this.color,
    required this.radius,
    required this.lifetime,
  });
}

/// A particle used for visual effects with enhanced properties
class WaveParticle {
  final Offset initialPosition;
  Offset position;
  final double angle;
  double distance = 0;
  final double maxDistance;
  final double velocity;
  final Color color;
  final double size;
  double opacity = 1.0;
  final bool glowing;
  final bool isRing;
  double ringRadius = 0;
  double ringWidth = 2;

  WaveParticle({
    required Offset position,
    required this.angle,
    required this.maxDistance,
    required this.velocity,
    required this.color,
    required this.size,
    this.glowing = false,
    this.isRing = false,
  })  : initialPosition = position,
        position = position;
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

/// Visual hint for emitter placement
class PlacementHint {
  final Offset position;
  final Color color;
  final double radius;
  final bool pulsing;

  PlacementHint({
    required this.position,
    required this.color,
    required this.radius,
    this.pulsing = false,
  });
}

/// Power-up types
enum PowerUpType {
  speedBoost,
  wideWaves,
  multiEmit,
  colorIntensity,
}

/// Power-up data
class PowerUp {
  final PowerUpType type;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  PowerUp({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// Custom painter for the wave background with enhanced visuals
class WaveBackgroundPainter extends CustomPainter {
  final double animation;
  final Color baseColor;
  final Color targetColor;
  final double similarity;

  WaveBackgroundPainter({
    required this.animation,
    required this.baseColor,
    required this.targetColor,
    required this.similarity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Create dynamic gradient background that responds to color similarity
    final HSVColor hsvBase = HSVColor.fromColor(baseColor);
    final HSVColor hsvTarget = HSVColor.fromColor(targetColor);
    final baseHue = hsvBase.hue;

    // Create a gradient that changes based on similarity to target color
    final Color topColor = HSVColor.fromAHSV(
      1.0,
      baseHue,
      0.7,
      0.3 + (similarity * 0.1),
    ).toColor();

    final Color bottomColor = HSVColor.fromAHSV(
      1.0,
      (baseHue + 30) % 360,
      0.8,
      0.2 + (similarity * 0.1),
    ).toColor();

    // Add a hint of the target color when getting close
    final Color highlightColor = similarity > 0.8
        ? HSVColor.lerp(
            HSVColor.fromColor(bottomColor),
            HSVColor.fromColor(targetColor),
            (similarity - 0.8) * 5,
          )!
            .toColor()
        : bottomColor;

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [topColor, highlightColor],
    );

    final rect = Rect.fromLTWH(0, 0, width, height);
    final paint = Paint()..shader = gradient.createShader(rect);

    canvas.drawRect(rect, paint);

    // Draw dynamic wave patterns that respond to the animation
    final wavePaint1 = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final wavePaint2 = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // First wave - slower and larger
    final path1 = Path();
    path1.moveTo(0, height * 0.3);

    for (double x = 0; x <= width; x += 1) {
      final y = height * 0.3 + sin((x / width * 6 * pi) + (animation * 2 * pi)) * 20;
      path1.lineTo(x, y);
    }

    canvas.drawPath(path1, wavePaint1);

    // Second wave - faster and medium size
    final path2 = Path();
    path2.moveTo(0, height * 0.6);

    for (double x = 0; x <= width; x += 1) {
      final y = height * 0.6 + sin((x / width * 8 * pi) + (animation * 2 * pi * 1.5)) * 15;
      path2.lineTo(x, y);
    }

    canvas.drawPath(path2, wavePaint1);

    // Third wave - fastest and smallest
    final path3 = Path();
    path3.moveTo(0, height * 0.45);

    for (double x = 0; x <= width; x += 1) {
      final y = height * 0.45 + sin((x / width * 12 * pi) + (animation * 2 * pi * 2.5)) * 10;
      path3.lineTo(x, y);
    }

    canvas.drawPath(path3, wavePaint2);

    // Draw circular target color indicator in the background when similarity > 0.7
    if (similarity > 0.7) {
      final pulseFactor = 0.9 + sin(animation * 6 * pi) * 0.1;
      final pulseSize = width * 0.15 * pulseFactor;

      final targetPaint = Paint()
        ..color = targetColor.withOpacity(0.2 * (similarity - 0.7) * 3.33)
        ..style = PaintingStyle.fill;

      final targetCenter = Offset(width * 0.85, height * 0.15);
      canvas.drawCircle(targetCenter, pulseSize, targetPaint);

      // Add outline
      final outlinePaint = Paint()
        ..color = targetColor.withOpacity(0.4 * (similarity - 0.7) * 3.33)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(targetCenter, pulseSize, outlinePaint);
    }

    // Add subtle particle effect that responds to the similarity
    final particleCount = (30 + (similarity * 20).round()).clamp(30, 50);
    final particlePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final random = Random(42); // Fixed seed for deterministic pattern

    for (int i = 0; i < particleCount; i++) {
      final x = random.nextDouble() * width;
      final y = random.nextDouble() * height;
      final size = 1 + random.nextDouble() * 3;

      // Make particles move with animation and respond to similarity
      final speedFactor = 1.0 + similarity * 0.5;
      final offsetX = sin(animation * 2 * pi + i) * 5 * speedFactor;
      final offsetY = cos(animation * 2 * pi + i) * 5 * speedFactor;

      canvas.drawCircle(
        Offset(
          (x + offsetX) % width,
          (y + offsetY) % height,
        ),
        size,
        particlePaint,
      );
    }

    // Add target color halo effect at higher similarity levels
    if (similarity > 0.85) {
      final haloIntensity = (similarity - 0.85) * 6.67; // 0 to 1 range
      final haloPaint = Paint()
        ..color = targetColor.withOpacity(0.1 * haloIntensity)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20);

      // Draw subtle halos around the edges
      final gradientPaint = Paint()
        ..shader = RadialGradient(
          colors: [targetColor.withOpacity(0.1 * haloIntensity), targetColor.withOpacity(0)],
          stops: const [0.2, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(width * 0.2, height * 0.2), radius: 150));

      canvas.drawCircle(Offset(width * 0.2, height * 0.2), 150, gradientPaint);

      final gradientPaint2 = Paint()
        ..shader = RadialGradient(
          colors: [targetColor.withOpacity(0.1 * haloIntensity), targetColor.withOpacity(0)],
          stops: const [0.2, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(width * 0.8, height * 0.8), radius: 150));

      canvas.drawCircle(Offset(width * 0.8, height * 0.8), 150, gradientPaint2);
    }
  }

  @override
  bool shouldRepaint(covariant WaveBackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.targetColor != targetColor ||
        oldDelegate.similarity != similarity;
  }
}
