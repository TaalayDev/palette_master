import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:palette_master/core/color_mixing_level_generator.dart';

class ColorDroplet extends StatefulWidget {
  final Color color;
  final double size;
  final Function(Color) onDropped;
  final bool isDraggable;
  final bool enablePhysics;
  final Offset initialVelocity;

  const ColorDroplet({
    super.key,
    required this.color,
    this.size = 60.0,
    required this.onDropped,
    this.isDraggable = true,
    this.enablePhysics = true,
    this.initialVelocity = Offset.zero,
  });

  @override
  State<ColorDroplet> createState() => _ColorDropletState();
}

class _ColorDropletState extends State<ColorDroplet> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Alignment _dragAlignment = Alignment.center;
  Animation<Alignment>? _springAnimation;
  AnimationStatus _lastStatus = AnimationStatus.dismissed;

  // For fluid dripping effect
  bool _isDripping = false;
  double _drippingProgress = 0.0;
  List<_Droplet> _miniDroplets = [];

  // Physics simulation properties
  Offset _velocity = Offset.zero;
  Offset _acceleration = const Offset(0, 9.8); // Gravity
  double _angularVelocity = 0.0;
  double _rotation = 0.0;

  // Random for physics variations
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );
    _animationController.addStatusListener((status) {
      _lastStatus = status;
    });

    // Initialize physics if enabled
    if (widget.enablePhysics) {
      _velocity = widget.initialVelocity;
      _angularVelocity = (_random.nextDouble() - 0.5) * 0.2;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _runAnimation(Offset pixelsPerSecond, Size size) {
    _springAnimation = _animationController.drive(
      AlignmentTween(
        begin: _dragAlignment,
        end: Alignment.center,
      ),
    );

    // Calculate the velocity relative to the unit interval, [0,1],
    // used by the animation controller.
    final unitsPerSecondX = pixelsPerSecond.dx / size.width;
    final unitsPerSecondY = pixelsPerSecond.dy / size.height;
    final unitsPerSecond = Offset(unitsPerSecondX, unitsPerSecondY);
    final unitVelocity = unitsPerSecond.distance;

    // Create a spring simulation with realistic physics
    const spring = SpringDescription(
      mass: 30,
      stiffness: 1,
      damping: 1,
    );

    final simulation = SpringSimulation(spring, 0, 1, -unitVelocity);

    _animationController.animateWith(simulation);
  }

  // Method to start fluid dripping animation
  void _startDripping() {
    setState(() {
      _isDripping = true;
      _drippingProgress = 0.0;
    });

    // Animate dripping over time
    Future.delayed(const Duration(milliseconds: 16), _updateDripping);
  }

  // Update dripping effect
  void _updateDripping() {
    if (!mounted || !_isDripping) return;

    setState(() {
      _drippingProgress += 0.02;

      // Create mini droplets at certain thresholds
      if (_drippingProgress > 0.3 && _miniDroplets.isEmpty) {
        _createMiniDroplet();
      } else if (_drippingProgress > 0.7 && _miniDroplets.length == 1) {
        _createMiniDroplet();
      } else if (_drippingProgress > 0.9 && _miniDroplets.length == 2) {
        _createMiniDroplet();
      }

      // Update mini droplets
      for (final droplet in _miniDroplets) {
        droplet.position += droplet.velocity;
        droplet.velocity += _acceleration * 0.01; // Scale down acceleration
      }
    });

    if (_drippingProgress < 1.0) {
      Future.delayed(const Duration(milliseconds: 16), _updateDripping);
    } else {
      _finishDripping();
    }
  }

  // Create a mini droplet for dripping effect
  void _createMiniDroplet() {
    final dropletSize = widget.size * 0.2 * (0.5 + _random.nextDouble() * 0.5);

    _miniDroplets.add(
      _Droplet(
        size: dropletSize,
        position: Offset(0, widget.size * 0.4),
        velocity: Offset((_random.nextDouble() - 0.5) * 0.5, 0.5),
      ),
    );
  }

  // Finish dripping animation
  void _finishDripping() {
    if (!mounted) return;

    setState(() {
      _isDripping = false;
      _miniDroplets.clear();
    });

    // Notify parent that drop completed
    widget.onDropped(widget.color);
  }

  // Update physics-based movement
  void _updatePhysics() {
    if (!mounted || !widget.enablePhysics) return;

    setState(() {
      // Apply acceleration
      _velocity += _acceleration * 0.01; // Scale down for smoother animation

      // Update rotation
      _rotation += _angularVelocity;

      // Apply damping to slow down
      _velocity *= 0.99;
      _angularVelocity *= 0.99;
    });

    if (_velocity.distance > 0.01 || _angularVelocity.abs() > 0.01) {
      Future.delayed(const Duration(milliseconds: 16), _updatePhysics);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (!widget.isDraggable) {
      return _buildDroplet(false);
    }

    return GestureDetector(
      onPanDown: (_) {
        if (_lastStatus == AnimationStatus.forward || _lastStatus == AnimationStatus.reverse) {
          _animationController.stop();
        }
        _animationController.reset();
        _animationController.forward();

        // Start dripping effect when pressed
        if (!_isDripping) {
          _startDripping();
        }
      },
      onPanUpdate: (details) {
        setState(() {
          _dragAlignment += Alignment(
            details.delta.dx / (size.width / 2),
            details.delta.dy / (size.height / 2),
          );
        });
      },
      onPanEnd: (details) {
        _runAnimation(details.velocity.pixelsPerSecond, size);

        // Notify parent about the color drop - handled by _finishDripping
        //_startDripping();

        // Reset the animation for next use
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _animationController.reset();
          }
        });
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: _buildDroplet(true),
      ),
    );
  }

  Widget _buildDroplet(bool interactive) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main droplet
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: widget.size * 0.3,
              height: widget.size * 0.3,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),

        // Dripping effect
        if (_isDripping && interactive)
          Positioned(
            bottom: -widget.size * 0.1,
            left: widget.size * 0.4,
            child: Container(
              width: widget.size * 0.2,
              height: widget.size * 0.2 * _drippingProgress,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(widget.size * 0.1),
              ),
            ),
          ),

        // Mini droplets
        ..._miniDroplets.map((droplet) {
          return Positioned(
            left: widget.size * 0.4 + droplet.position.dx,
            top: widget.size * 0.5 + droplet.position.dy,
            child: Container(
              width: droplet.size,
              height: droplet.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.2),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}

// Helper class for mini droplets
class _Droplet {
  final double size;
  Offset position;
  Offset velocity;

  _Droplet({
    required this.size,
    required this.position,
    required this.velocity,
  });
}

// Enhanced mixing container with realistic fluid physics
class EnhancedColorMixingContainer extends StatefulWidget {
  final double height;
  final double width;
  final Function(Color) onColorChanged;
  final List<Color> initialColors;

  const EnhancedColorMixingContainer({
    super.key,
    this.height = 200,
    this.width = 200,
    required this.onColorChanged,
    this.initialColors = const [],
  });

  @override
  State<EnhancedColorMixingContainer> createState() => _EnhancedColorMixingContainerState();
}

class _EnhancedColorMixingContainerState extends State<EnhancedColorMixingContainer>
    with SingleTickerProviderStateMixin {
  // List of fluid particles
  List<_FluidParticle> _particles = [];

  // Physics properties
  final double _gravity = 0.1;
  final double _friction = 0.97;
  final double _fluidDensity = 0.1;

  // Animation controller for fluid simulation
  late AnimationController _animationController;

  // Random for physics variations
  final Random _random = Random();

  // Track touch input
  bool _isTouching = false;
  Offset? _touchPosition;
  List<_RippleEffect> _ripples = [];

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _animationController.addListener(_updateFluidSimulation);

    // Initialize with any colors provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final color in widget.initialColors) {
        _addColorToMix(
          color,
          Offset(
            widget.width / 2 + (_random.nextDouble() * 40 - 20),
            widget.height / 2 + (_random.nextDouble() * 40 - 20),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Add a color to the fluid simulation
  void _addColorToMix(Color color, Offset position) {
    // Create multiple particles for this color
    final particleCount = 8 + _random.nextInt(8);

    for (int i = 0; i < particleCount; i++) {
      final size = 10.0 + _random.nextDouble() * 15.0;

      final particle = _FluidParticle(
        position: position +
            Offset(
              (_random.nextDouble() - 0.5) * 20,
              (_random.nextDouble() - 0.5) * 20,
            ),
        velocity: Offset(
          (_random.nextDouble() - 0.5) * 2,
          (_random.nextDouble() - 0.5) * 2,
        ),
        color: color,
        size: size,
        mass: size * size * 0.01,
      );

      setState(() {
        _particles.add(particle);
      });
    }

    // Create ripple effect
    _createRippleEffect(position, color);

    // Update mixed color
    _updateMixedColor();
  }

  // Create ripple effect at position
  void _createRippleEffect(Offset position, Color color) {
    setState(() {
      _ripples.add(
        _RippleEffect(
          position: position,
          color: color,
          maxRadius: 40 + _random.nextDouble() * 20,
          progress: 0.0,
        ),
      );
    });
  }

  // Update fluid simulation
  void _updateFluidSimulation() {
    if (!mounted) return;

    // Update ripple effects
    for (final ripple in _ripples) {
      ripple.progress += 0.05;
    }

    // Remove completed ripples
    _ripples = _ripples.where((r) => r.progress < 1.0).toList();

    // Apply fluid physics to particles
    for (int i = 0; i < _particles.length; i++) {
      final particle = _particles[i];

      // Apply gravity
      particle.velocity += Offset(0, _gravity);

      // Apply friction
      particle.velocity *= _friction;

      // Apply fluid forces from other particles
      for (int j = 0; j < _particles.length; j++) {
        if (i == j) continue;

        final other = _particles[j];
        final direction = other.position - particle.position;
        final distance = direction.distance;

        if (distance < particle.size + other.size) {
          // Collision resolution
          final overlap = (particle.size + other.size) - distance;
          final resolution = direction.normalize() * overlap * 0.5;

          // Move particles apart
          particle.position -= resolution * (other.mass / (particle.mass + other.mass));

          // Transfer momentum
          final relativeVelocity = other.velocity - particle.velocity;
          final velocityAlongNormal =
              relativeVelocity.dx * direction.dx / distance + relativeVelocity.dy * direction.dy / distance;

          if (velocityAlongNormal > 0) {
            final impulseMagnitude = (1.5 * velocityAlongNormal) / (particle.mass + other.mass);
            final impulse = direction.normalize() * impulseMagnitude;

            particle.velocity += impulse * other.mass;
          }
        } else if (distance < particle.size * 3) {
          // Fluid interaction - attraction/repulsion based on color similarity
          final colorSimilarity = _colorSimilarity(particle.color, other.color);
          final forceMagnitude = colorSimilarity * _fluidDensity * particle.mass * other.mass / (distance * distance);
          final force = direction.normalize() * forceMagnitude;

          // More similar colors attract, dissimilar colors repel
          if (colorSimilarity > 0.5) {
            particle.velocity += force / particle.mass;
          } else {
            particle.velocity -= force / particle.mass;
          }
        }
      }

      // Apply touch forces if user is touching
      if (_isTouching && _touchPosition != null) {
        final touchDirection = _touchPosition! - particle.position;
        final touchDistance = touchDirection.distance;

        if (touchDistance < 100) {
          final touchForce = touchDirection.normalize() * (1.0 - touchDistance / 100) * 0.5;
          particle.velocity += touchForce;
        }
      }

      // Update position
      particle.position += particle.velocity;

      // Contain within bounds
      if (particle.position.dx - particle.size < 0) {
        particle.position = Offset(particle.size, particle.position.dy);
        particle.velocity = Offset(-particle.velocity.dx * 0.8, particle.velocity.dy);
      }

      if (particle.position.dx + particle.size > widget.width) {
        particle.position = Offset(widget.width - particle.size, particle.position.dy);
        particle.velocity = Offset(-particle.velocity.dx * 0.8, particle.velocity.dy);
      }

      if (particle.position.dy - particle.size < 0) {
        particle.position = Offset(particle.position.dx, particle.size);
        particle.velocity = Offset(particle.velocity.dx, -particle.velocity.dy * 0.8);
      }

      if (particle.position.dy + particle.size > widget.height) {
        particle.position = Offset(particle.position.dx, widget.height - particle.size);
        particle.velocity = Offset(particle.velocity.dx, -particle.velocity.dy * 0.8);
      }
    }

    setState(() {});

    // Only update mixed color occasionaly to avoid excessive calculations
    if (_random.nextInt(10) == 0) {
      _updateMixedColor();
    }
  }

  // Calculate mixed color from all particles
  void _updateMixedColor() {
    if (_particles.isEmpty) {
      widget.onColorChanged(Colors.white);
      return;
    }

    // Calculate weighted average based on particle size
    double totalWeight = 0;
    double r = 0, g = 0, b = 0;

    for (final particle in _particles) {
      final weight = particle.size * particle.size; // Weight by area
      totalWeight += weight;

      r += particle.color.red * weight;
      g += particle.color.green * weight;
      b += particle.color.blue * weight;
    }

    final mixedColor = Color.fromRGBO(
      (r / totalWeight).round(),
      (g / totalWeight).round(),
      (b / totalWeight).round(),
      1.0,
    );

    widget.onColorChanged(mixedColor);
  }

  // Calculate similarity between two colors (0-1)
  double _colorSimilarity(Color a, Color b) {
    final dr = (a.red - b.red) / 255.0;
    final dg = (a.green - b.green) / 255.0;
    final db = (a.blue - b.blue) / 255.0;

    // Human eyes are more sensitive to green, less to blue
    final distance = sqrt(dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11);
    return 1.0 - distance.clamp(0.0, 1.0);
  }

  void _handlePointerDown(PointerDownEvent event) {
    setState(() {
      _isTouching = true;
      _touchPosition = event.localPosition;
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    setState(() {
      _touchPosition = event.localPosition;
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    setState(() {
      _isTouching = false;
      _touchPosition = null;
    });
  }

  // Reset all particles
  void reset() {
    setState(() {
      _particles.clear();
      _ripples.clear();
    });

    widget.onColorChanged(Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Fluid mixing container
        Listener(
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                painter: _FluidPainter(
                  particles: _particles,
                  ripples: _ripples,
                ),
                size: Size(widget.width, widget.height),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Reset button
        ElevatedButton.icon(
          onPressed: reset,
          icon: const Icon(Icons.refresh),
          label: const Text('Reset Mix'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// Custom painter for fluid simulation
class _FluidPainter extends CustomPainter {
  final List<_FluidParticle> particles;
  final List<_RippleEffect> ripples;

  _FluidPainter({
    required this.particles,
    required this.ripples,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a gradient background
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw ripple effects
    for (final ripple in ripples) {
      final ripplePaint = Paint()
        ..color = ripple.color.withOpacity((1.0 - ripple.progress) * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final radius = ripple.maxRadius * ripple.progress;

      canvas.drawCircle(
        ripple.position,
        radius,
        ripplePaint,
      );
    }

    // Draw fluid particles in two passes for better visual effect

    // First pass: Draw shadows
    for (final particle in particles) {
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

      canvas.drawCircle(
        particle.position + const Offset(2, 2),
        particle.size,
        shadowPaint,
      );
    }

    // Second pass: Draw actual particles
    for (final particle in particles) {
      final particlePaint = Paint()
        ..color = particle.color
        ..style = PaintingStyle.fill;

      // Main circle
      canvas.drawCircle(
        particle.position,
        particle.size,
        particlePaint,
      );

      // Highlight
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        particle.position - Offset(particle.size * 0.3, particle.size * 0.3),
        particle.size * 0.3,
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FluidPainter oldDelegate) {
    return true; // Always repaint for fluid simulation
  }
}

// Fluid particle class
class _FluidParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double mass;

  _FluidParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.mass,
  });
}

// Ripple effect class
class _RippleEffect {
  final Offset position;
  final Color color;
  final double maxRadius;
  double progress;

  _RippleEffect({
    required this.position,
    required this.color,
    required this.maxRadius,
    required this.progress,
  });
}
