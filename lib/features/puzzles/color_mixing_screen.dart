import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_master/core/constants/app_constants.dart';
import 'package:palette_master/features/puzzles/games/mixing.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
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
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize animation for target color bouncing effect
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.elasticOut,
      ),
    );
    _bounceController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _bounceController.reverse();
      }
    });

    // Background animation
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 30000),
      vsync: this,
    )..repeat();
    _backgroundAnimation = Tween<double>(begin: 0, end: 1).animate(_backgroundController);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _backgroundController.dispose();
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
        // Give feedback but continue game
        _bounceController.forward();
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
        title: const Text('Try Again'),
        content: const Text('You\'ve reached the maximum number of attempts. Would you like to retry this level?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.gameSelection.path);
            },
            child: const Text('Back to Games'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _attempts = 0;
              });
              ref.read(userMixedColorProvider.notifier).reset();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _nextLevel() {
    final int nextLevel = widget.level + 1;
    context.pushReplacementNamed(
      AppRoutes.classicMixing.name,
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
          'Classic Mixing',
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
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  HSVColor.fromAHSV(1.0, (_backgroundAnimation.value * 360) % 360, 0.3, 0.95).toColor(),
                  HSVColor.fromAHSV(1.0, ((_backgroundAnimation.value * 360) + 60) % 360, 0.4, 0.85).toColor(),
                ],
              ),
            ),
            child: child,
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
                        // Puzzle info section
                        _buildPuzzleInfo(context, puzzle),

                        const SizedBox(height: 20),

                        // Game area
                        Expanded(
                          child: Hero(
                            tag: 'mixing-game',
                            child: Material(
                              type: MaterialType.transparency,
                              child: ClassicMixingGame(
                                puzzle: puzzle,
                                userColor: userColor,
                                onColorMixed: (color) {
                                  ref.read(userMixedColorProvider.notifier).setColor(color);
                                },
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
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Loading Color Mixing...',
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
    );
  }

  Widget _buildPuzzleInfo(BuildContext context, Puzzle puzzle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            puzzle.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            puzzle.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(
                Icons.brush,
                'Colors: ${puzzle.availableColors.length}',
                Colors.purple.shade300,
              ),
              const SizedBox(width: 10),
              _buildInfoChip(
                Icons.refresh,
                'Attempts: $_attempts/${puzzle.maxAttempts}',
                _attempts >= puzzle.maxAttempts * 0.7 ? Colors.red.shade300 : Colors.blue.shade300,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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
            backgroundColor: Colors.green.withOpacity(0.7),
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
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Hint',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  puzzle.description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
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
                Text(
                  'Available Colors:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: puzzle.availableColors.map((color) {
                    return Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _toggleHint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Close Hint'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
