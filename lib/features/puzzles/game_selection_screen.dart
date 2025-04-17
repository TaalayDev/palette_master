import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_master/features/shared/providers/sound_controller.dart';
import 'package:palette_master/router/routes.dart';

import '../shared/providers/interstitial_ad_controller.dart';

class GameSelectionScreen extends ConsumerStatefulWidget {
  const GameSelectionScreen({super.key});

  @override
  ConsumerState<GameSelectionScreen> createState() => _GameSelectionScreenState();
}

class _GameSelectionScreenState extends ConsumerState<GameSelectionScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentPage = 0;
  final Random _random = Random();

  // Background bubbles for animation
  final List<_AnimatedBubble> _bubbles = [];

  // Game configurations with descriptions
  final List<Map<String, dynamic>> _games = [
    {
      'title': 'Classic Mixing',
      'description': 'Mix colors by dragging and dropping pigments into the mixing container.',
      'icon': Icons.palette,
      'color': Colors.purple,
      'route': AppRoutes.classicMixing,
      'params': {'enhanced': 'true'},
      'difficulty': 'Beginner',
      'features': ['Drag & Drop', 'Color Mixing', 'Basic Physics'],
      'gameType': 'classicMixing',
    },
    {
      'title': 'Bubble Physics',
      'description': 'Create colors by colliding bubbles with realistic physics.',
      'icon': Icons.bubble_chart,
      'color': Colors.blue,
      'route': AppRoutes.colorBubble,
      'difficulty': 'Intermediate',
      'features': ['Drag & Collide', 'Advanced Physics', 'Particle Effects'],
      'gameType': 'bubblePhysics',
    },
    {
      'title': 'Color Balance',
      'description': 'Balance complementary colors on a physics-based beam scale.',
      'icon': Icons.balance,
      'color': Colors.orange,
      'route': AppRoutes.colorBalance,
      'difficulty': 'Intermediate',
      'features': ['Balance Physics', 'Complementary Colors', 'Weight Mechanics'],
      'gameType': 'colorBalance',
    },
    {
      'title': 'Color Wave',
      'description': 'Create propagating color waves that interact and mix.',
      'icon': Icons.waves,
      'color': Colors.teal,
      'route': AppRoutes.colorWave,
      'difficulty': 'Advanced',
      'features': ['Wave Propagation', 'Additive Color Mixing', 'Dynamic Interactions'],
      'gameType': 'colorWave',
    },
    // {
    //   'title': 'Color Racer',
    //   'description': 'Race through a track collecting colors to mix your car\'s paint.',
    //   'icon': Icons.directions_car,
    //   'color': Colors.red,
    //   'route': AppRoutes.colorRacer,
    //   'difficulty': 'Advanced',
    //   'features': ['Racing Gameplay', 'Obstacle Avoidance', 'Collection Mechanics'],
    //   'gameType': 'colorRacer',
    // },
    {
      'title': 'Color Memory',
      'description': 'Test your color memory by repeating increasingly complex sequences.',
      'icon': Icons.memory,
      'color': Colors.indigo,
      'route': AppRoutes.colorMemory,
      'difficulty': 'Expert',
      'features': ['Pattern Memory', '3D Card Flipping', 'Progressive Difficulty'],
      'gameType': 'colorMemory',
    },
  ];

  @override
  void initState() {
    super.initState();
    ref.read(soundControllerProvider.notifier).playBgm();

    _pageController = PageController(
      viewportFraction: 0.85,
      initialPage: _currentPage,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    // Create background bubbles
    WidgetsBinding.instance.addPostFrameCallback((_) => _createBubbles());

    // Start animation ticker
    _animationController.addListener(_updateBubbles);
  }

  void _createBubbles() {
    for (int i = 0; i < 30; i++) {
      final size = 20.0 + _random.nextDouble() * 60;
      final speed = 0.5 + _random.nextDouble() * 1.5;
      final initialPosition = Offset(
        _random.nextDouble() * MediaQuery.of(context).size.width,
        _random.nextDouble() * MediaQuery.of(context).size.height,
      );

      _bubbles.add(_AnimatedBubble(
        color: HSVColor.fromAHSV(
          0.4 + _random.nextDouble() * 0.2, // opacity
          _random.nextDouble() * 360, // hue
          0.6 + _random.nextDouble() * 0.4, // saturation
          0.7 + _random.nextDouble() * 0.3, // value
        ).toColor(),
        size: size,
        position: initialPosition,
        speed: speed,
      ));
    }
  }

  void _updateBubbles() {
    if (!mounted) return;

    setState(() {
      for (final bubble in _bubbles) {
        // Move bubble upward
        bubble.position = Offset(
          bubble.position.dx + sin(bubble.position.dy / 50) * 0.5,
          bubble.position.dy - bubble.speed,
        );

        // If bubble is off-screen, reset to bottom
        if (bubble.position.dy < -bubble.size) {
          bubble.position = Offset(
            _random.nextDouble() * MediaQuery.of(context).size.width,
            MediaQuery.of(context).size.height + bubble.size,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.removeListener(_updateBubbles);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adLoaded = ref.watch(interstitialAdProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // title: const Text(
        //   'Choose Game Mode',
        //   style: TextStyle(
        //     color: Colors.white,
        //     fontWeight: FontWeight.bold,
        //     fontSize: 24,
        //   ),
        // ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back, color: Colors.white),
        //   onPressed: () => context.go('/'),
        // ),
        actions: [
          // Tutorials
          IconButton(
            icon: const Icon(
              Feather.help_circle,
              color: Colors.white,
            ),
            onPressed: () {
              ref.read(soundControllerProvider.notifier).playClick();
              context.pushNamed(AppRoutes.tutorial.name);
            },
          ),
          // Achievements
          IconButton(
            icon: const Icon(
              Feather.award,
              color: Colors.white,
            ),
            onPressed: () {
              ref.read(soundControllerProvider.notifier).playClick();
              context.pushNamed(AppRoutes.achievements.name);
            },
          ),
          // Settings
          IconButton(
            icon: const Icon(
              Feather.settings,
              color: Colors.white,
            ),
            onPressed: () {
              ref.read(soundControllerProvider.notifier).playClick();
              context.pushNamed(AppRoutes.settings.name);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.deepPurple.shade900,
                  Colors.deepPurple.shade700,
                  Colors.indigo.shade800,
                ],
              ),
            ),
          ),

          // Animated bubbles
          ...(_bubbles.map((bubble) => Positioned(
                left: bubble.position.dx - bubble.size / 2,
                top: bubble.position.dy - bubble.size / 2,
                child: Container(
                  width: bubble.size,
                  height: bubble.size,
                  decoration: BoxDecoration(
                    color: bubble.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ))),

          // Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explore & Play',
                        style: TextStyle(
                          color: Colors.amber.shade200,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Color Theory Games',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a game mode to start mastering color theory through interactive play',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Game carousel
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _games.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                      ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
                    },
                    itemBuilder: (context, index) {
                      final game = _games[index];
                      final isCurrentPage = index == _currentPage;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutQuint,
                        margin: EdgeInsets.symmetric(
                          vertical: isCurrentPage ? 8 : 30,
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: game['color'].withOpacity(0.9),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: game['color'].withOpacity(0.6),
                              blurRadius: isCurrentPage ? 20 : 10,
                              spreadRadius: isCurrentPage ? 5 : 2,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Decorative patterns
                            Positioned(
                              top: -40,
                              right: -40,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -20,
                              left: -20,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),

                            // Content
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Game icon
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: game['color'].withOpacity(0.4),
                                          blurRadius: 15,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      game['icon'],
                                      size: 40,
                                      color: game['color'],
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Game title
                                  Text(
                                    game['title'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Difficulty badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Difficulty: ${game['difficulty']}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Game description
                                  Text(
                                    game['description'],
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Feature tags
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (game['features'] as List<String>)
                                        .map((feature) => Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                feature,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),

                                  const Spacer(),

                                  // Play button
                                  Center(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        ref.read(soundControllerProvider.notifier).playClick();
                                        ref.read(interstitialAdProvider.notifier).showAdIfLoaded(() {
                                          final route = game['route'] as AppRoute;
                                          final params = game['params'] as Map<String, String>? ?? {};

                                          // Add level parameter (start at level 1)
                                          params['level'] = '1';
                                          params['gameType'] = game['gameType'];

                                          // For direct game routes, use puzzleId parameter
                                          params['id'] = _getPuzzleIdFromTitle(game['title']);

                                          context.pushNamed(
                                            route.name,
                                            queryParameters: params,
                                          );
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: game['color'],
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 40,
                                          vertical: 16,
                                        ),
                                        elevation: 8,
                                        shadowColor: Colors.black.withOpacity(0.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.play_arrow),
                                          SizedBox(width: 8),
                                          Text(
                                            'PLAY NOW',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Page indicator
                Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_games.length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 10,
                          width: index == _currentPage ? 30 : 10,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color:
                                index == _currentPage ? _games[_currentPage]['color'] : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPuzzleIdFromTitle(String title) {
    // Map game titles to puzzle IDs
    switch (title) {
      case 'Classic Mixing':
        return 'color_matching';
      case 'Bubble Physics':
        return 'color_matching';
      case 'Color Balance':
        return 'complementary';
      case 'Color Wave':
        return 'color_harmony';
      case 'Color Racer':
        return 'color_matching';
      case 'Color Memory':
        return 'complementary';
      default:
        return 'color_matching';
    }
  }
}

class _AnimatedBubble {
  final Color color;
  final double size;
  Offset position;
  final double speed;

  _AnimatedBubble({
    required this.color,
    required this.size,
    required this.position,
    required this.speed,
  });
}
