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
  bool _isLoading = true;

  // Animation controllers
  late AnimationController _bgAnimationController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  // Background elements
  List<_RacingParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Background animation
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
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

    // Generate background particles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateBackgroundParticles();
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _generateBackgroundParticles() {
    _particles = List.generate(40, (index) {
      return _RacingParticle(
        position: Offset(
          _random.nextDouble() * MediaQuery.of(context).size.width,
          _random.nextDouble() * MediaQuery.of(context).size.height,
        ),
        size: _random.nextDouble() * 40 + 5,
        speed: _random.nextDouble() * 3 + 1,
        color: HSVColor.fromAHSV(
          0.3 + _random.nextDouble() * 0.1,
          _random.nextDouble() * 360,
          0.7,
          0.9,
        ).toColor(),
        angle: _random.nextDouble() * pi * 2,
      );
    });
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _scaleController.dispose();
    super.dispose();
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
    // Handle failure - maybe show a dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A33),
        title: Text(
          'Race Failed',
          style: TextStyle(color: Colors.red.shade200),
        ),
        content: const Text(
          'Try again! Remember to collect colors that will help you match the target color.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Try Again', style: TextStyle(color: Colors.blue.shade200)),
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

  @override
  Widget build(BuildContext context) {
    final puzzleAsync = ref.watch(puzzleStateProvider(widget.puzzleId, widget.level));
    final userColor = ref.watch(userMixedColorProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedBuilder(
        animation: _bgAnimationController,
        builder: (context, child) {
          // Update background particles
          for (var particle in _particles) {
            particle.position = Offset(
              particle.position.dx + cos(particle.angle) * particle.speed * _bgAnimationController.value,
              particle.position.dy + sin(particle.angle) * particle.speed * _bgAnimationController.value,
            );

            // Wrap particles at screen edges
            final size = MediaQuery.of(context).size;
            if (particle.position.dx < -particle.size) {
              particle.position = Offset(size.width + particle.size, particle.position.dy);
              particle.angle = _random.nextDouble() * pi * 2;
            }
            if (particle.position.dx > size.width + particle.size) {
              particle.position = Offset(-particle.size, particle.position.dy);
              particle.angle = _random.nextDouble() * pi * 2;
            }
            if (particle.position.dy < -particle.size) {
              particle.position = Offset(particle.position.dx, size.height + particle.size);
              particle.angle = _random.nextDouble() * pi * 2;
            }
            if (particle.position.dy > size.height + particle.size) {
              particle.position = Offset(particle.position.dx, -particle.size);
              particle.angle = _random.nextDouble() * pi * 2;
            }
          }

          return Stack(
            children: [
              // Dark racing themed background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF111133),
                      const Color(0xFF0A0A1E),
                    ],
                  ),
                ),
              ),

              // Background particles (racing checkered flags, speed lines, etc)
              ...List.generate(_particles.length, (index) {
                final particle = _particles[index];
                return Positioned(
                  left: particle.position.dx - particle.size / 2,
                  top: particle.position.dy - particle.size / 2,
                  child: Transform.rotate(
                    angle: particle.angle,
                    child: Opacity(
                      opacity: 0.2 + (_random.nextDouble() * 0.1),
                      child: Container(
                        width: particle.size,
                        height: particle.size,
                        decoration: BoxDecoration(
                          color: particle.color,
                          shape: index % 3 == 0 ? BoxShape.circle : BoxShape.rectangle,
                        ),
                      ),
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
                        // Game area (takes all available space)
                        Expanded(
                          child: Hero(
                            tag: 'racer-game',
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
                                child: _isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: ColorRacerGame(
                                          targetColor: puzzle.targetColor,
                                          availableColors: puzzle.availableColors,
                                          onColorMixed: (color) {
                                            ref.read(userMixedColorProvider.notifier).setColor(color);
                                          },
                                          level: widget.level,
                                          onSuccess: _handleSuccess,
                                          onFailure: _handleFailure,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Starting Race...',
                  style: TextStyle(
                    color: Colors.blue.shade300,
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
                    color: Colors.blue.shade300,
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
}

// Helper class for background particles
class _RacingParticle {
  Offset position;
  double size;
  double speed;
  Color color;
  double angle;

  _RacingParticle({
    required this.position,
    required this.size,
    required this.speed,
    required this.color,
    required this.angle,
  });
}
