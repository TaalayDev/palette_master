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

    // Generate floating particles
    _generateParticles();
    _generateNeuronConnections();
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
    super.dispose();
  }

  void _handleLevelComplete() {
    // Update progress
    ref.read(gameProgressProvider.notifier).updateProgress(widget.puzzleId, widget.level + 1);

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 200, amplitude: 200);
      }
    });

    // Show level complete animation
    setState(() {
      _showLevelComplete = true;
    });
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

  void _toggleHint() {
    setState(() {
      _showHint = !_showHint;
    });
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
            icon: Icon(Icons.info_outline, color: Colors.indigo.shade200),
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
                if (particle.position.dx < -particle.size)
                  particle.position = Offset(size.width + particle.size, particle.position.dy);
                if (particle.position.dx > size.width + particle.size)
                  particle.position = Offset(-particle.size, particle.position.dy);
                if (particle.position.dy < -particle.size)
                  particle.position = Offset(particle.position.dx, size.height + particle.size);
                if (particle.position.dy > size.height + particle.size)
                  particle.position = Offset(particle.position.dx, -particle.size);
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
                          // Top section - Score and level info
                          _buildTopSection(context, puzzle),

                          const SizedBox(height: 12),

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

  Widget _buildTopSection(BuildContext context, Puzzle puzzle) {
    // Get level type based on level number
    String levelType = 'Beginner';
    if (puzzle.level > 5 && puzzle.level <= 10) {
      levelType = 'Complementary';
    } else if (puzzle.level > 10 && puzzle.level <= 15) {
      levelType = 'Sequence';
    } else if (puzzle.level > 15) {
      levelType = 'Mixing';
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.indigo.shade300.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Level info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.memory,
                      color: Colors.indigo.shade200,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Level ${puzzle.level}: $levelType',
                      style: TextStyle(
                        color: Colors.indigo.shade200,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getLevelDescription(puzzle.level),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            // Score display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.indigo.shade300.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SCORE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _score.toString(),
                    style: TextStyle(
                      color: Colors.indigo.shade200,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLevelDescription(int level) {
    if (level <= 5) {
      return 'Match pairs of identical colors';
    } else if (level <= 10) {
      return 'Match each color with its complementary pair';
    } else if (level <= 15) {
      return 'Memorize and repeat the color sequence';
    } else {
      return 'Find component colors that create each mix';
    }
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
      ];
    } else if (level <= 10) {
      title = 'Complementary Colors';
      hints = [
        'Match each color with its complementary color',
        'Complementary colors are opposite on the color wheel',
        'Red pairs with Cyan, Blue with Yellow, Green with Magenta',
        'These pairs create dynamic contrast when placed together',
      ];
    } else if (level <= 15) {
      title = 'Color Sequence Memory';
      hints = [
        'Watch the sequence of colors carefully',
        'Repeat the exact sequence in the same order',
        'Sequences get longer as levels progress',
        'You\'ll have limited time to reproduce the sequence',
      ];
    } else {
      title = 'Color Mixing Memory';
      hints = [
        'Find the two component colors that create each mix',
        'Remember how colors combine in subtractive mixing',
        'Red + Yellow = Orange, Blue + Yellow = Green, etc.',
        'Both component colors must be selected to match',
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
                        index == 0 ? Icons.touch_app : (index == 1 ? Icons.visibility : Icons.lightbulb),
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
