import 'package:flutter/material.dart';

class ColorPreview extends StatelessWidget {
  final Color color;
  final String label;
  final double size;

  const ColorPreview({super.key, required this.color, required this.label, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
          ),
        ),
        const SizedBox(height: 8),
        Text('RGB(${color.red}, ${color.green}, ${color.blue})', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
