import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_master/core/constants/app_constants.dart';
import 'package:palette_master/features/puzzles/games/color_memory.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:palette_master/features/puzzles/providers/puzzle_provider.dart';
import 'package:palette_master/features/puzzles/widgets/level_completion_animation.dart';
import 'package:palette_master/router/routes.dart';
import 'package:vibration/vibration.dart';
import 'dart:math';

class ColorMemoryScreen extends ConsumerStatefulWidget {
  final String puzzleId;
  final int level;

  const ColorMemoryScreen({
    super.key,
    required this.puzzleId,
    required this.level,
  });

  @override
  ConsumerState<ColorMemoryScreen> createState() => _ColorMemoryScreenState();
}

class _ColorMemoryScreenState extends ConsumerState<ColorMemoryScreen> with TickerProviderStateMixin {
  bool _showLevelComplete = false;
  int _attempts = 0;
  bool _showHint = false;

  // Animation controllers
  late AnimationController _bgAnimationController;
  late AnimationController _uiAnimationController;
  late Animation<double> _uiScaleAnimation;

  // Background elements
  List<_MemoryParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Background animation
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
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
      // Generate background particles
      _generateBackgroundParticles();
    });
  }

  void _generateBackgroundParticles() {
    _particles = List.generate(30, (index) {
      return _MemoryParticle(
        position: Offset(
          _random.nextDouble() * MediaQuery.of(context).size.width,
          _random.nextDouble() * MediaQuery.of(context).size.height,
        ),
        size: _random.nextDouble() * 20 + 5,
        speed: _random.nextDouble() * 0.5,
        color: HSVColor.fromAHSV(
          0.2 + _random.nextDouble() * 0.1,
          _random.nextDouble() * 360,
          0.8,
          0.9,
        ).toColor(),
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
              'Memory mismatch! Try to remember and recreate the correct color pattern.',
              style: TextStyle(color: Colors.indigo.shade100),
            ),
            backgroundColor: Colors.indigo.shade900,
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
        backgroundColor: const Color(0xFF191933),
        title: Text(
          'Memory Failed!',
          style: TextStyle(color: Colors.indigo.shade200),
        ),
        content: const Text(
          'You\'ve reached the maximum number of attempts. Would you like to retry with a new memory challenge?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.gameSelection.path);
            },
            child: Text('Back to Games', style: TextStyle(color: Colors.indigo.shade200)),
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
              backgroundColor: Colors.indigo.shade700,
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
      AppRoutes.colorMemory.name,
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.memory, color: Colors.indigo.shade200),
            const SizedBox(width: 8),
            Text(
              'Color Memory',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade200,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.indigo.shade200),
            onPressed: _toggleHint,
            tooltip: 'Show Hint',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.indigo.shade200),
            onPressed: _resetLevel,
            tooltip: 'Reset Level',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _bgAnimationController,
        builder: (context, child) {
          // Update background particles
          for (var particle in _particles) {
            particle.position = Offset(
              particle.position.dx,
              particle.position.dy - particle.speed,
            );

            // Wrap particles at screen edges
            if (particle.position.dy < -particle.size) {
              particle.position = Offset(
                _random.nextDouble() * MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height + particle.size,
              );
              particle.color = HSVColor.fromAHSV(
                0.2 + _random.nextDouble() * 0.1,
                _random.nextDouble() * 360,
                0.8,
                0.9,
              ).toColor();
            }
          }

          return Stack(
            children: [
              // Dark themed background
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF121236),
                      Color(0xFF1E1A3A),
                    ],
                  ),
                ),
              ),

              // Background particles
              Stack(
                children: List.generate(_particles.length, (index) {
                  final particle = _particles[index];
                  return Positioned(
                    left: particle.position.dx - particle.size / 2,
                    top: particle.position.dy - particle.size / 2,
                    child: Container(
                      width: particle.size,
                      height: particle.size,
                      decoration: BoxDecoration(
                        color: particle.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
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
                        // Memory-themed header
                        _buildMemoryHeader(context, puzzle, userColor),

                        const SizedBox(height: 16),

                        // Game area
                        Expanded(
                          child: Hero(
                            tag: 'memory-game',
                            child: Material(
                              type: MaterialType.transparency,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.indigo.shade700.withOpacity(0.5),
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
                                  child: ColorMemoryGame(
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade300),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Loading Memory Challenge...',
                  style: TextStyle(
                    color: Colors.indigo.shade200,
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
                    color: Colors.indigo.shade200,
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
                    backgroundColor: Colors.indigo.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemoryHeader(BuildContext context, Puzzle puzzle, Color userColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade900.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.indigo.shade400.withOpacity(0.3),
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
                  color: Colors.indigo.shade700.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.memory,
                  color: Colors.indigo.shade200,
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
                        color: Colors.indigo.shade200,
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

          // Color matching status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Target color
              Column(
                children: [
                  Text(
                    'Target Color',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade200,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: puzzle.targetColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: puzzle.targetColor.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                  ),
                ],
              ),

              // Game stats
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _getSimilarityColor(userColor, puzzle.targetColor, puzzle.accuracyThreshold)
                            .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Match: ${(_similarity(userColor, puzzle.targetColor) * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getSimilarityColor(userColor, puzzle.targetColor, puzzle.accuracyThreshold),
                        ),
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
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.psychology,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Level ${widget.level}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // User color
              Column(
                children: [
                  Text(
                    'Your Color',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade200,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: userColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: userColor.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2,
                      ),
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
            backgroundColor: Colors.indigo.shade900.withOpacity(0.6),
            foregroundColor: Colors.indigo.shade200,
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
          label: const Text('Check Memory'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade700,
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
              color: const Color(0xFF1A1A40),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.indigo.shade400,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.shade900.withOpacity(0.5),
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
                    Icon(Icons.lightbulb_outline, color: Colors.indigo.shade200),
                    const SizedBox(width: 10),
                    Text(
                      'Memory Game Tips',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade200,
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
                      color: Colors.indigo.shade700.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildHintItem(
                        '1',
                        'Watch the sequence of colors carefully when shown',
                        Icons.visibility,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '2',
                        'Tap cards to repeat the sequence in the correct order',
                        Icons.touch_app,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '3',
                        'Match pairs of cards with the same color in matching mode',
                        Icons.compare,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '4',
                        'Practice identifying color relationships (complementary, analogous)',
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
                    backgroundColor: Colors.indigo.shade700,
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
            color: Colors.indigo.shade700,
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
          color: Colors.indigo.shade200,
          size: 20,
        ),
      ],
    );
  }
}

// Helper class for background particles
class _MemoryParticle {
  Offset position;
  double size;
  double speed;
  Color color;

  _MemoryParticle({
    required this.position,
    required this.size,
    required this.speed,
    required this.color,
  });
}
