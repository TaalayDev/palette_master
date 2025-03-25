import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:forge2d/forge2d.dart' hide Transform;
import 'package:flutter/services.dart';
import 'package:palette_master/core/color_mixing_level_generator.dart';
import 'package:palette_master/core/color_models/color_mixer.dart';
import 'package:vibration/vibration.dart';

// Main game componentß
class ColorRacerGame extends StatefulWidget {
  final Color targetColor;
  final List<Color> availableColors;
  final Function(Color) onColorMixed;
  final int level;
  final Function() onSuccess;
  final Function() onFailure;

  const ColorRacerGame({
    super.key,
    required this.targetColor,
    required this.availableColors,
    required this.onColorMixed,
    required this.level,
    required this.onSuccess,
    required this.onFailure,
  });

  @override
  State<ColorRacerGame> createState() => _ColorRacerGameState();
}

class _ColorRacerGameState extends State<ColorRacerGame> with TickerProviderStateMixin {
  // Game state
  bool _gameStarted = false;
  bool _gameOver = false;
  bool _isPaused = false;
  bool _success = false;
  double _similarity = 0.0;
  int _score = 0;
  int _collectedColors = 0;
  int _secondsLeft = 60;
  String _statusMessage = "Ready to race!";
  Color _carColor = Colors.white;

  // Physics
  late RacerPhysicsWorld _physicsWorld;
  bool _isAccelerating = false;
  bool _isBraking = false;
  bool _isTurningLeft = false;
  bool _isTurningRight = false;

  // Animation controllers
  late AnimationController _gameLoopController;
  late AnimationController _countdownController;
  late AnimationController _powerupAnimationController;
  late Animation<double> _powerupAnimation;

  // Game elements
  late RaceCar _car;
  final List<ColorPickup> _colorPickups = [];
  final List<Obstacle> _obstacles = [];
  final List<TrackSection> _trackSections = [];
  final List<ColorSplash> _splashes = [];

  // Level configuration
  late TrackConfig _trackConfig;

  // Touch controls
  Offset? _leftJoystickPosition;
  Offset? _leftJoystickDragPosition;
  Offset? _rightJoystickPosition;
  Offset? _rightJoystickDragPosition;

  // Timer
  late AnimationController _timerController;

