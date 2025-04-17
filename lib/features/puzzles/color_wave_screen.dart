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

import '../../core/services/achievments-service.dart';
import '../shared/providers/game_progress_provider.dart';
import '../shared/providers/sound_controller.dart';
import '../shared/providers/interstitial_ad_controller.dart';

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
  final _selectedColor = ValueNotifier<Color?>(null);
  int _score = 0;
  bool _showPowerUpTooltip = false;
  String? _lastUnlockedAchievement;

  // Animation controllers
  late AnimationController _bgController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _colorPaletteController;
  late Animation<double> _colorPaletteAnimation;
  late AnimationController _scoreController;
  late Animation<double> _scoreAnimation;

  // UI effects
  bool _isColorPaletteExpanded = true;
  bool _isInfoExpanded = true;

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

    // Score animation
    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scoreAnimation = CurvedAnimation(
      parent: _scoreController,
      curve: Curves.elasticOut,
    );

    // Generate background particles
    _generateParticles();

    // Play ambient sound effects
    try {
      ref.read(soundControllerProvider.notifier).playBgm();
    } catch (e) {
      // Ignore sound errors - they shouldn't break the game
    }

    // Hide info box after a delay, but keep it for beginners
    if (widget.level > 3) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showInfo = false;
            _isInfoExpanded = false;
          });
        }
      });
    }

    // Show power-up tooltip for intermediate levels
    if (widget.level == 5) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showPowerUpTooltip = true;
          });

          // Auto-hide after a delay
          Future.delayed(const Duration(seconds: 7), () {
            if (mounted) {
              setState(() {
                _showPowerUpTooltip = false;
              });
            }
          });
        }
      });
    }
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
    _scoreController.dispose();
    _selectedColor.dispose();

    // Pause the background music when leaving the screen
    try {
      ref.read(soundControllerProvider.notifier).pauseBgm();
    } catch (e) {
      // Ignore sound errors
    }

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
        _handleSuccess(puzzle);
      } else if (_attempts >= puzzle.maxAttempts) {
        _handleFailure();
      } else {
        // Failed match - play sound
        try {
          ref.read(soundControllerProvider.notifier).playEffect(SoundType.failure);
        } catch (e) {
          // Ignore sound errors
        }

        // Show different messages based on similarity and attempts
        final similarity = _calculateColorSimilarity(userColor, puzzle.targetColor);
        String message;

        if (similarity > puzzle.accuracyThreshold * 0.9) {
          message = 'Almost there! Try a slight adjustment to your wave pattern.';
        } else if (similarity > puzzle.accuracyThreshold * 0.7) {
          message = 'Getting closer! Adjust your wave pattern for a better match.';
        } else if (_attempts > puzzle.maxAttempts / 2) {
          message = 'Try a different approach with your emitter placement.';
        } else {
          message = 'Not quite right! Try adjusting your wave pattern.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
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

  void _handleSuccess(Puzzle puzzle) {
    // Play success sound effects
    try {
      ref.read(soundControllerProvider.notifier).playSuccess();
      ref.read(soundControllerProvider.notifier).playEffect(SoundType.levelComplete);
    } catch (e) {
      // Ignore sound errors
    }

    // Calculate score based on attempts and difficulty
    final basePoints = puzzle.additionalData?['pointsValue'] ?? (widget.level * 10);
    final attemptMultiplier = 1.0 - ((_attempts - 1) / puzzle.maxAttempts) * 0.5;
    final levelMultiplier = widget.level * 0.1 + 1.0;
    final similarityBonus = _calculateColorSimilarity(
          ref.read(userMixedColorProvider),
          puzzle.targetColor,
        ) *
        50;

    final totalScore = (basePoints * attemptMultiplier * levelMultiplier + similarityBonus).round();

    setState(() {
      _score = totalScore;
      _scoreController.forward(from: 0.0);
    });

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 200, amplitude: 200);
      }
    });

    // Update progress
    ref.read(gameProgressProvider.notifier).updateProgress(widget.puzzleId, widget.level + 1);
    ref.read(gameProgressProvider.notifier).addScore(totalScore);

    // Update achievements
    _checkAchievements(puzzle);

    // Show level complete animation
    setState(() {
      _showLevelComplete = true;
    });
  }

  void _checkAchievements(Puzzle puzzle) {
    // Record level completion for achievements
    final achievementsNotifier = ref.read(achievementsProvider.notifier);

    try {
      // Check for specific achievements
      if (widget.puzzleId == 'color_matching') {
        achievementsNotifier.recordLevelCompletion('color_matching', widget.level, 0);

        // Check for perfect match achievement
        final userColor = ref.read(userMixedColorProvider);
        final similarity = _calculateColorSimilarity(userColor, puzzle.targetColor);

        if (similarity >= 0.95) {
          achievementsNotifier.recordColorMatch(true, similarity, _attempts);

          if (similarity >= 0.99 && _attempts == 1) {
            // Perfectly balanced achievement unlocked
            setState(() {
              _lastUnlockedAchievement = 'perfectly_balanced';
            });
          }
        }
      }
    } catch (e) {
      // Ignore achievement errors - they shouldn't break the game
    }
  }

  void _handleFailure() {
    // Play failure sound
    try {
      ref.read(soundControllerProvider.notifier).playFailure();
    } catch (e) {
      // Ignore sound errors
    }

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
    // Show an ad occasionally between levels
    final adController = ref.read(interstitialAdProvider.notifier);

    // Show an ad every 3 levels
    if (widget.level % 3 == 0) {
      adController.showAdIfLoaded(() {
        _navigateToNextLevel();
      });
    } else {
      _navigateToNextLevel();
    }
  }

  void _navigateToNextLevel() {
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
    // Play UI sound
    try {
      ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
    } catch (e) {
      // Ignore sound errors
    }

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
    // Play UI sound
    try {
      ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
    } catch (e) {
      // Ignore sound errors
    }

    setState(() {
      _attempts = 0;
    });
    ref.read(userMixedColorProvider.notifier).reset();
  }

  void _selectColor(Color color) {
    // Play UI sound
    try {
      ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
    } catch (e) {
      // Ignore sound errors
    }

    setState(() {
      _selectedColor.value = color;
    });
  }

  void _toggleInfoPanel() {
    setState(() {
      _isInfoExpanded = !_isInfoExpanded;
      _showInfo = _isInfoExpanded;
    });

    try {
      ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
    } catch (e) {
      // Ignore sound errors
    }
  }

  void _toggleColorPalette() {
    setState(() {
      _isColorPaletteExpanded = !_isColorPaletteExpanded;
    });

    if (_isColorPaletteExpanded) {
      _colorPaletteController.forward();
    } else {
      _colorPaletteController.reverse();
    }

    try {
      ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
    } catch (e) {
      // Ignore sound errors
    }
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.go(AppRoutes.gameSelection.path),
        ),
        title: const Text(
          'Color Wave',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 8.0,
                color: Colors.black,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          // Info toggle button
          IconButton(
            icon: Icon(
              _showInfo ? Icons.visibility_off : Icons.info_outline,
              color: Colors.white,
            ),
            onPressed: _toggleInfoPanel,
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
                      boxShadow: [
                        BoxShadow(
                          color: particle.color.withOpacity(0.3),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
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
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: _isInfoExpanded ? null : 0,
                          child: AnimatedOpacity(
                            opacity: _showInfo ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: _buildInfoHeader(puzzle, userColor),
                          ),
                        ),

                        SizedBox(height: _isInfoExpanded ? 8 : 0),

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

                        // Color palette toggle button
                        Center(
                          child: GestureDetector(
                            onTap: _toggleColorPalette,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade800,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.teal.shade500,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isColorPaletteExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Color Palette',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Color palette
                        AnimatedBuilder(
                          animation: _colorPaletteAnimation,
                          builder: (context, child) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: _isColorPaletteExpanded ? 70 * _colorPaletteAnimation.value : 0,
                              child: Opacity(
                                opacity: _colorPaletteAnimation.value,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
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
                                      child: isSelected
                                          ? const Center(
                                              child: Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            )
                                          : null,
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

                // Power-up tooltip
                if (_showPowerUpTooltip)
                  Positioned(
                    top: 100,
                    right: 20,
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade700,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tips_and_updates, color: Colors.amber.shade200),
                              const SizedBox(width: 8),
                              const Text(
                                'Power-Up Tip',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create wave combos to unlock special power-ups! Watch for the combo counter.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showPowerUpTooltip = false;
                              });
                            },
                            child: const Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Got it',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Achievement unlock notification
                if (_lastUnlockedAchievement != null)
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 250,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade800,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.emoji_events, color: Colors.amber),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Achievement Unlocked!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getAchievementName(_lastUnlockedAchievement!),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getAchievementDescription(_lastUnlockedAchievement!),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _lastUnlockedAchievement = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade600,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Great!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        onEnd: () {
                          // Auto-dismiss after 5 seconds
                          Future.delayed(const Duration(seconds: 5), () {
                            if (mounted) {
                              setState(() {
                                _lastUnlockedAchievement = null;
                              });
                            }
                          });
                        },
                      ),
                    ),
                  ),

                // Score animation
                if (_showLevelComplete && _score > 0)
                  Positioned(
                    top: size.height * 0.4,
                    left: 0,
                    right: 0,
                    child: AnimatedBuilder(
                      animation: _scoreAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scoreAnimation.value,
                          child: child,
                        );
                      },
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade800,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'SCORE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '+$_score',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

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
        color: Colors.black.withOpacity(0.3),
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
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
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
                        const SizedBox(width: 8),
                        Text(
                          _getDifficultyLabel(widget.level),
                          style: TextStyle(
                            color: Colors.teal.shade200,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
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
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _attempts >= puzzle.maxAttempts - 1 ? Colors.red.shade300 : Colors.teal.shade700,
                    width: 1,
                  ),
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

          const SizedBox(height: 12),

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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
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
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                            begin: 0, end: _calculateColorSimilarity(userColor, puzzle.targetColor) * 100),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, value, child) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
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
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.5),
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
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.5),
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

                // Color theory hint based on level
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade800.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tips_and_updates, color: Colors.amber.shade200),
                          const SizedBox(width: 8),
                          const Text(
                            'Color Theory Tip',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getColorTheoryHint(widget.level, puzzle.targetColor),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
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

  String _getColorTheoryHint(int level, Color targetColor) {
    // Extract color properties
    final HSVColor hsv = HSVColor.fromColor(targetColor);
    final hue = hsv.hue;
    final saturation = hsv.saturation;
    final value = hsv.value;

    // Basic hints for different levels
    if (level <= 2) {
      // Primary color mixing
      if (targetColor.red > 200 && targetColor.green > 200) {
        return 'To create yellow, mix red and green waves together.';
      } else if (targetColor.red > 200 && targetColor.blue > 200) {
        return 'To create magenta/purple, mix red and blue waves together.';
      } else if (targetColor.green > 200 && targetColor.blue > 200) {
        return 'To create cyan, mix green and blue waves together.';
      }
      return 'Try combining two primary colors (red, green, blue) to create the target color.';
    } else if (level <= 5) {
      // More complex mixing
      if (saturation < 0.3) {
        return 'For less saturated colors, try mixing with white or combining complementary colors.';
      } else if (value < 0.5) {
        return 'For darker colors, use reflective obstacles to reduce intensity or mix with darker colors.';
      }
      return 'Place emitters at opposite sides of obstacles to create interesting interference patterns.';
    } else {
      // Advanced color theory
      if (hue >= 0 && hue < 30 || hue >= 330 && hue < 360) {
        return 'This is a red-based color. Try using red with a bit of blue or yellow depending on the shade.';
      } else if (hue >= 30 && hue < 90) {
        return 'This is a yellow or yellow-green color. Combine red and green waves with different intensities.';
      } else if (hue >= 90 && hue < 150) {
        return 'This is a green color. Try using multiple green waves with different obstacles.';
      } else if (hue >= 150 && hue < 210) {
        return 'This is a cyan or turquoise color. Mix blue and green with absorptive obstacles.';
      } else if (hue >= 210 && hue < 270) {
        return 'This is a blue color. Use blue waves with reflective obstacles to create variations.';
      } else if (hue >= 270 && hue < 330) {
        return 'This is a purple or magenta color. Mix red and blue waves in different proportions.';
      }
      return 'Experiment with wave collisions and reflective obstacles to create complex color mixes.';
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

  String _getAchievementName(String achievementId) {
    switch (achievementId) {
      case 'color_apprentice':
        return 'Color Apprentice';
      case 'mixing_master':
        return 'Mixing Master';
      case 'pigment_virtuoso':
        return 'Pigment Virtuoso';
      case 'complementary_expert':
        return 'Complementary Expert';
      case 'harmony_seeker':
        return 'Harmony Seeker';
      case 'color_wheel_navigator':
        return 'Color Wheel Navigator';
      case 'optical_illusion_master':
        return 'Optical Illusion Master';
      case 'after_image_observer':
        return 'After-Image Observer';
      case 'color_theory_guru':
        return 'Color Theory Guru';
      case 'speed_mixer':
        return 'Speed Mixer';
      case 'perfectly_balanced':
        return 'Perfectly Balanced';
      default:
        return 'New Achievement';
    }
  }

  String _getAchievementDescription(String achievementId) {
    switch (achievementId) {
      case 'color_apprentice':
        return 'Complete 5 color mixing puzzles';
      case 'mixing_master':
        return 'Create 20 perfect color matches';
      case 'pigment_virtuoso':
        return 'Mix 5 colors to create a complex shade';
      case 'complementary_expert':
        return 'Complete all complementary color challenges';
      case 'harmony_seeker':
        return 'Create 10 perfect color harmonies';
      case 'color_wheel_navigator':
        return 'Identify all tertiary colors correctly';
      case 'optical_illusion_master':
        return 'Complete 5 optical illusion puzzles';
      case 'after_image_observer':
        return 'Successfully predict color after-images';
      case 'color_theory_guru':
        return 'Complete all puzzles with perfect scores';
      case 'speed_mixer':
        return 'Complete any level in under 30 seconds';
      case 'perfectly_balanced':
        return 'Create an exact match with no color adjustments';
      default:
        return 'You unlocked a new achievement!';
    }
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
