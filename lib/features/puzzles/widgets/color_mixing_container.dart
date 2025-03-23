import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/color_models/color_mixer.dart';
import 'package:palette_master/features/puzzles/providers/puzzle_provider.dart';

class ColorMixingContainer extends ConsumerStatefulWidget {
  final double height;
  final double width;

  const ColorMixingContainer({
    super.key,
    this.height = 200,
    this.width = 200,
  });

  @override
  ConsumerState<ColorMixingContainer> createState() => ColorMixingContainerState();
}

class ColorMixingContainerState extends ConsumerState<ColorMixingContainer> with SingleTickerProviderStateMixin {
  final List<_ColorBubble> _bubbles = [];
  late AnimationController _animationController;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void addColor(Color color) {
    final size = _random.nextDouble() * 20 + 30;

    setState(() {
      _bubbles.add(
        _ColorBubble(
          color: color,
          position: Offset(
            _random.nextDouble() * (widget.width - size),
            _random.nextDouble() * (widget.height - size),
          ),
          size: size,
          velocity: Offset(
            (_random.nextDouble() - 0.5) * 2,
            (_random.nextDouble() - 0.5) * 2,
          ),
        ),
      );
    });

    // Update the mixed color in the provider
    final mixedColor = _calculateMixedColor();
    ref.read(userMixedColorProvider.notifier).setColor(mixedColor);
  }

  Color _calculateMixedColor() {
    if (_bubbles.isEmpty) return Colors.white;

    final colors = _bubbles.map((bubble) => bubble.color).toList();
    return ColorMixer.mixSubtractive(colors);
  }

  void reset() {
    setState(() {
      _bubbles.clear();
    });
    ref.read(userMixedColorProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: _calculateMixedColor(),
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
            ),
            SizedBox(
              width: widget.width,
              height: widget.height,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, _) {
                  // Move bubbles
                  for (var bubble in _bubbles) {
                    bubble.position += bubble.velocity;

                    // Bounce off walls
                    if (bubble.position.dx <= 0 || bubble.position.dx >= widget.width - bubble.size) {
                      bubble.velocity = Offset(-bubble.velocity.dx, bubble.velocity.dy);
                    }
                    if (bubble.position.dy <= 0 || bubble.position.dy >= widget.height - bubble.size) {
                      bubble.velocity = Offset(bubble.velocity.dx, -bubble.velocity.dy);
                    }

                    // Ensure bubble stays within bounds
                    bubble.position = Offset(
                      bubble.position.dx.clamp(0, widget.width - bubble.size),
                      bubble.position.dy.clamp(0, widget.height - bubble.size),
                    );
                  }

                  return CustomPaint(
                    painter: _BubblePainter(_bubbles),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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

class _ColorBubble {
  Color color;
  Offset position;
  double size;
  Offset velocity;

  _ColorBubble({
    required this.color,
    required this.position,
    required this.size,
    required this.velocity,
  });
}

class _BubblePainter extends CustomPainter {
  final List<_ColorBubble> bubbles;

  _BubblePainter(this.bubbles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var bubble in bubbles) {
      final paint = Paint()
        ..color = bubble.color.withOpacity(0.7)
        ..style = PaintingStyle.fill;

      // Draw bubble
      canvas.drawCircle(
        Offset(bubble.position.dx + bubble.size / 2, bubble.position.dy + bubble.size / 2),
        bubble.size / 2,
        paint,
      );

      // Draw highlight
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(
          bubble.position.dx + bubble.size / 2 - bubble.size / 5,
          bubble.position.dy + bubble.size / 2 - bubble.size / 5,
        ),
        bubble.size / 6,
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
