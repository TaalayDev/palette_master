import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_master/core/constants/app_constants.dart';
import 'package:palette_master/features/puzzles/games/mixing.dart';
import 'package:palette_master/features/puzzles/providers/puzzle_provider.dart';
import 'package:palette_master/features/puzzles/widgets/level_completion_animation.dart';
import 'package:palette_master/router/routes.dart';
import 'package:vibration/vibration.dart';

class ClassicMixingScreen extends ConsumerStatefulWidget {
  final String puzzleId;
  final int level;

  const ClassicMixingScreen({
    super.key,
    required this.puzzleId,
    required this.level,
  });

  @override
  ConsumerState<ClassicMixingScreen> createState() => _ClassicMixingScreenState();
}

class _ClassicMixingScreenState extends ConsumerState<ClassicMixingScreen> with TickerProviderStateMixin {
  bool _showLevelComplete = false;
  int _attempts = 0;
  bool _showHint = false;
  bool _showTips = true;
  int _score = 0;

  // Animation controllers
  late AnimationController _backgroundController;
  late AnimationController _uiAnimationController;
  late Animation<double> _uiScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Background animation
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
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
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _uiAnimationController.dispose();
    super.dispose();
  }

  void _checkResult(BuildContext context, Map<String, dynamic> puzzleState) {
    if (puzzleState == null) return;

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
        .checkResult(userColor, puzzleState['targetColor'], puzzleState['accuracyThreshold'])
        .then((success) {
      if (success) {
        _handleSuccess();
      } else if (_attempts >= puzzleState['maxAttempts']) {
        _handleFailure();
      } else {
        // Show feedback for mismatch
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Not quite right! Try adjusting your color mix.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.purple.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'Show Tip',
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
    // Calculate score based on attempts and level
    final levelBonus = widget.level * 10;
    final attemptBonus = 50 - (_attempts * 10);
    final newPoints = 100 + levelBonus + attemptBonus.clamp(0, 50);

    setState(() {
      _score += newPoints;
    });

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
        backgroundColor: const Color(0xFF2A1A36),
        title: Text(
          'Too Many Attempts!',
          style: TextStyle(color: Colors.purple.shade200),
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
            child: Text('Back to Games', style: TextStyle(color: Colors.purple.shade200)),
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
              backgroundColor: Colors.purple.shade700,
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
        'gameType': 'classicMixing',
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

  String _getLevelDescription(int level) {
    if (level <= 3) {
      return 'Mix primary colors to create secondary colors.';
    } else if (level <= 6) {
      return 'Create more complex color combinations using multiple colors.';
    } else if (level <= 9) {
      return 'Master subtle color variations by mixing different proportions.';
    } else {
      return 'Expert challenge: Create precise color matches with complex mixes.';
    }
  }

  Color _getColorMixTarget(int level) {
    // Primary colors
    const red = Colors.red;
    const blue = Colors.blue;
    const yellow = Colors.yellow;

    // Secondary colors - These are created by mixing primary colors
    const orange = Color(0xFFFF8800); // Red + Yellow
    const green = Color(0xFF008800); // Blue + Yellow
    const purple = Color(0xFF880088); // Red + Blue

    // More complex colors
    const brown = Color(0xFF8B4513);
    const teal = Color(0xFF008080);
    const coral = Color(0xFFFF7F50);
    const lavender = Color(0xFFE6E6FA);

    // Levels progress from simple to complex color mixing
    switch (level) {
      case 1:
        return orange; // Mix Red + Yellow
      case 2:
        return green; // Mix Blue + Yellow
      case 3:
        return purple; // Mix Red + Blue
      case 4:
        return brown; // Mix Red + Green (complex)
      case 5:
        return teal; // Mix Blue + Green
      case 6:
        return coral; // Mix Red + Orange
      case 7:
        return lavender; // Mix Blue + White
      default:
        // For higher levels, create a random challenge
        final random = Random(level); // Seed with level for consistency
        return Color.fromRGBO(
          50 + random.nextInt(150),
          50 + random.nextInt(150),
          50 + random.nextInt(150),
          1.0,
        );
    }
  }

  List<Color> _getAvailableColors(int level) {
    // Primary colors always available
    final colors = <Color>[Colors.red, Colors.blue, Colors.yellow];

    // Add more colors as levels progress
    if (level >= 3) {
      colors.add(Colors.green);
    }

    if (level >= 5) {
      colors.add(Colors.purple);
      colors.add(Colors.orange);
    }

    if (level >= 7) {
      colors.add(Colors.white);
      colors.add(Colors.black);
      colors.add(Colors.pink);
    }

    if (level >= 9) {
      colors.add(Colors.teal);
      colors.add(Colors.brown);
      colors.add(const Color(0xFFFFD700)); // Gold
    }

    return colors;
  }

  @override
  Widget build(BuildContext context) {
    // For simplicity, we'll create our own puzzle state instead of using the provider
    // This allows us to focus on the UI and physics without dependencies
    final targetColor = _getColorMixTarget(widget.level);
    final availableColors = _getAvailableColors(widget.level);
    final userColor = ref.watch(userMixedColorProvider);
    final resultAsync = ref.watch(puzzleResultProvider);

    // Let's simulate the puzzle state for this demo
    final puzzleState = {
      'targetColor': targetColor,
      'maxAttempts': 5 + (widget.level ~/ 2),
      'accuracyThreshold': 0.9,
    };

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.palette, color: Colors.purple.shade200),
            const SizedBox(width: 8),
            Text(
              'Color Mixing',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade200,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.purple.shade200),
            onPressed: _toggleHint,
            tooltip: 'Show Hint',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.purple.shade200),
            onPressed: _resetLevel,
            tooltip: 'Reset Level',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2A1A36),
                      const Color(0xFF1A1026),
                    ],
                  ),
                ),
                child: CustomPaint(
                  painter: BackgroundPainter(
                    animation: _backgroundController.value,
                  ),
                  size: MediaQuery.of(context).size,
                ),
              );
            },
          ),

          // Main content with animation
          SafeArea(
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
                  // Header with level info
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Level badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade900.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            'Level ${widget.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Score
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade700.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Score: $_score',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Level description
                  if (_showTips)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.purple.shade300.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Colors.purple.shade300,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getLevelDescription(widget.level),
                                style: TextStyle(
                                  color: Colors.purple.shade100,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white54,
                                size: 16,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showTips = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Main game component
                  Expanded(
                    child: ClassicMixingGame(
                      targetColor: targetColor,
                      availableColors: availableColors,
                      onColorMixed: (color) {
                        ref.read(userMixedColorProvider.notifier).setColor(color);
                      },
                      level: widget.level,
                    ),
                  ),

                  // Bottom controls
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Attempt counter
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Attempts: $_attempts/${puzzleState['maxAttempts']}',
                            style: TextStyle(
                              color: _attempts >= (puzzleState['maxAttempts'] as int) - 1
                                  ? Colors.red.shade300
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Check button
                        ElevatedButton.icon(
                          onPressed: resultAsync.isLoading ? null : () => _checkResult(context, puzzleState),
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
                            backgroundColor: Colors.purple.shade700,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.purple.shade200,
                            elevation: 4,
                            shadowColor: Colors.black.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Hint overlay
          if (_showHint) _buildHintOverlay(context, targetColor),

          // Level complete overlay
          if (_showLevelComplete)
            LevelCompletionAnimation(
              onComplete: _nextLevel,
              primaryColor: targetColor,
              secondaryColor: userColor,
            ),
        ],
      ),
    );
  }

  Widget _buildHintOverlay(BuildContext context, Color targetColor) {
    // Convert to RGB for display
    final r = targetColor.red;
    final g = targetColor.green;
    final b = targetColor.blue;

    return GestureDetector(
      onTap: _toggleHint,
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1A36),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.purple.shade700,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.shade900.withOpacity(0.5),
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
                    Icon(Icons.tips_and_updates, color: Colors.purple.shade200),
                    const SizedBox(width: 10),
                    Text(
                      'Color Mixing Tips',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade200,
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
                      color: Colors.purple.shade700.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildHintItem(
                        '1',
                        'Try dragging and dropping more than one color.',
                        Icons.touch_app,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '2',
                        'Different proportions will create different shades.',
                        Icons.balance,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '3',
                        'Watch how colors interact with fluid physics!',
                        Icons.bubble_chart,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '4',
                        'Your target has these RGB values: ($r, $g, $b)',
                        Icons.colorize,
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
                      height: 50,
                      decoration: BoxDecoration(
                        color: targetColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: targetColor.withOpacity(0.5),
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
                    backgroundColor: Colors.purple.shade700,
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
            color: Colors.purple.shade700,
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
          color: Colors.purple.shade200,
          size: 20,
        ),
      ],
    );
  }
}

// Background animator
class BackgroundPainter extends CustomPainter {
  final double animation;

  BackgroundPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Background bubbles
    final bubbleCount = 20;
    final random = Random(42); // Fixed seed for deterministic animation

    for (int i = 0; i < bubbleCount; i++) {
      // Use animation to move bubbles
      final yOffset = (animation * 100) % height;

      final x = random.nextDouble() * width;
      var y = (random.nextDouble() * height * 2) - yOffset;
      y = y % (height * 1.5);

      final radius = 10 + random.nextDouble() * 40;
      final opacity = 0.05 + random.nextDouble() * 0.1;

      final hue = (random.nextDouble() * 60) + 240; // Purple-blue range
      final color = HSVColor.fromAHSV(opacity, hue, 0.7, 0.8).toColor();

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Add subtle radial gradient overlay
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.8,
      colors: [
        Colors.transparent,
        Colors.black.withOpacity(0.2),
      ],
      stops: const [0.6, 1.0],
    );

    final rect = Rect.fromCenter(
      center: Offset(width / 2, height / 2),
      width: width,
      height: height,
    );

    final gradientPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
