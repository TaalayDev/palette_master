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
import '../shared/providers/sound_controller.dart';
import 'games/color_memory.dart';

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
  int _score = 0;
  Color _selectedColor = Colors.white;
  bool _showHint = false;
  bool _showColorTheory = false;

  // Achievement tracking
  int _perfectMatches = 0;
  int _fastMatches = 0;

  // Animation controllers
  late AnimationController _bgController;
  late AnimationController _floatingParticlesController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Background particles
  List<_FloatingParticle> _particles = [];
  final Random _random = Random();

  // Neural pattern animation
  late AnimationController _neuronController;
  List<_NeuronConnection> _connections = [];

  // Reward animation
  late AnimationController _rewardAnimationController;
  String _rewardText = '';
  bool _showReward = false;

  @override
  void initState() {
    super.initState();

    // Background animation
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Floating particles animation
    _floatingParticlesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Pulse animation for UI elements
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Neural animation
    _neuronController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Reward animation
    _rewardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _rewardAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showReward = false;
        });
      }
    });

    // Generate floating particles
    _generateParticles();
    _generateNeuronConnections();

    // Play background music
    Future.delayed(const Duration(milliseconds: 300), () {
      ref.read(soundControllerProvider.notifier).playBgm();
    });
  }

  void _generateParticles() {
    _particles = List.generate(30, (index) {
      return _FloatingParticle(
        position: Offset(
          _random.nextDouble() * 500,
          _random.nextDouble() * 800,
        ),
        velocity: Offset(
          (_random.nextDouble() - 0.5) * 0.3,
          (_random.nextDouble() - 0.5) * 0.3,
        ),
        size: _random.nextDouble() * 15 + 3,
        shape: _random.nextInt(3), // 0: circle, 1: diamond, 2: square
        color: HSVColor.fromAHSV(
          0.4 + _random.nextDouble() * 0.2,
          _random.nextDouble() * 360,
          0.7,
          0.9,
        ).toColor(),
      );
    });
  }

  void _generateNeuronConnections() {
    _connections = [];
    final nodeCount = 10;
    final nodes = <Offset>[];

    // Generate random node positions
    for (int i = 0; i < nodeCount; i++) {
      nodes.add(Offset(
        _random.nextDouble(),
        _random.nextDouble(),
      ));
    }

    // Generate connections between nodes
    for (int i = 0; i < nodeCount; i++) {
      final connectionCount = 2 + _random.nextInt(3); // 2-4 connections per node
      final currentNode = nodes[i];

      for (int j = 0; j < connectionCount; j++) {
        final targetIndex = _random.nextInt(nodeCount);
        if (targetIndex != i) {
          final targetNode = nodes[targetIndex];

          _connections.add(
            _NeuronConnection(
              start: currentNode,
              end: targetNode,
              pulseOffset: _random.nextDouble(),
              pulseSpeed: 0.2 + _random.nextDouble() * 0.8,
              color: HSVColor.fromAHSV(
                0.3,
                _random.nextDouble() * 60 + 230, // Blue/purple hue range
                0.6,
                0.9,
              ).toColor(),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _floatingParticlesController.dispose();
    _pulseController.dispose();
    _neuronController.dispose();
    _rewardAnimationController.dispose();

    // Fade out music
    ref.read(soundControllerProvider.notifier).fadeBgm();

    super.dispose();
  }

  void _handleLevelComplete() {
    // Update progress
    ref.read(gameProgressProvider.notifier).updateProgress(widget.puzzleId, widget.level + 1);

    // Update achievement progress
    if (_perfectMatches >= 3) {
      showReward('Achievement: Perfect Matcher!');
    }

    if (_fastMatches >= 2) {
      showReward('Achievement: Speed Demon!');
    }

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 200, amplitude: 200);
      }
    });

    // Play success sound
    ref.read(soundControllerProvider.notifier).playEffect(SoundType.levelComplete);

    // Show level complete animation
    setState(() {
      _showLevelComplete = true;
    });
  }

  void showReward(String rewardText) {
    setState(() {
      _rewardText = rewardText;
      _showReward = true;
      _rewardAnimationController.reset();
      _rewardAnimationController.forward();
    });
  }

  void _nextLevel() {
    final int nextLevel = widget.level + 1;

    // Play click sound
    ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);

    context.pushReplacementNamed(
      AppRoutes.colorMemory.name,
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

    // Play sound
    ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
  }

  void _toggleColorTheory() {
    setState(() {
      _showColorTheory = !_showColorTheory;
    });

    // Play sound
    ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
  }

  void _trackPerfectMatch() {
    _perfectMatches++;
    if (_perfectMatches == 3) {
      showReward('Perfect Matcher: 3 Perfect Matches!');
    }
  }

  void _trackFastMatch() {
    _fastMatches++;
    if (_fastMatches == 2) {
      showReward('Speed Demon: Quick Matching!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final puzzleAsync = ref.watch(puzzleStateProvider(widget.puzzleId, widget.level));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.indigo.shade200),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Color Memory',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade200,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showColorTheory ? Icons.school : Icons.school_outlined, color: Colors.indigo.shade200),
            onPressed: _toggleColorTheory,
            tooltip: 'Color Theory',
          ),
          IconButton(
            icon: Icon(_showHint ? Icons.lightbulb : Icons.lightbulb_outline, color: Colors.indigo.shade200),
            onPressed: _toggleHint,
            tooltip: 'Show Hint',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: Listenable.merge([
              _bgController,
              _floatingParticlesController,
              _neuronController,
            ]),
            builder: (context, child) {
              // Update particle positions
              for (var particle in _particles) {
                particle.position += particle.velocity;

                // Wrap around screen edges
                final size = MediaQuery.of(context).size;
                if (particle.position.dx < -particle.size) {
                  particle.position = Offset(size.width + particle.size, particle.position.dy);
                }
                if (particle.position.dx > size.width + particle.size) {
                  particle.position = Offset(-particle.size, particle.position.dy);
                }
                if (particle.position.dy < -particle.size) {
                  particle.position = Offset(particle.position.dx, size.height + particle.size);
                }
                if (particle.position.dy > size.height + particle.size) {
                  particle.position = Offset(particle.position.dx, -particle.size);
                }
              }

              return Stack(
                children: [
                  // Background gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1A1035),
                          const Color(0xFF0D0627),
                        ],
                      ),
                    ),
                  ),

                  // Neural connections
                  CustomPaint(
                    painter: NeuralNetworkPainter(
                      connections: _connections,
                      animation: _neuronController.value,
                    ),
                    size: MediaQuery.of(context).size,
                  ),

                  // Floating particles
                  ...List.generate(_particles.length, (index) {
                    final particle = _particles[index];
                    final animValue = _floatingParticlesController.value;
                    final pulseFactor = 0.8 + 0.2 * sin((animValue + index / 10) * 2 * pi);

                    return Positioned(
                      left: particle.position.dx - particle.size / 2,
                      top: particle.position.dy - particle.size / 2,
                      child: _buildParticle(particle, pulseFactor),
                    );
                  }),
                ],
              );
            },
          ),

          // Main content
          SafeArea(
            child: puzzleAsync.when(
              data: (puzzle) {
                if (puzzle == null) {
                  return const Center(child: Text('Puzzle not found'));
                }

                return Stack(
                  children: [
                    // Game content
                    Padding(
                      padding: const EdgeInsets.all(AppConstants.defaultPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Game area
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.indigo.shade300.withOpacity(0.5),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: MemoryGame(
                                  puzzle: puzzle,
                                  onColorSelected: (color) {
                                    setState(() {
                                      _selectedColor = color;
                                    });
                                  },
                                  onScoreUpdate: (score) {
                                    setState(() {
                                      _score = score;
                                    });
                                  },
                                  onLevelComplete: _handleLevelComplete,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Hint overlay
                    if (_showHint) _buildHintOverlay(context, puzzle),

                    // Color theory overlay
                    if (_showColorTheory) _buildColorTheoryOverlay(context, puzzle),

                    // Reward animation overlay
                    if (_showReward) _buildRewardOverlay(),

                    // Level complete overlay
                    if (_showLevelComplete)
                      LevelCompletionAnimation(
                        onComplete: _nextLevel,
                        primaryColor: Colors.indigo,
                        secondaryColor: _selectedColor,
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade200),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Loading Memory Patterns...',
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
        ],
      ),
    );
  }

  Widget _buildParticle(_FloatingParticle particle, double pulseFactor) {
    final size = particle.size * pulseFactor;

    switch (particle.shape) {
      case 0: // Circle
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: particle.color.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
        );
      case 1: // Diamond
        return Transform.rotate(
          angle: pi / 4,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: particle.color.withOpacity(0.6),
              shape: BoxShape.rectangle,
            ),
          ),
        );
      case 2: // Square
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: particle.color.withOpacity(0.6),
            shape: BoxShape.rectangle,
          ),
        );
      default:
        return Container();
    }
  }

  Widget _buildRewardOverlay() {
    return AnimatedBuilder(
      animation: _rewardAnimationController,
      builder: (context, child) {
        final value = _rewardAnimationController.value;
        double opacity = 0.0;
        double scale = 1.0;

        if (value < 0.3) {
          // Fade in and scale up
          opacity = value / 0.3;
          scale = 0.5 + 0.5 * (value / 0.3);
        } else if (value > 0.7) {
          // Fade out
          opacity = 1.0 - ((value - 0.7) / 0.3);
        } else {
          // Hold
          opacity = 1.0;
          scale = 1.0;
        }

        return Positioned(
          top: MediaQuery.of(context).size.height * 0.2,
          left: 0,
          right: 0,
          child: Center(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.shade500.withOpacity(0.6),
                        blurRadius: 10,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.white,
                        size: 30,
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Text(
                          _rewardText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
      },
    );
  }

  Widget _buildHintOverlay(BuildContext context, Puzzle puzzle) {
    int level = puzzle.level;
    String title;
    List<String> hints;

    if (level <= 5) {
      title = 'Classic Memory Match';
      hints = [
        'Find pairs of identical colors in the grid',
        'Try to remember the positions of cards you\'ve seen',
        'Match all pairs to complete the level',
        'Fewer moves means a higher score',
        'Build a streak for combo multipliers!',
      ];
    } else if (level <= 10) {
      title = 'Complementary Colors';
      hints = [
        'Match each color with its complementary color',
        'Complementary colors are opposite on the color wheel',
        'Red pairs with Cyan, Blue with Yellow, Green with Magenta',
        'These pairs create dynamic contrast when placed together',
        'Try to match pairs in a row for higher scores!',
      ];
    } else if (level <= 15) {
      title = 'Color Sequence Memory';
      hints = [
        'Watch the sequence of colors carefully',
        'Repeat the exact sequence in the same order',
        'Sequences get longer as levels progress',
        'You\'ll have limited time to reproduce the sequence',
        'Pay attention to the pattern - some sequences may have a logic to them',
      ];
    } else {
      title = 'Color Mixing Memory';
      hints = [
        'Find the two component colors that create each mix',
        'Remember how colors combine in subtractive mixing',
        'Red + Yellow = Orange, Blue + Yellow = Green, etc.',
        'Both component colors must be selected to match',
        'The reference colors at the top show the mixed colors you need to create',
      ];
    }

    return GestureDetector(
      onTap: _toggleHint,
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1035),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.indigo.shade700,
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
                    Icon(Icons.tips_and_updates, color: Colors.indigo.shade200),
                    const SizedBox(width: 10),
                    Text(
                      title,
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
                    children: List.generate(hints.length, (index) {
                      return _buildHintItem(
                        (index + 1).toString(),
                        hints[index],
                        index == 0
                            ? Icons.touch_app
                            : (index == 1
                                ? Icons.visibility
                                : (index == 2 ? Icons.lightbulb : (index == 3 ? Icons.stars : Icons.functions))),
                      );
                    }),
                  ),
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

  Widget _buildColorTheoryOverlay(BuildContext context, Puzzle puzzle) {
    int level = puzzle.level;
    String title;
    Widget content;

    if (level <= 5) {
      title = 'Primary Colors';
      content = _buildPrimaryColorsTheory();
    } else if (level <= 10) {
      title = 'Complementary Colors';
      content = _buildComplementaryColorsTheory();
    } else if (level <= 15) {
      title = 'Sequence & Pattern Recognition';
      content = _buildPatternTheory();
    } else {
      title = 'Color Mixing Theory';
      content = _buildColorMixingTheory();
    }

    return GestureDetector(
      onTap: _toggleColorTheory,
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1035),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.indigo.shade700,
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
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school, color: Colors.amber.shade300),
                    const SizedBox(width: 10),
                    Text(
                      'Color Theory: $title',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade300,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: content,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _toggleColorTheory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Back to Game'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryColorsTheory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTheorySection(
          'Primary Colors',
          'Primary colors cannot be created by mixing other colors. In traditional color theory, the primary colors are:',
          [
            ColorInfo(Colors.red, 'Red'),
            ColorInfo(Colors.blue, 'Blue'),
            ColorInfo(Colors.yellow, 'Yellow'),
          ],
        ),
        _buildTheorySection(
          'Secondary Colors',
          'Secondary colors are created by mixing two primary colors in equal amounts:',
          [
            ColorInfo(Colors.purple, 'Purple (Red + Blue)'),
            ColorInfo(Colors.green, 'Green (Blue + Yellow)'),
            ColorInfo(Colors.orange, 'Orange (Red + Yellow)'),
          ],
        ),
        _buildTheorySection(
          'Tertiary Colors',
          'Tertiary colors are created by mixing a primary and a neighboring secondary color:',
          [
            ColorInfo(Colors.red.shade900, 'Red-Purple'),
            ColorInfo(Colors.deepPurple, 'Blue-Purple'),
            ColorInfo(Colors.lightBlue, 'Blue-Green'),
            ColorInfo(Colors.lightGreen, 'Yellow-Green'),
            ColorInfo(Colors.amber, 'Yellow-Orange'),
            ColorInfo(Colors.deepOrange, 'Red-Orange'),
          ],
        ),
        _buildTheoryTip(
          'Memory Tip: Memorizing the position of colors on the color wheel can help you quickly identify relationships between colors.',
        ),
      ],
    );
  }

  Widget _buildComplementaryColorsTheory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTheorySection(
          'Complementary Colors',
          'Complementary colors are directly opposite each other on the color wheel. They create maximum contrast and vibrance when placed side by side:',
          [
            ColorInfo(Colors.red, 'Red', complementary: Colors.cyan),
            ColorInfo(Colors.yellow, 'Yellow', complementary: Colors.blue),
            ColorInfo(Colors.green, 'Green', complementary: Colors.purple.shade300),
            ColorInfo(Colors.blue, 'Blue', complementary: Colors.yellow),
            ColorInfo(Colors.purple, 'Purple', complementary: Colors.green.shade300),
            ColorInfo(Colors.cyan, 'Cyan', complementary: Colors.red),
          ],
        ),
        _buildTheorySection(
          'Properties of Complementary Colors',
          'Complementary color pairs have these special properties:',
          [],
          description:
              '• They create strong contrast when placed side by side\n• They create brown/gray when mixed together\n• They can make each other appear more vibrant\n• They are used to create shadow colors (add the complement to create a natural shadow)',
        ),
        _buildTheorySection(
          'Using Complementary Colors',
          'Complementary colors are useful in these situations:',
          [],
          description:
              '• Creating emphasis and focal points\n• Making text more readable against backgrounds\n• Creating vibrant designs that "pop"\n• Creating natural-looking shadows in art',
        ),
        _buildTheoryTip(
          'Memory Tip: Complementary colors are always across from each other on the color wheel. Red is opposite cyan, blue is opposite yellow, etc.',
        ),
      ],
    );
  }

  Widget _buildPatternTheory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTheorySection(
          'Color Sequences',
          'Color sequences follow patterns that our brains can recognize and remember. These patterns can be based on:',
          [],
          description:
              '• Hue progression (moving around the color wheel)\n• Saturation changes (from vivid to muted)\n• Brightness changes (from light to dark)\n• Combinations of the above',
        ),
        _buildTheorySection(
          'Working Memory and Colors',
          'The average person can remember 5-9 items in their short-term working memory. This is why color sequences become more challenging as they get longer.',
          [],
          description:
              'Strategies to remember longer sequences:\n• Chunking: Group colors into meaningful patterns\n• Visualization: Create a mental image or story\n• Verbalization: Name the colors in sequence\n• Association: Connect colors to familiar objects',
        ),
        _buildTheorySection(
          'Pattern Recognition',
          'Our brains naturally look for patterns. In color sequences, these might include:',
          [],
          description:
              '• Repeating elements (Red-Blue-Red-Blue)\n• Alternating patterns (warm-cool-warm-cool)\n• Gradual progressions (light to dark)\n• Color relationships (complementary pairs)',
        ),
        _buildTheoryTip(
          'Memory Tip: When memorizing color sequences, try to find patterns or create a story that links the colors together in a meaningful way.',
        ),
      ],
    );
  }

  Widget _buildColorMixingTheory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTheorySection(
          'Subtractive Color Mixing',
          'When mixing pigments or paints (subtractive mixing), colors absorb (subtract) certain wavelengths of light:',
          [],
          description:
              '• Red + Yellow = Orange\n• Yellow + Blue = Green\n• Blue + Red = Purple\n• All colors mixed = Brown/Black',
        ),
        _buildTheorySection(
          'Color Mixing Proportions',
          'The proportion of each color determines the final result:',
          [
            ColorInfo(Colors.red, 'Red',
                proportion: 2, secondColor: Colors.yellow, secondProportion: 1, resultColor: Colors.deepOrange),
            ColorInfo(Colors.yellow, 'Yellow',
                proportion: 2, secondColor: Colors.blue, secondProportion: 1, resultColor: Colors.lightGreen),
            ColorInfo(Colors.blue, 'Blue',
                proportion: 2, secondColor: Colors.red, secondProportion: 1, resultColor: Colors.deepPurple),
          ],
        ),
        _buildTheorySection(
          'Tints, Tones, and Shades',
          'You can modify colors by adding white, gray, or black:',
          [
            ColorInfo(Colors.red, 'Original Red'),
            ColorInfo(Colors.red.shade300, 'Tint (+ White)'),
            ColorInfo(Colors.red.shade200.withOpacity(0.7), 'Tone (+ Gray)'),
            ColorInfo(Colors.red.shade900, 'Shade (+ Black)'),
          ],
        ),
        _buildTheorySection(
          'Complex Color Mixing',
          'Creating specific colors often requires mixing multiple primaries in different proportions:',
          [],
          description:
              '• Turquoise: Blue + Green (+ tiny bit of Yellow)\n• Coral: Red + Orange + White\n• Lavender: Purple + White (+ tiny bit of Red)\n• Brown: Orange + Blue (or any complement pair)',
        ),
        _buildTheoryTip(
          'Memory Tip: Think of color mixing as a recipe. Primary colors are your basic ingredients, and the proportions determine the final result.',
        ),
      ],
    );
  }

  Widget _buildTheorySection(String title, String intro, List<ColorInfo> colors, {String? description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            intro,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          if (colors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: colors.map((colorInfo) => _buildColorSample(colorInfo)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColorSample(ColorInfo colorInfo) {
    if (colorInfo.complementary != null) {
      // Complementary color display
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              color: colorInfo.color,
            ),
          ),
          Container(
            width: 80,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              color: colorInfo.complementary,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 80,
            child: Text(
              colorInfo.name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    } else if (colorInfo.secondColor != null && colorInfo.resultColor != null) {
      // Color mixing display
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  color: colorInfo.color,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${colorInfo.proportion}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  color: colorInfo.secondColor,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${colorInfo.secondProportion}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: 80,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: colorInfo.resultColor,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_downward,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 80,
            child: Text(
              colorInfo.name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    } else {
      // Basic color sample
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: colorInfo.color,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 80,
            child: Text(
              colorInfo.name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildTheoryTip(String tip) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.shade700.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb,
            color: Colors.amber.shade300,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                color: Colors.amber.shade100,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintItem(String number, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
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
      ),
    );
  }
}

// Helper class for floating particles
class _FloatingParticle {
  Offset position;
  Offset velocity;
  double size;
  Color color;
  int shape; // 0: circle, 1: diamond, 2: square

  _FloatingParticle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    required this.shape,
  });
}

// Helper class for neural connections
class _NeuronConnection {
  final Offset start;
  final Offset end;
  final Color color;
  final double pulseOffset;
  final double pulseSpeed;

  _NeuronConnection({
    required this.start,
    required this.end,
    required this.color,
    required this.pulseOffset,
    required this.pulseSpeed,
  });
}

// Helper class for color theory information
class ColorInfo {
  final Color color;
  final String name;
  final Color? complementary;
  final Color? secondColor;
  final Color? resultColor;
  final int proportion;
  final int secondProportion;

  ColorInfo(
    this.color,
    this.name, {
    this.complementary,
    this.secondColor,
    this.resultColor,
    this.proportion = 1,
    this.secondProportion = 1,
  });
}

// Custom painter for neural network animation
class NeuralNetworkPainter extends CustomPainter {
  final List<_NeuronConnection> connections;
  final double animation;

  NeuralNetworkPainter({
    required this.connections,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final connection in connections) {
      // Calculate start and end points in actual screen coordinates
      final start = Offset(connection.start.dx * size.width, connection.start.dy * size.height);
      final end = Offset(connection.end.dx * size.width, connection.end.dy * size.height);

      // Calculate pulse position along the line
      final phase = (animation * connection.pulseSpeed + connection.pulseOffset) % 1.0;
      final pulsePos = Offset.lerp(start, end, phase)!;

      // Draw the line
      final paint = Paint()
        ..color = connection.color.withOpacity(0.2)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(start, end, paint);

      // Draw the pulse
      final pulsePaint = Paint()
        ..color = connection.color.withOpacity(0.7)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(pulsePos, 3.0, pulsePaint);

      // Draw small circles at start and end
      final nodePaint = Paint()
        ..color = connection.color.withOpacity(0.5)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(start, 2.0, nodePaint);
      canvas.drawCircle(end, 2.0, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant NeuralNetworkPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
