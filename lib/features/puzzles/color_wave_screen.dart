import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_master/core/constants/app_constants.dart';
import 'package:palette_master/features/puzzles/games/color_wave.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:palette_master/features/puzzles/providers/puzzle_provider.dart';
import 'package:palette_master/features/puzzles/widgets/level_completion_animation.dart';
import 'package:palette_master/router/routes.dart';
import 'package:vibration/vibration.dart';
import 'dart:math';

class ColorWaveScreen extends ConsumerStatefulWidget {
  final String puzzleId;
  final int level;

  const ColorWaveScreen({
    super.key,
    required this.puzzleId,
    required this.level,
  });

  @override
  ConsumerState<ColorWaveScreen> createState() => _ColorWaveScreenState();
}

class _ColorWaveScreenState extends ConsumerState<ColorWaveScreen> with TickerProviderStateMixin {
  bool _showLevelComplete = false;
  int _attempts = 0;
  bool _showHint = false;

  // Animation controllers
  late AnimationController _bgWaveController;
  late AnimationController _bgGradientController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Background waves
  List<_BackgroundWave> _backgroundWaves = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Background wave animation
    _bgWaveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Background gradient animation
    _bgGradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    // Pulse animation for UI elements
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

    // Generate background waves
    _generateBackgroundWaves();
  }

  void _generateBackgroundWaves() {
    _backgroundWaves = List.generate(3, (index) {
      return _BackgroundWave(
        color: HSVColor.fromAHSV(
          0.3 + (_random.nextDouble() * 0.2),
          (120.0 * index) % 360, // Evenly spaced hues
          0.7,
          0.9,
        ).toColor(),
        amplitude: 30 + _random.nextDouble() * 20,
        frequency: 0.5 + _random.nextDouble() * 0.5,
        speed: 0.2 + _random.nextDouble() * 0.3,
        phase: _random.nextDouble() * 2 * pi,
      );
    });
  }

  @override
  void dispose() {
    _bgWaveController.dispose();
    _bgGradientController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _checkResult(BuildContext context, Puzzle puzzle) {
    final userColor = ref.read(userMixedColorProvider);

    setState(() {
      _attempts++;
    });

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 50, amplitude: 100);
      }
    });

    ref
        .read(puzzleResultProvider.notifier)
        .checkResult(userColor, puzzle.targetColor, puzzle.accuracyThreshold)
        .then((success) {
      if (success) {
        _handleSuccess();
      } else if (_attempts >= puzzle.maxAttempts) {
        _handleFailure();
      } else {
        // Show feedback for wave mismatch
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Waves not aligned yet. Adjust their properties to match the target gradient!',
              style: TextStyle(color: Colors.teal.shade100),
            ),
            backgroundColor: Colors.teal.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    });
  }

  void _handleSuccess() {
    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 200, amplitude: 200);
      }
    });

    // Update progress
    ref.read(gameProgressProvider.notifier).updateProgress(widget.puzzleId, widget.level + 1);

    // Show level complete animation
    setState(() {
      _showLevelComplete = true;
    });
  }

  void _handleFailure() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A2F35),
        title: Text(
          'Waves Out of Sync',
          style: TextStyle(color: Colors.teal.shade200),
        ),
        content: const Text(
          'You\'ve reached the maximum number of attempts. Would you like to retry creating the wave pattern?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.gameSelection.path);
            },
            child: Text('Back to Games', style: TextStyle(color: Colors.teal.shade200)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _attempts = 0;
              });
              ref.read(userMixedColorProvider.notifier).reset();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
            ),
            child: const Text('Retry'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  void _nextLevel() {
    final int nextLevel = widget.level + 1;
    context.pushReplacementNamed(
      AppRoutes.colorWave.name,
      queryParameters: {
        'id': widget.puzzleId,
        'level': nextLevel.toString(),
      },
    );
  }

  void _resetLevel() {
    setState(() {
      _attempts = 0;
      _showHint = false;
    });
    ref.read(userMixedColorProvider.notifier).reset();
  }

  void _toggleHint() {
    setState(() {
      _showHint = !_showHint;
    });
  }

  @override
  Widget build(BuildContext context) {
    final puzzleAsync = ref.watch(puzzleStateProvider(widget.puzzleId, widget.level));
    final userColor = ref.watch(userMixedColorProvider);
    final resultAsync = ref.watch(puzzleResultProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.waves, color: Colors.teal.shade200),
            const SizedBox(width: 8),
            Text(
              'Color Wave - Level ${widget.level}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade200,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.teal.shade200),
            onPressed: _toggleHint,
            tooltip: 'Show Hint',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.teal.shade200),
            onPressed: _resetLevel,
            tooltip: 'Reset Level',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_bgWaveController, _bgGradientController]),
        builder: (context, child) {
          return Stack(
            children: [
              // Animated gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      HSVColor.fromAHSV(
                        1.0,
                        (_bgGradientController.value * 360) % 360,
                        0.3,
                        0.2,
                      ).toColor(),
                      HSVColor.fromAHSV(
                        1.0,
                        ((_bgGradientController.value * 360) + 60) % 360,
                        0.3,
                        0.3,
                      ).toColor(),
                    ],
                  ),
                ),
              ),

              // Background waves
              CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _BackgroundWavePainter(
                  waves: _backgroundWaves,
                  animationValue: _bgWaveController.value,
                ),
              ),

              // Main content
              SafeArea(
                child: child!,
              ),
            ],
          );
        },
        child: puzzleAsync.when(
          data: (puzzle) {
            if (puzzle == null) {
              return const Center(child: Text('Puzzle not found'));
            }

            return Stack(
              children: [
                // Main game content
                Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Wave-themed header
                      _buildWaveHeader(context, puzzle, userColor),

                      const SizedBox(height: 16),

                      // Game area
                      Expanded(
                        child: Hero(
                          tag: 'wave-game',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.teal.shade200.withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: ColorWaveGame(
                                  puzzle: puzzle,
                                  userColor: userColor,
                                  onColorMixed: (color) {
                                    ref.read(userMixedColorProvider.notifier).setColor(color);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action buttons
                      _buildActionButtons(context, puzzle, resultAsync),
                    ],
                  ),
                ),

                // Hint overlay
                if (_showHint) _buildHintOverlay(context, puzzle),

                // Level complete overlay
                if (_showLevelComplete)
                  LevelCompletionAnimation(
                    onComplete: _nextLevel,
                    primaryColor: puzzle.targetColor,
                    secondaryColor: userColor,
                  ),
              ],
            );
          },
          loading: () => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade200),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Generating Waves...',
                  style: TextStyle(
                    color: Colors.teal.shade200,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          error: (error, stackTrace) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red.shade300,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Game',
                  style: TextStyle(
                    color: Colors.teal.shade200,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go(AppRoutes.gameSelection.path),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Games'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaveHeader(BuildContext context, Puzzle puzzle, Color userColor) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.teal.shade200.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              children: [
                // Title and description
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.waves,
                        color: Colors.teal.shade200,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            puzzle.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade200,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            puzzle.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Gradient preview
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Target gradient
                    Column(
                      children: [
                        Text(
                          'Target Gradient',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade200,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 120,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [puzzle.availableColors[0], puzzle.targetColor],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Similarity indicator
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _getSimilarityColor(userColor, puzzle.targetColor, puzzle.accuracyThreshold)
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getSimilarityColor(userColor, puzzle.targetColor, puzzle.accuracyThreshold),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _similarity(userColor, puzzle.targetColor) >= puzzle.accuracyThreshold
                                    ? Icons.check_circle
                                    : Icons.waves,
                                color: _getSimilarityColor(userColor, puzzle.targetColor, puzzle.accuracyThreshold),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(_similarity(userColor, puzzle.targetColor) * 100).toInt()}%',
                                style: TextStyle(
                                  color: _getSimilarityColor(userColor, puzzle.targetColor, puzzle.accuracyThreshold),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Attempts: $_attempts/${puzzle.maxAttempts}',
                          style: TextStyle(
                            fontSize: 14,
                            color: _attempts >= puzzle.maxAttempts * 0.7 ? Colors.red.shade300 : Colors.white70,
                          ),
                        ),
                      ],
                    ),

                    // Your gradient
                    Column(
                      children: [
                        Text(
                          'Your Gradient',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade200,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 120,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [puzzle.availableColors.last, userColor],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _similarity(Color a, Color b) {
    // Calculate color similarity (normalized between 0 and 1)
    final dr = (a.red - b.red) / 255.0;
    final dg = (a.green - b.green) / 255.0;
    final db = (a.blue - b.blue) / 255.0;

    // Human eyes are more sensitive to green, less to blue
    final distance = (dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11);
    return (1.0 - sqrt(distance)).clamp(0.0, 1.0);
  }

  Color _getSimilarityColor(Color userColor, Color targetColor, double threshold) {
    final similarity = _similarity(userColor, targetColor);
    if (similarity >= threshold) {
      return Colors.green;
    } else if (similarity >= 0.7) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildActionButtons(BuildContext context, Puzzle puzzle, AsyncValue<bool?> resultAsync) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _resetLevel,
          icon: const Icon(Icons.refresh),
          label: const Text('Reset'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black.withOpacity(0.3),
            foregroundColor: Colors.teal.shade200,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: resultAsync.isLoading ? null : () => _checkResult(context, puzzle),
          icon: resultAsync.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.check),
          label: const Text('Check Waves'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHintOverlay(BuildContext context, Puzzle puzzle) {
    return GestureDetector(
      onTap: _toggleHint,
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0A3138),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.teal.shade700,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.shade900.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.tips_and_updates, color: Colors.teal.shade200),
                    const SizedBox(width: 10),
                    Text(
                      'Wave Manipulation Tips',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade200,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.teal.shade700.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildHintItem(
                        '1',
                        'Touch a wave to select it for adjustment',
                        Icons.touch_app,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '2',
                        'Drag up/down to change amplitude (wave height)',
                        Icons.swap_vert,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '3',
                        'Drag left/right to change frequency (wave density)',
                        Icons.swap_horiz,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '4',
                        'Change colors to match the target gradient ends',
                        Icons.palette,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Target Gradient:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 100,
                      height: 20,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [puzzle.availableColors[0], puzzle.targetColor],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _toggleHint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Got it!'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHintItem(String number, String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.teal.shade700,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          icon,
          color: Colors.teal.shade200,
          size: 20,
        ),
      ],
    );
  }
}

// Helper class for background waves
class _BackgroundWave {
  final Color color;
  final double amplitude;
  final double frequency;
  final double speed;
  final double phase;

  _BackgroundWave({
    required this.color,
    required this.amplitude,
    required this.frequency,
    required this.speed,
    required this.phase,
  });
}

// Painter for background waves
class _BackgroundWavePainter extends CustomPainter {
  final List<_BackgroundWave> waves;
  final double animationValue;

  _BackgroundWavePainter({
    required this.waves,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var wave in waves) {
      _drawWave(canvas, size, wave);
    }
  }

  void _drawWave(Canvas canvas, Size size, _BackgroundWave wave) {
    final width = size.width;
    final height = size.height;
    final centerY = height * 0.5;

    // Create wave path
    final path = Path();
    path.moveTo(0, centerY);

    for (int x = 0; x <= width; x++) {
      final wavePhase = wave.phase + (animationValue * wave.speed * 10);
      final y = centerY + sin((x / width * wave.frequency * 2 * pi) + wavePhase) * wave.amplitude;
      path.lineTo(x.toDouble(), y);
    }

    // Complete the path
    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    // Draw the wave
    final paint = Paint()
      ..color = wave.color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BackgroundWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
