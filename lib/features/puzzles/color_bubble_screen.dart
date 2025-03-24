import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_master/core/constants/app_constants.dart';
import 'package:palette_master/features/puzzles/games/color_bubble.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:palette_master/features/puzzles/providers/puzzle_provider.dart';
import 'package:palette_master/features/puzzles/widgets/color_preview.dart';
import 'package:palette_master/features/puzzles/widgets/level_completion_animation.dart';
import 'package:palette_master/router/routes.dart';
import 'package:vibration/vibration.dart';

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
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;
  late AnimationController _bubbleAnimationController;
  List<_BackgroundBubble> _backgroundBubbles = [];

  @override
  void initState() {
    super.initState();

    // Background animation
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 30000),
      vsync: this,
    )..repeat();
    _backgroundAnimation = Tween<double>(begin: 0, end: 1).animate(_backgroundController);

    // Bubble animation
    _bubbleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    )..repeat();

    _generateBackgroundBubbles();
  }

  void _generateBackgroundBubbles() {
    final random = Random();
    _backgroundBubbles = List.generate(15, (index) {
      return _BackgroundBubble(
        x: random.nextDouble() * 400,
        y: random.nextDouble() * 800,
        size: random.nextDouble() * 80 + 20,
        speed: random.nextDouble() * 2 + 0.5,
        color: HSVColor.fromAHSV(
          0.3 + random.nextDouble() * 0.3,
          random.nextDouble() * 360,
          0.7,
          0.9,
        ).toColor(),
      );
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _bubbleAnimationController.dispose();
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
        Vibration.vibrate(duration: 50, amplitude: 150);
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
        // Give feedback for mismatch
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Not quite right! Try adjusting your bubbles.'),
            backgroundColor: Colors.orange,
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
        backgroundColor: Colors.indigo.shade900,
        title: const Text('Try Again', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You\'ve reached the maximum number of attempts. Would you like to retry this level?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.gameSelection.path);
            },
            child: Text('Back to Games', style: TextStyle(color: Colors.blue.shade300)),
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
              backgroundColor: Colors.blue.shade600,
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
        centerTitle: true,
        title: Text(
          'Bubble Physics',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _toggleHint,
            tooltip: 'Show Hint',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetLevel,
            tooltip: 'Reset Level',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated background with bubbles
          AnimatedBuilder(
            animation: _bubbleAnimationController,
            builder: (context, child) {
              // Move background bubbles
              for (var bubble in _backgroundBubbles) {
                bubble.y -= bubble.speed;
                if (bubble.y < -bubble.size) {
                  bubble.y = MediaQuery.of(context).size.height + bubble.size;
                  bubble.x = Random().nextDouble() * MediaQuery.of(context).size.width;
                }
              }

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade900,
                      Colors.indigo.shade800,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Background bubbles
                    ...List.generate(_backgroundBubbles.length, (index) {
                      final bubble = _backgroundBubbles[index];
                      return Positioned(
                        left: bubble.x,
                        top: bubble.y,
                        child: Container(
                          width: bubble.size,
                          height: bubble.size,
                          decoration: BoxDecoration(
                            color: bubble.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                    child!,
                  ],
                ),
              );
            },
            child: SafeArea(
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
                            // Color preview and info section
                            _buildBubbleHeader(context, puzzle, userColor),

                            const SizedBox(height: 16),

                            // Game area
                            Expanded(
                              child: Hero(
                                tag: 'bubble-game',
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
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
                                      child: ColorBubblePhysicsGame(
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
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade200),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Loading Bubble Physics...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 18,
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
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
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
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                        ),
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
  }

  Widget _buildBubbleHeader(BuildContext context, Puzzle puzzle, Color userColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      puzzle.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      puzzle.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildAttemptsMeter(puzzle),
            ],
          ),
          const SizedBox(height: 16),
          // Color previews
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Target color
              Column(
                children: [
                  const Text(
                    'Target',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: puzzle.targetColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: puzzle.targetColor.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Similarity indicator
              Column(
                children: [
                  const Icon(
                    Icons.compare_arrows,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getSimilarityColor(userColor, puzzle.targetColor, puzzle.accuracyThreshold),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(_calculateSimilarity(userColor, puzzle.targetColor) * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // Current color
              Column(
                children: [
                  const Text(
                    'Current',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: userColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: userColor.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptsMeter(Puzzle puzzle) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Attempts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(puzzle.maxAttempts, (index) {
              final isUsed = index < _attempts;
              return Container(
                width: 8,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isUsed ? Colors.red.withOpacity(0.7) : Colors.green.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Color _getSimilarityColor(Color userColor, Color targetColor, double threshold) {
    final similarity = _calculateSimilarity(userColor, targetColor);
    if (similarity >= threshold) {
      return Colors.green;
    } else if (similarity >= 0.7) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  double _calculateSimilarity(Color a, Color b) {
    // Calculate color similarity (normalized between 0 and 1)
    final dr = (a.red - b.red) / 255.0;
    final dg = (a.green - b.green) / 255.0;
    final db = (a.blue - b.blue) / 255.0;

    // Human eyes are more sensitive to green, less to blue
    final distance = (dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11);
    return (1.0 - sqrt(distance)).clamp(0.0, 1.0);
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
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundColor: Colors.white,
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
          label: const Text('Check Match'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade500,
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
              color: Colors.indigo.shade900,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.blue.shade200.withOpacity(0.3),
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
                    Icon(Icons.lightbulb, color: Colors.yellow.shade300),
                    const SizedBox(width: 10),
                    const Text(
                      'Bubble Physics Tips',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildHintItem(
                        '1',
                        'Tap to split bubbles into smaller ones',
                        Icons.touch_app,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '2',
                        'Drag bubbles to move them around the screen',
                        Icons.swipe,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '3',
                        'When bubbles collide, they mix their colors',
                        Icons.compare_arrows,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '4',
                        'Try to match the target color shown above',
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
                      'Target Color:',
                      style: TextStyle(
                        color: Colors.white,
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
                    backgroundColor: Colors.blue.shade600,
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
            color: Colors.blue.shade600,
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
          color: Colors.blue.shade300,
          size: 20,
        ),
      ],
    );
  }
}

// Helper class for background bubbles
class _BackgroundBubble {
  double x;
  double y;
  double size;
  double speed;
  Color color;

  _BackgroundBubble({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
  });
}
