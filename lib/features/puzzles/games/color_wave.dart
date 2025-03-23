import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/color_models/color_mixer.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:vibration/vibration.dart';

class ColorWaveGame extends ConsumerStatefulWidget {
  final Puzzle puzzle;
  final Color userColor;
  final Function(Color) onColorMixed;

  const ColorWaveGame({
    super.key,
    required this.puzzle,
    required this.userColor,
    required this.onColorMixed,
  });

  @override
  ConsumerState<ColorWaveGame> createState() => _ColorWaveGameState();
}

class _ColorWaveGameState extends ConsumerState<ColorWaveGame> with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _waveAnimationController;
  late AnimationController _transitionController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Game state
  List<ColorWave> _colorWaves = [];
  List<Color> _selectedColors = [];
  Color _resultColor = Colors.white;
  Color _targetGradientStart = Colors.white;
  Color _targetGradientEnd = Colors.white;
  Color _userGradientStart = Colors.white;
  Color _userGradientEnd = Colors.white;
  double _similarity = 0.0;
  int _currentWaveCount = 2;

  // Wave parameters
  double _amplitude = 15.0;
  double _frequency = 1.0;
  double _speed = 0.5;

  // Touch interaction
  ColorWave? _selectedWave;
  bool _isDraggingAmplitude = false;
  bool _isDraggingFrequency = false;

  // Tutorial state
  bool _showTutorial = true;
  int _tutorialStep = 0;

  @override
  void initState() {
    super.initState();

    // Setup animation controllers
    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

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

    // Initialize game
    _initializeGame();

    // Listen to animation updates to recalculate colors
    _waveAnimationController.addListener(_updateMixedColor);
  }

  void _initializeGame() {
    final colors = widget.puzzle.availableColors;
    final random = Random();

    // Generate target gradient colors
    final targetIndex1 = random.nextInt(colors.length);
    int targetIndex2 = random.nextInt(colors.length);
    while (targetIndex2 == targetIndex1 && colors.length > 1) {
      targetIndex2 = random.nextInt(colors.length);
    }

    _targetGradientStart = colors[targetIndex1];
    _targetGradientEnd = colors[targetIndex2];

    // Initialize with 2 waves to start
    _initializeWaves(2);

    // Initially set user gradient same as target (will be replaced when waves are adjusted)
    _userGradientStart = Colors.white;
    _userGradientEnd = Colors.white;
  }

  void _initializeWaves(int count) {
    final random = Random();
    final colors = widget.puzzle.availableColors;

    // Clear existing waves
    _colorWaves = [];
    _selectedColors = [];

    // Create new waves
    for (int i = 0; i < count; i++) {
      final colorIndex = random.nextInt(colors.length);
      final color = colors[colorIndex];

      // Add variation to wave parameters based on level
      final baseAmplitude = _amplitude;
      final baseFrequency = _frequency;
      final baseSpeed = _speed;

      final randomAmplitude = baseAmplitude * (0.7 + random.nextDouble() * 0.6);
      final randomFrequency = baseFrequency * (0.7 + random.nextDouble() * 0.6);
      final randomSpeed = baseSpeed * (0.7 + random.nextDouble() * 0.6);
      final randomPhase = random.nextDouble() * 2 * pi;

      final wave = ColorWave(
        color: color,
        amplitude: randomAmplitude,
        frequency: randomFrequency,
        speed: randomSpeed,
        phase: randomPhase,
      );

      _colorWaves.add(wave);
      _selectedColors.add(color);
    }

    _currentWaveCount = count;
    _selectWave(null);
  }

  @override
  void dispose() {
    _waveAnimationController.dispose();
    _transitionController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _updateMixedColor() {
    if (_colorWaves.isEmpty) {
      setState(() {
        _resultColor = Colors.white;
        _similarity = 0.0;
      });
      widget.onColorMixed(Colors.white);
      return;
    }

    // Calculate mixed color from waves
    // This is a simplified version - in a real implementation,
    // we would calculate the actual color blend at each point
    final colors = _colorWaves.map((wave) => wave.color).toList();
    final mixedColor = ColorMixer.mixSubtractive(colors);

    // Update gradient start/end colors based on wave positions
    // This simulates how the waves would blend at different points
    final firstPeakColor = _colorWaves.isNotEmpty ? _colorWaves.first.color : Colors.white;
    final lastPeakColor = _colorWaves.length > 1 ? _colorWaves.last.color : firstPeakColor;

    setState(() {
      _resultColor = mixedColor;
      _userGradientStart = firstPeakColor;
      _userGradientEnd = lastPeakColor;
    });

    widget.onColorMixed(mixedColor);

    // Calculate similarity based on gradient match
    _calculateGradientSimilarity();
  }

  void _calculateGradientSimilarity() {
    // Calculate similarity between target gradient and user gradient
    // We compare both color endpoints of the gradients

    final startSimilarity = _calculateColorSimilarity(_targetGradientStart, _userGradientStart);
    final endSimilarity = _calculateColorSimilarity(_targetGradientEnd, _userGradientEnd);

    // Overall similarity is the average of start and end similarities
    final overallSimilarity = (startSimilarity + endSimilarity) / 2.0;

    setState(() {
      _similarity = overallSimilarity;
    });
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

  void _selectWave(ColorWave? wave) {
    setState(() {
      _selectedWave = wave;
    });
  }

  void _handlePanStart(DragStartDetails details, ColorWave wave) {
    _selectWave(wave);

    // Determine if dragging amplitude or frequency
    final waveHeight = 100.0; // Height of the wave display area
    final yPosition = details.localPosition.dy;

    if (yPosition < waveHeight / 2) {
      // Dragging the upper half affects amplitude
      setState(() {
        _isDraggingAmplitude = true;
        _isDraggingFrequency = false;
      });
    } else {
      // Dragging the lower half affects frequency
      setState(() {
        _isDraggingAmplitude = false;
        _isDraggingFrequency = true;
      });
    }

    // Progress tutorial if needed
    if (_showTutorial && _tutorialStep == 0) {
      setState(() {
        _tutorialStep = 1;
      });

      // Vibrate to indicate progress
      Vibration.hasVibrator().then((hasVibrator) {
        if (hasVibrator ?? false) {
          Vibration.vibrate(duration: 40, amplitude: 40);
        }
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details, ColorWave wave) {
    if (_selectedWave != wave) return;

    if (_isDraggingAmplitude) {
      // Change amplitude based on vertical drag
      final newAmplitude = wave.amplitude - details.delta.dy / 3;
      setState(() {
        wave.amplitude = newAmplitude.clamp(5.0, 40.0);
      });
    } else if (_isDraggingFrequency) {
      // Change frequency based on horizontal drag
      final newFrequency = wave.frequency + details.delta.dx / 100;
      setState(() {
        wave.frequency = newFrequency.clamp(0.5, 3.0);
      });

      // Progress tutorial if needed
      if (_showTutorial && _tutorialStep == 1) {
        setState(() {
          _tutorialStep = 2;
        });

        // Vibrate to indicate progress
        Vibration.hasVibrator().then((hasVibrator) {
          if (hasVibrator ?? false) {
            Vibration.vibrate(duration: 40, amplitude: 40);
          }
        });
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _isDraggingAmplitude = false;
      _isDraggingFrequency = false;
    });
  }

  void _changeWaveColor(ColorWave wave, Color newColor) {
    setState(() {
      wave.color = newColor;

      // Update selected colors list
      final index = _colorWaves.indexOf(wave);
      if (index >= 0 && index < _selectedColors.length) {
        _selectedColors[index] = newColor;
      }
    });

    // Progress tutorial if needed
    if (_showTutorial && _tutorialStep == 2) {
      setState(() {
        _tutorialStep = 3;
      });

      // Vibrate to indicate progress
      Vibration.hasVibrator().then((hasVibrator) {
        if (hasVibrator ?? false) {
          Vibration.vibrate(duration: 40, amplitude: 40);
        }
      });

      // After all tutorial steps are complete, hide tutorial
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showTutorial = false;
          });
        }
      });
    }
  }

  void _changeWaveSpeed(ColorWave wave, double speedFactor) {
    setState(() {
      wave.speed = (wave.speed * speedFactor).clamp(0.1, 3.0);
    });
  }

  void _addWave() {
    // Only allow up to 4 waves
    if (_colorWaves.length >= 4) return;

    final random = Random();
    final colors = widget.puzzle.availableColors;
    final colorIndex = random.nextInt(colors.length);
    final color = colors[colorIndex];

    final wave = ColorWave(
      color: color,
      amplitude: _amplitude,
      frequency: _frequency,
      speed: _speed,
      phase: random.nextDouble() * 2 * pi,
    );

    setState(() {
      _colorWaves.add(wave);
      _selectedColors.add(color);
      _currentWaveCount++;
      _selectWave(wave);
    });

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 40, amplitude: 100);
      }
    });
  }

  void _removeWave() {
    // Always keep at least one wave
    if (_colorWaves.length <= 1) return;

    setState(() {
      // Remove the selected wave or the last one if none is selected
      if (_selectedWave != null && _colorWaves.contains(_selectedWave)) {
        final index = _colorWaves.indexOf(_selectedWave!);
        _colorWaves.removeAt(index);
        if (_selectedColors.length > index) {
          _selectedColors.removeAt(index);
        }
      } else {
        _colorWaves.removeLast();
        if (_selectedColors.isNotEmpty) {
          _selectedColors.removeLast();
        }
      }

      _currentWaveCount = _colorWaves.length;
      _selectWave(null);
    });

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 40, amplitude: 50);
      }
    });
  }

  void _resetWaves() {
    _initializeWaves(_currentWaveCount);

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 40, amplitude: 80);
      }
    });
  }

  void _showHint() {
    // Show a dialog with hints about how to match the target gradient
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Color Wave Hint'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Try to match these gradient colors:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_targetGradientStart, _targetGradientEnd],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• The wave on the left affects the left side of the gradient'),
              const Text('• The wave on the right affects the right side of the gradient'),
              const Text('• Try matching colors to the target gradient ends'),
              const Text('• Adjust amplitude (top-down) and frequency (left-right)'),
              const SizedBox(height: 16),
              Image.asset(
                'assets/images/wave_hint.png',
                width: 200,
                height: 100,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 200,
                  height: 100,
                  color: Colors.grey[200],
                  child: const Center(child: Text('Wave Diagram')),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Gradient preview section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Target gradient
              _buildGradientPreview(
                'Target Gradient',
                [_targetGradientStart, _targetGradientEnd],
                true,
              ),

              // Similarity indicator
              Column(
                children: [
                  Icon(
                    _similarity >= widget.puzzle.accuracyThreshold ? Icons.check_circle : Icons.compare_arrows,
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

              // Current gradient
              _buildGradientPreview(
                'Your Gradient',
                [_userGradientStart, _userGradientEnd],
                false,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Wave canvas area
        Expanded(
          child: _buildWaveCanvasArea(),
        ),

        const SizedBox(height: 8),

        // Controls for manipulating waves
        _buildWaveControls(),

        const SizedBox(height: 8),

        // Color palette for selected wave
        if (_selectedWave != null) _buildColorPalette(),
      ],
    );
  }

  Widget _buildGradientPreview(String label, List<Color> colors, bool isTarget) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final scale = isTarget && _similarity >= 0.95 ? _pulseAnimation.value : 1.0;
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            width: 120,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaveCanvasArea() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Wave canvas
          SizedBox.expand(
            child: AnimatedBuilder(
              animation: _waveAnimationController,
              builder: (context, _) {
                return CustomPaint(
                  painter: WavePainter(
                    waves: _colorWaves,
                    animationValue: _waveAnimationController.value,
                    selectedWave: _selectedWave,
                  ),
                );
              },
            ),
          ),

          // Interactive wave handlers
          ..._colorWaves.map((wave) => Positioned.fill(
                child: GestureDetector(
                  onPanStart: (details) => _handlePanStart(details, wave),
                  onPanUpdate: (details) => _handlePanUpdate(details, wave),
                  onPanEnd: _handlePanEnd,
                  onTap: () => _selectWave(wave),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              )),

          // Tutorial overlay if needed
          if (_showTutorial) _buildTutorialOverlay(),
        ],
      ),
    );
  }

  Widget _buildTutorialOverlay() {
    String message;
    AlignmentGeometry alignment;

    switch (_tutorialStep) {
      case 0:
        message = 'Tap and drag a wave to start';
        alignment = Alignment.center;
        break;
      case 1:
        message = 'Drag up/down to change amplitude';
        alignment = Alignment.topCenter;
        break;
      case 2:
        message = 'Drag left/right to change frequency';
        alignment = Alignment.center;
        break;
      case 3:
        message = 'Change colors to match the target gradient';
        alignment = Alignment.bottomCenter;
        break;
      default:
        message = '';
        alignment = Alignment.center;
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        alignment: alignment,
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.remove_circle_outline,
            label: 'Remove',
            onPressed: _colorWaves.length > 1 ? _removeWave : null,
          ),
          _buildControlButton(
            icon: Icons.refresh,
            label: 'Reset',
            onPressed: _resetWaves,
          ),
          if (_selectedWave != null) ...[
            _buildControlButton(
              icon: Icons.speed,
              label: 'Slower',
              onPressed: () => _changeWaveSpeed(_selectedWave!, 0.8),
            ),
            _buildControlButton(
              icon: Icons.fast_forward,
              label: 'Faster',
              onPressed: () => _changeWaveSpeed(_selectedWave!, 1.25),
            ),
          ],
          _buildControlButton(
            icon: Icons.add_circle_outline,
            label: 'Add',
            onPressed: _colorWaves.length < 4 ? _addWave : null,
          ),
          _buildControlButton(
            icon: Icons.help_outline,
            label: 'Hint',
            onPressed: _showHint,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: onPressed != null
                ? Theme.of(context).colorScheme.secondaryContainer
                : Theme.of(context).colorScheme.surfaceVariant,
            foregroundColor: onPressed != null
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: onPressed != null
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPalette() {
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
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Wave Color',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              if (_selectedWave != null)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _selectedWave!.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedWave!.color.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.puzzle.availableColors.length,
              itemBuilder: (context, index) {
                final color = widget.puzzle.availableColors[index];
                final bool isSelected = _selectedWave != null && _selectedWave!.color == color;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: GestureDetector(
                    onTap: _selectedWave != null ? () => _changeWaveColor(_selectedWave!, color) : null,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: isSelected ? 2 : 0,
                          ),
                        ],
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

// Wave class to store wave properties
class ColorWave {
  Color color;
  double amplitude;
  double frequency;
  double speed;
  double phase;

  ColorWave({
    required this.color,
    this.amplitude = 15.0,
    this.frequency = 1.0,
    this.speed = 0.5,
    this.phase = 0.0,
  });
}

// Custom painter for drawing waves
class WavePainter extends CustomPainter {
  final List<ColorWave> waves;
  final double animationValue;
  final ColorWave? selectedWave;

  WavePainter({
    required this.waves,
    required this.animationValue,
    this.selectedWave,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.grey.withOpacity(0.1),
    );

    // Draw center line
    final centerLinePaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(width, centerY),
      centerLinePaint,
    );

    // Draw individual waves
    for (int i = 0; i < waves.length; i++) {
      final wave = waves[i];
      _drawWave(canvas, size, wave, animationValue);

      // Add highlight for selected wave
      if (wave == selectedWave) {
        _drawWaveHighlight(canvas, size, wave, animationValue);
      }
    }

    // Draw interactive controls if a wave is selected
    if (selectedWave != null) {
      _drawInteractiveControls(canvas, size, selectedWave!);
    }
  }

  void _drawWave(Canvas canvas, Size size, ColorWave wave, double animationValue) {
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    // Create a path for the wave
    final path = Path();

    // Move to the start point (left edge)
    path.moveTo(0, centerY);

    // Draw the wave points
    for (int x = 0; x <= width; x++) {
      final normalizedX = x / width;
      final wavePhase = wave.phase + (animationValue * wave.speed * 10);

      final y = centerY + sin((normalizedX * wave.frequency * 2 * pi) + wavePhase) * wave.amplitude;
      path.lineTo(x.toDouble(), y);
    }

    // Complete the path by connecting back to bottom
    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    // Draw gradient filling based on wave color
    final gradientPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, centerY),
        Offset(0, height),
        [
          wave.color.withOpacity(0.7),
          wave.color.withOpacity(0.0),
        ],
      );

    canvas.drawPath(path, gradientPaint);

    // Draw the wave line
    final wavePaint = Paint()
      ..color = wave.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Draw just the wave line (not filling to bottom)
    final linePath = Path();
    linePath.moveTo(0, centerY + sin(wave.phase + (animationValue * wave.speed * 10)) * wave.amplitude);

    for (int x = 1; x <= width; x++) {
      final normalizedX = x / width;
      final wavePhase = wave.phase + (animationValue * wave.speed * 10);

      final y = centerY + sin((normalizedX * wave.frequency * 2 * pi) + wavePhase) * wave.amplitude;
      linePath.lineTo(x.toDouble(), y);
    }

    canvas.drawPath(linePath, wavePaint);
  }

  void _drawWaveHighlight(Canvas canvas, Size size, ColorWave wave, double animationValue) {
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    // Create a path for the highlight around the wave
    final path = Path();
    path.moveTo(0, centerY + sin(wave.phase + (animationValue * wave.speed * 10)) * wave.amplitude);

    for (int x = 1; x <= width; x++) {
      final normalizedX = x / width;
      final wavePhase = wave.phase + (animationValue * wave.speed * 10);

      final y = centerY + sin((normalizedX * wave.frequency * 2 * pi) + wavePhase) * wave.amplitude;
      path.lineTo(x.toDouble(), y);
    }

    // Highlighted outline
    final highlightPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, highlightPaint);
  }

  void _drawInteractiveControls(Canvas canvas, Size size, ColorWave wave) {
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    // Draw amplitude handle (vertical)
    final amplitudeHandleY = centerY - wave.amplitude - 20;
    final amplitudeHandlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(width / 2, amplitudeHandleY),
      10,
      amplitudeHandlePaint,
    );

    // Draw outline for amplitude handle
    final amplitudeOutlinePaint = Paint()
      ..color = wave.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(
      Offset(width / 2, amplitudeHandleY),
      10,
      amplitudeOutlinePaint,
    );

    // Draw arrow indicating amplitude
    canvas.drawLine(
      Offset(width / 2, centerY),
      Offset(width / 2, amplitudeHandleY),
      Paint()
        ..color = wave.color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Draw vertical label for amplitude
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Amplitude',
        style: TextStyle(
          color: wave.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(width / 2 - textPainter.width / 2, amplitudeHandleY - 30),
    );

    // Draw frequency handle (horizontal)
    final frequencyHandleX = wave.frequency * width / 3;
    final frequencyHandlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(frequencyHandleX, height - 20),
      10,
      frequencyHandlePaint,
    );

    // Draw outline for frequency handle
    final frequencyOutlinePaint = Paint()
      ..color = wave.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(
      Offset(frequencyHandleX, height - 20),
      10,
      frequencyOutlinePaint,
    );

    // Draw horizontal label for frequency
    final freqTextPainter = TextPainter(
      text: TextSpan(
        text: 'Frequency',
        style: TextStyle(
          color: wave.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    freqTextPainter.layout();
    freqTextPainter.paint(
      canvas,
      Offset(frequencyHandleX - freqTextPainter.width / 2, height - 50),
    );
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.waves != waves ||
        oldDelegate.selectedWave != selectedWave;
  }
}
