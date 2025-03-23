import 'dart:math';
import 'package:flutter/material.dart';
import 'package:palette_master/core/constants/app_constants.dart';

class LevelCompletionAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  final Color primaryColor;
  final Color secondaryColor;

  const LevelCompletionAnimation({
    super.key,
    required this.onComplete,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  State<LevelCompletionAnimation> createState() => _LevelCompletionAnimationState();
}

class _LevelCompletionAnimationState extends State<LevelCompletionAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    // Generate particles
    _generateParticles();

    _controller.forward();

    // Trigger the onComplete callback when animation is done
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          widget.onComplete();
        });
      }
    });
  }

  void _generateParticles() {
    for (int i = 0; i < 50; i++) {
      final color = _random.nextBool() ? widget.primaryColor : widget.secondaryColor;
      final angle = _random.nextDouble() * 2 * pi;
      final velocity = _random.nextDouble() * 5 + 2;
      final size = _random.nextDouble() * 10 + 5;
      final lifetime = _random.nextDouble() * 0.7 + 0.3; // 0.3 to 1.0

      _particles.add(_Particle(
        color: color,
        position: Offset.zero,
        velocity: Offset(cos(angle) * velocity, sin(angle) * velocity),
        size: size,
        lifetime: lifetime,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Update particles
            for (var particle in _particles) {
              if (_controller.value <= particle.lifetime) {
                final t = _controller.value / particle.lifetime;
                particle.position += particle.velocity;
                particle.velocity += const Offset(0, 0.1); // gravity
                particle.opacity = 1.0 - t;
              }
            }

            return Stack(
              children: [
                // Particles
                ...List.generate(_particles.length, (index) {
                  final particle = _particles[index];
                  if (_controller.value > particle.lifetime) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    left: MediaQuery.of(context).size.width / 2 + particle.position.dx - particle.size / 2,
                    top: MediaQuery.of(context).size.height / 2 + particle.position.dy - particle.size / 2,
                    child: Opacity(
                      opacity: particle.opacity,
                      child: Container(
                        width: particle.size,
                        height: particle.size,
                        decoration: BoxDecoration(
                          color: particle.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),

                // Completion text
                Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(AppConstants.largePadding),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 60,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Level Complete!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: widget.onComplete,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                            child: const Text(
                              'Next Level',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  Color color;
  Offset position;
  Offset velocity;
  double size;
  double lifetime;
  double opacity = 1.0;

  _Particle({
    required this.color,
    required this.position,
    required this.velocity,
    required this.size,
    required this.lifetime,
  });
}
