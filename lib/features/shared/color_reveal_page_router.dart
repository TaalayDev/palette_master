import 'dart:math';
import 'package:flutter/material.dart';

class ColorRevealPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Color color;

  ColorRevealPageRoute({
    required this.page,
    required this.color,
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return ClipPath(
              clipper: CircleRevealClipper(
                animation.value,
                center: Offset(
                  MediaQuery.of(context).size.width / 2,
                  MediaQuery.of(context).size.height / 2,
                ),
              ),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  color.withOpacity(1.0 - animation.value),
                  BlendMode.srcOver,
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        );
}

class CircleRevealClipper extends CustomClipper<Path> {
  final double progress;
  final Offset center;

  CircleRevealClipper(this.progress, {required this.center});

  @override
  Path getClip(Size size) {
    final radius = size.width * 1.5 * progress;

    return Path()
      ..addOval(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
      );
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

class ColorSplashTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final Color color;
  final List<Color>? splashColors;

  const ColorSplashTransition({
    Key? key,
    required this.animation,
    required this.child,
    required this.color,
    this.splashColors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = splashColors ??
        [
          color,
          color.withRed((color.red + 50) % 256),
          color.withGreen((color.green + 50) % 256),
          color.withBlue((color.blue + 50) % 256),
        ];

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Stack(
          children: [
            // Background color splash
            ...List.generate(colors.length, (index) {
              final delay = index * 0.2;
              final progress = (animation.value - delay).clamp(0.0, 1.0);

              return progress <= 0
                  ? const SizedBox.shrink()
                  : CustomPaint(
                      painter: _SplashPainter(
                        progress: progress,
                        color: colors[index],
                      ),
                      size: MediaQuery.of(context).size,
                    );
            }),

            // Fade in the child
            Opacity(
              opacity: animation.value.clamp(0.0, 1.0),
              child: child,
            ),
          ],
        );
      },
    );
  }
}

class _SplashPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Random _random = Random(42); // Fixed seed for consistent pattern

  _SplashPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Create a splash pattern with multiple circles
    final numSplashes = 10;

    for (int i = 0; i < numSplashes; i++) {
      final centerX = _random.nextDouble() * size.width;
      final centerY = _random.nextDouble() * size.height;
      final maxRadius = _random.nextDouble() * 200 + 100;

      final currentRadius = maxRadius * progress;
      final opacity = (1.0 - progress) * 0.7;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(centerX, centerY),
        currentRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SplashPainter oldDelegate) => progress != oldDelegate.progress || color != oldDelegate.color;
}

class PaletteShimmerTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const PaletteShimmerTransition({
    Key? key,
    required this.animation,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withOpacity(animation.value),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: GradientRotation(animation.value * pi * 2),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: child,
        );
      },
    );
  }
}

class ColorWheelTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const ColorWheelTransition({
    Key? key,
    required this.animation,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Stack(
          children: [
            // Color wheel that expands and then fades out
            if (animation.value < 0.7)
              Opacity(
                opacity: (0.7 - animation.value) / 0.7,
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * animation.value * 3,
                    height: MediaQuery.of(context).size.height * animation.value * 3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.red,
                          Colors.orange,
                          Colors.yellow,
                          Colors.green,
                          Colors.blue,
                          Colors.indigo,
                          Colors.purple,
                          Colors.red,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Child that fades in
            Opacity(
              opacity: animation.value.clamp(0.0, 1.0),
              child: child,
            ),
          ],
        );
      },
    );
  }
}

// Usage example for animated page transitions
class AnimatedPageTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final TransitionType type;
  final Color? color;

  const AnimatedPageTransition({
    Key? key,
    required this.child,
    required this.animation,
    required this.secondaryAnimation,
    this.type = TransitionType.fade,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );

    switch (type) {
      case TransitionType.fade:
        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );

      case TransitionType.slide:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );

      case TransitionType.scale:
        return ScaleTransition(
          scale: curvedAnimation,
          child: child,
        );

      case TransitionType.colorSplash:
        return ColorSplashTransition(
          animation: curvedAnimation,
          color: color ?? Colors.purple,
          child: child,
        );

      case TransitionType.shimmer:
        return PaletteShimmerTransition(
          animation: curvedAnimation,
          child: child,
        );

      case TransitionType.colorWheel:
        return ColorWheelTransition(
          animation: curvedAnimation,
          child: child,
        );

      default:
        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );
    }
  }
}

enum TransitionType {
  fade,
  slide,
  scale,
  colorSplash,
  shimmer,
  colorWheel,
}
