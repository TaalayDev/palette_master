import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/ClassicMixingLevelGenerator.dart';
import 'package:palette_master/core/color_models/color_mixer.dart';
import 'package:palette_master/core/color_models/rgb_model.dart';
import 'package:vibration/vibration.dart';

class ClassicMixingGame extends ConsumerStatefulWidget {
  final Color targetColor;
  final List<Color> availableColors;
  final Function(Color) onColorMixed;
  final int level;

  const ClassicMixingGame({
    super.key,
    required this.targetColor,
    required this.availableColors,
    required this.onColorMixed,
    required this.level,
  });

  @override
  ConsumerState<ClassicMixingGame> createState() => _ClassicMixingGameState();
}

class _ClassicMixingGameState extends ConsumerState<ClassicMixingGame> with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _waveAnimationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _backgroundAnimationController;
  late AnimationController _splashController;
  late Animation<double> _splashAnimation;

  // Game state
  final List<ColorDroplet> _droplets = [];
  Color _currentMixedColor = Colors.white;
  double _similarity = 0.0;
  Color? _selectedColor;
  Offset? _dragPosition;
  bool _isDragging = false;
  bool _showTutorial = true;
  int _tutorialStep = 0;
  List<ColorSplash> _splashes = [];

  // Physics simulation
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

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

    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _splashAnimation = CurvedAnimation(
      parent: _splashController,
      curve: Curves.easeOut,
    );

    // Start with tutorial
    _showTutorialStep(0);

    // Set up game update ticker
    _setupGameTicker();
  }

  @override
  void dispose() {
    _waveAnimationController.dispose();
    _pulseController.dispose();
    _backgroundAnimationController.dispose();
    _splashController.dispose();
    super.dispose();
  }

  void _setupGameTicker() {
    // Create a ticker for game physics updates
    createTicker((elapsed) {
      _updatePhysics(elapsed);
    }).start();
  }

  void _updatePhysics(Duration elapsed) {
    if (!mounted) return;

    setState(() {
      // Update droplet physics
      for (var droplet in _droplets) {
        // Apply velocity
        droplet.position += droplet.velocity;

        // Apply gravity
        droplet.velocity += const Offset(0, 0.05);

        // Apply friction
        droplet.velocity *= 0.98;

        // Apply bounds
        final size = MediaQuery.of(context).size;
        final containerWidth = size.width * 0.8;
        final containerHeight = size.height * 0.5;

        if (droplet.position.dx - droplet.radius < 0) {
          droplet.position = Offset(droplet.radius, droplet.position.dy);
          droplet.velocity = Offset(-droplet.velocity.dx * 0.8, droplet.velocity.dy);
        }

        if (droplet.position.dx + droplet.radius > containerWidth) {
          droplet.position = Offset(containerWidth - droplet.radius, droplet.position.dy);
          droplet.velocity = Offset(-droplet.velocity.dx * 0.8, droplet.velocity.dy);
        }

        if (droplet.position.dy - droplet.radius < 0) {
          droplet.position = Offset(droplet.position.dx, droplet.radius);
          droplet.velocity = Offset(droplet.velocity.dx, -droplet.velocity.dy * 0.8);
        }

        if (droplet.position.dy + droplet.radius > containerHeight) {
          droplet.position = Offset(droplet.position.dx, containerHeight - droplet.radius);
          droplet.velocity = Offset(droplet.velocity.dx, -droplet.velocity.dy * 0.8);
        }

        // Handle collisions between droplets
        for (var other in _droplets) {
          if (other == droplet) continue;

          final distance = (other.position - droplet.position).distance;
          final minDistance = droplet.radius + other.radius;

          if (distance < minDistance) {
            // Collision detected
            final direction = (other.position - droplet.position).normalize();
            final force = direction * (minDistance - distance) * 0.05;

            droplet.velocity -= force;
            other.velocity += force;

            // Push droplets apart to prevent overlap
            droplet.position -= force;
            other.position += force;
          }
        }
      }

      // Update splashes
      _splashes = _splashes.where((splash) => splash.alpha > 0).toList();
      for (var splash in _splashes) {
        splash.radius += 0.5;
        splash.alpha -= 0.02;
      }

      // Calculate mixed color
      _calculateMixedColor();
    });
  }

  void _calculateMixedColor() {
    if (_droplets.isEmpty) {
      _currentMixedColor = Colors.white;
      _similarity = 0.0;
      widget.onColorMixed(_currentMixedColor);
      return;
    }

    // Mix colors using the ColorMixer utility from the core app
    final List<Color> colors = _droplets.map((d) => d.color).toList();
    final mixedColor = ColorMixer.mixSubtractive(colors);

    // Calculate similarity to target
    final similarity = _calculateColorSimilarity(mixedColor, widget.targetColor);

    setState(() {
      _currentMixedColor = mixedColor;
      _similarity = similarity;
    });

    // Update parent with new mixed color
    widget.onColorMixed(mixedColor);
  }

  double _calculateColorSimilarity(Color color1, Color color2) {
    // Calculate color similarity (normalized between 0 and 1)
    final dr = (color1.red - color2.red) / 255.0;
    final dg = (color1.green - color2.green) / 255.0;
    final db = (color1.blue - color2.blue) / 255.0;

    // Human eyes are more sensitive to green, less to blue
    final distance = (dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11);

    return (1.0 - sqrt(distance)).clamp(0.0, 1.0);
  }

  void _addDroplet(Color color, Offset position) {
    // Create a new droplet at the given position
    final droplet = ColorDroplet(
      id: _random.nextInt(10000),
      position: position,
      color: color,
      radius: 20.0 + _random.nextDouble() * 10.0,
      velocity: Offset(
        _random.nextDouble() * 2.0 - 1.0,
        _random.nextDouble() * 2.0 - 1.0,
      ),
    );

    setState(() {
      _droplets.add(droplet);
    });

    // Create splash effect
    _createSplash(position, color);

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 20, amplitude: 40);
      }
    });

    // Progress tutorial if needed
    if (_showTutorial && _tutorialStep == 0) {
      _showTutorialStep(1);
    } else if (_showTutorial && _tutorialStep == 1 && _droplets.length >= 2) {
      _showTutorialStep(2);
    }
  }

  void _createSplash(Offset position, Color color) {
    final splash = ColorSplash(
      position: position,
      color: color,
      radius: 10.0,
      alpha: 0.7,
    );

    setState(() {
      _splashes.add(splash);
    });

    // Reset and run splash animation
    _splashController.reset();
    _splashController.forward();

    // Create splash particles
    for (int i = 0; i < 8; i++) {
      final angle = i * (pi / 4);
      final particleOffset = Offset(cos(angle) * 20, sin(angle) * 20);

      final particleSplash = ColorSplash(
        position: position + particleOffset,
        color: color,
        radius: 5.0,
        alpha: 0.5,
      );

      setState(() {
        _splashes.add(particleSplash);
      });
    }
  }

  void _handleColorSelect(Color color) {
    setState(() {
      _selectedColor = color;
    });
  }

  void _handlePanStart(DragStartDetails details) {
    if (_selectedColor == null) return;

    setState(() {
      _isDragging = true;
      _dragPosition = details.localPosition;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _selectedColor == null) return;

    setState(() {
      _dragPosition = details.localPosition;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDragging || _selectedColor == null || _dragPosition == null) return;

    // Add a droplet at the drag end position
    _addDroplet(_selectedColor!, _dragPosition!);

    setState(() {
      _isDragging = false;
      _dragPosition = null;
      _selectedColor = null;
    });
  }

  void _resetMix() {
    setState(() {
      _droplets.clear();
      _splashes.clear();
      _currentMixedColor = Colors.white;
      _similarity = 0.0;
    });

    widget.onColorMixed(Colors.white);
  }

  void _showTutorialStep(int step) {
    setState(() {
      _tutorialStep = step;
    });

    if (step < 3) {
      Future.delayed(Duration(seconds: step == 0 ? 5 : 4), () {
        if (mounted && _showTutorial && _tutorialStep == step) {
          // Auto advance tutorial if user hasn't already progressed
          if (step == 0 && _droplets.isEmpty) {
            _showTutorialStep(step + 1);
          } else if (step == 2) {
            _showTutorialStep(step + 1);
            // End tutorial after last step
            Future.delayed(const Duration(seconds: 4), () {
              if (mounted && _showTutorial) {
                setState(() {
                  _showTutorial = false;
                });
              }
            });
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final containerWidth = size.width;
    final containerHeight = size.height * 0.2;

    return Stack(
      children: [
        // Background with animated bubbles
        // Positioned.fill(
        //   child: AnimatedBuilder(
        //     animation: _backgroundAnimationController,
        //     builder: (context, child) {
        //       return CustomPaint(
        //         painter: BubbleBackgroundPainter(
        //           animationValue: _backgroundAnimationController.value,
        //         ),
        //         size: Size.infinite,
        //       );
        //     },
        //   ),
        // ),

        Column(
          children: [
            // Game stats section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Level indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Level ${widget.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Match percentage
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getSimilarityColor().withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _similarity >= 0.9 ? Icons.check_circle : Icons.color_lens,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Match: ${(_similarity * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Color targets
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  // Target color
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Target Color',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _similarity >= 0.9 ? _pulseAnimation.value : 1.0,
                                child: Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: widget.targetColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: widget.targetColor.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: _currentMixedColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _currentMixedColor.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _droplets.isEmpty
                                ? const Text(
                                    'Add colors!',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  )
                                : Text(
                                    'RGB(${_currentMixedColor.red}, ${_currentMixedColor.green}, ${_currentMixedColor.blue})',
                                    style: TextStyle(
                                      color: _getContrastColor(_currentMixedColor),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Mixing container
            GestureDetector(
              onPanStart: _handlePanStart,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              child: Container(
                width: containerWidth,
                height: containerHeight,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white30,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Wave animation background
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _waveAnimationController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: WaveBackgroundPainter(
                                animationValue: _waveAnimationController.value,
                                baseColor: _currentMixedColor,
                              ),
                              size: Size(containerWidth, containerHeight),
                            );
                          },
                        ),
                      ),

                      // Splashes
                      ..._splashes.map((splash) {
                        return Positioned(
                          left: splash.position.dx - splash.radius,
                          top: splash.position.dy - splash.radius,
                          width: splash.radius * 2,
                          height: splash.radius * 2,
                          child: Opacity(
                            opacity: splash.alpha.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: splash.color,
                              ),
                            ),
                          ),
                        );
                      }).toList(),

                      // Droplets
                      ..._droplets.map((droplet) {
                        return Positioned(
                          left: droplet.position.dx - droplet.radius,
                          top: droplet.position.dy - droplet.radius,
                          width: droplet.radius * 2,
                          height: droplet.radius * 2,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: droplet.color,
                              boxShadow: [
                                BoxShadow(
                                  color: droplet.color.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: droplet.radius * 0.5,
                                height: droplet.radius * 0.5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),

                      // Dragging color preview
                      if (_isDragging && _selectedColor != null && _dragPosition != null)
                        Positioned(
                          left: _dragPosition!.dx - 20,
                          top: _dragPosition!.dy - 20,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _selectedColor!.withOpacity(0.7),
                              boxShadow: [
                                BoxShadow(
                                  color: _selectedColor!.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Droplet count
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_droplets.length} ${_droplets.length == 1 ? 'droplet' : 'droplets'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Color palette
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Color Palette',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _resetMix,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reset'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Color grid
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: widget.availableColors.length,
                        itemBuilder: (context, index) {
                          final color = widget.availableColors[index];
                          final isSelected = _selectedColor == color;

                          return GestureDetector(
                            onTap: () => _handleColorSelect(color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: isSelected ? 8 : 4,
                                    spreadRadius: isSelected ? 2 : 0,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Color theory tip
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.indigo.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lightbulb,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getColorTheoryTip(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Tutorial overlay
        if (_showTutorial)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  width: size.width * 0.8,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade900,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.indigo.shade300,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _tutorialStep == 0
                            ? Icons.palette
                            : _tutorialStep == 1
                                ? Icons.touch_app
                                : _tutorialStep == 2
                                    ? Icons.auto_awesome_mosaic
                                    : Icons.check_circle,
                        color: Colors.indigo.shade200,
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _tutorialStep == 0
                            ? 'Welcome to Color Mixing!'
                            : _tutorialStep == 1
                                ? 'Drag & Drop Colors'
                                : _tutorialStep == 2
                                    ? 'Mix Multiple Colors'
                                    : 'Match the Target Color',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _tutorialStep == 0
                            ? 'Select colors from the palette below and drag them into the mixing container.'
                            : _tutorialStep == 1
                                ? 'Great! Now try adding more colors to see how they blend together.'
                                : _tutorialStep == 2
                                    ? 'Watch how the colors mix with fluid physics. Try to match the target color shown at the top.'
                                    : 'When your mixed color matches the target, you\'ll complete the level!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.indigo.shade100,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showTutorial = false;
                          });
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.indigo.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Got it!'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _getSimilarityColor() {
    if (_similarity >= 0.9) return Colors.green;
    if (_similarity >= 0.7) return Colors.orange;
    return Colors.red;
  }

  Color _getContrastColor(Color color) {
    // Returns black or white text color based on background
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  String _getColorTheoryTip() {
    if (widget.level <= 3) {
      return 'Primary colors are Red, Yellow, and Blue. They can be mixed to create secondary colors.';
    } else if (widget.level <= 6) {
      return 'Secondary colors are Orange (Red + Yellow), Green (Yellow + Blue), and Purple (Blue + Red).';
    } else if (widget.level <= 9) {
      return 'The more droplets you add, the more intense your mixed color will become.';
    } else {
      return 'Try adding colors in different proportions to achieve subtle shade variations.';
    }
  }
}

// CustomPainter for animated waves
class WaveBackgroundPainter extends CustomPainter {
  final double animationValue;
  final Color baseColor;

  WaveBackgroundPainter({
    required this.animationValue,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Create gradient background
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        baseColor.withOpacity(0.1),
        baseColor.withOpacity(0.2),
      ],
    );

    final rect = Rect.fromLTWH(0, 0, width, height);
    final paint = Paint()..shader = gradient.createShader(rect);

    canvas.drawRect(rect, paint);

    // Draw animated waves
    final wavePaint = Paint()
      ..color = baseColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();

    // Starting point
    path.moveTo(0, height);

    // First wave
    final wave1Height = height * 0.2;
    final wave1Amplitude = 20.0;
    final wave1Frequency = width / 200.0;

    for (double x = 0; x <= width; x++) {
      final y = height -
          wave1Height +
          sin((x / width * 2 * pi * wave1Frequency) + (animationValue * 2 * pi)) * wave1Amplitude;

      path.lineTo(x, y);
    }

    // Connect to bottom right corner then to bottom left to complete
    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    canvas.drawPath(path, wavePaint);

    // Second wave (smaller)
    final wave2Paint = Paint()
      ..color = baseColor.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final path2 = Path();

    path2.moveTo(0, height);

    final wave2Height = height * 0.3;
    final wave2Amplitude = 15.0;
    final wave2Frequency = width / 150.0;

    for (double x = 0; x <= width; x++) {
      final y = height -
          wave2Height +
          sin((x / width * 2 * pi * wave2Frequency) + (animationValue * 2 * pi * 1.5)) * wave2Amplitude;

      path2.lineTo(x, y);
    }

    path2.lineTo(width, height);
    path2.lineTo(0, height);
    path2.close();

    canvas.drawPath(path2, wave2Paint);
  }

  @override
  bool shouldRepaint(covariant WaveBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.baseColor != baseColor;
  }
}

// Background bubble painter
class BubbleBackgroundPainter extends CustomPainter {
  final double animationValue;
  final List<Bubble> _bubbles = [];

  BubbleBackgroundPainter({required this.animationValue}) {
    final random = Random();

    // Create bubbles once
    if (_bubbles.isEmpty) {
      for (int i = 0; i < 30; i++) {
        _bubbles.add(
          Bubble(
            x: random.nextDouble(),
            y: random.nextDouble(),
            size: 0.02 + random.nextDouble() * 0.05,
            speed: 0.0001 + random.nextDouble() * 0.0002,
            color: HSVColor.fromAHSV(
              0.2 + random.nextDouble() * 0.1,
              random.nextDouble() * 360,
              0.7,
              0.9,
            ).toColor(),
          ),
        );
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final bubble in _bubbles) {
      // Update bubble position based on animation
      final y = (bubble.y - (animationValue * bubble.speed)) % 1.0;

      final paint = Paint()
        ..color = bubble.color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(
          bubble.x * size.width,
          y * size.height,
        ),
        bubble.size * size.width,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BubbleBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// Bubble model for background animation
class Bubble {
  final double x;
  double y;
  final double size;
  final double speed;
  final Color color;

  Bubble({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
  });
}

// Color droplet class for fluid simulation
class ColorDroplet {
  final int id;
  Offset position;
  Offset velocity;
  final double radius;
  final Color color;

  ColorDroplet({
    required this.id,
    required this.position,
    required this.color,
    required this.radius,
    required this.velocity,
  });
}

// Splash effect class
class ColorSplash {
  final Offset position;
  double radius;
  final Color color;
  double alpha;

  ColorSplash({
    required this.position,
    required this.color,
    required this.radius,
    required this.alpha,
  });
}
