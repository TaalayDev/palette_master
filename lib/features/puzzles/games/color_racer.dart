import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/color_models/color_mixer.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:palette_master/features/puzzles/widgets/color_preview.dart';
import 'package:vibration/vibration.dart';

class ColorRacerGame extends ConsumerStatefulWidget {
  final Puzzle puzzle;
  final Color userColor;
  final Function(Color) onColorMixed;

  const ColorRacerGame({
    super.key,
    required this.puzzle,
    required this.userColor,
    required this.onColorMixed,
  });

  @override
  ConsumerState<ColorRacerGame> createState() => _ColorRacerGameState();
}

class _ColorRacerGameState extends ConsumerState<ColorRacerGame> with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _gameLoopController;
  late AnimationController _introAnimationController;
  late Animation<double> _introAnimation;

  // Game state
  final _random = Random();
  List<ColorGate> _gates = [];
  List<PowerUp> _powerUps = [];
  List<ColorSwatch> _swatches = [];
  List<Color> _selectedColors = [];

  // Player state
  late Racer _racer;
  double _score = 0;
  double _timeRemaining = 60.0;
  bool _gameOver = false;
  bool _gameStarted = false;
  bool _countdownActive = false;
  int _countdownValue = 3;
  int _gatesPassed = 0;

  // Track parameters
  late Size _trackSize;
  late double _trackLength;
  double _trackScrollPosition = 0;
  double _scrollSpeed = 2.0;

  // Colors and mixing
  Color _racerColor = Colors.white;
  double _similarity = 0.0;
  double _maxSimilarityAchieved = 0.0;
  double _colorMixTimeout = 0;

  // Touch handling
  Offset? _lastDragPosition;

  // Tutorial state
  bool _showTutorial = true;
  int _tutorialStep = 0;
  String _statusMessage = '';
  Color _statusColor = Colors.white;

  @override
  void initState() {
    super.initState();

    // Setup animation controllers
    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_gameLoop);

    _introAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _introAnimation = CurvedAnimation(
      parent: _introAnimationController,
      curve: Curves.easeOutBack,
    );

    // Initialize game
    _initializeGame();

    // Start intro animation
    _introAnimationController.forward();

    // Delayed start to allow player to get ready
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _countdownActive = true;
        });

        _startCountdown();
      }
    });
  }

  void _initializeGame() {
    // Calculate track size based on screen dimensions (will be updated in build)
    _trackSize = Size(300, 500);
    _trackLength = 5000; // Total length of the track

    // Initialize racer
    _racer = Racer(
      position: Offset(_trackSize.width / 2, _trackSize.height * 0.75),
      size: const Size(50, 80),
      color: Colors.white,
    );

    // Create initial gates
    _createInitialGates();

    // Create color swatches from available colors
    _createColorSwatches();

    // Set initial user color
    _racerColor = Colors.white;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onColorMixed(_racerColor);
    });
  }

  void _createInitialGates() {
    _gates = [];

    // Distance between gates increases with level difficulty
    double gateSpacing = 250 - (widget.puzzle.level * 5).clamp(0, 150).toDouble();
    double minGateWidth = 100 - (widget.puzzle.level * 2).clamp(0, 50).toDouble();

    // Create gates along the track
    for (int i = 0; i < 20; i++) {
      final gatePosition = 300.0 + (i * gateSpacing);
      final gateWidth = minGateWidth + _random.nextDouble() * 80;

      // Choose a color for the gate
      // Lower levels use primary or secondary colors, higher levels use more complex mixes
      Color gateColor;

      if (widget.puzzle.level <= 3 || i < 2) {
        // Simple colors for early gates or lower levels
        gateColor = widget.puzzle.availableColors[_random.nextInt(widget.puzzle.availableColors.length)];
      } else {
        // Mix colors for more complex gates
        final colorCount = 2 + (_random.nextInt(widget.puzzle.level ~/ 3).clamp(0, 2));
        List<Color> mixColors = [];

        for (int c = 0; c < colorCount; c++) {
          mixColors.add(widget.puzzle.availableColors[_random.nextInt(widget.puzzle.availableColors.length)]);
        }

        gateColor = ColorMixer.mixSubtractive(mixColors);
      }

      final gate = ColorGate(
        position: Offset((_trackSize.width - gateWidth) / 2, gatePosition),
        size: Size(gateWidth, 20),
        color: gateColor,
      );

      _gates.add(gate);
    }

    // Add some power-ups
    _powerUps = [];

    for (int i = 0; i < 10; i++) {
      final yPos = 600.0 + (i * gateSpacing * 1.5);
      final xPos = 50 + _random.nextDouble() * (_trackSize.width - 100);

      PowerUpType type;
      if (_random.nextDouble() > 0.7) {
        type = PowerUpType.timeBonus;
      } else if (_random.nextDouble() > 0.5) {
        type = PowerUpType.speedBoost;
      } else {
        type = PowerUpType.colorHint;
      }

      final powerUp = PowerUp(
        position: Offset(xPos, yPos),
        type: type,
      );

      _powerUps.add(powerUp);
    }
  }

  void _createColorSwatches() {
    _swatches = [];

    // Create a swatch for each available color
    for (final color in widget.puzzle.availableColors) {
      _swatches.add(
        ColorSwatch(
          color: color,
          isSelected: false,
        ),
      );
    }
  }

  void _startCountdown() {
    // Countdown timer before starting game
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _countdownValue--;
        });

        // Provide feedback
        Vibration.hasVibrator().then((hasVibrator) {
          if (hasVibrator ?? false) {
            Vibration.vibrate(duration: 50, amplitude: 100);
          }
        });

        if (_countdownValue <= 0) {
          timer.cancel();
          _startGame();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _startGame() {
    setState(() {
      _gameStarted = true;
      _countdownActive = false;
    });

    // Start game loop
    _gameLoopController.repeat();

    // Show first tutorial message if needed
    if (_showTutorial) {
      _showStatusMessage('Mix colors to match the gates!', Colors.white);

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _showTutorial) {
          _showStatusMessage('Drag left & right to steer', Colors.white);
          setState(() {
            _tutorialStep = 1;
          });
        }
      });
    }
  }

  void _gameLoop() {
    if (!_gameStarted || _gameOver) return;

    // Update time
    setState(() {
      _timeRemaining -= 0.016; // Roughly 60fps

      if (_timeRemaining <= 0) {
        _endGame();
      }
    });

    // // Move track (scroll gates and power-ups)
    _updateTrackPosition();

    // // Check collisions with gates and power-ups
    _checkCollisions();

    // // Update color mix timeout
    if (_colorMixTimeout > 0) {
      setState(() {
        _colorMixTimeout -= 0.016;
      });
    }
  }

  void _updateTrackPosition() {
    // Scroll the track based on speed
    setState(() {
      _trackScrollPosition += _scrollSpeed;

      // Move racer slightly forward if not at position
      if (_racer.position.dy > _trackSize.height * 0.75) {
        _racer.position = Offset(_racer.position.dx, _racer.position.dy - 1);
      } else if (_racer.position.dy < _trackSize.height * 0.75) {
        _racer.position = Offset(_racer.position.dx, _racer.position.dy + 1);
      }
    });
  }

  void _checkCollisions() {
    // Check gates
    for (final gate in _gates) {
      // Adjust gate position for scrolling
      final gateY = gate.position.dy - _trackScrollPosition;

      // Check if racer is passing through the gate
      if (gateY >= _racer.position.dy - _racer.size.height / 2 && gateY <= _racer.position.dy && !gate.passed) {
        // Check if racer is within gate horizontally
        final racerLeft = _racer.position.dx - _racer.size.width / 2;
        final racerRight = _racer.position.dx + _racer.size.width / 2;
        final gateLeft = gate.position.dx;
        final gateRight = gate.position.dx + gate.size.width;

        if (racerRight >= gateLeft && racerLeft <= gateRight) {
          // Calculate color similarity
          final similarity = _calculateColorSimilarity(_racerColor, gate.color);

          // Record highest similarity achieved
          if (similarity > _maxSimilarityAchieved) {
            _maxSimilarityAchieved = similarity;
          }

          // // Gate passed, check color match
          if (similarity >= widget.puzzle.accuracyThreshold) {
            // Successful match
            _handleGateSuccess(gate, similarity);
          } else {
            // Failed match
            _handleGateFailure(gate, similarity);
          }

          //  Mark gate as passed
          // WidgetsBinding.instance.addPostFrameCallback((_) {
          //   setState(() {
          //     gate.passed = true;
          //     _gatesPassed++;
          //   });
          // });
          // setState(() {
          //   gate.passed = true;
          //   _gatesPassed++;
          // });

          // // Update color for puzzle completion
          widget.onColorMixed(gate.color);

          // // Show tutorial message if needed
          if (_showTutorial && _tutorialStep == 1) {
            setState(() {
              _tutorialStep = 2;
            });
            _showStatusMessage('Use color swatches to mix colors', Colors.white);
          }
        }
      }
    }

    // Check power-ups
    for (final powerUp in List<PowerUp>.from(_powerUps)) {
      if (powerUp.collected) continue;

      // Adjust power-up position for scrolling
      final powerUpY = powerUp.position.dy - _trackScrollPosition;

      // Check if racer is collecting the power-up
      if ((powerUpY - _racer.position.dy).abs() < 40 && (powerUp.position.dx - _racer.position.dx).abs() < 40) {
        // Collect power-up
        setState(() {
          powerUp.collected = true;
        });

        // Apply power-up effect
        _applyPowerUp(powerUp);
      }
    }
  }

  double _calculateColorSimilarity(Color a, Color b) {
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

    return similarity;
  }

  void _handleGateSuccess(ColorGate gate, double similarity) {
    // Calculate points based on similarity
    final basePoints = 100.0 * similarity;
    final timeBonus = (_timeRemaining / 10.0).clamp(1.0, 6.0);
    final totalPoints = basePoints * timeBonus;

    setState(() {
      _score += totalPoints.roundToDouble();
      _scrollSpeed += 0.1; // Speed up a bit for each successful gate
      _scrollSpeed = _scrollSpeed.clamp(1.0, 8.0); // Cap max speed
    });

    // Show success message
    _showStatusMessage('Perfect Match! +${totalPoints.round()}', Colors.green);

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 100, amplitude: 150);
      }
    });
  }

  void _handleGateFailure(ColorGate gate, double similarity) {
    // Calculate penalty based on how far off the match was
    final penalty = 5.0 * (1.0 - similarity);

    setState(() {
      _timeRemaining -= penalty;
      _scrollSpeed *= 0.8; // Slow down a bit
      _scrollSpeed = _scrollSpeed.clamp(1.0, 8.0);
    });

    // Show failure message
    _showStatusMessage('Wrong Color! -${penalty.round()}s', Colors.red);

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 200, amplitude: 100);
      }
    });
  }

  void _applyPowerUp(PowerUp powerUp) {
    switch (powerUp.type) {
      case PowerUpType.timeBonus:
        setState(() {
          _timeRemaining += 5.0;
        });
        _showStatusMessage('+5 Seconds!', Colors.blue);
        break;

      case PowerUpType.speedBoost:
        setState(() {
          _scrollSpeed *= 1.5;
        });
        _showStatusMessage('Speed Boost!', Colors.orange);

        // Reset speed after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _gameStarted && !_gameOver) {
            setState(() {
              _scrollSpeed /= 1.5;
            });
          }
        });
        break;

      case PowerUpType.colorHint:
        // Find the next gate that hasn't been passed
        ColorGate? nextGate;
        for (final gate in _gates) {
          if (!gate.passed) {
            nextGate = gate;
            break;
          }
        }

        if (nextGate != null) {
          _showStatusMessage('Next Gate: Match this color!', nextGate.color);

          // Temporarily show the gate's color on the racer
          setState(() {
            _racer.hintColor = nextGate?.color;
          });

          // Reset hint after 2 seconds
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _racer.hintColor = null;
              });
            }
          });
        }
        break;
    }

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 50, amplitude: 150);
      }
    });
  }

  void _showStatusMessage(String message, Color color) {
    setState(() {
      _statusMessage = message;
      _statusColor = color;
    });

    // Clear message after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _statusMessage == message) {
        setState(() {
          _statusMessage = '';
        });
      }
    });
  }

  void _handleColorSwatchTap(ColorSwatch swatch) {
    if (_colorMixTimeout > 0) return; // Prevent rapid mixing

    setState(() {
      // Toggle selection
      swatch.isSelected = !swatch.isSelected;

      // Update selected colors
      if (swatch.isSelected) {
        _selectedColors.add(swatch.color);
      } else {
        _selectedColors.remove(swatch.color);
      }

      // Mix colors
      if (_selectedColors.isEmpty) {
        _racerColor = Colors.white;
      } else if (_selectedColors.length == 1) {
        _racerColor = _selectedColors.first;
      } else {
        _racerColor = ColorMixer.mixSubtractive(_selectedColors);
      }

      // Update racer color
      _racer.color = _racerColor;

      // Set cooldown for color mixing (prevents rapid changes)
      _colorMixTimeout = 0.2;
    });

    // Update widget color
    widget.onColorMixed(_racerColor);

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 20, amplitude: 40);
      }
    });
  }

  void _handleRacerDrag(DragUpdateDetails details) {
    if (!_gameStarted || _gameOver) return;

    setState(() {
      // Move racer horizontally
      _racer.position = Offset(
        (_racer.position.dx + details.delta.dx).clamp(
          _racer.size.width / 2,
          _trackSize.width - _racer.size.width / 2,
        ),
        _racer.position.dy,
      );

      // Store last drag position for inertia
      _lastDragPosition = details.globalPosition;
    });
  }

  void _handleRacerDragEnd(DragEndDetails details) {
    // Apply slight inertia
    _lastDragPosition = null;
  }

  void _endGame() {
    if (_gameOver) return;

    // Stop game loop
    _gameLoopController.stop();

    setState(() {
      _gameOver = true;
      _gameStarted = false;
      _timeRemaining = 0;
    });

    // Update similarity for puzzle completion based on max achieved
    _calculateColorSimilarity(
      widget.puzzle.targetColor,
      Color.lerp(Colors.white, widget.puzzle.targetColor, _maxSimilarityAchieved) ?? Colors.white,
    );

    // Show game over dialog after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _showGameOverDialog();
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Race Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score: ${_score.round()}'),
            const SizedBox(height: 8),
            Text('Gates Passed: $_gatesPassed'),
            const SizedBox(height: 8),
            Text(
              'Best Color Match: ${(_maxSimilarityAchieved * 100).round()}%',
              style: TextStyle(
                color: _getSimilarityColor(_maxSimilarityAchieved),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You\'ve learned how to quickly mix colors to match targets - a valuable color theory skill!',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartGame();
            },
            child: const Text('Play Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _restartGame() {
    setState(() {
      // Reset game state
      _score = 0;
      _timeRemaining = 60.0;
      _gameOver = false;
      _trackScrollPosition = 0;
      _scrollSpeed = 2.0;
      _gatesPassed = 0;
      _maxSimilarityAchieved = 0.0;
      _showTutorial = false;

      // Reinitialize game components
      _initializeGame();

      // Start countdown
      _countdownActive = true;
      _countdownValue = 3;
    });

    _startCountdown();
  }

  @override
  void dispose() {
    _gameLoopController.dispose();
    _introAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Update track size based on actual screen size
    final screenSize = MediaQuery.of(context).size;
    _trackSize = Size(screenSize.width - 32, screenSize.height * 0.6);

    return AnimatedBuilder(
      animation: _introAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _introAnimation.value,
          child: Column(
            children: [
              // Game status area
              _buildGameStatusArea(),

              const SizedBox(height: 8),

              // Race track area
              Expanded(
                child: _buildRaceTrack(),
              ),

              const SizedBox(height: 8),

              // Color mixing controls
              _buildColorControls(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGameStatusArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Score and time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Score
              Row(
                children: [
                  Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 24,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Score: ${_score.round()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),

              // Gates passed
              Text(
                'Gates: $_gatesPassed',
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),

              // Time remaining
              Row(
                children: [
                  Icon(
                    Icons.timer,
                    color: _timeRemaining < 10 ? Colors.red : Colors.blue,
                    size: 24,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_timeRemaining.toStringAsFixed(1)}s',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _timeRemaining < 10 ? Colors.red : null,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Current status message
          if (_statusMessage.isNotEmpty || _countdownActive)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              decoration: BoxDecoration(
                color: _countdownActive ? Colors.blue.withOpacity(0.2) : _statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _countdownActive ? 'Starting in: $_countdownValue' : _statusMessage,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _countdownActive ? Colors.blue : _statusColor,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRaceTrack() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Track background
          CustomPaint(
            size: _trackSize,
            painter: TrackPainter(
              scrollPosition: _trackScrollPosition,
              trackLength: _trackLength,
            ),
          ),

          // Color gates
          ..._gates.map((gate) {
            final gateY = gate.position.dy - _trackScrollPosition;

            // Only show gates within visible area
            if (gateY < -50 || gateY > _trackSize.height + 50) {
              return const SizedBox.shrink();
            }

            return Positioned(
              left: gate.position.dx,
              top: gateY,
              child: Container(
                width: gate.size.width,
                height: gate.size.height,
                decoration: BoxDecoration(
                  color: gate.color,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: gate.color.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: gate.passed
                    ? Icon(
                        gate.passed &&
                                _calculateColorSimilarity(gate.color, _racerColor) >= widget.puzzle.accuracyThreshold
                            ? Icons.check
                            : Icons.close,
                        color: Colors.white,
                      )
                    : null,
              ),
            );
          }),

          // Power-ups
          ..._powerUps.map((powerUp) {
            if (powerUp.collected) return const SizedBox.shrink();

            final powerUpY = powerUp.position.dy - _trackScrollPosition;

            // Only show power-ups within visible area
            if (powerUpY < -50 || powerUpY > _trackSize.height + 50) {
              return const SizedBox.shrink();
            }

            return Positioned(
              left: powerUp.position.dx - 15,
              top: powerUpY - 15,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _getPowerUpColor(powerUp.type),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getPowerUpColor(powerUp.type).withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _getPowerUpIcon(powerUp.type),
                  color: Colors.white,
                  size: 18,
                ),
              ),
            );
          }),

          // Player's racer
          GestureDetector(
            onHorizontalDragUpdate: _handleRacerDrag,
            onHorizontalDragEnd: _handleRacerDragEnd,
            child: Container(
              color: Colors.transparent,
              width: _trackSize.width,
              height: _trackSize.height,
              child: Stack(
                children: [
                  Positioned(
                    left: _racer.position.dx - _racer.size.width / 2,
                    top: _racer.position.dy - _racer.size.height / 2,
                    child: CustomPaint(
                      size: _racer.size,
                      painter: RacerPainter(
                        color: _racer.color,
                        hintColor: _racer.hintColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Countdown overlay
          if (_countdownActive)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Text(
                        '$_countdownValue',
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Game over overlay
          if (_gameOver)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Race Complete!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Score: ${_score.round()}',
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColorControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
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
          // Current mix preview
          Row(
            children: [
              // Color preview
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _racerColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _racerColor.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
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
                      'Current Mix',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Tap colors below to mix',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Clear selection button
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    for (final swatch in _swatches) {
                      swatch.isSelected = false;
                    }
                    _selectedColors = [];
                    _racerColor = Colors.white;
                    _racer.color = Colors.white;
                  });

                  widget.onColorMixed(_racerColor);
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Color swatches
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _swatches.length,
              itemBuilder: (context, index) {
                final swatch = _swatches[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: GestureDetector(
                    onTap: () => _handleColorSwatchTap(swatch),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: swatch.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: swatch.isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: swatch.color.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: swatch.isSelected ? 2 : 0,
                          ),
                        ],
                      ),
                      child: swatch.isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
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

  Color _getPowerUpColor(PowerUpType type) {
    switch (type) {
      case PowerUpType.timeBonus:
        return Colors.blue;
      case PowerUpType.speedBoost:
        return Colors.orange;
      case PowerUpType.colorHint:
        return Colors.purple;
    }
  }

  IconData _getPowerUpIcon(PowerUpType type) {
    switch (type) {
      case PowerUpType.timeBonus:
        return Icons.timer;
      case PowerUpType.speedBoost:
        return Icons.speed;
      case PowerUpType.colorHint:
        return Icons.palette;
    }
  }

  Color _getSimilarityColor(double similarity) {
    if (similarity >= widget.puzzle.accuracyThreshold) {
      return Colors.green;
    } else if (similarity >= 0.8) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

// Helper classes for game objects

class Racer {
  Offset position;
  Size size;
  Color color;
  Color? hintColor;

  Racer({
    required this.position,
    required this.size,
    required this.color,
    this.hintColor,
  });
}

class ColorGate {
  Offset position;
  Size size;
  Color color;
  bool passed;

  ColorGate({
    required this.position,
    required this.size,
    required this.color,
    this.passed = false,
  });
}

enum PowerUpType {
  timeBonus,
  speedBoost,
  colorHint,
}

class PowerUp {
  Offset position;
  PowerUpType type;
  bool collected;

  PowerUp({
    required this.position,
    required this.type,
    this.collected = false,
  });
}

class ColorSwatch {
  Color color;
  bool isSelected;

  ColorSwatch({
    required this.color,
    required this.isSelected,
  });
}

// Custom painters

class TrackPainter extends CustomPainter {
  final double scrollPosition;
  final double trackLength;

  TrackPainter({
    required this.scrollPosition,
    required this.trackLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Draw track background
    final backgroundPaint = Paint()..color = Colors.grey.shade900;

    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), backgroundPaint);

    // Draw center line
    final linePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Draw dashed line
    final lineY = scrollPosition % 40;
    for (double y = -lineY; y < height; y += 40) {
      canvas.drawLine(
        Offset(width / 2, y),
        Offset(width / 2, y + 20),
        linePaint,
      );
    }

    // Draw side lines
    final sidePaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    // Left side line
    canvas.drawLine(
      const Offset(30, 0),
      Offset(30, height),
      sidePaint,
    );

    // Right side line
    canvas.drawLine(
      Offset(width - 30, 0),
      Offset(width - 30, height),
      sidePaint,
    );

    // Draw finish line if near end
    final distanceToEnd = trackLength - scrollPosition;
    if (distanceToEnd >= 0 && distanceToEnd <= height) {
      final finishPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;

      // Draw checkered pattern
      for (int i = 0; i < width ~/ 20; i++) {
        if (i % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(i * 20.0, distanceToEnd, 20, 20),
            Paint()..color = Colors.white,
          );
          canvas.drawRect(
            Rect.fromLTWH(i * 20.0, distanceToEnd + 20, 20, 20),
            Paint()..color = Colors.black,
          );
        } else {
          canvas.drawRect(
            Rect.fromLTWH(i * 20.0, distanceToEnd, 20, 20),
            Paint()..color = Colors.black,
          );
          canvas.drawRect(
            Rect.fromLTWH(i * 20.0, distanceToEnd + 20, 20, 20),
            Paint()..color = Colors.white,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant TrackPainter oldDelegate) {
    return oldDelegate.scrollPosition != scrollPosition;
  }
}

class RacerPainter extends CustomPainter {
  final Color color;
  final Color? hintColor;

  RacerPainter({
    required this.color,
    this.hintColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Draw racer body (using a car-like shape)
    final bodyPath = Path();

    // Car body
    bodyPath.moveTo(width * 0.2, height * 0.8);
    bodyPath.lineTo(width * 0.2, height * 0.5);
    bodyPath.quadraticBezierTo(width * 0.2, height * 0.3, width * 0.3, height * 0.2);
    bodyPath.lineTo(width * 0.7, height * 0.2);
    bodyPath.quadraticBezierTo(width * 0.8, height * 0.3, width * 0.8, height * 0.5);
    bodyPath.lineTo(width * 0.8, height * 0.8);
    bodyPath.close();

    // Draw body with color or hint color
    final bodyPaint = Paint()
      ..color = hintColor ?? color
      ..style = PaintingStyle.fill;

    canvas.drawPath(bodyPath, bodyPaint);

    // Add highlights
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(width * 0.35, height * 0.3),
      width * 0.1,
      highlightPaint,
    );

    // Draw outline
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(bodyPath, outlinePaint);

    // Draw wheels
    final wheelPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Left wheels
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(width * 0.1, height * 0.3, width * 0.1, height * 0.2),
        const Radius.circular(4),
      ),
      wheelPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(width * 0.1, height * 0.6, width * 0.1, height * 0.2),
        const Radius.circular(4),
      ),
      wheelPaint,
    );

    // Right wheels
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(width * 0.8, height * 0.3, width * 0.1, height * 0.2),
        const Radius.circular(4),
      ),
      wheelPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(width * 0.8, height * 0.6, width * 0.1, height * 0.2),
        const Radius.circular(4),
      ),
      wheelPaint,
    );

    // If showing hint, add a pulsing effect
    if (hintColor != null) {
      final hintPaint = Paint()
        ..color = hintColor!.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;

      canvas.drawPath(bodyPath, hintPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RacerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.hintColor != hintColor;
  }
}
