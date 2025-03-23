# Palette Master

Palette Master is an interactive Flutter game designed to teach color theory through engaging puzzle challenges. Players solve various puzzles by applying principles such as color mixing, complementary colors, and optical illusions.

## Features

### Core Functionality

- **Realistic Color Mixing Engine**: Implementation of subtractive color model rules for accurate color mixing
- **Multiple Puzzle Types**:
  - **Color Matching**: Create target colors by mixing available pigments
  - **Complementary Challenges**: Identify or create complementary color pairs
  - **Optical Illusions**: Puzzles utilizing after-image effects and color perception
  - **Color Harmony**: Create balanced color schemes (analogous, triadic, etc.)
- **Interactive Game Modes**:
  - **Classic Mixing**: Mix colors by adding droplets
  - **Bubble Physics**: Play with bubble physics to mix colors through collisions
  - **Color Balance**: Adjust sliders to find perfect color proportions
  - **Color Wave**: Create waves of color to match gradient transitions
  - **Color Racer**: Race through color gates and mix colors at top speed
  - **Color Memory**: Test color memory and recognition skills

### Technical Highlights

- Built with Flutter and Dart
- Responsive design for iPhone, iPad, Android phones/tablets, desktop, and web
- Light/dark mode support
- Dynamic color rendering system with high color accuracy
- State management with Riverpod
- Navigation with Go Router
- Engaging animations and physics simulations

## Architecture

The app follows a clean architecture approach with the following structure:

- **Core**: Contains fundamental models and utilities
  - **Color Models**: Implementations of RGB, CMYK, and color mixing algorithms
  - **Constants**: App-wide constants and configuration
- **Features**: Contains feature-specific implementations organized by domain
  - **Home**: Home screen and navigation
  - **Puzzles**: Various puzzle types and game modes
  - **Tutorials**: Interactive tutorials for learning color theory
  - **Achievements**: Tracking progress and achievements
  - **Settings**: App configuration
- **Router**: Navigation configuration using Go Router
- **Theme**: App theming and styling

## Color Theory in Action

Palette Master isn't just a game - it's an educational tool that teaches important color theory concepts:

- **Subtractive Color Mixing**: Learn how pigments work in real-world mixing (like paint)
- **RGB and CMYK Color Spaces**: Understand digital vs. print color models
- **Color Relationships**: Master complementary, analogous, and triadic color schemes
- **Perceptual Effects**: Experience how colors influence human perception

## Getting Started

### Prerequisites

- Flutter SDK (>=3.4.4)
- Dart (>=3.0.0)
- Android Studio / VS Code with Flutter plugin

### Installation

1. Clone the repository:
```bash
git clone https://github.com/TaalayDev/palette_master.git
```

2. Navigate to the project directory:
```bash
cd palette_master
```

3. Get dependencies:
```bash
flutter pub get
```

4. Run the app:
```bash
flutter run
```

## Building for Different Platforms

### Android
```bash
flutter build apk
```

### iOS
```bash
flutter build ios
```

### Web
```bash
flutter build web
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Acknowledgements

- [Flutter](https://flutter.dev) - The UI toolkit used
- [Riverpod](https://riverpod.dev) - State management
- [Go Router](https://gorouter.dev) - Navigation
- [Equatable](https://pub.dev/packages/equatable) - Value equality
- All the color theory resources that inspired this project