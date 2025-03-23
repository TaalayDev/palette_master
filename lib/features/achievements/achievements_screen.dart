import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/constants/app_constants.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDarkMode ? Colors.white : const Color(0xFF4F378B),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header section
              SliverToBoxAdapter(
                child: _buildHeaderSection(context),
              ),

              // Main content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Achievement categories
                    _buildAchievementCategory(
                      context,
                      title: 'Color Mixing',
                      iconData: Icons.palette,
                      achievements: [
                        _buildAchievement(
                          context,
                          title: 'Color Apprentice',
                          description: 'Complete 5 color mixing puzzles',
                          icon: Icons.palette,
                          isUnlocked: true,
                          progress: 1.0,
                          rewardPoints: 100,
                        ),
                        _buildAchievement(
                          context,
                          title: 'Mixing Master',
                          description: 'Create 20 perfect color matches',
                          icon: Icons.auto_awesome,
                          isUnlocked: false,
                          progress: 0.6,
                          rewardPoints: 250,
                        ),
                        _buildAchievement(
                          context,
                          title: 'Pigment Virtuoso',
                          description: 'Mix 5 colors to create a complex shade',
                          icon: Icons.color_lens,
                          isUnlocked: false,
                          progress: 0.2,
                          rewardPoints: 500,
                        ),
                      ],
                    ),

                    _buildAchievementCategory(
                      context,
                      title: 'Color Theory',
                      iconData: Icons.lightbulb,
                      achievements: [
                        _buildAchievement(
                          context,
                          title: 'Complementary Expert',
                          description: 'Complete all complementary color challenges',
                          icon: Icons.contrast,
                          isUnlocked: false,
                          progress: 0.3,
                          rewardPoints: 300,
                        ),
                        _buildAchievement(
                          context,
                          title: 'Harmony Seeker',
                          description: 'Create 10 perfect color harmonies',
                          icon: Icons.vibration,
                          isUnlocked: false,
                          progress: 0.0,
                          rewardPoints: 400,
                        ),
                        _buildAchievement(
                          context,
                          title: 'Color Wheel Navigator',
                          description: 'Identify all tertiary colors correctly',
                          icon: Icons.track_changes,
                          isUnlocked: false,
                          progress: 0.0,
                          rewardPoints: 350,
                        ),
                      ],
                    ),

                    _buildAchievementCategory(
                      context,
                      title: 'Perception',
                      iconData: Icons.visibility,
                      achievements: [
                        _buildAchievement(
                          context,
                          title: 'Optical Illusion Master',
                          description: 'Complete 5 optical illusion puzzles',
                          icon: Icons.remove_red_eye,
                          isUnlocked: false,
                          progress: 0.4,
                          rewardPoints: 400,
                        ),
                        _buildAchievement(
                          context,
                          title: 'After-Image Observer',
                          description: 'Successfully predict color after-images',
                          icon: Icons.filter_center_focus,
                          isUnlocked: false,
                          progress: 0.0,
                          rewardPoints: 350,
                        ),
                      ],
                    ),

                    _buildAchievementCategory(
                      context,
                      title: 'Mastery',
                      iconData: Icons.emoji_events,
                      achievements: [
                        _buildAchievement(
                          context,
                          title: 'Color Theory Guru',
                          description: 'Complete all puzzles with perfect scores',
                          icon: Icons.emoji_events,
                          isUnlocked: false,
                          progress: 0.1,
                          rewardPoints: 1000,
                          isEpic: true,
                        ),
                        _buildAchievement(
                          context,
                          title: 'Speed Mixer',
                          description: 'Complete any level in under 30 seconds',
                          icon: Icons.speed,
                          isUnlocked: false,
                          progress: 0.0,
                          rewardPoints: 500,
                        ),
                        _buildAchievement(
                          context,
                          title: 'Perfectly Balanced',
                          description: 'Create an exact match with no color adjustments',
                          icon: Icons.balance,
                          isUnlocked: false,
                          progress: 0.0,
                          rewardPoints: 750,
                          isEpic: true,
                        ),
                      ],
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          // Achievement summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2A2A3A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAchievementStat(
                  context,
                  '1/15',
                  'Achieved',
                  Icons.emoji_events_rounded,
                  Colors.amber,
                ),
                Container(
                  height: 50,
                  width: 1,
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                ),
                _buildAchievementStat(
                  context,
                  '100',
                  'Points',
                  Icons.star_rounded,
                  Colors.orange,
                ),
                Container(
                  height: 50,
                  width: 1,
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                ),
                _buildAchievementStat(
                  context,
                  'Bronze',
                  'Rank',
                  Icons.workspace_premium_rounded,
                  Colors.brown.shade300,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Your Color Theory Journey',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF4F378B),
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            'Unlock achievements by mastering color theory concepts and completing puzzles',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementStat(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color iconColor,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementCategory(
    BuildContext context, {
    required String title,
    required IconData iconData,
    required List<Widget> achievements,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16),
            child: Row(
              children: [
                Icon(
                  iconData,
                  color: isDarkMode ? Theme.of(context).colorScheme.primary : const Color(0xFF6750A4),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Theme.of(context).colorScheme.primary : const Color(0xFF6750A4),
                      ),
                ),
              ],
            ),
          ),
          ...achievements,
        ],
      ),
    );
  }

  Widget _buildAchievement(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required bool isUnlocked,
    required double progress,
    required int rewardPoints,
    bool isEpic = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final primaryColor = isEpic
        ? (isUnlocked ? Colors.amber : Colors.grey)
        : (isUnlocked ? Theme.of(context).colorScheme.primary : Colors.grey);

    final bgColor = isDarkMode
        ? (isUnlocked ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.02))
        : (isUnlocked ? Colors.white : Colors.white.withOpacity(0.7));

    final borderColor = isUnlocked ? primaryColor.withOpacity(0.5) : Colors.transparent;

    final glowEffect = isUnlocked && isEpic;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: glowEffect
            ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Achievement icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? (isEpic ? Colors.amber.withOpacity(0.2) : primaryColor.withOpacity(0.2))
                        : Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border:
                        isEpic ? Border.all(color: isUnlocked ? Colors.amber : Colors.grey.shade400, width: 2) : null,
                  ),
                  child: Icon(
                    icon,
                    color: isUnlocked ? (isEpic ? Colors.amber : primaryColor) : Colors.grey.shade400,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 16),

                // Achievement details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isEpic)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: isUnlocked ? Colors.amber : Colors.grey.shade400,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isUnlocked ? (isEpic ? Colors.amber : primaryColor) : Colors.grey.shade500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isUnlocked
                                  ? (isEpic ? Colors.amber.withOpacity(0.2) : primaryColor.withOpacity(0.2))
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: isEpic
                                  ? Border.all(color: isUnlocked ? Colors.amber.shade200 : Colors.grey.shade300)
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: isUnlocked ? (isEpic ? Colors.amber : primaryColor) : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$rewardPoints',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isUnlocked ? (isEpic ? Colors.amber : primaryColor) : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: isUnlocked ? null : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress indicator
            Stack(
              children: [
                // Background progress bar
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Actual progress
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  height: 8,
                  width: MediaQuery.of(context).size.width * 0.7 * progress,
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? (isEpic ? Colors.amber : primaryColor)
                        : (progress > 0 ? Colors.grey.shade400 : Colors.transparent),
                    borderRadius: BorderRadius.circular(4),
                    gradient: isUnlocked && isEpic
                        ? const LinearGradient(
                            colors: [Colors.amber, Colors.orange],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Progress label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isUnlocked ? 'Complete!' : '${(progress * 100).toInt()}% complete',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
                    color: isUnlocked
                        ? (isEpic ? Colors.amber : primaryColor)
                        : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                if (!isUnlocked && progress > 0)
                  TextButton(
                    onPressed: () {
                      // In a real app, this would navigate to the relevant puzzle
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Continue'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
