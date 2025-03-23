import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class ColorDroplet extends StatefulWidget {
  final Color color;
  final double size;
  final Function(Color) onDropped;
  final bool isDraggable;

  const ColorDroplet({
    super.key,
    required this.color,
    this.size = 60.0,
    required this.onDropped,
    this.isDraggable = true,
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

    const spring = SpringDescription(
      mass: 30,
      stiffness: 1,
      damping: 1,
    );

    final simulation = SpringSimulation(spring, 0, 1, -unitVelocity);

    _animationController.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (!widget.isDraggable) {
      return _buildDroplet();
    }

    return GestureDetector(
      onPanDown: (_) {
        if (_lastStatus == AnimationStatus.forward || _lastStatus == AnimationStatus.reverse) {
          _animationController.stop();
        }
        _animationController.reset();
        _animationController.forward();
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

        // Notify parent about the color drop
        widget.onDropped(widget.color);

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
        child: _buildDroplet(),
      ),
    );
  }

  Widget _buildDroplet() {
    return Container(
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
    );
  }
}
