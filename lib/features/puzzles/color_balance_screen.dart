import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_master/core/constants/app_constants.dart';
import 'package:palette_master/features/puzzles/games/color_balance.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:palette_master/features/puzzles/providers/puzzle_provider.dart';
import 'package:palette_master/features/puzzles/widgets/level_completion_animation.dart';
import 'package:palette_master/router/routes.dart';
import 'package:vibration/vibration.dart';
import 'dart:math';

class ColorBalanceScreen extends ConsumerStatefulWidget {
  final String puzzleId;
  final int level;

  const ColorBalanceScreen({
    super.key,
    required this.puzzleId,
    required this.level,
  });

  @override
  ConsumerState<ColorBalanceScreen> createState() => _ColorBalanceScreenState();
}

class _ColorBalanceScreenState extends ConsumerState<ColorBalanceScreen> with TickerProviderStateMixin {
  bool _showLevelComplete = false;
  int _attempts = 0;
  bool _showHint = false;

  // Animation controllers
  late AnimationController _bgController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  // Background particles
  List<_BackgroundParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Background animation
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Scale animation for UI elements
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );
    _scaleController.forward();

    // Create background particles
    _generateParticles();
  }

  void _generateParticles() {
    _particles = List.generate(30, (index) {
      return _BackgroundParticle(
        position: Offset(
          _random.nextDouble() * 500,
          _random.nextDouble() * 800,
        ),
        velocity: Offset(
          (_random.nextDouble() - 0.5) * 0.5,
          (_random.nextDouble() - 0.5) * 0.5,
        ),
        radius: _random.nextDouble() * 20 + 5,
        color: HSVColor.fromAHSV(
          0.1 + _random.nextDouble() * 0.1,
          _random.nextDouble() * 360,
          0.7,
          0.9,
        ).toColor(),
      );
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _scaleController.dispose();
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
        // Failed match
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not balanced yet. Adjust the sliders to find the right proportion!',
              style: TextStyle(color: Colors.orange.shade100),
            ),
            backgroundColor: Colors.deepOrange.shade800,
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
        backgroundColor: const Color(0xFF2A2118),
        title: Text(
          'Unbalanced!',
          style: TextStyle(color: Colors.orange.shade200),
        ),
        content: const Text(
          'You\'ve reached the maximum number of attempts. Would you like to retry balancing the colors?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.gameSelection.path);
            },
            child: Text('Back to Games', style: TextStyle(color: Colors.orange.shade200)),
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
              backgroundColor: Colors.orange.shade800,
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
      AppRoutes.colorBalance.name,
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
        title: Text(
          'Color Balance',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade200,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.orange.shade200),
            onPressed: _toggleHint,
            tooltip: 'Show Hint',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.orange.shade200),
            onPressed: _resetLevel,
            tooltip: 'Reset Level',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          // Update particle positions
          for (var particle in _particles) {
            particle.position += particle.velocity;

            // Wrap around screen edges
            if (particle.position.dx < -particle.radius)
              particle.position = Offset(MediaQuery.of(context).size.width + particle.radius, particle.position.dy);
            if (particle.position.dx > MediaQuery.of(context).size.width + particle.radius)
              particle.position = Offset(-particle.radius, particle.position.dy);
            if (particle.position.dy < -particle.radius)
              particle.position = Offset(particle.position.dx, MediaQuery.of(context).size.height + particle.radius);
            if (particle.position.dy > MediaQuery.of(context).size.height + particle.radius)
              particle.position = Offset(particle.position.dx, -particle.radius);
          }

          return Stack(
            children: [
              // Background gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF3A291D),
                      Color(0xFF1A1410),
                    ],
                  ),
                ),
              ),

              // Background particles
              ...List.generate(_particles.length, (index) {
                final particle = _particles[index];
                return Positioned(
                  left: particle.position.dx - particle.radius,
                  top: particle.position.dy - particle.radius,
                  child: Container(
                    width: particle.radius * 2,
                    height: particle.radius * 2,
                    decoration: BoxDecoration(
                      color: particle.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),

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
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Balance-themed header
                        //  _buildBalanceHeader(context, puzzle, userColor),

                        const SizedBox(height: 16),

                        // Game area
                        Expanded(
                          child: Hero(
                            tag: 'balance-game',
                            child: Material(
                              type: MaterialType.transparency,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.orange.shade800.withOpacity(0.3),
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
                                  child: ColorBalanceGame(
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade200),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Balancing Colors...',
                  style: TextStyle(
                    color: Colors.orange.shade200,
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
                    color: Colors.orange.shade200,
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
                    backgroundColor: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceHeader(BuildContext context, Puzzle puzzle, Color userColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF302118),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.shade800.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.balance,
                  color: Colors.orange.shade200,
                  size: 24,
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
                        color: Colors.orange.shade200,
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

          // Attempt counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.brown.shade900.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history,
                  size: 16,
                  color: Colors.orange.shade200,
                ),
                const SizedBox(width: 8),
                Text(
                  'Attempts: $_attempts/${puzzle.maxAttempts}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _attempts >= puzzle.maxAttempts * 0.7 ? Colors.red.shade300 : Colors.orange.shade200,
                  ),
                ),
              ],
            ),
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
            backgroundColor: Colors.brown.shade800,
            foregroundColor: Colors.orange.shade200,
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
          label: const Text('Check Balance'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
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
              color: const Color(0xFF2A2118),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.orange.shade800,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.shade900.withOpacity(0.5),
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
                    Icon(Icons.scale, color: Colors.orange.shade200),
                    const SizedBox(width: 10),
                    Text(
                      'Balancing Colors',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade200,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.brown.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.shade800.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildHintItem(
                        '1',
                        'Select sliders and adjust them to change color proportions',
                        Icons.tune,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '2',
                        'Drag up and down to change amplitude (color intensity)',
                        Icons.arrow_upward,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '3',
                        'Drag left and right to change frequency (color distribution)',
                        Icons.arrow_forward,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '4',
                        'Find just the right balance to match the target color',
                        Icons.balance,
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
                    backgroundColor: Colors.orange.shade800,
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
            color: Colors.orange.shade800,
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
          color: Colors.orange.shade200,
          size: 20,
        ),
      ],
    );
  }
}

// Helper class for background particles
class _BackgroundParticle {
  Offset position;
  Offset velocity;
  double radius;
  Color color;

  _BackgroundParticle({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.color,
  });
}
