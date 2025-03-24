import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_master/core/constants/app_constants.dart';
import 'package:palette_master/features/puzzles/games/color_racer.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:palette_master/features/puzzles/providers/puzzle_provider.dart';
import 'package:palette_master/features/puzzles/widgets/level_completion_animation.dart';
import 'package:palette_master/router/routes.dart';
import 'package:vibration/vibration.dart';
import 'dart:math';

class ColorRacerScreen extends ConsumerStatefulWidget {
  final String puzzleId;
  final int level;

  const ColorRacerScreen({
    super.key,
    required this.puzzleId,
    required this.level,
  });

  @override
  ConsumerState<ColorRacerScreen> createState() => _ColorRacerScreenState();
}

class _ColorRacerScreenState extends ConsumerState<ColorRacerScreen> with TickerProviderStateMixin {
  bool _showLevelComplete = false;
  int _attempts = 0;
  bool _showHint = false;
  bool _isCountingDown = false;
  int _countdownValue = 3;

  // Animation controllers
  late AnimationController _bgAnimationController;
  late AnimationController _uiAnimationController;
  late Animation<double> _uiScaleAnimation;

  // Background elements
  List<_RoadStripe> _roadStripes = [];
  List<_RoadLight> _roadLights = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Background animation
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();

    // UI animation
    _uiAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _uiScaleAnimation = CurvedAnimation(
      parent: _uiAnimationController,
      curve: Curves.easeOutBack,
    );