  @override
  void initState() {
    super.initState();

    // Create physics world
    _physicsWorld = RacerPhysicsWorld();

    // Initialize track configuration based on level
    _trackConfig = TrackConfig.fromLevel(widget.level);

    // Set up game loop controller
    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _gameLoopController.addListener(_gameLoop);

    // Set up countdown animation
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Set up powerup animation
    _powerupAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _powerupAnimation = CurvedAnimation(
      parent: _powerupAnimationController,
      curve: Curves.elasticOut,
    );

    // Set up timer
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _secondsLeft),
    );

    _timerController.addListener(() {
      if (_timerController.isAnimating) {
        setState(() {
          _secondsLeft = (_secondsLeft - _timerController.value).ceil();
          if (_secondsLeft <= 0) {
            _endGame(false);
          }
        });
      }
    });

    // Initialize track and game elements
    _initializeGame();

    // Setup joystick positions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupJoystickPositions();
    });
  }

  @override
  void dispose() {
    _gameLoopController.removeListener(_gameLoop);
    _gameLoopController.dispose();
    _countdownController.dispose();
    _powerupAnimationController.dispose();
    _timerController.dispose();
    super.dispose();
  }

  void _setupJoystickPositions() {
    final size = MediaQuery.of(context).size;

    // Set left joystick at bottom left
    _leftJoystickPosition = Offset(size.width * 0.15, size.height * 0.8);

    // Set right joystick at bottom right
    _rightJoystickPosition = Offset(size.width * 0.85, size.height * 0.8);
  }

  void _initializeGame() {
    // Create car
    _car = RaceCar(
      position: _trackConfig.startPosition,
      size: const Size(40, 70),
      color: Colors.white,
      angle: _trackConfig.startAngle,
    );

    // Add car to physics world
    _physicsWorld.addCar(_car);

    // Create track sections
    _createTrack();

    // Add track boundaries to physics world
    for (final section in _trackSections) {
      _physicsWorld.addTrackBounds(section);
    }

    // Create color pickups
    _createColorPickups();

    // Create obstacles
    _createObstacles();

    // Set initial car color
    _carColor = Colors.white;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onColorMixed(_carColor);
    });
  }

  void _createTrack() {
    _trackSections.clear();

    // Create track based on configuration
    for (final sectionConfig in _trackConfig.trackSections) {
      _trackSections.add(
        TrackSection(
          rect: sectionConfig.rect,
          trackWidth: sectionConfig.width,
          cornerRadius: sectionConfig.cornerRadius,
          rotation: sectionConfig.rotation,
          type: sectionConfig.type,
        ),
      );
    }

    // Add checkpoints
    for (final checkpoint in _trackConfig.checkpoints) {
      _trackSections.add(
        TrackSection(
          rect: checkpoint.rect,
          trackWidth: 10,
          cornerRadius: 0,
          rotation: checkpoint.rotation,
          type: TrackSectionType.checkpoint,
        ),
      );
    }

    // Add finish line
    _trackSections.add(
      TrackSection(
        rect: _trackConfig.finishLine,
        trackWidth: 10,
        cornerRadius: 0,
        rotation: 0,
        type: TrackSectionType.finishLine,
      ),
    );
  }

  void _createColorPickups() {
    _colorPickups.clear();

    // Add color pickups of available colors
    for (int i = 0; i < widget.availableColors.length; i++) {
      // Calculate pickup position along the track
      final trackProgress = (i + 1) / (widget.availableColors.length + 1);
      final sectionIndex =
          ((trackProgress * _trackConfig.trackSections.length) % _trackConfig.trackSections.length).floor();
      final section = _trackConfig.trackSections[sectionIndex];

      // Position within section
      final positionAlongSection = Random().nextDouble();
      final offset = _getOffsetAlongTrack(section, positionAlongSection);

      // Create pickup
      _colorPickups.add(
        ColorPickup(
          position: offset,
          color: widget.availableColors[i],
          radius: 20,
        ),
      );
    }

    // Add bonus color pickups
    final bonusColors = [
      Colors.white,
      Colors.black,
      ...widget.availableColors,
    ];

    for (int i = 0; i < 5; i++) {
      final randomSectionIndex = Random().nextInt(_trackConfig.trackSections.length);
      final section = _trackConfig.trackSections[randomSectionIndex];
      final positionAlongSection = Random().nextDouble();
      final offset = _getOffsetAlongTrack(section, positionAlongSection);

      // Create pickup
      _colorPickups.add(
        ColorPickup(
          position: offset,
          color: bonusColors[Random().nextInt(bonusColors.length)],
          radius: 15,
        ),
      );
    }
  }

  Offset _getOffsetAlongTrack(TrackSectionConfig section, double progress) {
    switch (section.type) {
      case TrackSectionType.straight:
        // Linear interpolation along straight section
        final start = section.rect.topLeft;
        final end = section.rect.bottomRight;
        return Offset(
          start.dx + (end.dx - start.dx) * progress,
          start.dy + (end.dy - start.dy) * progress,
        );

      case TrackSectionType.curve:
        // Calculate position along curve
        final center = section.rect.center;
        final radius = section.width / 2;
        final angle = section.rotation + (progress * pi / 2);
        return Offset(
          center.dx + cos(angle) * radius,
          center.dy + sin(angle) * radius,
        );

      default:
        // Default position at center of section
        return section.rect.center;
    }
  }

  void _createObstacles() {
    _obstacles.clear();

    // Create obstacles based on level configuration
    for (final obstacleConfig in _trackConfig.obstacles) {
      _obstacles.add(
        Obstacle(
          position: obstacleConfig.position,
          size: obstacleConfig.size,
          type: obstacleConfig.type,
          rotation: obstacleConfig.rotation,
        ),
      );

      // Add to physics world
      _physicsWorld.addObstacle(_obstacles.last);
    }
  }

  void _gameLoop() {
    if (!_gameStarted || _gameOver || _isPaused) return;

    // Update physics (apply car controls)
    if (_isAccelerating) {
      _car.accelerate();
    }

    if (_isBraking) {
      _car.brake();
    }

    if (_isTurningLeft) {
      _car.turnLeft();
    }

    if (_isTurningRight) {
      _car.turnRight();
    }

    // Step physics simulation
    _physicsWorld.step();

    // Update car position from physics
    _car.updateFromPhysics();

    // Check for collisions with color pickups
    _checkColorPickupCollisions();

    // Check for collisions with track boundaries
    _checkTrackBoundaryCollisions();

    // Check for level completion
    _checkLevelCompletion();

    // Update visual effects
    _updateSplashes();

    // Force rebuild to reflect updated positions
    setState(() {});
  }

  void _checkColorPickupCollisions() {
    // Check each color pickup
    for (int i = _colorPickups.length - 1; i >= 0; i--) {
      final pickup = _colorPickups[i];

      // Calculate distance to car
      final distance = (pickup.position - _car.position).distance;

      // If car collides with pickup
      if (distance < pickup.radius + 20) {
        // Mix colors
        _mixNewColor(pickup.color);

        // Create splash effect
        _createColorSplash(pickup.position, pickup.color);

        // Remove pickup
        _colorPickups.removeAt(i);

        // Update score
        _score += 10;
        _collectedColors++;

        // Provide haptic feedback
        Vibration.hasVibrator().then((hasVibrator) {
          if (hasVibrator ?? false) {
            Vibration.vibrate(duration: 50, amplitude: 100);
          }
        });

        // Play pickup animation
        _powerupAnimationController.reset();
        _powerupAnimationController.forward();
      }
    }
  }

  void _mixNewColor(Color newColor) {
    // Mix current car color with new pickup color
    final mixedColor = ColorMixer.mixSubtractive([_carColor, newColor]);

    setState(() {
      _carColor = mixedColor;
      _car.color = mixedColor;
    });

    // Update parent
    widget.onColorMixed(_carColor);

    // Calculate similarity to target
    _calculateSimilarity();
  }

  void _calculateSimilarity() {
    // Calculate similarity between current car color and target color
    final dr = (_carColor.red - widget.targetColor.red) / 255.0;
    final dg = (_carColor.green - widget.targetColor.green) / 255.0;
    final db = (_carColor.blue - widget.targetColor.blue) / 255.0;

    // Human eyes are more sensitive to green, less to blue
    final distance = (dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11);
    final similarity = (1.0 - sqrt(distance)).clamp(0.0, 1.0);

    setState(() {
      _similarity = similarity;
    });

    // Update status message based on similarity
    if (_similarity > 0.95) {
      _statusMessage = "Perfect match! Find the finish line!";
    } else if (_similarity > 0.85) {
      _statusMessage = "Very close! Just needs a little adjusting...";
    } else if (_similarity > 0.7) {
      _statusMessage = "Getting closer to the target color!";
    } else if (_similarity > 0.5) {
      _statusMessage = "Making progress, but need more colors...";
    } else {
      _statusMessage = "Keep collecting colors to match the target!";
    }
  }

  void _checkTrackBoundaryCollisions() {
    // If car goes off track, apply penalty
    if (_physicsWorld.isCarOffTrack()) {
      // Slow down car
      _car.applyBrake(0.95);

      // Update status message
      _statusMessage = "Off track! Slow down!";
    }
  }

  void _checkLevelCompletion() {
    // Check if car has crossed finish line
    if (_physicsWorld.hasCarCrossedFinishLine()) {
      // If color similarity is high enough, level completed
      if (_similarity >= 0.85) {
        _endGame(true);
      } else {
        // Otherwise, show message that color isn't matching yet
        _statusMessage = "Color doesn't match target yet! (${(_similarity * 100).toInt()}%)";
      }
    }
  }

  void _createColorSplash(Offset position, Color color) {
    // Create color splash effect
    _splashes.add(
      ColorSplash(
        position: position,
        color: color,
        size: 30.0,
        opacity: 1.0,
      ),
    );
  }

  void _updateSplashes() {
    // Update and fade out splashes
    for (int i = _splashes.length - 1; i >= 0; i--) {
      final splash = _splashes[i];

      // Increase size and reduce opacity
      splash.size += 2.0;
      splash.opacity -= 0.05;

      // Remove if fully transparent
      if (splash.opacity <= 0) {
        _splashes.removeAt(i);
      }
    }
  }

  void _startGame() {
    setState(() {
      _gameStarted = true;
      _gameOver = false;
      _isPaused = false;
    });

    // Start countdown
    _countdownController.forward().then((_) {
      // Start timer after countdown
      _timerController.forward();
    });
  }

  void _endGame(bool success) {
    setState(() {
      _gameOver = true;
      _success = success;
      _timerController.stop();
    });

    // Call appropriate callback
    if (success) {
      widget.onSuccess();
    } else {
      widget.onFailure();
    }
  }

  void _pauseGame() {
    setState(() {
      _isPaused = true;
      _timerController.stop();
    });
  }

  void _resumeGame() {
    setState(() {
      _isPaused = false;
      _timerController.forward();
    });
  }

  void _restartGame() {
    // Reset game state
    setState(() {
      _gameStarted = false;
      _gameOver = false;
      _isPaused = false;
      _score = 0;
      _collectedColors = 0;
      _secondsLeft = 60;
      _carColor = Colors.white;
      _similarity = 0.0;
      _statusMessage = "Ready to race!";

      // Reset animations
      _countdownController.reset();
      _timerController.reset();

      // Clear effects
      _splashes.clear();
    });

    // Re-initialize game elements
    _initializeGame();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[800],
        child: Stack(
          children: [
            // Track and game elements
            _buildGameView(),

            // Overlay UI
            _buildUI(),

            // Joystick controls
            if (_gameStarted && !_gameOver) ...[
              _buildLeftJoystick(),
              _buildRightJoystick(),
            ],

            // Countdown overlay
            if (_gameStarted && _countdownController.isAnimating) _buildCountdown(),

            // Game over overlay
            if (_gameOver) _buildGameOverOverlay(),

            // Pause overlay
            if (_isPaused) _buildPauseOverlay(),

            // Start screen
            if (!_gameStarted && !_gameOver) _buildStartScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildGameView() {
    return CustomPaint(
      painter: RaceTrackPainter(
        trackSections: _trackSections,
        car: _car,
        colorPickups: _colorPickups,
        obstacles: _obstacles,
        splashes: _splashes,
        similarity: _similarity,
        targetColor: widget.targetColor,
      ),
      size: Size.infinite,
    );
  }

  Widget _buildUI() {
    return SafeArea(
      child: Column(
        children: [
          // Top UI bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Score counter
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      "Score: $_score",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // Timer
                Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: _secondsLeft <= 10 ? Colors.red : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${_secondsLeft}s",
                      style: TextStyle(
                        color: _secondsLeft <= 10 ? Colors.red : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // Color counter
                Row(
                  children: [
                    const Icon(Icons.palette, color: Colors.white, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      "$_collectedColors",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // Pause button
                if (_gameStarted && !_gameOver)
                  GestureDetector(
                    onTap: _pauseGame,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pause, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ),

          // Color match indicator
          if (_gameStarted && !_gameOver)
            Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedBuilder(
                animation: _powerupAnimationController,
                builder: (context, child) {
                  final scale = _powerupAnimationController.isAnimating ? 1.0 + (_powerupAnimation.value * 0.2) : 1.0;

                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getSimilarityColor(),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Target color
                      Column(
                        children: [
                          const Text(
                            "Target",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: widget.targetColor,
                              shape: BoxShape.circle,
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
                        ],
                      ),

                      const SizedBox(width: 16),

                      // Similarity meter
                      Column(
                        children: [
                          Text(
                            "${(_similarity * 100).toInt()}% Match",
                            style: TextStyle(
                              color: _getSimilarityColor(),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 100,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 100 * _similarity,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getSimilarityColor(),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: 16),

                      // Current car color
                      Column(
                        children: [
                          const Text(
                            "Your Car",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _carColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _carColor.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const Spacer(),

          // Status message
          if (_gameStarted && !_gameOver)
            Container(
              margin: const EdgeInsets.only(bottom: 100),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeftJoystick() {
    if (_leftJoystickPosition == null) return const SizedBox();

    final joystickSize = 120.0;
    final actualPosition = _leftJoystickDragPosition ?? _leftJoystickPosition!;

    final dragOffset =
        _leftJoystickDragPosition != null ? (_leftJoystickDragPosition! - _leftJoystickPosition!).distance : 0.0;

    // Normalize drag position within bounds
    final maxDrag = joystickSize / 4;
    final dragPercent = dragOffset / maxDrag;
    final normalizedPercent = dragPercent.clamp(0.0, 1.0);

    // Calculate normalized direction
    Offset direction = Offset.zero;
    if (_leftJoystickDragPosition != null) {
      direction = (_leftJoystickDragPosition! - _leftJoystickPosition!).normalize();
    }

    // Define whether acceleration or braking
    _isAccelerating = _leftJoystickDragPosition != null && direction.dy < -0.2;
    _isBraking = _leftJoystickDragPosition != null && direction.dy > 0.2;

    return Positioned(
      left: _leftJoystickPosition!.dx - joystickSize / 2,
      top: _leftJoystickPosition!.dy - joystickSize / 2,
      width: joystickSize,
      height: joystickSize,
      child: Stack(
        children: [
          // Joystick background
          Container(
            width: joystickSize,
            height: joystickSize,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.arrow_upward,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),

          // Joystick handle
          Positioned(
            left: joystickSize / 2 - 20 + (direction.dx * maxDrag * normalizedPercent),
            top: joystickSize / 2 - 20 + (direction.dy * maxDrag * normalizedPercent),
            width: 40,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                color: _isAccelerating
                    ? Colors.green
                    : _isBraking
                        ? Colors.red
                        : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                _isAccelerating
                    ? Icons.arrow_upward
                    : _isBraking
                        ? Icons.arrow_downward
                        : Icons.radio_button_unchecked,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightJoystick() {
    if (_rightJoystickPosition == null) return const SizedBox();

    final joystickSize = 120.0;
    final actualPosition = _rightJoystickDragPosition ?? _rightJoystickPosition!;

    final dragOffset =
        _rightJoystickDragPosition != null ? (_rightJoystickDragPosition! - _rightJoystickPosition!).distance : 0.0;

    // Normalize drag position within bounds
    final maxDrag = joystickSize / 4;
    final dragPercent = dragOffset / maxDrag;
    final normalizedPercent = dragPercent.clamp(0.0, 1.0);

    // Calculate normalized direction
    Offset direction = Offset.zero;
    if (_rightJoystickDragPosition != null) {
      direction = (_rightJoystickDragPosition! - _rightJoystickPosition!).normalize();
    }

    // Define turning direction
    _isTurningLeft = _rightJoystickDragPosition != null && direction.dx < -0.2;
    _isTurningRight = _rightJoystickDragPosition != null && direction.dx > 0.2;

    return Positioned(
      left: _rightJoystickPosition!.dx - joystickSize / 2,
      top: _rightJoystickPosition!.dy - joystickSize / 2,
      width: joystickSize,
      height: joystickSize,
      child: Stack(
        children: [
          // Joystick background
          Container(
            width: joystickSize,
            height: joystickSize,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 20),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),

          // Joystick handle
          Positioned(
            left: joystickSize / 2 - 20 + (direction.dx * maxDrag * normalizedPercent),
            top: joystickSize / 2 - 20 + (direction.dy * maxDrag * normalizedPercent),
            width: 40,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                color: _isTurningLeft
                    ? Colors.orange
                    : _isTurningRight
                        ? Colors.orange
                        : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                _isTurningLeft
                    ? Icons.arrow_back
                    : _isTurningRight
                        ? Icons.arrow_forward
                        : Icons.radio_button_unchecked,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdown() {
    // Calculate current countdown number
    int countdownNumber = 3 - (_countdownController.value * 3).floor();
    if (countdownNumber <= 0) {
      countdownNumber = 0; // GO!
    }

    // Determine size and opacity based on animation
    final progress = _countdownController.value % (1 / 3) * 3;
    final scale = 1.5 - progress;
    final opacity = 1.0 - progress;

    return Center(
      child: AnimatedOpacity(
        opacity: opacity,
        duration: Duration.zero,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(
                color: countdownNumber == 0 ? Colors.green : Colors.white,
                width: 5,
              ),
            ),
            child: Center(
              child: Text(
                countdownNumber == 0 ? 'GO!' : countdownNumber.toString(),
                style: TextStyle(
                  color: countdownNumber == 0 ? Colors.green : Colors.white,
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _success ? Colors.green.shade900 : Colors.red.shade900,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _success ? 'Level Complete!' : 'Level Failed',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _success
                  ? Column(
                      children: [
                        Icon(
                          Icons.emoji_events,
                          color: Colors.amber,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Score: $_score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Colors Collected: $_collectedColors',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Color Match: ${(_similarity * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade300,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _secondsLeft <= 0 ? 'Out of time!' : 'Color match not close enough!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 32),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _restartGame,
                    icon: const Icon(Icons.replay),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade900,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Game Paused',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _resumeGame,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _restartGame,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Restart'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.indigo.shade900,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo.shade800,
                Colors.indigo.shade900,
                Colors.purple.shade900,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Color Racer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Target Color',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: widget.targetColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.targetColor.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Race around the track and collect colors to match your car\'s paint to the target color.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ControlInstruction(
                    icon: Icons.arrow_upward,
                    text: 'Accelerate',
                  ),
                  SizedBox(width: 16),
                  _ControlInstruction(
                    icon: Icons.arrow_downward,
                    text: 'Brake',
                  ),
                  SizedBox(width: 16),
                  _ControlInstruction(
                    icon: Icons.arrow_back,
                    text: 'Turn Left',
                  ),
                  SizedBox(width: 16),
                  _ControlInstruction(
                    icon: Icons.arrow_forward,
                    text: 'Turn Right',
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow),
                label: const Text('START RACE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSimilarityColor() {
    if (_similarity >= 0.9) {
      return Colors.green;
    } else if (_similarity >= 0.75) {
      return Colors.orange;
    } else if (_similarity >= 0.5) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }

  void _handlePanStart(DragStartDetails details) {
    final position = details.localPosition;

    // Check if touch is near left joystick
    if (_leftJoystickPosition != null) {
      final distance = (position - _leftJoystickPosition!).distance;
      if (distance < 80) {
        setState(() {
          _leftJoystickDragPosition = position;
        });
        return;
      }
    }

    // Check if touch is near right joystick
    if (_rightJoystickPosition != null) {
      final distance = (position - _rightJoystickPosition!).distance;
      if (distance < 80) {
        setState(() {
          _rightJoystickDragPosition = position;
        });
        return;
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final position = details.localPosition;

    // Update drag position for left joystick
    if (_leftJoystickDragPosition != null) {
      setState(() {
        _leftJoystickDragPosition = position;
      });
      return;
    }

    // Update drag position for right joystick
    if (_rightJoystickDragPosition != null) {
      setState(() {
        _rightJoystickDragPosition = position;
      });
      return;
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    // Reset joystick positions
    setState(() {
      _leftJoystickDragPosition = null;
      _rightJoystickDragPosition = null;
      _isAccelerating = false;
      _isBraking = false;
      _isTurningLeft = false;
      _isTurningRight = false;
    });
  }
}

// Race car class
class RaceCar {
  Offset position;
  Size size;
  Color color;
  double angle;
  Body? body;

  RaceCar({
    required this.position,
    required this.size,
    required this.color,
    this.angle = 0,
  });

  void accelerate() {
    if (body != null) {
      // Apply forward force in direction of car
      final force = Vector2(sin(angle), -cos(angle))..scale(10.0);
      body!.applyForce(force);
    }
  }

  void brake() {
    if (body != null) {
      // Apply reverse force in opposite direction of car
      final force = Vector2(sin(angle), -cos(angle))..scale(-5.0);
      body!.applyForce(force);

      // Also apply friction
      applyBrake(0.95);
    }
  }

  void turnLeft() {
    if (body != null) {
      // Apply torque for left turn
      body!.applyTorque(-2.0);
    }
  }

  void turnRight() {
    if (body != null) {
      // Apply torque for right turn
      body!.applyTorque(2.0);
    }
  }

  void applyBrake(double factor) {
    if (body != null) {
      // Reduce velocity by factor
      final velocity = body!.linearVelocity;
      body!.linearVelocity.setValues(
        velocity.x * factor,
        velocity.y * factor,
      );
    }
  }

  void updateFromPhysics() {
    if (body != null) {
      // Update position from physics body
      position = Offset(body!.position.x, body!.position.y);

      // Update angle from physics body
      angle = body!.angle;
    }
  }
}

// Color pickup class
class ColorPickup {
  Offset position;
  Color color;
  double radius;

  ColorPickup({
    required this.position,
    required this.color,
    required this.radius,
  });
}

// Obstacle class
class Obstacle {
  Offset position;
  Size size;
  ObstacleType type;
  double rotation;
  Body? body;

  Obstacle({
    required this.position,
    required this.size,
    required this.type,
    this.rotation = 0,
  });
}

// Track section class
class TrackSection {
  Rect rect;
  double trackWidth;
  double cornerRadius;
  double rotation;
  TrackSectionType type;

  TrackSection({
    required this.rect,
    required this.trackWidth,
    required this.cornerRadius,
    required this.rotation,
    required this.type,
  });
}

// Color splash effect
class ColorSplash {
  Offset position;
  Color color;
  double size;
  double opacity;

  ColorSplash({
    required this.position,
    required this.color,
    required this.size,
    required this.opacity,
  });
}

// Track configuration
class TrackConfig {
  final Offset startPosition;
  final double startAngle;
  final List<TrackSectionConfig> trackSections;
  final List<CheckpointConfig> checkpoints;
  final Rect finishLine;
  final List<ObstacleConfig> obstacles;

  TrackConfig({
    required this.startPosition,
    required this.startAngle,
    required this.trackSections,
    required this.checkpoints,
    required this.finishLine,
    required this.obstacles,
  });

  // Factory constructor to create track config based on level
  factory TrackConfig.fromLevel(int level) {
    // Set up track sections based on level
    switch (level) {
      case 1:
        return _createLevel1Track();
      case 2:
        return _createLevel2Track();
      case 3:
        return _createLevel3Track();
      case 4:
        return _createLevel4Track();
      case 5:
        return _createLevel5Track();
      default:
        return _createLevel1Track();
    }
  }

  // Level 1 - Oval track (simple)
  static TrackConfig _createLevel1Track() {
    final trackWidth = 120.0;
    final trackSections = <TrackSectionConfig>[
      // Top straight
      TrackSectionConfig(
        rect: Rect.fromLTWH(200, 100, 400, trackWidth),
        width: trackWidth,
        cornerRadius: 0,
        rotation: 0,
        type: TrackSectionType.straight,
      ),
      // Right curve
      TrackSectionConfig(
        rect: Rect.fromLTWH(600, 100, 120, 120),
        width: trackWidth,
        cornerRadius: 60,
        rotation: 0,
        type: TrackSectionType.curve,
      ),
      // Right straight
      TrackSectionConfig(
        rect: Rect.fromLTWH(600, 220, trackWidth, 260),
        width: trackWidth,
        cornerRadius: 0,
        rotation: 0,
        type: TrackSectionType.straight,
      ),
      // Bottom curve
      TrackSectionConfig(
        rect: Rect.fromLTWH(480, 480, 120, 120),
        width: trackWidth,
        cornerRadius: 60,
        rotation: 1.5 * pi,
        type: TrackSectionType.curve,
      ),
      // Bottom straight
      TrackSectionConfig(
        rect: Rect.fromLTWH(200, 480, 280, trackWidth),
        width: trackWidth,
        cornerRadius: 0,
        rotation: 0,
        type: TrackSectionType.straight,
      ),
      // Left curve
      TrackSectionConfig(
        rect: Rect.fromLTWH(80, 360, 120, 120),
        width: trackWidth,
        cornerRadius: 60,
        rotation: pi,
        type: TrackSectionType.curve,
      ),
      // Left straight
      TrackSectionConfig(
        rect: Rect.fromLTWH(80, 220, trackWidth, 140),
        width: trackWidth,
        cornerRadius: 0,
        rotation: 0,
        type: TrackSectionType.straight,
      ),
      // Top-left curve
      TrackSectionConfig(
        rect: Rect.fromLTWH(80, 100, 120, 120),
        width: trackWidth,
        cornerRadius: 60,
        rotation: 0.5 * pi,
        type: TrackSectionType.curve,
      ),
    ];

    // Add checkpoints
    final checkpoints = <CheckpointConfig>[
      CheckpointConfig(
        rect: Rect.fromLTWH(600, 300, 50, 10),
        rotation: 0,
      ),
      CheckpointConfig(
        rect: Rect.fromLTWH(300, 480, 50, 10),
        rotation: 0,
      ),
      CheckpointConfig(
        rect: Rect.fromLTWH(80, 300, 50, 10),
        rotation: 0,
      ),
    ];

    // Set finish line
    final finishLine = Rect.fromLTWH(350, 100, 50, trackWidth);

    // Add obstacles
    final obstacles = <ObstacleConfig>[
      ObstacleConfig(
        position: const Offset(400, 220),
        size: const Size(30, 30),
        type: ObstacleType.cone,
        rotation: 0,
      ),
      ObstacleConfig(
        position: const Offset(450, 380),
        size: const Size(30, 30),
        type: ObstacleType.cone,
        rotation: 0,
      ),
      ObstacleConfig(
        position: const Offset(200, 380),
        size: const Size(30, 30),
        type: ObstacleType.cone,
        rotation: 0,
      ),
      ObstacleConfig(
        position: const Offset(200, 220),
        size: const Size(30, 30),
        type: ObstacleType.cone,
        rotation: 0,
      ),
    ];

    return TrackConfig(
      startPosition: const Offset(300, 160),
      startAngle: 0,
      trackSections: trackSections,
      checkpoints: checkpoints,
      finishLine: finishLine,
      obstacles: obstacles,
    );
  }

  // Level 2 - Figure 8 track
  static TrackConfig _createLevel2Track() {
    final trackWidth = 100.0;

    // Create figure 8 track
    final trackSections = <TrackSectionConfig>[];

    // Add more complex track sections for figure 8

    // Add checkpoints
    final checkpoints = <CheckpointConfig>[];

    // Set finish line
    final finishLine = Rect.fromLTWH(350, 100, 50, trackWidth);

    // Add obstacles
    final obstacles = <ObstacleConfig>[];

    return TrackConfig(
      startPosition: const Offset(300, 150),
      startAngle: 0,
      trackSections: trackSections,
      checkpoints: checkpoints,
      finishLine: finishLine,
      obstacles: obstacles,
    );
  }

  // Level 3 - Complex track with bridges/tunnels
  static TrackConfig _createLevel3Track() {
    // Create even more complex track with elevation changes

    final trackWidth = 100.0;
    final trackSections = <TrackSectionConfig>[];
    final checkpoints = <CheckpointConfig>[];
    final finishLine = Rect.fromLTWH(350, 100, 50, trackWidth);
    final obstacles = <ObstacleConfig>[];

    return TrackConfig(
      startPosition: const Offset(300, 150),
      startAngle: 0,
      trackSections: trackSections,
      checkpoints: checkpoints,
      finishLine: finishLine,
      obstacles: obstacles,
    );
  }

  // Level 4 - Technical track with tight corners
  static TrackConfig _createLevel4Track() {
    // Create technical track with tight corners

    final trackWidth = 80.0;
    final trackSections = <TrackSectionConfig>[];
    final checkpoints = <CheckpointConfig>[];
    final finishLine = Rect.fromLTWH(350, 100, 50, trackWidth);
    final obstacles = <ObstacleConfig>[];

    return TrackConfig(
      startPosition: const Offset(300, 150),
      startAngle: 0,
      trackSections: trackSections,
      checkpoints: checkpoints,
      finishLine: finishLine,
      obstacles: obstacles,
    );
  }

  // Level 5 - Final challenge track
  static TrackConfig _createLevel5Track() {
    // Create final challenge track

    final trackWidth = 80.0;
    final trackSections = <TrackSectionConfig>[];
    final checkpoints = <CheckpointConfig>[];
    final finishLine = Rect.fromLTWH(350, 100, 50, trackWidth);
    final obstacles = <ObstacleConfig>[];

    return TrackConfig(
      startPosition: const Offset(300, 150),
      startAngle: 0,
      trackSections: trackSections,
      checkpoints: checkpoints,
      finishLine: finishLine,
      obstacles: obstacles,
    );
  }
}

// Track section config
class TrackSectionConfig {
  final Rect rect;
  final double width;
  final double cornerRadius;
  final double rotation;
  final TrackSectionType type;

  TrackSectionConfig({
    required this.rect,
    required this.width,
    required this.cornerRadius,
    required this.rotation,
    required this.type,
  });
}

// Checkpoint config
class CheckpointConfig {
  final Rect rect;
  final double rotation;

  CheckpointConfig({
    required this.rect,
    required this.rotation,
  });
}

// Obstacle config
class ObstacleConfig {
  final Offset position;
  final Size size;
  final ObstacleType type;
  final double rotation;

  ObstacleConfig({
    required this.position,
    required this.size,
    required this.type,
    required this.rotation,
  });
}

// Enum for track section types
enum TrackSectionType {
  straight,
  curve,
  checkpoint,
  finishLine,
}

// Enum for obstacle types
enum ObstacleType {
  cone,
  barrier,
  oil,
  boost,
}

// Physics world for the racer game
class RacerPhysicsWorld {
  final World world = World(Vector2(0, 0)); // No gravity
  Body? carBody;
  final List<Body> trackBodies = [];
  final List<Body> obstacleBodies = [];

  RacerPhysicsWorld() {
    // Set up world
  }

  void addCar(RaceCar car) {
    // Create car body
    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = Vector2(car.position.dx, car.position.dy)
      ..angle = car.angle
      ..angularDamping = 2.0
      ..linearDamping = 0.5;

    carBody = world.createBody(bodyDef);

    // Create car shape
    final shape = PolygonShape()..setAsBox(car.size.width / 2, car.size.height / 2, Vector2.zero(), car.angle);

    // Create fixture
    final fixtureDef = FixtureDef(shape)
      ..density = 1.0
      ..friction = 0.3
      ..restitution = 0.2;

    carBody!.createFixture(fixtureDef);

    // Store body in car
    car.body = carBody;
  }

  void addTrackBounds(TrackSection section) {
    // Create track boundary bodies

    // For now, simulate with a simple body
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = Vector2(section.rect.center.dx, section.rect.center.dy)
      ..angle = section.rotation;

    final body = world.createBody(bodyDef);

    // Simple box shape for now
    final shape = PolygonShape()..setAsBox(section.rect.width / 2, section.rect.height / 2, Vector2.zero(), 0);

    body.createFixture(FixtureDef(shape)
      ..friction = 0.3
      ..restitution = 0.2
      ..filter.categoryBits = 2
      ..filter.maskBits = 1);

    trackBodies.add(body);
  }

  void addObstacle(Obstacle obstacle) {
    // Create obstacle body
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = Vector2(obstacle.position.dx, obstacle.position.dy)
      ..angle = obstacle.rotation;

    final body = world.createBody(bodyDef);

    // Create shape based on obstacle type
    Shape shape;

    switch (obstacle.type) {
      case ObstacleType.cone:
        shape = CircleShape()..radius = obstacle.size.width / 2;
        break;
      case ObstacleType.barrier:
        shape = PolygonShape()..setAsBox(obstacle.size.width / 2, obstacle.size.height / 2, Vector2.zero(), 0);
        break;
      case ObstacleType.oil:
        shape = CircleShape()..radius = obstacle.size.width / 2;
        break;
      case ObstacleType.boost:
        shape = CircleShape()..radius = obstacle.size.width / 2;
        break;
    }

    // Create fixture
    final fixtureDef = FixtureDef(shape)
      ..friction = 0.1
      ..restitution = 0.4;

    body.createFixture(fixtureDef);

    // Store body in obstacle
    obstacle.body = body;

    obstacleBodies.add(body);
  }

  void step() {
    // Step the physics simulation
    world.stepDt(1 / 60); // 60 FPS
  }

  bool isCarOffTrack() {
    // Check if car is off the track
    return false; // Simplified for now
  }

  bool hasCarCrossedFinishLine() {
    // Check if car has crossed the finish line
    return false; // Simplified for now
  }
}

// Custom painter for the race track
class RaceTrackPainter extends CustomPainter {
  final List<TrackSection> trackSections;
  final RaceCar car;
  final List<ColorPickup> colorPickups;
  final List<Obstacle> obstacles;
  final List<ColorSplash> splashes;
  final double similarity;
  final Color targetColor;

  RaceTrackPainter({
    required this.trackSections,
    required this.car,
    required this.colorPickups,
    required this.obstacles,
    required this.splashes,
    required this.similarity,
    required this.targetColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    final backgroundPaint = Paint()..color = Colors.grey[800]!;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Draw track sections
    for (final section in trackSections) {
      _drawTrackSection(canvas, section);
    }

    // Draw splashes
    for (final splash in splashes) {
      _drawSplash(canvas, splash);
    }

    // Draw color pickups
    for (final pickup in colorPickups) {
      _drawColorPickup(canvas, pickup);
    }

    // Draw obstacles
    for (final obstacle in obstacles) {
      _drawObstacle(canvas, obstacle);
    }

    // Draw car
    _drawCar(canvas, car);
  }

  void _drawTrackSection(Canvas canvas, TrackSection section) {
    Paint paint;

    switch (section.type) {
      case TrackSectionType.straight:
      case TrackSectionType.curve:
        // Track surface
        paint = Paint()
          ..color = Colors.grey[600]!
          ..style = PaintingStyle.fill;

        canvas.drawRect(section.rect, paint);

        // Track border
        paint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5;

        canvas.drawRect(section.rect, paint);
        break;

      case TrackSectionType.checkpoint:
        // Checkpoint
        paint = Paint()
          ..color = Colors.blue.withOpacity(0.5)
          ..style = PaintingStyle.fill;

        canvas.drawRect(section.rect, paint);
        break;

      case TrackSectionType.finishLine:
        // Finish line with checkered pattern
        paint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.fill;

        canvas.drawRect(section.rect, paint);

        // Draw checkered pattern
        const checkerSize = 10.0;
        paint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

        for (int i = 0; i < section.rect.width / checkerSize; i++) {
          for (int j = 0; j < section.rect.height / checkerSize; j++) {
            if ((i + j) % 2 == 0) {
              canvas.drawRect(
                Rect.fromLTWH(
                  section.rect.left + i * checkerSize,
                  section.rect.top + j * checkerSize,
                  checkerSize,
                  checkerSize,
                ),
                paint,
              );
            }
          }
        }
        break;
    }
  }

  void _drawColorPickup(Canvas canvas, ColorPickup pickup) {
    // Draw outer glow
    final outerPaint = Paint()
      ..color = pickup.color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(pickup.position.dx, pickup.position.dy),
      pickup.radius * 1.5,
      outerPaint,
    );

    // Draw middle glow
    final middlePaint = Paint()
      ..color = pickup.color.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(pickup.position.dx, pickup.position.dy),
      pickup.radius * 1.2,
      middlePaint,
    );

    // Draw main circle
    final mainPaint = Paint()
      ..color = pickup.color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(pickup.position.dx, pickup.position.dy),
      pickup.radius,
      mainPaint,
    );

    // Draw inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(pickup.position.dx - pickup.radius * 0.3, pickup.position.dy - pickup.radius * 0.3),
      pickup.radius * 0.3,
      highlightPaint,
    );
  }

  void _drawObstacle(Canvas canvas, Obstacle obstacle) {
    Paint paint;

    // Save canvas state
    canvas.save();

    // Translate to obstacle position and rotate
    canvas.translate(obstacle.position.dx, obstacle.position.dy);
    canvas.rotate(obstacle.rotation);

    switch (obstacle.type) {
      case ObstacleType.cone:
        // Draw cone
        paint = Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.fill;

        final path = Path()
          ..moveTo(0, -obstacle.size.height / 2)
          ..lineTo(obstacle.size.width / 2, obstacle.size.height / 2)
          ..lineTo(-obstacle.size.width / 2, obstacle.size.height / 2)
          ..close();

        canvas.drawPath(path, paint);

        // Draw stripes
        paint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        canvas.drawLine(
          Offset(0, -obstacle.size.height / 4),
          Offset(0, obstacle.size.height / 4),
          paint,
        );
        break;

      case ObstacleType.barrier:
        // Draw barrier
        paint = Paint()
          ..color = Colors.red.shade700
          ..style = PaintingStyle.fill;

        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: obstacle.size.width,
            height: obstacle.size.height,
          ),
          paint,
        );

        // Draw stripes
        paint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        for (int i = -1; i <= 1; i += 2) {
          canvas.drawLine(
            Offset(i * obstacle.size.width / 4, -obstacle.size.height / 2),
            Offset(i * obstacle.size.width / 4, obstacle.size.height / 2),
            paint,
          );
        }
        break;

      case ObstacleType.oil:
        // Draw oil slick
        paint = Paint()
          ..color = Colors.black.withOpacity(0.7)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          Offset.zero,
          obstacle.size.width / 2,
          paint,
        );

        // Draw oil pattern
        paint = Paint()
          ..color = Colors.purple.withOpacity(0.3)
          ..style = PaintingStyle.fill;

        for (int i = 0; i < 5; i++) {
          final angle = i * pi / 2.5;
          canvas.drawCircle(
            Offset(
              cos(angle) * obstacle.size.width / 4,
              sin(angle) * obstacle.size.width / 4,
            ),
            obstacle.size.width / 8,
            paint,
          );
        }
        break;

      case ObstacleType.boost:
        // Draw boost pad
        paint = Paint()
          ..color = Colors.green.shade400
          ..style = PaintingStyle.fill;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: obstacle.size.width,
              height: obstacle.size.height,
            ),
            Radius.circular(obstacle.size.height / 4),
          ),
          paint,
        );

        // Draw arrow
        paint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

        final arrowPath = Path()
          ..moveTo(0, -obstacle.size.height / 3)
          ..lineTo(obstacle.size.width / 4, 0)
          ..lineTo(0, obstacle.size.height / 3)
          ..lineTo(-obstacle.size.width / 4, 0)
          ..close();

        canvas.drawPath(arrowPath, paint);
        break;
    }

    // Restore canvas state
    canvas.restore();
  }

  void _drawCar(Canvas canvas, RaceCar car) {
    // Save canvas state
    canvas.save();

    // Translate to car position and rotate
    canvas.translate(car.position.dx, car.position.dy);
    canvas.rotate(car.angle);

    // Draw car body
    final bodyPaint = Paint()
      ..color = car.color
      ..style = PaintingStyle.fill;

    final carRect = Rect.fromCenter(
      center: Offset.zero,
      width: car.size.width,
      height: car.size.height,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(carRect, Radius.circular(car.size.width / 3)),
      bodyPaint,
    );

    // Draw windows
    final windowPaint = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final windowRect = Rect.fromCenter(
      center: Offset(0, -car.size.height / 6),
      width: car.size.width * 0.7,
      height: car.size.height * 0.25,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(windowRect, Radius.circular(car.size.width / 6)),
      windowPaint,
    );

    // Draw wheels
    final wheelPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Front wheels
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(-car.size.width / 3, -car.size.height / 3),
        width: car.size.width / 6,
        height: car.size.height / 5,
      ),
      wheelPaint,
    );

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(car.size.width / 3, -car.size.height / 3),
        width: car.size.width / 6,
        height: car.size.height / 5,
      ),
      wheelPaint,
    );

    // Rear wheels
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(-car.size.width / 3, car.size.height / 3),
        width: car.size.width / 6,
        height: car.size.height / 5,
      ),
      wheelPaint,
    );

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(car.size.width / 3, car.size.height / 3),
        width: car.size.width / 6,
        height: car.size.height / 5,
      ),
      wheelPaint,
    );

    // Draw headlights
    final headlightPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(-car.size.width / 4, -car.size.height / 2 + 5),
      car.size.width / 10,
      headlightPaint,
    );

    canvas.drawCircle(
      Offset(car.size.width / 4, -car.size.height / 2 + 5),
      car.size.width / 10,
      headlightPaint,
    );

    // Restore canvas state
    canvas.restore();
  }

  void _drawSplash(Canvas canvas, ColorSplash splash) {
    // Draw color splash
    final paint = Paint()
      ..color = splash.color.withOpacity(splash.opacity)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.screen;

    canvas.drawCircle(
      Offset(splash.position.dx, splash.position.dy),
      splash.size,
      paint,
    );

    // Draw splash rays
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      final rayLength = splash.size * 1.5;

      final startPoint = Offset(
        splash.position.dx + cos(angle) * splash.size * 0.7,
        splash.position.dy + sin(angle) * splash.size * 0.7,
      );

      final endPoint = Offset(
        splash.position.dx + cos(angle) * rayLength,
        splash.position.dy + sin(angle) * rayLength,
      );

      final rayPaint = Paint()
        ..color = splash.color.withOpacity(splash.opacity * 0.7)
        ..strokeWidth = 3 * splash.opacity
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(startPoint, endPoint, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RaceTrackPainter oldDelegate) {
    return true; // Always repaint for animation
  }
}

// Helper widget for control instructions
class _ControlInstruction extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ControlInstruction({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
