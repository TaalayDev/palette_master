import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_master/core/constants/app_constants.dart';
import 'package:palette_master/router/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDarkMode = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    const Color(0xFF2C2C3E),
                    const Color(0xFF1C1B26),
                  ]
                : [
                    const Color(0xFFE9DEFF),
                    const Color(0xFFFFD8E7),
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                // App logo and title
                Center(
                  child: Column(
                    children: [
                      _buildLogo(isDarkMode),
                      const SizedBox(height: 24),
                      Text(
                        'PALETTE MASTER',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: isDarkMode ? Colors.white : const Color(0xFF4F378B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Text(
                          'Learn color theory through fun, interactive puzzles',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkMode ? Colors.white70 : const Color(0xFF4F378B).withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // Main menu options
                _buildMenuButton(
                  context,
                  icon: Icons.play_arrow_rounded,
                  label: 'Start Playing',
                  description: 'Jump right into color matching challenges',
                  onTap: () {
                    context.pushNamed(AppRoutes.puzzles.name, queryParameters: {'id': 'color_matching', 'level': '1'});
                  },
                  accentColor: const Color(0xFF6750A4),
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  context,
                  icon: Icons.sports_esports_rounded,
                  label: 'Game Selection',
                  description: 'Explore our collection of interactive color games',
                  onTap: () {
                    context.goNamed(AppRoutes.gameSelection.name);
                  },
                  accentColor: const Color(0xFF03A9F4),
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  context,
                  icon: Icons.school_rounded,
                  label: 'Tutorials',
                  description: 'Learn the fundamentals of color theory',
                  onTap: () {
                    context.pushNamed(AppRoutes.tutorial.name, queryParameters: {'id': 'basics'});
                  },
                  accentColor: const Color(0xFF7D5260),
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  context,
                  icon: Icons.emoji_events_rounded,
                  label: 'Achievements',
                  description: 'Track your progress and mastery',
                  onTap: () {
                    context.pushNamed(AppRoutes.achievements.name);
                  },
                  accentColor: const Color(0xFFAD8E03),
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  context,
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  description: 'Customize your experience',
                  onTap: () {
                    context.pushNamed(AppRoutes.settings.name);
                  },
                  accentColor: const Color(0xFF4A4458),
                  isDarkMode: isDarkMode,
                ),

                const Spacer(),

                // Footer text
                Center(
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDarkMode) {
    // Using a custom logo made with Container for now
    // In a real app, you would use SvgPicture.asset() with your SVG logo
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2E2A3D) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(70, 70),
          painter: ColorWheelPainter(),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
    required Color accentColor,
    required bool isDarkMode,
  }) {
    final buttonColor = isDarkMode ? accentColor.withOpacity(0.2) : accentColor.withOpacity(0.1);
    final textColor = isDarkMode ? Colors.white : accentColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: accentColor.withOpacity(0.1),
        highlightColor: accentColor.withOpacity(0.05),
        child: Ink(
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? accentColor.withOpacity(0.3) : accentColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDarkMode ? accentColor.withOpacity(0.3) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : accentColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: textColor.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ColorWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Define primary colors
    const List<Color> colors = [
      Color(0xFFFF0000), // Red
      Color(0xFFFF8000), // Orange
      Color(0xFFFFFF00), // Yellow
      Color(0xFF80FF00), // Chartreuse
      Color(0xFF00FF00), // Green
      Color(0xFF00FF80), // Spring green
      Color(0xFF00FFFF), // Cyan
      Color(0xFF0080FF), // Azure
      Color(0xFF0000FF), // Blue
      Color(0xFF8000FF), // Violet
      Color(0xFFFF00FF), // Magenta
      Color(0xFFFF0080), // Rose
    ];

    final paint = Paint()..style = PaintingStyle.fill;

    // Draw color wheel segments
    final segmentAngle = 2 * 3.14159 / colors.length;
    for (var i = 0; i < colors.length; i++) {
      paint.color = colors[i];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * segmentAngle - 1.57079, // Start at top (-π/2)
        segmentAngle,
        true,
        paint,
      );
    }

    // Draw white center
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.3, paint);

    // Draw border
    paint
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
