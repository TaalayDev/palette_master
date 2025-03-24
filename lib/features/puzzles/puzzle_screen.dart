import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_master/core/constants/app_constants.dart';
import 'package:palette_master/features/puzzles/games/color_balance.dart';
import 'package:palette_master/features/puzzles/games/color_bubble.dart';
import 'package:palette_master/features/puzzles/games/color_memory.dart';
import 'package:palette_master/features/puzzles/games/color_racer.dart';
import 'package:palette_master/features/puzzles/games/color_wave.dart';
import 'package:palette_master/features/puzzles/games/mixing.dart';
import 'package:palette_master/features/puzzles/models/game_type.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:palette_master/features/puzzles/providers/puzzle_provider.dart';
import 'package:palette_master/features/puzzles/widgets/level_completion_animation.dart';
import 'package:palette_master/router/routes.dart';

class PuzzleScreen extends ConsumerStatefulWidget {
  final String? puzzleId;
  final int level;
  final GameType gameType;

  const PuzzleScreen({super.key, this.puzzleId, required this.level, this.gameType = GameType.classicMixing});

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;
  bool _showLevelComplete = false;
  int _attempts = 0;
  bool _showHint = false;

  // UI animation controllers
  late AnimationController _fadeInController;
  late Animation<double> _fadeInAnimation;

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

    // Initialize background gradient animation
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat(reverse: true);

