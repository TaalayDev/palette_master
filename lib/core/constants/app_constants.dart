class AppConstants {
  // Urls
  static const String privacyPolicyUrl = 'https://taalaydev.github.io/palettemaster/privacy-policy.html';
  static const String termsOfServiceUrl = 'https://taalaydev.github.io/palettemaster/terms-of-service.html';

  // Game settings
  static const int initialLevel = 1;
  static const int maxLevel = 50;

  // Color mixing
  static const double minOpacity = 0.1;
  static const double maxOpacity = 1.0;
  static const double opacityStep = 0.1;

  // Puzzle difficulty levels
  static const Map<String, String> difficultyLabels = {
    'beginner': 'Beginner',
    'intermediate': 'Intermediate',
    'advanced': 'Advanced',
    'expert': 'Expert',
  };

  // Achievement thresholds
  static const int puzzlesForBronze = 10;
  static const int puzzlesForSilver = 25;
  static const int puzzlesForGold = 50;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  static const double defaultBorderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;

  static const double defaultAnimationDuration = 300.0;

  // Default primary colors
  static const List<String> primaryColorNames = ['Red', 'Yellow', 'Blue'];

  // Default secondary colors
  static const List<String> secondaryColorNames = ['Orange', 'Green', 'Purple'];

  // Default tertiary colors
  static const List<String> tertiaryColorNames = [
    'Red-Orange',
    'Yellow-Orange',
    'Yellow-Green',
    'Blue-Green',
    'Blue-Purple',
    'Red-Purple',
  ];

  // Don't allow instance creation
  AppConstants._();
}
