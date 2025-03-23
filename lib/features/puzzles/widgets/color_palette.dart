import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/features/puzzles/providers/puzzle_provider.dart';

class ColorPalette extends ConsumerWidget {
  final List<Color> colors;

  const ColorPalette({super.key, required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: colors.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            ref.read(userMixedColorProvider.notifier).mixColor(colors[index]);
          },
          child: Container(
            decoration: BoxDecoration(
              color: colors[index],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 2))],
            ),
          ),
        );
      },
    );
  }
}
