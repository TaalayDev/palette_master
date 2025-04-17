import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_master/core/constants/app_constants.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:palette_master/features/puzzles/providers/puzzle_provider.dart';
import 'package:palette_master/features/puzzles/widgets/level_completion_animation.dart';
import 'package:palette_master/router/routes.dart';
import 'package:vibration/vibration.dart';

import '../shared/providers/game_progress_provider.dart';
import 'games/color_bubble.dart';

class ColorBubbleScreen extends ConsumerStatefulWidget {
  final String puzzleId;
  final int level;

  const ColorBubbleScreen({
    super.key,
    required this.puzzleId,
    required this.level,
  });

  @override
  ConsumerState<ColorBubbleScreen> createState() => _ColorBubbleScreenState();
}

class _ColorBubbleScreenState extends ConsumerState<ColorBubbleScreen> with TickerProviderStateMixin {
  bool _showLevelComplete = false;
  int _attempts = 0;
  bool _showHint = false;
  bool _isLoading = false; // For the check button

  // Animation controllers
  late AnimationController _bgAnimationController;
  late AnimationController _uiAnimationController;
  late Animation<double> _uiScaleAnimation;

  // Background elements
  List<BackgroundBubble> _backgroundBubbles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Background animation
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
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

    // Generate background bubbles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateBackgroundBubbles();
    });
  }

  void _generateBackgroundBubbles() {
    _backgroundBubbles = List.generate(30, (index) {
      return BackgroundBubble(
        position: Offset(
          _random.nextDouble() * MediaQuery.of(context).size.width,
          _random.nextDouble() * MediaQuery.of(context).size.height,
        ),
        radius: 5.0 + _random.nextDouble() * 25.0,
        color: HSVColor.fromAHSV(
          0.2 + _random.nextDouble() * 0.1,
          _random.nextDouble() * 360,
          0.7,
          0.8,
        ).toColor(),
        speed: _random.nextDouble() * 0.5,
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
      _isLoading = true;
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
      setState(() {
        _isLoading = false;
      });

      if (success) {
        _handleSuccess();
      } else if (_attempts >= puzzle.maxAttempts) {
        _handleFailure();
      } else {
        // Show feedback for mismatch
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not quite right! Try more bubble collisions to mix colors better.',
              style: TextStyle(color: Colors.blue.shade100),
            ),
            backgroundColor: Colors.blue.shade900,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'Show Hint',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _showHint = true;
                });
              },
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
        backgroundColor: const Color(0xFF102040),
        title: Text(
          'Too Many Attempts!',
          style: TextStyle(color: Colors.blue.shade200),
        ),
        content: const Text(
          'You\'ve reached the maximum number of attempts. Would you like to retry the level?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.gameSelection.path);
            },
            child: Text('Back to Games', style: TextStyle(color: Colors.blue.shade200)),
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
              backgroundColor: Colors.blue.shade700,
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
      AppRoutes.colorBubble.name,
      queryParameters: {
        'id': widget.puzzleId,
        'level': nextLevel.toString(),
      },
    );
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Bubble Physics',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade200,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.go(AppRoutes.gameSelection.path),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.blue.shade200),
            onPressed: _toggleHint,
            tooltip: 'Show Hint',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _bgAnimationController,
        builder: (context, child) {
          // Update background bubbles
          for (var bubble in _backgroundBubbles) {
            bubble.position = Offset(
              bubble.position.dx,
              bubble.position.dy - bubble.speed,
            );

            // Reset position when off screen
            if (bubble.position.dy < -bubble.radius) {
              bubble.position = Offset(
                _random.nextDouble() * MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height + bubble.radius,
              );
              bubble.color = HSVColor.fromAHSV(
                0.2 + _random.nextDouble() * 0.1,
                _random.nextDouble() * 360,
                0.7,
                0.8,
              ).toColor();
            }
          }

          return Stack(
            children: [
              // Background gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0A1A30),
                      const Color(0xFF0A2A40),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),

              // Background bubbles
              Stack(
                children: _backgroundBubbles
                    .map((bubble) => Positioned(
                          left: bubble.position.dx - bubble.radius,
                          top: bubble.position.dy - bubble.radius,
                          child: Container(
                            width: bubble.radius * 2,
                            height: bubble.radius * 2,
                            decoration: BoxDecoration(
                              color: bubble.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ))
                    .toList(),
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
                      children: [
                        // Level header with challenge description
                        // _buildHeader(puzzle),

                        // const SizedBox(height: 16),

                        // Game area
                        Expanded(
                          child: Hero(
                            tag: 'bubble-physics-game',
                            child: Material(
                              type: MaterialType.transparency,
                              child: BubblePhysicsGame(
                                targetColor: puzzle.targetColor,
                                availableColors: puzzle.availableColors,
                                onColorMixed: (color) {
                                  ref.read(userMixedColorProvider.notifier).setColor(color);
                                },
                                level: widget.level,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Check result button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : () => _checkResult(context, puzzle),
                            icon: _isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade200),
                                    ),
                                  )
                                : const Icon(Icons.science_outlined),
                            label: Text(
                              _isLoading ? 'Analyzing Colors...' : 'Check Color Match',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.blue.shade900,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 5,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Hint overlay
                if (_showHint) _buildHintOverlay(context, puzzle),

                // Level complete overlay
                if (_showLevelComplete)
                  LevelCompletionAnimation(
                    onComplete: _nextLevel,
                    primaryColor: Colors.blue.shade700,
                    secondaryColor: userColor,
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Loading Bubble Physics...',
                  style: TextStyle(
                    color: Colors.white,
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
                    color: Colors.blue.shade200,
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
                    backgroundColor: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Container _buildHeader(Puzzle puzzle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade900.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.shade400.withOpacity(0.3),
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade800.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bubble_chart,
                  color: Colors.blue.shade200,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${widget.level}: ${_getLevelTitle(widget.level)}',
                      style: TextStyle(
                        color: Colors.blue.shade100,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getLevelDescription(widget.level),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Attempt counter and difficulty indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Attempts
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade800.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.refresh,
                      color: _attempts >= puzzle.maxAttempts - 1 ? Colors.red.shade300 : Colors.blue.shade200,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Attempt $_attempts/${puzzle.maxAttempts}',
                      style: TextStyle(
                        color: _attempts >= puzzle.maxAttempts - 1 ? Colors.red.shade300 : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Level difficulty
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getDifficultyColor(widget.level).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getDifficultyColor(widget.level).withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_graph,
                      color: _getDifficultyColor(widget.level),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getDifficultyText(widget.level),
                      style: TextStyle(
                        color: _getDifficultyColor(widget.level),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLevelTitle(int level) {
    switch (level) {
      case 1:
        return 'Bubble Beginnings';
      case 2:
        return 'Collision Course';
      case 3:
        return 'Mix Master';
      case 4:
        return 'Physics Explorer';
      case 5:
        return 'Color Catalyst';
      case 6:
        return 'Harmony in Motion';
      case 7:
        return 'Kinetic Artistry';
      case 8:
        return 'Precision Mixing';
      case 9:
        return 'Molecular Maestro';
      case 10:
        return 'Grand Finale';
      default:
        return 'Challenge ${level - 10}';
    }
  }

  String _getLevelDescription(int level) {
    if (level <= 3) {
      return 'Create and collide colored bubbles to mix them. Try to match the target color.';
    } else if (level <= 6) {
      return 'Mix multiple colors with precise collisions to create more complex hues.';
    } else if (level <= 8) {
      return 'Master the physics of bubble interactions to create subtle color blends.';
    } else {
      return 'Achieve perfect color matching through strategic bubble creation and collision.';
    }
  }

  String _getDifficultyText(int level) {
    if (level <= 3) {
      return 'Beginner';
    } else if (level <= 6) {
      return 'Intermediate';
    } else if (level <= 8) {
      return 'Advanced';
    } else {
      return 'Expert';
    }
  }

  Color _getDifficultyColor(int level) {
    if (level <= 3) {
      return Colors.green;
    } else if (level <= 6) {
      return Colors.orange;
    } else if (level <= 8) {
      return Colors.deepOrange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildHintOverlay(BuildContext context, Puzzle puzzle) {
    // Extract RGB values for display
    final r = puzzle.targetColor.red;
    final g = puzzle.targetColor.green;
    final b = puzzle.targetColor.blue;

    return GestureDetector(
      onTap: _toggleHint,
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.blue.shade700,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade900.withOpacity(0.5),
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
                    Icon(Icons.lightbulb_outline, color: Colors.blue.shade200),
                    const SizedBox(width: 10),
                    Text(
                      'Bubble Physics Tips',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade200,
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
                      color: Colors.blue.shade700.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildHintItem(
                        '1',
                        'Create bubbles by selecting a color and dragging on the surface.',
                        Icons.touch_app,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '2',
                        'Bubbles will collide and mix colors when they hit each other with enough force.',
                        Icons.offline_bolt,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '3',
                        'The faster the collision, the more likely bubbles are to mix.',
                        Icons.speed,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '4',
                        'Your target RGB values are: ($r, $g, $b)',
                        Icons.colorize,
                      ),
                      const SizedBox(height: 12),
                      _buildLevelSpecificHint(widget.level),
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
                      height: 50,
                      decoration: BoxDecoration(
                        color: puzzle.targetColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
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
                    backgroundColor: Colors.blue.shade700,
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
            color: Colors.blue.shade700,
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
          color: Colors.blue.shade200,
          size: 20,
        ),
      ],
    );
  }

  Widget _buildLevelSpecificHint(int level) {
    String hintText;
    IconData hintIcon;

    if (level <= 3) {
      hintText = 'Try mixing primary colors to create secondary colors (Blue + Yellow = Green).';
      hintIcon = Icons.architecture;
    } else if (level <= 6) {
      hintText = 'Create bubbles of different sizes for more nuanced color proportions.';
      hintIcon = Icons.tune;
    } else {
      hintText = 'For complex colors, try mixing in stages - first create intermediate colors.';
      hintIcon = Icons.auto_awesome;
    }

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.amber,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              '!',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            hintText,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          hintIcon,
          color: Colors.amber,
          size: 20,
        ),
      ],
    );
  }
}

// Background bubble for animation
class BackgroundBubble {
  Offset position;
  final double radius;
  Color color;
  final double speed;

  BackgroundBubble({
    required this.position,
    required this.radius,
    required this.color,
    required this.speed,
  });
}
