import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/constants/app_constants.dart';
import 'package:palette_master/theme/app_theme.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDarkMode = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Settings'),
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
                    // Theme settings
                    _buildSettingsCard(
                      context,
                      ref,
                      title: 'Appearance',
                      icon: Icons.palette,
                      children: [
                        _buildSettingItem(
                          context,
                          title: 'Theme Mode',
                          subtitle: _getThemeModeDescription(themeMode),
                          icon: _getThemeIcon(themeMode),
                          trailing: _buildThemeDropdown(context, ref, themeMode),
                        ),
                        _buildDivider(),
                        _buildColorItem(
                          context,
                          title: 'Primary Color',
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () {
                            // Would open a color picker in a real app
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Accessibility settings
                    // _buildSettingsCard(
                    //   context,
                    //   ref,
                    //   title: 'Accessibility',
                    //   icon: Icons.accessibility_new,
                    //   children: [
                    //     _buildSwitchItem(
                    //       context,
                    //       title: 'Color Blindness Mode',
                    //       subtitle: 'Adjust colors for color vision deficiencies',
                    //       value: false,
                    //       onChanged: (value) {
                    //         // Toggle color blindness mode
                    //       },
                    //     ),
                    //     _buildDivider(),
                    //     _buildSwitchItem(
                    //       context,
                    //       title: 'High Contrast',
                    //       subtitle: 'Increase contrast for better visibility',
                    //       value: false,
                    //       onChanged: (value) {
                    //         // Toggle high contrast mode
                    //       },
                    //     ),
                    //     _buildDivider(),
                    //     _buildSwitchItem(
                    //       context,
                    //       title: 'Reduced Motion',
                    //       subtitle: 'Minimize animated effects',
                    //       value: false,
                    //       onChanged: (value) {
                    //         // Toggle reduced motion
                    //       },
                    //     ),
                    //   ],
                    // ),

                    // const SizedBox(height: 16),

                    // Game settings
                    // _buildSettingsCard(
                    //   context,
                    //   ref,
                    //   title: 'Game Settings',
                    //   icon: Icons.games,
                    //   children: [
                    //     _buildSwitchItem(
                    //       context,
                    //       title: 'Sound Effects',
                    //       subtitle: 'Play sounds during gameplay',
                    //       value: true,
                    //       onChanged: (value) {
                    //         // Toggle sound effects
                    //       },
                    //     ),
                    //     _buildDivider(),
                    //     _buildSwitchItem(
                    //       context,
                    //       title: 'Haptic Feedback',
                    //       subtitle: 'Vibrate on interactions',
                    //       value: true,
                    //       onChanged: (value) {
                    //         // Toggle haptic feedback
                    //       },
                    //     ),
                    //     _buildDivider(),
                    //     _buildSliderItem(
                    //       context,
                    //       title: 'Difficulty',
                    //       value: 0.5,
                    //       min: 0.0,
                    //       max: 1.0,
                    //       labels: {
                    //         0.0: 'Easy',
                    //         0.33: 'Medium',
                    //         0.67: 'Hard',
                    //         1.0: 'Expert',
                    //       },
                    //       onChanged: (value) {
                    //         // Adjust difficulty
                    //       },
                    //     ),
                    //     _buildDivider(),
                    //     _buildResetButton(context),
                    //   ],
                    // ),

                    // const SizedBox(height: 16),

                    // About section
                    _buildSettingsCard(
                      context,
                      ref,
                      title: 'About',
                      icon: Icons.info,
                      children: [
                        _buildInfoItem(
                          context,
                          title: 'Version',
                          subtitle: '1.0.0',
                          icon: Icons.new_releases,
                          onTap: () {
                            // Could show release notes
                          },
                        ),
                        _buildDivider(),
                        _buildInfoItem(
                          context,
                          title: 'Privacy Policy',
                          subtitle: 'Read how we handle your data',
                          icon: Icons.privacy_tip,
                          onTap: () {
                            launchUrlString(AppConstants.privacyPolicyUrl);
                          },
                        ),
                        _buildDivider(),
                        _buildInfoItem(
                          context,
                          title: 'Terms of Service',
                          subtitle: 'App usage terms and conditions',
                          icon: Icons.description,
                          onTap: () {
                            launchUrlString(AppConstants.termsOfServiceUrl);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          // Settings icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.settings,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Customize Your Experience',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            color: isDarkMode ? Colors.white12 : Colors.black12,
            thickness: 1,
            height: 1,
          ),

          // Settings items
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildThemeDropdown(BuildContext context, WidgetRef ref, ThemeMode currentThemeMode) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButton<ThemeMode>(
        value: currentThemeMode,
        onChanged: (value) {
          if (value != null) {
            switch (value) {
              case ThemeMode.light:
                ref.read(themeModeProvider.notifier).setLightMode();
                break;
              case ThemeMode.dark:
                ref.read(themeModeProvider.notifier).setDarkMode();
                break;
              case ThemeMode.system:
                ref.read(themeModeProvider.notifier).setSystemMode();
                break;
            }
          }
        },
        items: const [
          DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
        ],
        underline: Container(), // Remove the default underline
        icon: Icon(
          Icons.arrow_drop_down,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSwitchItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              value ? Icons.check_circle : Icons.circle_outlined,
              color: value ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildColorItem(
    BuildContext context, {
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.colorize,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderItem(
    BuildContext context, {
    required String title,
    required double value,
    required double min,
    required double max,
    required Map<double, String> labels,
    required ValueChanged<double> onChanged,
  }) {
    // Find the closest label for the current value
    String currentLabel = '';
    double closestKey = min;
    double smallestDifference = double.infinity;

    for (final entry in labels.entries) {
      final difference = (entry.key - value).abs();
      if (difference < smallestDifference) {
        smallestDifference = difference;
        closestKey = entry.key;
        currentLabel = entry.value;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.tune,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  currentLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
              showValueIndicator: ShowValueIndicator.always,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) * 10).toInt(),
              label: currentLabel,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels.entries.map((entry) {
              return Text(
                entry.value,
                style: TextStyle(
                  fontSize: 10,
                  color: closestKey == entry.key
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: closestKey == entry.key ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.restart_alt,
              color: Theme.of(context).colorScheme.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset All Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Delete all achievements and game progress',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Show confirmation dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Progress'),
                  content: const Text(
                    'Are you sure you want to reset all your progress? This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Reset progress logic would go here
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 76,
      endIndent: 0,
    );
  }

  String _getThemeModeDescription(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.system:
        return 'Follow system preference';
      case ThemeMode.light:
        return 'Always use light mode';
      case ThemeMode.dark:
        return 'Always use dark mode';
    }
  }

  IconData _getThemeIcon(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.brightness_7;
      case ThemeMode.dark:
        return Icons.brightness_2;
    }
  }
}
