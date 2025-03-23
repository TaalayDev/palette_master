class AppRoute {
  final String name;
  final String path;

  const AppRoute({required this.name, required this.path});
}

class AppRoutes {
  static const home = AppRoute(name: 'home', path: '/');

  static const gameSelection = AppRoute(name: 'gameSelection', path: '/game-selection');

  static const puzzles = AppRoute(name: 'puzzles', path: '/puzzles');

  static const tutorial = AppRoute(name: 'tutorial', path: '/tutorial');

  static const achievements = AppRoute(name: 'achievements', path: '/achievements');

  static const settings = AppRoute(name: 'settings', path: '/settings');

  static const colorBubble = AppRoute(name: 'colorBubble', path: '/games/color-bubble');
  static const colorBalance = AppRoute(name: 'colorBalance', path: '/games/color-balance');
  static const colorWave = AppRoute(name: 'colorWave', path: '/games/color-wave');
  static const colorRacer = AppRoute(name: 'colorRacer', path: '/games/color-racer');
  static const colorMemory = AppRoute(name: 'colorMemory', path: '/games/color-memory');

  static const all = [
    home,
    gameSelection,
    puzzles,
    tutorial,
    achievements,
    settings,
    colorBubble,
    colorBalance,
    colorWave,
    colorRacer,
    colorMemory
  ];
}
