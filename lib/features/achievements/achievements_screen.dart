import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/constants/app_constants.dart';
import 'package:palette_master/core/services/achievments-service.dart';

import 'package:vibration/vibration.dart';

import '../shared/providers/sound_controller.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final achievementsState = ref.watch(achievementsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDarkMode ? Colors.white : const Color(0xFF4F378B),
      ),
      body: GradientBackground(
        colors: isDarkMode
            ? [
                const Color(0xFF2C2C3E),
                const Color(0xFF1C1B26),
              ]
            : [
                const Color(0xFFE9DEFF),
                const Color(0xFFFFD8E7),
              ],
        child: SafeArea(
          child: achievementsState.isLoading
              ? _buildLoadingIndicator()
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header section
                    SliverToBoxAdapter(
                      child: _buildHeaderSection(context, achievementsState),
                    ),

                    // Main content
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Achievement categories
                          _buildAchievementCategory(
                            context,
                            ref,
                            title: 'Color Mixing',
                            iconData: Icons.palette,
                            achievements: _filterAchievementsByIds(
                              achievementsState.achievements,
                              ['color_apprentice', 'mixing_master', 'pigment_virtuoso'],
                            ),
                          ),

                          _buildAchievementCategory(
                            context,
                            ref,
                            title: 'Color Theory',
                            iconData: Icons.lightbulb,
                            achievements: _filterAchievementsByIds(
                              achievementsState.achievements,
                              ['complementary_expert', 'harmony_seeker', 'color_wheel_navigator'],
                            ),
                          ),

                          _buildAchievementCategory(
                            context,
                            ref,
                            title: 'Perception',
                            iconData: Icons.visibility,
                            achievements: _filterAchievementsByIds(
                              achievementsState.achievements,
                              ['optical_illusion_master', 'after_image_observer'],
                            ),
                          ),

                          _buildAchievementCategory(
                            context,
                            ref,
                            title: 'Mastery',
                            iconData: Icons.emoji_events,
                            achievements: _filterAchievementsByIds(
                              achievementsState.achievements,
                              ['color_theory_guru', 'speed_mixer', 'perfectly_balanced'],
                            ),
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

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading achievements...'),
        ],
      ),
    );
  }

  List<Achievement> _filterAchievementsByIds(List<Achievement> allAchievements, List<String> ids) {
    return allAchievements.where((achievement) => ids.contains(achievement.id)).toList();
  }

  Widget _buildHeaderSection(BuildContext context, AchievementsState state) {
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
                  '${state.unlockedCount}/${state.achievements.length}',
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
                  '${state.totalPoints}',
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
                  state.userRank,
                  'Rank',
                  Icons.workspace_premium_rounded,
                  _getRankColor(state.userRank),
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

  Color _getRankColor(String rank) {
    switch (rank) {
      case 'Beginner':
        return Colors.brown.shade300;
      case 'Intermediate':
        return Colors.grey.shade400;
      case 'Advanced':
        return Colors.grey.shade300;
      case 'Expert':
        return Colors.amber.shade300;
      case 'Master':
        return Colors.amber;
      default:
        return Colors.brown.shade300;
    }
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
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required IconData iconData,
    required List<Achievement> achievements,
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
          if (achievements.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No achievements in this category yet.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            )
          else
            ...achievements
                .map((achievement) => _buildAchievement(
                      context,
                      ref,
                      achievement: achievement,
                    ))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildAchievement(
    BuildContext context,
    WidgetRef ref, {
    required Achievement achievement,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final primaryColor = achievement.isEpic
        ? (achievement.isUnlocked ? Colors.amber : Colors.grey)
        : (achievement.isUnlocked ? Theme.of(context).colorScheme.primary : Colors.grey);

    final bgColor = isDarkMode
        ? (achievement.isUnlocked ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.02))
        : (achievement.isUnlocked ? Colors.white : Colors.white.withOpacity(0.7));

    final borderColor = achievement.isUnlocked ? primaryColor.withOpacity(0.5) : Colors.transparent;

    final glowEffect = achievement.isUnlocked && achievement.isEpic;

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onAchievementTap(context, ref, achievement),
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
                        color: achievement.isUnlocked
                            ? (achievement.isEpic ? Colors.amber.withOpacity(0.2) : primaryColor.withOpacity(0.2))
                            : Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: achievement.isEpic
                            ? Border.all(color: achievement.isUnlocked ? Colors.amber : Colors.grey.shade400, width: 2)
                            : null,
                      ),
                      child: Icon(
                        achievement.icon,
                        color: achievement.isUnlocked
                            ? (achievement.isEpic ? Colors.amber : primaryColor)
                            : Colors.grey.shade400,
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
                              if (achievement.isEpic)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 16,
                                    color: achievement.isUnlocked ? Colors.amber : Colors.grey.shade400,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  achievement.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: achievement.isUnlocked
                                        ? (achievement.isEpic ? Colors.amber : primaryColor)
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: achievement.isUnlocked
                                      ? (achievement.isEpic
                                          ? Colors.amber.withOpacity(0.2)
                                          : primaryColor.withOpacity(0.2))
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: achievement.isEpic
                                      ? Border.all(
                                          color: achievement.isUnlocked ? Colors.amber.shade200 : Colors.grey.shade300)
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 12,
                                      color: achievement.isUnlocked
                                          ? (achievement.isEpic ? Colors.amber : primaryColor)
                                          : Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${achievement.rewardPoints}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: achievement.isUnlocked
                                            ? (achievement.isEpic ? Colors.amber : primaryColor)
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            achievement.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: achievement.isUnlocked ? null : Colors.grey.shade500,
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
                      width: MediaQuery.of(context).size.width * 0.7 * achievement.progress,
                      decoration: BoxDecoration(
                        color: achievement.isUnlocked
                            ? (achievement.isEpic ? Colors.amber : primaryColor)
                            : (achievement.progress > 0 ? Colors.grey.shade400 : Colors.transparent),
                        borderRadius: BorderRadius.circular(4),
                        gradient: achievement.isUnlocked && achievement.isEpic
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
                      achievement.isUnlocked ? 'Complete!' : '${(achievement.progress * 100).toInt()}% complete',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: achievement.isUnlocked ? FontWeight.bold : FontWeight.normal,
                        color: achievement.isUnlocked
                            ? (achievement.isEpic ? Colors.amber : primaryColor)
                            : Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    if (!achievement.isUnlocked && achievement.progress > 0)
                      TextButton(
                        onPressed: () => _onContinueTap(context, achievement),
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
        ),
      ),
    );
  }

  void _onAchievementTap(BuildContext context, WidgetRef ref, Achievement achievement) {
    // Play sound effect
    if (achievement.isUnlocked) {
      final soundController = ref.read(soundControllerProvider.notifier);
      soundController.playEffect(SoundType.achievement);
    }

    // Show details dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (achievement.isEpic)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  Icons.auto_awesome,
                  color: achievement.isUnlocked ? Colors.amber : Colors.grey,
                  size: 24,
                ),
              ),
            Expanded(
              child: Text(
                achievement.title,
                style: TextStyle(
                  color: achievement.isUnlocked
                      ? (achievement.isEpic ? Colors.amber : Theme.of(context).colorScheme.primary)
                      : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: achievement.isUnlocked
                      ? (achievement.isEpic
                          ? Colors.amber.withOpacity(0.2)
                          : Theme.of(context).colorScheme.primaryContainer)
                      : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: achievement.isUnlocked
                        ? (achievement.isEpic ? Colors.amber : Theme.of(context).colorScheme.primary)
                        : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Icon(
                  achievement.icon,
                  color: achievement.isUnlocked
                      ? (achievement.isEpic ? Colors.amber : Theme.of(context).colorScheme.primary)
                      : Colors.grey,
                  size: 40,
                ),
              ),
            ),

            // Description
            Text(
              achievement.description,
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 12),

            // Status
            Row(
              children: [
                Icon(
                  achievement.isUnlocked ? Icons.check_circle : Icons.hourglass_top,
                  color: achievement.isUnlocked ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  achievement.isUnlocked ? 'Unlocked' : '${(achievement.progress * 100).toInt()}% Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: achievement.isUnlocked ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Reward
            Row(
              children: [
                const Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Reward: ${achievement.rewardPoints} points',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _onContinueTap(BuildContext context, Achievement achievement) {
    // Haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 20);
      }
    });

    // Here you would navigate to the relevant puzzle type
    // based on the achievement ID
    final puzzleType = _getPuzzleTypeFromAchievement(achievement.id);

    // You would implement navigation to the appropriate game screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigating to $puzzleType games...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getPuzzleTypeFromAchievement(String achievementId) {
    // Map achievement IDs to puzzle types
    if (['color_apprentice', 'mixing_master', 'pigment_virtuoso'].contains(achievementId)) {
      return 'Color Mixing';
    } else if (['complementary_expert', 'harmony_seeker', 'color_wheel_navigator'].contains(achievementId)) {
      return 'Color Theory';
    } else if (['optical_illusion_master', 'after_image_observer'].contains(achievementId)) {
      return 'Optical Illusions';
    } else {
      return 'Game Selection';
    }
  }
}

// Simple gradient background widget (to be implemented in shared/widgets directory)
class GradientBackground extends StatelessWidget {
  final List<Color> colors;
  final Widget child;

  const GradientBackground({
    super.key,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: child,
    );
  }
}