    _backgroundAnimation = CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    );

    // Initialize fade-in animation for UI elements
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeInAnimation = CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeOut,
    );

    // Start fade-in animation
    _fadeInController.forward();
  }

  @override
  void didUpdateWidget(PuzzleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.level != widget.level) {
      // Reset level state
      setState(() {
        _attempts = 0;
        _showHint = false;
        _showLevelComplete = false;
      });

      // Reset user color
      ref.read(userMixedColorProvider.notifier).reset();
    } else if (oldWidget.puzzleId != widget.puzzleId) {
      // Reset level state
      setState(() {
        _attempts = 0;
        _showHint = false;
        _showLevelComplete = false;
      });

      // Reset user color
      ref.read(userMixedColorProvider.notifier).reset();
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _backgroundController.dispose();
    _fadeInController.dispose();
    super.dispose();
  }

  void _checkResult(BuildContext context) {
    final userColor = ref.read(userMixedColorProvider);
    final puzzle = ref.read(puzzleStateProvider(widget.puzzleId ?? 'color_matching', widget.level)).value;

    if (puzzle == null) return;

    setState(() {
      _attempts++;
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
        _showFeedbackSnackBar(false);
      }
    });
  }

  void _handleSuccess() {
    // Update progress
    ref.read(gameProgressProvider.notifier).updateProgress(widget.puzzleId ?? 'color_matching', widget.level + 1);

    // Show success feedback
    _showFeedbackSnackBar(true);

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
              context.go(AppRoutes.home.path);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.secondary,
            ),
            child: const Text('Back to Home'),
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
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('Retry'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showFeedbackSnackBar(bool isSuccess) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error_outline,
            color: isSuccess ? Colors.green[300] : Colors.red[300],
          ),
          const SizedBox(width: 16),
          Text(
            isSuccess ? 'Perfect match! Great job!' : 'Not quite right. Try again!',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isSuccess ? Colors.green.withOpacity(0.9) : Colors.red.withOpacity(0.9),
      duration: Duration(seconds: isSuccess ? 3 : 2),
    );

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _nextLevel() {
    final int nextLevel = widget.level + 1;
    context.pushReplacement(
      AppRoutes.puzzles.path,
      extra: {
        'id': widget.puzzleId,
        'level': nextLevel,
        'gameType': widget.gameType,
      },
    );
  }

  void _resetLevel() {
    setState(() {
      _attempts = 0;
      _showHint = false;
    });
    ref.read(userMixedColorProvider.notifier).reset();

    // Show reset feedback
    final snackBar = SnackBar(
      content: const Row(
        children: [
          Icon(Icons.refresh, color: Colors.white),
          SizedBox(width: 16),
          Text(
            'Level reset! Start fresh.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      duration: const Duration(seconds: 1),
    );

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _toggleHint() {
    setState(() {
      _showHint = !_showHint;
    });
  }

  String _getGameTypeDescription() {
    switch (widget.gameType) {
      case GameType.classicMixing:
        return 'Mix colors by adding droplets to create the perfect shade';
      case GameType.bubblePhysics:
        return 'Play with bubble physics to mix colors through collisions';
      case GameType.colorBalance:
        return 'Adjust sliders to find the perfect color proportion balance';
      case GameType.colorWave:
        return 'Create waves of color to match gradient transitions';
      case GameType.colorRacer:
        return 'Race through color gates and mix colors at top speed';
      case GameType.colorMemory:
        return 'Test your color memory and recognition skills';
      default:
        return 'Mix and match colors to solve the puzzle';
    }
  }

  @override
  Widget build(BuildContext context) {
    final puzzleAsync = ref.watch(puzzleStateProvider(widget.puzzleId ?? 'color_matching', widget.level));
    final userColor = ref.watch(userMixedColorProvider);
    final resultAsync = ref.watch(puzzleResultProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          onPressed: () => context.pop(),
        ),
        title: FadeTransition(
          opacity: _fadeInAnimation,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.gameType.icon,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Level ${widget.level}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            onPressed: _toggleHint,
            tooltip: 'Show Hint',
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.refresh,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
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
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.tertiaryContainer,
                ],
                stops: [
                  0.3 + (_backgroundAnimation.value * 0.2),
                  0.7 + (_backgroundAnimation.value * 0.2),
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
                  // Main puzzle content
                  FadeTransition(
                    opacity: _fadeInAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.defaultPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Game type description
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _getGameTypeDescription(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),

                          // Puzzle info section
                          _buildPuzzleInfo(context, puzzle),

                          const SizedBox(height: 24),

                          // Game area
                          Expanded(
                            child: _buildGameByType(
                              puzzle: puzzle,
                              userColor: userColor,
                              onColorMixed: (color) {
                                ref.read(userMixedColorProvider.notifier).setColor(color);
                              },
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Action buttons
                          _buildActionButtons(context, puzzle),
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
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stackTrace) => Center(
              child: Text('Error: $error'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPuzzleInfo(BuildContext context, Puzzle puzzle) {
    return Row(
      children: [
        // Available colors indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.brush,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Colors: ${puzzle.availableColors.length}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Attempts counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _attempts >= puzzle.maxAttempts * 0.7
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh,
                size: 16,
                color: _attempts >= puzzle.maxAttempts * 0.7
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Attempts: $_attempts/${puzzle.maxAttempts}',
                style: TextStyle(
                  color: _attempts >= puzzle.maxAttempts * 0.7
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameByType({required Puzzle puzzle, required Color userColor, required Function(Color) onColorMixed}) {
    // Wrap game in a decorated container for consistent styling
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: _getGameWidget(puzzle, userColor, onColorMixed),
    );
  }

  Widget _getGameWidget(Puzzle puzzle, Color userColor, Function(Color) onColorMixed) {
    switch (widget.gameType) {
      case GameType.bubblePhysics:
        return ColorBubblePhysicsGame(
          puzzle: puzzle,
          userColor: userColor,
          onColorMixed: onColorMixed,
        );
      case GameType.colorBalance:
        return ColorBalanceGame(
          puzzle: puzzle,
          userColor: userColor,
          onColorMixed: onColorMixed,
        );
      case GameType.colorWave:
        return ColorWaveGame(
          puzzle: puzzle,
          userColor: userColor,
          onColorMixed: onColorMixed,
        );
      case GameType.colorRacer:
        return ColorRacerGame(
          puzzle: puzzle,
          userColor: userColor,
          onColorMixed: onColorMixed,
        );
      case GameType.colorMemory:
        return ColorMemoryGame(
          puzzle: puzzle,
          userColor: userColor,
          onColorMixed: onColorMixed,
        );
      case GameType.classicMixing:
      default:
        return ClassicMixingGame(
          puzzle: puzzle,
          userColor: userColor,
          onColorMixed: onColorMixed,
        );
    }
  }

  Widget _buildActionButtons(BuildContext context, Puzzle puzzle) {
    final resultAsync = ref.watch(puzzleResultProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Reset button
        TextButton.icon(
          onPressed: _resetLevel,
          icon: const Icon(Icons.refresh),
          label: const Text('Reset'),
          style: TextButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 20),

        // Check match button
        TextButton.icon(
          onPressed: resultAsync.isLoading ? null : () => _checkResult(context),
          icon: resultAsync.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary),
          label: const Text('Check Match'),
          style: TextButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
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
        color: Colors.black.withOpacity(0.7),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hint header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lightbulb,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Hint',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Hint content
                  Text(
                    puzzle.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Target color
                  const Text(
                    'Your Target:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: puzzle.targetColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: puzzle.targetColor.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Available colors
                  const Text(
                    'Available Colors:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
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
                              color: color.withOpacity(0.3),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Close button
                  ElevatedButton.icon(
                    onPressed: _toggleHint,
                    icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSecondary),
                    label: const Text('Close Hint'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
}
