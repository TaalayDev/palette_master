import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_master/core/constants/app_constants.dart';
import 'package:palette_master/core/color_models/color_mixer.dart';

class TutorialScreen extends ConsumerStatefulWidget {
  final String? tutorialId;

  const TutorialScreen({super.key, this.tutorialId});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  late PageController _pageController;
  late String _currentTutorialId;
  int _currentPage = 0;

  final List<String> _tutorialIds = ['basics', 'rgb', 'cmyk', 'harmonies'];
  final List<String> _tutorialTitles = ['Color Basics', 'RGB Color Space', 'CMYK Color Space', 'Color Harmonies'];

  @override
  void initState() {
    super.initState();
    _currentTutorialId = widget.tutorialId ?? 'basics';
    _currentPage = _tutorialIds.indexOf(_currentTutorialId);
    if (_currentPage < 0) _currentPage = 0;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      _currentTutorialId = _tutorialIds[page];
    });

    // Update URL without triggering a new navigation
    // context.replaceQueryParameters({'id': _currentTutorialId});
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Color Theory Tutorials'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tutorial navigation tabs
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tutorialIds.length,
              itemBuilder: (context, index) {
                final isSelected = index == _currentPage;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _tutorialTitles[index],
                        style: TextStyle(
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Tutorial content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                _buildBasicsTutorial(context),
                _buildRGBTutorial(context),
                _buildCMYKTutorial(context),
                _buildHarmoniesTutorial(context),
              ],
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentPage > 0
                      ? () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  '${_currentPage + 1}/${_tutorialIds.length}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                ElevatedButton.icon(
                  onPressed: _currentPage < _tutorialIds.length - 1
                      ? () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicsTutorial(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTutorialHeader(
            context,
            title: 'Color Theory Basics',
            subtitle: 'The fundamental building blocks of color',
            icon: Icons.palette,
          ),

          // Introduction
          _buildInfoCard(
            context,
            title: 'Introduction to Color Theory',
            content: 'Color theory is the study of how colors work together and how they impact human perception. '
                'Understanding color theory is essential for artists, designers, and anyone working with visual media. '
                'This tutorial will introduce you to the fundamental concepts of color theory.',
            iconData: Icons.lightbulb_outline,
          ),

          const SizedBox(height: 24),

          // Primary Colors Section
          _buildTutorialSection(
            context,
            title: 'Primary Colors',
            content:
                'Primary colors are the three pigment colors that cannot be mixed or formed by any combination of other colors. '
                'All other colors are derived from these three colors.',
            colorBoxes: [
              _buildColorBox(Colors.red, 'Red'),
              _buildColorBox(Colors.yellow, 'Yellow'),
              _buildColorBox(Colors.blue, 'Blue'),
            ],
          ),

          // Secondary Colors Section
          _buildTutorialSection(
            context,
            title: 'Secondary Colors',
            content: 'Secondary colors are created by mixing two primary colors together in equal amounts.',
            colorBoxes: [
              _buildColorBox(Colors.orange, 'Orange\n(Red + Yellow)'),
              _buildColorBox(Colors.green, 'Green\n(Yellow + Blue)'),
              _buildColorBox(Colors.purple, 'Purple\n(Blue + Red)'),
            ],
          ),

          // Tertiary Colors Section
          _buildTutorialSection(
            context,
            title: 'Tertiary Colors',
            content:
                'Tertiary colors are created by mixing a primary color with an adjacent secondary color in equal amounts.',
            colorBoxes: [
              _buildColorBox(const Color(0xFFFF8000), 'Red-Orange'),
              _buildColorBox(const Color(0xFFFFFF00), 'Yellow-Orange'),
              _buildColorBox(const Color(0xFF80FF00), 'Yellow-Green'),
              _buildColorBox(const Color(0xFF00FF80), 'Blue-Green'),
              _buildColorBox(const Color(0xFF0080FF), 'Blue-Purple'),
              _buildColorBox(const Color(0xFF8000FF), 'Red-Purple'),
            ],
          ),

          // Color Wheel Section
          _buildTutorialSection(
            context,
            title: 'The Color Wheel',
            content:
                'The color wheel is a circular arrangement of colors that helps visualize the relationships between colors. '
                'It organizes primary, secondary, and tertiary colors in a way that makes it easy to see how they relate to each other.',
            customContent: _buildColorWheel(context),
          ),

          // Interactive Demo
          _buildInteractiveDemo(
            context,
            title: 'Color Mixing Demo',
            description: 'Tap on the circles below to see how primary colors mix together!',
            demoWidget: _buildColorMixingDemo(context),
          ),

          // Did You Know
          _buildDidYouKnow(
            context,
            factTitle: 'Historical Color Wheels',
            factContent:
                'The first color wheel was created by Sir Isaac Newton in 1666. Since then, many artists and scientists '
                'have created their own versions of the color wheel to help explain color relationships in different ways.',
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildRGBTutorial(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTutorialHeader(
            context,
            title: 'RGB Color Model',
            subtitle: 'Understanding the additive color system',
            icon: Icons.monitor,
          ),

          // Introduction
          _buildInfoCard(
            context,
            title: 'What is RGB?',
            content:
                'RGB stands for Red, Green, and Blue. It\'s an additive color model where these three light colors are added together in various combinations to reproduce a broad array of colors. RGB is used in digital displays, such as computer monitors, TVs, and smartphone screens.',
            iconData: Icons.devices,
          ),

          const SizedBox(height: 24),

          // RGB Primary Colors
          _buildTutorialSection(
            context,
            title: 'RGB Primary Colors',
            content:
                'In the RGB model, the primary colors are Red, Green, and Blue. When mixed together in full intensity, they produce white light.',
            colorBoxes: [
              _buildColorBox(Colors.red, 'Red\nR: 255, G: 0, B: 0'),
              _buildColorBox(Colors.green, 'Green\nR: 0, G: 255, B: 0'),
              _buildColorBox(Colors.blue, 'Blue\nR: 0, G: 0, B: 255'),
            ],
          ),

          // RGB Secondary Colors
          _buildTutorialSection(
            context,
            title: 'RGB Secondary Colors',
            content:
                'When RGB primary colors are mixed in pairs, they create the secondary colors: Cyan, Magenta, and Yellow.',
            colorBoxes: [
              _buildColorBox(Colors.cyan, 'Cyan\n(Green + Blue)'),
              _buildColorBox(Color(0xFFFD3DB5), 'Magenta\n(Red + Blue)'),
              _buildColorBox(Colors.yellow, 'Yellow\n(Red + Green)'),
            ],
          ),

          // Additive vs Subtractive
          _buildTutorialSection(
            context,
            title: 'Additive Color Mixing',
            content:
                'The RGB model uses additive color mixing. This means that colors are created by adding light of different wavelengths together:',
            customContent: _buildAdditiveColorDiagram(context),
          ),

          // RGB Color Depth
          _buildTutorialSection(
            context,
            title: 'RGB Color Depth',
            content:
                'In digital systems, each RGB channel typically has 8 bits of color depth, allowing for 256 different intensity levels (0-255) per channel. This creates a total of 16,777,216 possible colors (256³).',
            customContent: _buildRGBSliders(context),
          ),

          // Did You Know
          _buildDidYouKnow(
            context,
            factTitle: 'Your Eyes and RGB',
            factContent:
                'The RGB color model closely mimics how human eyes perceive color. The retina contains three types of cone cells that are sensitive to red, green, and blue light wavelengths, which is why RGB works so well for digital displays.',
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCMYKTutorial(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTutorialHeader(
            context,
            title: 'CMYK Color Model',
            subtitle: 'Understanding the subtractive color system',
            icon: Icons.print,
          ),

          // Introduction
          _buildInfoCard(
            context,
            title: 'What is CMYK?',
            content:
                'CMYK stands for Cyan, Magenta, Yellow, and Key (Black). It\'s a subtractive color model used in color printing. '
                'Unlike RGB, which adds light to create colors, CMYK subtracts light by applying colored inks to a white surface.',
            iconData: Icons.format_paint,
          ),

          const SizedBox(height: 24),

          // CMYK Primary Colors
          _buildTutorialSection(
            context,
            title: 'CMYK Primary Colors',
            content:
                'In the CMYK model, the primary colors are Cyan, Magenta, and Yellow. These are the key inks used in color printing.',
            colorBoxes: [
              _buildColorBox(Colors.cyan, 'Cyan\nC: 100%, M: 0%, Y: 0%, K: 0%'),
              _buildColorBox(Color(0xFFFD3DB5), 'Magenta\nC: 0%, M: 100%, Y: 0%, K: 0%'),
              _buildColorBox(Colors.yellow, 'Yellow\nC: 0%, M: 0%, Y: 100%, K: 0%'),
            ],
          ),

          // Black Key
          _buildTutorialSection(
            context,
            title: 'The K in CMYK: Black',
            content:
                'While theoretically mixing 100% of Cyan, Magenta, and Yellow should produce black, in practice it creates a muddy dark brown. '
                'That\'s why a separate black ink (K) is added to the model for true black colors and improved shadow details.',
            colorBoxes: [
              _buildColorBox(const Color(0xFF3C2415), 'C+M+Y\n(100% each)'),
              _buildColorBox(Colors.black, 'K (Black)\nC: 0%, M: 0%, Y: 0%, K: 100%'),
            ],
          ),

          // Subtractive Mixing
          _buildTutorialSection(
            context,
            title: 'Subtractive Color Mixing',
            content: 'In subtractive color mixing, each ink absorbs (subtracts) certain wavelengths of light. '
                'The more ink applied, the more light is absorbed, resulting in darker colors.',
            customContent: _buildSubtractiveColorDiagram(context),
          ),

          // CMYK vs RGB
          _buildTutorialSection(
            context,
            title: 'CMYK vs RGB',
            content:
                'CMYK has a smaller color gamut (range of colors) than RGB. This is why colors sometimes appear different when printed versus on screen. '
                'Designers must consider this when creating work that will be both displayed digitally and printed.',
            customContent: _buildColorGamutComparison(context),
          ),

          // Did You Know
          _buildDidYouKnow(
            context,
            factTitle: 'Why K Instead of B?',
            factContent:
                'The "K" in CMYK stands for "Key" rather than "Black." In four-color printing, the cyan, magenta, and yellow printing plates must be carefully aligned with the key plate (black), which usually contains the detail of the image.',
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHarmoniesTutorial(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTutorialHeader(
            context,
            title: 'Color Harmonies',
            subtitle: 'Creating balanced and pleasing color combinations',
            icon: Icons.grain,
          ),

          // Introduction
          _buildInfoCard(
            context,
            title: 'What are Color Harmonies?',
            content: 'Color harmonies are combinations of colors that create a pleasing visual effect. '
                'They help create a sense of order and balance in designs. Understanding color harmonies can help you create more effective and appealing color schemes.',
            iconData: Icons.auto_awesome,
          ),

          const SizedBox(height: 24),

          // Complementary Colors
          _buildTutorialSection(
            context,
            title: 'Complementary Colors',
            content: 'Complementary colors are directly opposite each other on the color wheel. '
                'They create a high-contrast, vibrant look when used together.',
            customContent: _buildComplementaryColors(context),
          ),

          // Analogous Colors
          _buildTutorialSection(
            context,
            title: 'Analogous Colors',
            content: 'Analogous color schemes use colors that are adjacent to each other on the color wheel. '
                'They create a harmonious, cohesive look with low contrast.',
            customContent: _buildAnalogousColors(context),
          ),

          // Triadic Colors
          _buildTutorialSection(
            context,
            title: 'Triadic Colors',
            content: 'Triadic color schemes use three colors that are evenly spaced around the color wheel. '
                'They tend to be quite vibrant and offer strong visual contrast while maintaining balance.',
            customContent: _buildTriadicColors(context),
          ),

          // Monochromatic Colors
          _buildTutorialSection(
            context,
            title: 'Monochromatic Colors',
            content: 'Monochromatic color schemes use variations in lightness and saturation of a single color. '
                'They create a cohesive look that\'s easy to manage and always looks elegant.',
            customContent: _buildMonochromaticColors(context),
          ),

          // Split Complementary
          _buildTutorialSection(
            context,
            title: 'Split Complementary',
            content: 'Split complementary schemes use a base color and the two colors adjacent to its complement. '
                'This creates high contrast but with less tension than complementary schemes.',
            customContent: _buildSplitComplementaryColors(context),
          ),

          // Did You Know
          _buildDidYouKnow(
            context,
            factTitle: '60-30-10 Rule',
            factContent:
                'A common design principle for using color harmonies is the 60-30-10 rule: 60% of your design should use a dominant color, 30% a secondary color, and 10% an accent color. This creates a balanced and visually appealing composition.',
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Helper methods for building UI components

  Widget _buildTutorialHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String content,
    required IconData iconData,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  iconData,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialSection(
    BuildContext context, {
    required String title,
    required String content,
    List<Widget> colorBoxes = const [],
    Widget? customContent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (colorBoxes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: colorBoxes,
              ),
            ),
          ],
          if (customContent != null) ...[
            const SizedBox(height: 16),
            customContent,
          ],
        ],
      ),
    );
  }

  Widget _buildColorBox(Color color, String label) {
    final isDark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    final labelColor = isDark ? Colors.white : Colors.black;

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveDemo(
    BuildContext context, {
    required String title,
    required String description,
    required Widget demoWidget,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            Center(child: demoWidget),
          ],
        ),
      ),
    );
  }

  Widget _buildDidYouKnow(
    BuildContext context, {
    required String factTitle,
    required String factContent,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Did You Know?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              factTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              factContent,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Custom content widgets for tutorials

  Widget _buildColorWheel(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: CustomPaint(
                size: const Size(250, 250),
                painter: ColorWheelPainter(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'The color wheel organizes colors in a circle, showing the relationships between primary, secondary, and tertiary colors.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorMixingDemo(BuildContext context) {
    return _ColorMixingDemoWidget();
  }

  Widget _buildAdditiveColorDiagram(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(200, 200),
                painter: AdditiveColorMixingPainter(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'In additive color mixing, red + green + blue light creates white light. '
              'Red + green creates yellow, red + blue creates magenta, and green + blue creates cyan.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRGBSliders(BuildContext context) {
    return const _RGBSliderDemo();
  }

  Widget _buildSubtractiveColorDiagram(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(200, 200),
                painter: SubtractiveColorMixingPainter(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'In subtractive color mixing, cyan + magenta + yellow pigments create black (absorbing all light). '
              'Cyan + magenta creates blue, cyan + yellow creates green, and magenta + yellow creates red.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorGamutComparison(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(200, 200),
                painter: ColorGamutComparisonPainter(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'The RGB color space (represented by the outer triangle) can produce a wider range of colors than the CMYK color space (inner shape). This difference is why some vibrant colors that appear on screen cannot be reproduced in print.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplementaryColors(BuildContext context) {
    final baseColor = Colors.blue;
    final compColor = ColorMixer.getComplementary(baseColor);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHarmonyColorBox(baseColor, 'Base Color'),
                const SizedBox(width: 16),
                Icon(Icons.compare_arrows, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                _buildHarmonyColorBox(compColor, 'Complementary'),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Complementary colors are directly opposite each other on the color wheel. They create high contrast and vibrant looks.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalogousColors(BuildContext context) {
    final baseColor = Colors.blue;
    final analogousColors = ColorMixer.getAnalogous(baseColor);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: analogousColors
                  .map((color) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildHarmonyColorBox(
                          color,
                          color == baseColor ? 'Base Color' : '',
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Analogous colors are next to each other on the color wheel. They create harmonious, cohesive looks.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriadicColors(BuildContext context) {
    final baseColor = Colors.blue;
    final triadicColors = ColorMixer.getTriadic(baseColor);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: triadicColors
                  .map((color) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildHarmonyColorBox(
                          color,
                          color == baseColor ? 'Base Color' : '',
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Triadic colors are evenly spaced around the color wheel (120° apart). They create vibrant, balanced designs.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonochromaticColors(BuildContext context) {
    final baseColor = HSVColor.fromColor(Colors.blue);
    final colors = [
      baseColor.withSaturation(1.0).withValue(1.0).toColor(),
      baseColor.withSaturation(0.75).withValue(0.9).toColor(),
      baseColor.withSaturation(0.5).withValue(0.8).toColor(),
      baseColor.withSaturation(0.25).withValue(0.7).toColor(),
      baseColor.withSaturation(0.1).withValue(0.6).toColor(),
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: colors
                  .map((color) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildHarmonyColorBox(
                          color,
                          color == colors[0] ? 'Base Color' : '',
                          small: true,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Monochromatic colors are variations in lightness and saturation of a single color. They create elegant, cohesive designs.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitComplementaryColors(BuildContext context) {
    final baseColor = HSVColor.fromColor(Colors.blue);
    final comp = HSVColor.fromAHSV(1.0, (baseColor.hue + 180) % 360, baseColor.saturation, baseColor.value);
    final colors = [
      baseColor.toColor(),
      HSVColor.fromAHSV(1.0, (comp.hue - 30) % 360, comp.saturation, comp.value).toColor(),
      HSVColor.fromAHSV(1.0, (comp.hue + 30) % 360, comp.saturation, comp.value).toColor(),
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: colors
                  .map((color) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildHarmonyColorBox(
                          color,
                          color == colors[0] ? 'Base Color' : '',
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Split complementary schemes use a base color and the two colors adjacent to its complement. They create high contrast but less tension than complementary schemes.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHarmonyColorBox(Color color, String label, {bool small = false}) {
    final isDark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    final labelColor = isDark ? Colors.white : Colors.black;
    final size = small ? 50.0 : 70.0;

    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}

// Helper widgets for interactive demos

class _ColorMixingDemoWidget extends StatefulWidget {
  @override
  _ColorMixingDemoWidgetState createState() => _ColorMixingDemoWidgetState();
}

class _ColorMixingDemoWidgetState extends State<_ColorMixingDemoWidget> {
  Color _mixedColor = Colors.white;
  bool _redSelected = false;
  bool _blueSelected = false;
  bool _yellowSelected = false;

  void _updateMixedColor() {
    List<Color> colors = [];
    if (_redSelected) colors.add(Colors.red);
    if (_blueSelected) colors.add(Colors.blue);
    if (_yellowSelected) colors.add(Colors.yellow);

    setState(() {
      if (colors.isEmpty) {
        _mixedColor = Colors.white;
      } else if (colors.length == 1) {
        _mixedColor = colors[0];
      } else {
        _mixedColor = ColorMixer.mixSubtractive(colors);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: _mixedColor,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))],
            border: Border.all(color: Colors.grey.withOpacity(0.3), width: 2),
          ),
          child: Center(
            child: Text(
              _getColorName(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    ThemeData.estimateBrightnessForColor(_mixedColor) == Brightness.dark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildColorToggle(Colors.red, 'Red', _redSelected, (selected) {
              setState(() {
                _redSelected = selected;
                _updateMixedColor();
              });
            }),
            const SizedBox(width: 24),
            _buildColorToggle(Colors.yellow, 'Yellow', _yellowSelected, (selected) {
              setState(() {
                _yellowSelected = selected;
                _updateMixedColor();
              });
            }),
            const SizedBox(width: 24),
            _buildColorToggle(Colors.blue, 'Blue', _blueSelected, (selected) {
              setState(() {
                _blueSelected = selected;
                _updateMixedColor();
              });
            }),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _redSelected = false;
              _blueSelected = false;
              _yellowSelected = false;
              _mixedColor = Colors.white;
            });
          },
          child: const Text('Reset'),
        ),
      ],
    );
  }

  Widget _buildColorToggle(Color color, String label, bool isSelected, Function(bool) onToggle) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => onToggle(!isSelected),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? color.withOpacity(0.6) : Colors.black.withOpacity(0.2),
                  blurRadius: isSelected ? 12 : 4,
                  spreadRadius: isSelected ? 2 : 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  String _getColorName() {
    if (!_redSelected && !_blueSelected && !_yellowSelected) {
      return "White";
    } else if (_redSelected && !_blueSelected && !_yellowSelected) {
      return "Red";
    } else if (!_redSelected && _blueSelected && !_yellowSelected) {
      return "Blue";
    } else if (!_redSelected && !_blueSelected && _yellowSelected) {
      return "Yellow";
    } else if (_redSelected && _blueSelected && !_yellowSelected) {
      return "Purple";
    } else if (_redSelected && !_blueSelected && _yellowSelected) {
      return "Orange";
    } else if (!_redSelected && _blueSelected && _yellowSelected) {
      return "Green";
    } else {
      return "Brown";
    }
  }
}

class _RGBSliderDemo extends StatefulWidget {
  const _RGBSliderDemo();

  @override
  _RGBSliderDemoState createState() => _RGBSliderDemoState();
}

class _RGBSliderDemoState extends State<_RGBSliderDemo> {
  double _red = 100;
  double _green = 150;
  double _blue = 200;

  @override
  Widget build(BuildContext context) {
    final color = Color.fromRGBO(_red.round(), _green.round(), _blue.round(), 1.0);

    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'RGB(${_red.round()}, ${_green.round()}, ${_blue.round()})',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        _buildSlider(
          label: 'R',
          value: _red,
          color: Colors.red,
          onChanged: (value) {
            setState(() {
              _red = value;
            });
          },
        ),
        _buildSlider(
          label: 'G',
          value: _green,
          color: Colors.green,
          onChanged: (value) {
            setState(() {
              _green = value;
            });
          },
        ),
        _buildSlider(
          label: 'B',
          value: _blue,
          color: Colors.blue,
          onChanged: (value) {
            setState(() {
              _blue = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            divisions: 255,
            activeColor: color,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.round().toString(),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// Custom Painters

class ColorWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final segments = 12;
    final segmentAngle = 2 * pi / segments;

    // Define colors around the wheel
    final List<Color> colors = [
      Colors.red,
      const Color(0xFFFF4000), // Red-Orange
      const Color(0xFFFF8000), // Orange
      const Color(0xFFFFC000), // Yellow-Orange
      Colors.yellow,
      const Color(0xFF80FF00), // Yellow-Green
      Colors.green,
      const Color(0xFF00FF80), // Blue-Green
      Colors.cyan,
      Colors.blue,
      const Color(0xFF8000FF), // Purple
      const Color(0xFFFF00FF), // Magenta
    ];

    final paint = Paint()..style = PaintingStyle.fill;

    // Draw segments
    for (var i = 0; i < segments; i++) {
      final startAngle = i * segmentAngle - pi / 2;
      paint.color = colors[i];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );
    }

    // Draw center
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.2, paint);

    // Draw text labels
    _drawTexts(canvas, center, radius, segments);

    // Draw rings to indicate primary, secondary, tertiary colors
    _drawRings(canvas, center, radius);
  }

  void _drawTexts(Canvas canvas, Offset center, double radius, int segments) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final segmentAngle = 2 * pi / segments;

    // Primary Colors
    _drawText(canvas, 'RED', center, radius * 0.75, 0 * segmentAngle - pi / 2, textPainter);
    _drawText(canvas, 'YELLOW', center, radius * 0.75, 4 * segmentAngle - pi / 2, textPainter);
    _drawText(canvas, 'BLUE', center, radius * 0.75, 8 * segmentAngle - pi / 2, textPainter);

    // Secondary Colors
    _drawText(canvas, 'ORANGE', center, radius * 0.75, 2 * segmentAngle - pi / 2, textPainter);
    _drawText(canvas, 'GREEN', center, radius * 0.75, 6 * segmentAngle - pi / 2, textPainter);
    _drawText(canvas, 'PURPLE', center, radius * 0.75, 10 * segmentAngle - pi / 2, textPainter);
  }

  void _drawText(Canvas canvas, String text, Offset center, double radius, double angle, TextPainter textPainter) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    textPainter.text = TextSpan(text: text, style: textStyle);
    textPainter.layout(minWidth: 0, maxWidth: 100);

    final x = center.dx + radius * cos(angle) - textPainter.width / 2;
    final y = center.dy + radius * sin(angle) - textPainter.height / 2;

    textPainter.paint(canvas, Offset(x, y));
  }

  void _drawRings(Canvas canvas, Offset center, double radius) {
    final outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 2;

    // Primary color ring
    canvas.drawCircle(center, radius * 0.85, outerRingPaint);

    // Secondary color ring
    final secondaryRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius * 0.7, secondaryRingPaint);

    // Tertiary color ring
    final tertiaryRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius * 0.55, tertiaryRingPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AdditiveColorMixingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 3;

    // Define colors with opacity for blending
    final redPaint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.screen;

    final greenPaint = Paint()
      ..color = Colors.green.withOpacity(0.7)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.screen;

    final bluePaint = Paint()
      ..color = Colors.blue.withOpacity(0.7)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.screen;

    // Calculate circle positions
    final redCenter = Offset(center.dx - radius * 0.5, center.dy - radius * 0.4);
    final greenCenter = Offset(center.dx + radius * 0.5, center.dy - radius * 0.4);
    final blueCenter = Offset(center.dx, center.dy + radius * 0.6);

    // Draw circles
    canvas.drawCircle(redCenter, radius, redPaint);
    canvas.drawCircle(greenCenter, radius, greenPaint);
    canvas.drawCircle(blueCenter, radius, bluePaint);

    // Add labels
    _drawLabel(canvas, 'RED', redCenter, radius);
    _drawLabel(canvas, 'GREEN', greenCenter, radius);
    _drawLabel(canvas, 'BLUE', blueCenter, radius);

    // Add intersection labels
    _drawLabel(canvas, 'YELLOW', Offset((redCenter.dx + greenCenter.dx) / 2, (redCenter.dy + greenCenter.dy) / 2),
        radius * 0.3);
    _drawLabel(canvas, 'CYAN', Offset((greenCenter.dx + blueCenter.dx) / 2, (greenCenter.dy + blueCenter.dy) / 2),
        radius * 0.3);
    _drawLabel(canvas, 'MAGENTA', Offset((redCenter.dx + blueCenter.dx) / 2, (redCenter.dy + blueCenter.dy) / 2),
        radius * 0.3);
    _drawLabel(canvas, 'WHITE', center, radius * 0.3);
  }

  void _drawLabel(Canvas canvas, String text, Offset position, double radius) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(minWidth: 0, maxWidth: 100);

    final x = position.dx - textPainter.width / 2;
    final y = position.dy - textPainter.height / 2;

    // Add a subtle shadow for better readability
    final shadowPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black.withOpacity(0.5),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    shadowPainter.layout(minWidth: 0, maxWidth: 100);
    shadowPainter.paint(canvas, Offset(x + 1, y + 1));

    textPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SubtractiveColorMixingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 3;

    // Define colors with opacity for blending
    final cyanPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.7)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.multiply;

    final magentaPaint = Paint()
      ..color = Color(0xFFFD3DB5).withOpacity(0.7)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.multiply;

    final yellowPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.7)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.multiply;

    // White background for proper subtractive mixing
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);

    // Calculate circle positions
    final cyanCenter = Offset(center.dx - radius * 0.5, center.dy - radius * 0.4);
    final magentaCenter = Offset(center.dx + radius * 0.5, center.dy - radius * 0.4);
    final yellowCenter = Offset(center.dx, center.dy + radius * 0.6);

    // Draw circles
    canvas.drawCircle(cyanCenter, radius, cyanPaint);
    canvas.drawCircle(magentaCenter, radius, magentaPaint);
    canvas.drawCircle(yellowCenter, radius, yellowPaint);

    // Add labels
    _drawLabel(canvas, 'CYAN', cyanCenter, radius, Colors.black);
    _drawLabel(canvas, 'MAGENTA', magentaCenter, radius, Colors.black);
    _drawLabel(canvas, 'YELLOW', yellowCenter, radius, Colors.black);

    // Add intersection labels
    _drawLabel(canvas, 'BLUE', Offset((cyanCenter.dx + magentaCenter.dx) / 2, (cyanCenter.dy + magentaCenter.dy) / 2),
        radius * 0.3, Colors.white);
    _drawLabel(canvas, 'GREEN', Offset((cyanCenter.dx + yellowCenter.dx) / 2, (cyanCenter.dy + yellowCenter.dy) / 2),
        radius * 0.3, Colors.white);
    _drawLabel(
        canvas,
        'RED',
        Offset((magentaCenter.dx + yellowCenter.dx) / 2, (magentaCenter.dy + yellowCenter.dy) / 2),
        radius * 0.3,
        Colors.white);
    _drawLabel(canvas, 'BLACK', center, radius * 0.3, Colors.white);
  }

  void _drawLabel(Canvas canvas, String text, Offset position, double radius, Color textColor) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(minWidth: 0, maxWidth: 100);

    final x = position.dx - textPainter.width / 2;
    final y = position.dy - textPainter.height / 2;

    textPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ColorGamutComparisonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2.2;

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.grey.shade200,
    );

    // Draw RGB triangle (larger)
    final rgbPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    final rgbStrokePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rgbPath = Path();

    // RGB vertices
    final redPoint = Offset(center.dx, center.dy - radius * 0.9);
    final greenPoint = Offset(center.dx - radius * 0.8, center.dy + radius * 0.7);
    final bluePoint = Offset(center.dx + radius * 0.8, center.dy + radius * 0.7);

    rgbPath.moveTo(redPoint.dx, redPoint.dy);
    rgbPath.lineTo(greenPoint.dx, greenPoint.dy);
    rgbPath.lineTo(bluePoint.dx, bluePoint.dy);
    rgbPath.close();

    canvas.drawPath(rgbPath, rgbPaint);
    canvas.drawPath(rgbPath, rgbStrokePaint);

    // Draw CMYK gamut (smaller, irregular shape)
    final cmykPaint = Paint()
      ..color = Colors.red.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final cmykStrokePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // CMYK has a smaller gamut, especially in blues and greens
    final cmykPath = Path();

    final cyanPoint = Offset(center.dx + radius * 0.4, center.dy + radius * 0.45);
    final magentaPoint = Offset(center.dx - radius * 0.2, center.dy + radius * 0.4);
    final yellowPoint = Offset(center.dx - radius * 0.4, center.dy - radius * 0.1);
    final midPoint1 = Offset(center.dx, center.dy - radius * 0.5);
    final midPoint2 = Offset(center.dx + radius * 0.5, center.dy - radius * 0.1);

    cmykPath.moveTo(yellowPoint.dx, yellowPoint.dy);
    cmykPath.quadraticBezierTo(midPoint1.dx, midPoint1.dy, midPoint2.dx, midPoint2.dy);
    cmykPath.quadraticBezierTo(cyanPoint.dx, cyanPoint.dy, magentaPoint.dx, magentaPoint.dy);
    cmykPath.close();

    canvas.drawPath(cmykPath, cmykPaint);
    canvas.drawPath(cmykPath, cmykStrokePaint);

    // Add labels
    _drawLabel(canvas, 'RGB Color Space', Offset(center.dx, center.dy - radius - 15), Colors.blue);
    _drawLabel(canvas, 'CMYK Color Space', Offset(center.dx, center.dy + radius + 15), Colors.red);
  }

  void _drawLabel(Canvas canvas, String text, Offset position, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout(minWidth: 0, maxWidth: 200);

    final x = position.dx - textPainter.width / 2;
    final y = position.dy - textPainter.height / 2;

    textPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
