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
  bool _showInfo = true;
  final _selectedColor = ValueNotifier(Colors.transparent);

  // Animation controllers
  late AnimationController _bgController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _colorPaletteController;
  late Animation<double> _colorPaletteAnimation;

  // Background particles
  final List<_BackgroundParticle> _particles = [];
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

    // Color palette animation
    _colorPaletteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _colorPaletteAnimation = CurvedAnimation(
      parent: _colorPaletteController,
      curve: Curves.easeInOut,
    );
    _colorPaletteController.forward();

    // Generate background particles
    _generateParticles();

    // Hide info box after a delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showInfo = false;
        });
      }
    });
  }

  void _generateParticles() {
    for (int i = 0; i < 40; i++) {
      _particles.add(_BackgroundParticle(
        position: Offset(
          _random.nextDouble() * 500,
          _random.nextDouble() * 800,
        ),
        velocity: Offset(
          (_random.nextDouble() - 0.5) * 0.3,
          (_random.nextDouble() - 0.5) * 0.3,
        ),
        radius: _random.nextDouble() * 15 + 3,
        color: HSVColor.fromAHSV(
          0.1 + _random.nextDouble() * 0.1,
          _random.nextDouble() * 360,
          0.7,
          0.9,
        ).toColor(),
      ));
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _scaleController.dispose();
    _colorPaletteController.dispose();
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
              'Not quite right! Try adjusting your wave pattern.',
              style: TextStyle(color: Colors.teal.shade100),
            ),
            backgroundColor: Colors.teal.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'Hint',
              textColor: Colors.white,
              onPressed: () => _toggleHint(),
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
        backgroundColor: Colors.teal.shade900,
        title: Text(
          'Wave Interference Failed!',
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
              foregroundColor: Colors.white,
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

  void _toggleHint() {
    setState(() {
      _showHint = !_showHint;
    });

    // If showing hint, hide the color palette
    if (_showHint) {
      _colorPaletteController.reverse();
    } else {
      _colorPaletteController.forward();
    }
  }

  void _resetLevel() {
    setState(() {
      _attempts = 0;
    });
    ref.read(userMixedColorProvider.notifier).reset();
  }

  void _selectColor(Color color) {
    setState(() {
      _selectedColor.value = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    final puzzleAsync = ref.watch(puzzleStateProvider(widget.puzzleId, widget.level));
    final userColor = ref.watch(userMixedColorProvider);
    final resultAsync = ref.watch(puzzleResultProvider);
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.teal.shade200),
          onPressed: () => context.go(AppRoutes.gameSelection.path),
        ),
        title: Text(
          'Color Wave',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade200,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _showInfo ? Icons.visibility_off : Icons.info_outline,
              color: Colors.teal.shade200,
            ),
            onPressed: () {
              setState(() {
                _showInfo = !_showInfo;
              });
            },
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
            if (particle.position.dx < -particle.radius) {
              particle.position = Offset(size.width + particle.radius, particle.position.dy);
            }
            if (particle.position.dx > size.width + particle.radius) {
              particle.position = Offset(-particle.radius, particle.position.dy);
            }
            if (particle.position.dy < -particle.radius) {
              particle.position = Offset(particle.position.dx, size.height + particle.radius);
            }
            if (particle.position.dy > size.height + particle.radius) {
              particle.position = Offset(particle.position.dx, -particle.radius);
            }
          }

          return Stack(
            children: [
              // Background gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF094A4C),
                      Color(0xFF052A2C),
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
                        // Level info and color previews
                        if (_showInfo)
                          AnimatedOpacity(
                            opacity: _showInfo ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: _buildInfoHeader(puzzle, userColor),
                          ),

                        const SizedBox(height: 8),

                        // Game area
                        Expanded(
                          child: Hero(
                            tag: 'wave-game',
                            child: Material(
                              type: MaterialType.transparency,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.teal.shade700.withOpacity(0.5),
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
                                    level: widget.level,
                                    targetColor: puzzle.targetColor,
                                    availableColors: puzzle.availableColors,
                                    onColorMixed: (color) {
                                      ref.read(userMixedColorProvider.notifier).setColor(color);
                                    },
                                    onReset: _resetLevel,
                                    selectedColorNotifier: _selectedColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Color palette
                        AnimatedBuilder(
                          animation: _colorPaletteAnimation,
                          builder: (context, child) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 70 * _colorPaletteAnimation.value,
                              child: Opacity(
                                opacity: _colorPaletteAnimation.value,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.teal.shade700.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ...puzzle.availableColors.map((color) {
                                  final isSelected = _selectedColor.value == color;
                                  return GestureDetector(
                                    onTap: () => _selectColor(color),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
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
                                            color: color.withOpacity(0.5),
                                            blurRadius: isSelected ? 10 : 5,
                                            spreadRadius: isSelected ? 2 : 0,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),

                                // Reset selection button
                                GestureDetector(
                                  onTap: () => _selectColor(Colors.transparent),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade800,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _selectedColor.value == Colors.transparent
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.clear,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade200),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Generating Wave Patterns...',
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

  Widget _buildInfoHeader(Puzzle puzzle, Color userColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.teal.shade700.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Level info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade800,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Level ${widget.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getDifficultyLabel(widget.level),
                          style: TextStyle(
                            color: Colors.teal.shade200,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getLevelDescription(widget.level),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Attempt counter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Attempts: $_attempts/${puzzle.maxAttempts}',
                      style: TextStyle(
                        color: _attempts >= puzzle.maxAttempts - 1 ? Colors.red.shade300 : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Color targets
          Row(
            children: [
              // Target color
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Target Color',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: puzzle.targetColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white,
                          width: 1,
                        ),
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
              ),

              const SizedBox(width: 16),

              // Current mix
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Your Mix',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: userColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: userColor.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Match percentage
              Column(
                children: [
                  const Text(
                    'Match',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: _getMatchColor(userColor, puzzle.targetColor, puzzle.accuracyThreshold),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color:
                              _getMatchColor(userColor, puzzle.targetColor, puzzle.accuracyThreshold).withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${(_calculateColorSimilarity(userColor, puzzle.targetColor) * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildActionButtons(BuildContext context, Puzzle puzzle, AsyncValue<bool?> resultAsync) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () => _toggleHint(),
          icon: Icon(_showHint ? Icons.visibility_off : Icons.lightbulb_outline),
          label: Text(_showHint ? 'Hide Hint' : 'Show Hint'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
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
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              color: Colors.teal.shade900,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.teal.shade300,
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
                    Icon(Icons.waves, color: Colors.teal.shade200),
                    const SizedBox(width: 10),
                    Text(
                      'Wave Interaction Tips',
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
                        'Select a color from the palette at the bottom',
                        Icons.color_lens,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '2',
                        'Tap and drag on the canvas to place wave emitters',
                        Icons.touch_app,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '3',
                        'Waves will interact when they collide, creating new colors',
                        Icons.waves,
                      ),
                      const SizedBox(height: 12),
                      _buildHintItem(
                        '4',
                        'Reflective obstacles bounce waves, absorptive ones change them',
                        Icons.blur_circular,
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

  String _getDifficultyLabel(int level) {
    if (level <= 3) return 'Beginner';
    if (level <= 6) return 'Intermediate';
    if (level <= 9) return 'Advanced';
    return 'Expert';
  }

  String _getLevelDescription(int level) {
    switch (level) {
      case 1:
        return 'Create your first wave interference pattern';
      case 2:
        return 'Mix primary colors to create secondary colors';
      case 3:
        return 'Try adding a reflective obstacle';
      case 4:
        return 'Create a complex wave pattern with multiple emitters';
      case 5:
        return 'Navigate waves through an obstacle course';
      case 6:
        return 'Create harmony with reflection and absorption';
      case 7:
        return 'Use color subtraction through absorptive obstacles';
      case 8:
        return 'Create a complex harmonic pattern';
      case 9:
        return 'Master wave interference in a complex environment';
      case 10:
        return 'The ultimate wave challenge';
      default:
        return 'Level $level: Mastery challenge';
    }
  }

  Color _getMatchColor(Color userColor, Color targetColor, double threshold) {
    final similarity = _calculateColorSimilarity(userColor, targetColor);
    if (similarity >= threshold) {
      return Colors.green;
    } else if (similarity >= threshold * 0.8) {
      return Colors.orange;
    }
    return Colors.red;
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
}

// Helper class for background particles
class _BackgroundParticle {
  Offset position;
  final Offset velocity;
  final double radius;
  final Color color;

  _BackgroundParticle({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.color,
  });
}