    _uiAnimationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Generate background elements
      _generateRoadElements();
    });
  }

  void _generateRoadElements() {
    // Road stripes
    _roadStripes = List.generate(10, (index) {
      return _RoadStripe(
        y: index * 80.0,
        speed: 5.0,
      );
    });

    // Road lights
    _roadLights = List.generate(12, (index) {
      final isLeft = index % 2 == 0;
      return _RoadLight(
        position: Offset(
          isLeft ? 30.0 : MediaQuery.of(context).size.width - 30.0,
          index * 120.0,
        ),
        color: isLeft ? Colors.red : Colors.blue,
        speed: 5.0,
      );
    });
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _uiAnimationController.dispose();
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
        // Show feedback for mismatch
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Color not matched! Collect different gates to adjust your car\'s color.',
              style: TextStyle(color: Colors.red.shade100),
            ),
            backgroundColor: Colors.red.shade900,
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
        backgroundColor: const Color(0xFF331A1A),
        title: Text(
          'Race Over!',
          style: TextStyle(color: Colors.red.shade200),
        ),
        content: const Text(
          'You\'ve reached the maximum number of attempts. Would you like to retry the race?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.gameSelection.path);
            },
            child: Text('Back to Games', style: TextStyle(color: Colors.red.shade200)),
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
              backgroundColor: Colors.red.shade800,
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
      AppRoutes.colorRacer.name,
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

  void _startRace() {
    setState(() {
      _isCountingDown = true;
    });

    // Start countdown
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _countdownValue--;
        });

        if (_countdownValue > 0) {
          _startCountdown();
        } else {
          // Start race
          setState(() {
            _isCountingDown = false;
          });
        }
      }
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
            Icon(Icons.directions_car_rounded, color: Colors.red.shade200),
            const SizedBox(width: 8),
            Text(
              'Color Racer - Level ${widget.level}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade200,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.red.shade200),
            onPressed: _toggleHint,
            tooltip: 'Show Hint',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.red.shade200),
            onPressed: _resetLevel,
            tooltip: 'Reset Level',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _bgAnimationController,
        builder: (context, child) {
          _updateRoadElements();

          return Stack(
            children: [
              // Dark asphalt background
              Container(
                color: const Color(0xFF111111),
              ),

              // Road markings
              CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _RoadPainter(
                  stripes: _roadStripes,
                  lights: _roadLights,
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
                  child: AnimatedBuilder(
                    animation: _uiScaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _uiScaleAnimation.value,
                        child: child,
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Racer-themed header
                        _buildRacerHeader(context, puzzle, userColor),

                        const SizedBox(height: 16),

                        // Game area
                        Expanded(
                          child: Hero(
                            tag: 'racer-game',
                            child: Material(
                              type: MaterialType.transparency,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.red.shade900,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.shade900.withOpacity(0.3),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: ColorRacerGame(
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
                ),

                // Hint overlay
                if (_showHint) _buildHintOverlay(context, puzzle),

                // Countdown overlay
                if (_isCountingDown) _buildCountdownOverlay(),

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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade500),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Loading Race...',
                  style: TextStyle(
                    color: Colors.red.shade300,
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
                    color: Colors.red.shade300,
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
                    backgroundColor: Colors.red.shade900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateRoadElements() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Update road stripes
      for (var stripe in _roadStripes) {
        stripe.y += stripe.speed;
        if (stripe.y > MediaQuery.of(context).size.height) {
          stripe.y = -80;
        }
      }

      // Update road lights
      for (var light in _roadLights) {
        light.position = Offset(light.position.dx, light.position.dy + light.speed);
        if (light.position.dy > MediaQuery.of(context).size.height) {
          light.position = Offset(light.position.dx, -120);
        }
      }
    });
  }

  Widget _buildRacerHeader(BuildContext context, Puzzle puzzle, Color userColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.shade900,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade900.withOpacity(0.3),
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
                  color: Colors.red.shade900.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.speed,
                  color: Colors.red.shade300,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          puzzle.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade300,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Attempts: $_attempts/${puzzle.maxAttempts}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _attempts >= puzzle.maxAttempts * 0.7 ? Colors.red.shade300 : Colors.white70,
                            ),
                          ),
                        ),
                      ],
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

          // Car color preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Target car color
              _buildCarPreview(
                'Target Color',
                puzzle.targetColor,
                false,
              ),

              // Similarity indicator
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          _getSimilarityColor(userColor, puzzle.targetColor, puzzle.accuracyThreshold).withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getSimilarityColor(userColor, puzzle.targetColor, puzzle.accuracyThreshold),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${(_similarity(userColor, puzzle.targetColor) * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _getSimilarityColor(userColor, puzzle.targetColor, puzzle.accuracyThreshold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Match',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade200,
                    ),
                  ),
                ],
              ),

              // Current car color
              _buildCarPreview(
                'Your Car',
                userColor,
                true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarPreview(String label, Color color, bool isUserCar) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ],
          ),
          // Simplified car shape
          child: Stack(
            children: [
              // Car wheels
              Positioned(
                bottom: 2,
                left: 15,
                child: Container(
                  width: 10,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 15,
                child: Container(
                  width: 10,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Car windows
              Positioned(
                top: 5,
                left: 20,
                right: 20,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.shade900,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isUserCar ? Colors.red.shade200 : Colors.white70,
          ),
        ),
      ],
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
            backgroundColor: Colors.black.withOpacity(0.7),
            foregroundColor: Colors.red.shade200,
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
          label: const Text('Check Color'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade800,
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
              color: const Color(0xFF2A0A0A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.red.shade900,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade900.withOpacity(0.5),
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
                    Icon(Icons.drive_eta, color: Colors.red.shade200),
                    const SizedBox(width: 10),
                    Text(
                      'Racing Tips',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade200,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.shade900.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildHintItem(
                        '1',
                        'Drag left & right to steer your car',
                        Icons.swipe,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '2',
                        'Drive through color gates to change your car\'s color',
                        Icons.palette,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '3',
                        'Collect power-ups for speed boosts and color hints',
                        Icons.auto_awesome,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '4',
                        'Try to match your car\'s color to the target color',
                        Icons.color_lens,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Target Color:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 50,
                      height: 25,
                      decoration: BoxDecoration(
                        color: puzzle.targetColor,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.white, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: puzzle.targetColor.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _toggleHint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
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

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _countdownValue > 0 ? _countdownValue.toString() : 'GO!',
              style: TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: _countdownValue > 0 ? Colors.white : Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Get Ready to Race!',
              style: TextStyle(
                fontSize: 20,
                color: Colors.red.shade300,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
            color: Colors.red.shade900,
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
          color: Colors.red.shade200,
          size: 20,
        ),
      ],
    );
  }
}

// Helper class for road stripes
class _RoadStripe {
  double y;
  double speed;

  _RoadStripe({
    required this.y,
    required this.speed,
  });
}

// Helper class for road lights
class _RoadLight {
  Offset position;
  Color color;
  double speed;

  _RoadLight({
    required this.position,
    required this.color,
    required this.speed,
  });
}

// Painter for road elements
class _RoadPainter extends CustomPainter {
  final List<_RoadStripe> stripes;
  final List<_RoadLight> lights;

  _RoadPainter({
    required this.stripes,
    required this.lights,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Draw road
    final roadPaint = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), roadPaint);

    // Draw center line
    final centerPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final centerX = width / 2;

    // Draw road stripes
    for (var stripe in stripes) {
      canvas.drawLine(
        Offset(centerX, stripe.y),
        Offset(centerX, stripe.y + 40),
        centerPaint,
      );
    }

    // Draw road edge lines
    final edgePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawLine(
      Offset(width * 0.2, 0),
      Offset(width * 0.2, height),
      edgePaint,
    );

    canvas.drawLine(
      Offset(width * 0.8, 0),
      Offset(width * 0.8, height),
      edgePaint,
    );

    // Draw road lights
    for (var light in lights) {
      final lightPaint = Paint()
        ..color = light.color.withOpacity(0.7)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(light.position, 5, lightPaint);

      // Draw light glow
      final glowPaint = Paint()
        ..color = light.color.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(light.position, 10, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) {
    return true; // Always repaint for animation
  }
}
