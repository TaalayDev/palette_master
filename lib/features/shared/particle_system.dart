import 'dart:math';
import 'package:flutter/material.dart';

class ParticleSystem extends StatefulWidget {
  final Color baseColor;
  final int particleCount;
  final double maxParticleSize;
  final Duration duration;
  final bool repeat;
  final ParticleSystemType type;
  final Widget? child;
  final Alignment origin;

  const ParticleSystem({
    super.key,
    required this.baseColor,
    this.particleCount = 50,
    this.maxParticleSize = 20,
    this.duration = const Duration(seconds: 2),
    this.repeat = false,
    this.type = ParticleSystemType.explosion,
    this.child,
    this.origin = Alignment.center,
  });

  @override
  State<ParticleSystem> createState() => _ParticleSystemState();
}

class _ParticleSystemState extends State<ParticleSystem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    if (widget.repeat) {
      _controller.repeat();
    } else {
      _controller.forward();
    }

    _generateParticles();

    _controller.addListener(() {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild to animate particles
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generateParticles() {
    _particles = List.generate(widget.particleCount, (index) {
      return _createParticle(index);
    });
  }

  Particle _createParticle(int index) {
    final size = (1.0 + _random.nextDouble()) * widget.maxParticleSize / 2;

    Color color = widget.baseColor;
    if (widget.type == ParticleSystemType.rainbow || widget.type == ParticleSystemType.confetti) {
      // For rainbow and confetti, generate random colors
      color = HSVColor.fromAHSV(
        0.7 + _random.nextDouble() * 0.3, // opacity
        _random.nextDouble() * 360, // hue
        0.7 + _random.nextDouble() * 0.3, // saturation
        0.9, // value
      ).toColor();
    } else if (widget.type == ParticleSystemType.flame) {
      // For flame, stay in red-orange-yellow spectrum
      color = HSVColor.fromAHSV(
        0.7 + _random.nextDouble() * 0.3, // opacity
        10 + _random.nextDouble() * 50, // hue (red to orange)
        0.9, // saturation
        0.9, // value
      ).toColor();
    }

    // Generate different shapes based on type
    ParticleShape shape;
    if (widget.type == ParticleSystemType.confetti) {
      shape = _random.nextBool() ? ParticleShape.rectangle : ParticleShape.line;
    } else if (widget.type == ParticleSystemType.smoke) {
      shape = ParticleShape.circle;
    } else if (widget.type == ParticleSystemType.flame) {
      shape = _random.nextDouble() > 0.7 ? ParticleShape.triangle : ParticleShape.circle;
    } else {
      // Random shape for other types
      final shapeValue = _random.nextDouble();
      if (shapeValue < 0.5) {
        shape = ParticleShape.circle;
      } else if (shapeValue < 0.8) {
        shape = ParticleShape.rectangle;
      } else {
        shape = ParticleShape.triangle;
      }
    }

    // Create different initial velocities based on type
    double vx, vy;
    switch (widget.type) {
      case ParticleSystemType.explosion:
        final angle = _random.nextDouble() * 2 * pi;
        final velocity = 2.0 + _random.nextDouble() * 2.0;
        vx = cos(angle) * velocity;
        vy = sin(angle) * velocity;
        break;
      case ParticleSystemType.waterfall:
        vx = (_random.nextDouble() - 0.5) * 0.5;
        vy = 1.0 + _random.nextDouble() * 0.5;
        break;
      case ParticleSystemType.confetti:
        vx = (_random.nextDouble() - 0.5) * 2.0;
        vy = -2.0 - _random.nextDouble() * 2.0;
        break;
      case ParticleSystemType.flame:
        vx = (_random.nextDouble() - 0.5) * 0.5;
        vy = -1.0 - _random.nextDouble() * 1.0;
        break;
      case ParticleSystemType.smoke:
        vx = (_random.nextDouble() - 0.5) * 0.3;
        vy = -0.5 - _random.nextDouble() * 0.5;
        break;
      case ParticleSystemType.rainbow:
      default:
        vx = (_random.nextDouble() - 0.5) * 2.0;
        vy = (_random.nextDouble() - 0.5) * 2.0;
        break;
    }

    return Particle(
      color: color,
      position: Offset.zero,
      velocity: Offset(vx, vy),
      size: size,
      rotation: _random.nextDouble() * 2 * pi,
      rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
      lifetime: _random.nextDouble() * 0.5 + 0.5,
      shape: shape,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRect(
          child: CustomPaint(
            painter: ParticleSystemPainter(
              particles: _particles,
              animationValue: _controller.value,
              type: widget.type,
              origin: widget.origin,
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class ParticleSystemPainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;
  final ParticleSystemType type;
  final Alignment origin;

  ParticleSystemPainter({
    required this.particles,
    required this.animationValue,
    required this.type,
    required this.origin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final originX = size.width * ((origin.x + 1) / 2);
    final originY = size.height * ((origin.y + 1) / 2);

    for (var i = 0; i < particles.length; i++) {
      final particle = particles[i];

      // Calculate particle lifetime progress
      final particleProgress = (animationValue / particle.lifetime).clamp(0.0, 1.0);

      if (particleProgress >= 1.0) {
        continue; // Skip dead particles
      }

      // Calculate particle position based on type
      double posX, posY;

      switch (type) {
        case ParticleSystemType.explosion:
          posX = originX + particle.velocity.dx * size.width * particleProgress * 0.5;
          posY = originY + particle.velocity.dy * size.height * particleProgress * 0.5;
          break;
        case ParticleSystemType.waterfall:
          posX = originX + particle.velocity.dx * size.width * particleProgress;
          posY = originY + particle.velocity.dy * size.height * particleProgress;
          // Add some sine wave motion
          posX += sin(particleProgress * 10) * 10;
          break;
        case ParticleSystemType.confetti:
          // Confetti falls with gravity
          posX = originX + particle.velocity.dx * size.width * particleProgress;
          posY = originY +
              particle.velocity.dy * size.height * particleProgress +
              9.8 * particleProgress * particleProgress * 100; // Gravity effect
          break;
        case ParticleSystemType.flame:
          // Flames rise and flicker
          posX = originX +
              particle.velocity.dx * size.width * particleProgress +
              sin(particleProgress * 10) * 5; // Flickering
          posY = originY + particle.velocity.dy * size.height * particleProgress;
          break;
        case ParticleSystemType.smoke:
          // Smoke rises and spreads
          posX = originX +
              particle.velocity.dx * size.width * particleProgress +
              sin(particleProgress * 5) * 10 * particleProgress; // Spreading
          posY = originY + particle.velocity.dy * size.height * particleProgress;
          break;
        case ParticleSystemType.rainbow:
        default:
          posX = originX + particle.velocity.dx * size.width * particleProgress;
          posY = originY + particle.velocity.dy * size.height * particleProgress;
          break;
      }

      // Calculate opacity based on lifetime
      double opacity;
      if (type == ParticleSystemType.flame || type == ParticleSystemType.smoke) {
        // Fade out toward the end
        opacity = (1.0 - particleProgress) * particle.color.opacity;
      } else {
        // Fade in at start, fade out at end
        opacity = sin(particleProgress * pi) * particle.color.opacity;
      }

      // Calculate size based on type
      double particleSize;
      if (type == ParticleSystemType.flame) {
        // Flames get smaller as they rise
        particleSize = particle.size * (1.0 - particleProgress * 0.7);
      } else if (type == ParticleSystemType.smoke) {
        // Smoke gets larger as it rises
        particleSize = particle.size * (0.5 + particleProgress * 2.0);
      } else {
        particleSize = particle.size;
      }

      // Draw the particle
      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(posX, posY);
      canvas.rotate(particle.rotation + particle.rotationSpeed * particleProgress * 10);

      switch (particle.shape) {
        case ParticleShape.circle:
          canvas.drawCircle(Offset.zero, particleSize / 2, paint);
          break;
        case ParticleShape.rectangle:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: particleSize,
              height: particleSize * 0.6,
            ),
            paint,
          );
          break;
        case ParticleShape.triangle:
          final path = Path();
          path.moveTo(0, -particleSize / 2);
          path.lineTo(particleSize / 2, particleSize / 2);
          path.lineTo(-particleSize / 2, particleSize / 2);
          path.close();
          canvas.drawPath(path, paint);
          break;
        case ParticleShape.line:
          paint.strokeWidth = particleSize / 6;
          paint.style = PaintingStyle.stroke;
          canvas.drawLine(
            Offset(-particleSize / 2, 0),
            Offset(particleSize / 2, 0),
            paint,
          );
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ParticleSystemPainter oldDelegate) => animationValue != oldDelegate.animationValue;
}

class Particle {
  final Color color;
  Offset position;
  final Offset velocity;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final double lifetime;
  final ParticleShape shape;

  Particle({
    required this.color,
    required this.position,
    required this.velocity,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.lifetime,
    required this.shape,
  });
}

enum ParticleSystemType {
  explosion,
  waterfall,
  confetti,
  flame,
  smoke,
  rainbow,
}

enum ParticleShape {
  circle,
  rectangle,
  triangle,
  line,
}
