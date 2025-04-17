import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/color_models/color_mixer.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:vibration/vibration.dart';

import '../../shared/providers/sound_controller.dart';

class MemoryGame extends ConsumerStatefulWidget {
  final Puzzle puzzle;
  final Function(Color) onColorSelected;
  final Function(int) onScoreUpdate;
  final Function() onLevelComplete;

  const MemoryGame({
    super.key,
    required this.puzzle,
    required this.onColorSelected,
    required this.onScoreUpdate,
    required this.onLevelComplete,
  });

  @override
  ConsumerState<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends ConsumerState<MemoryGame> with TickerProviderStateMixin {
  // Game state
  late List<MemoryCard> _cards;
  final List<int> _selectedIndices = [];
  int _matchedPairs = 0;
  int _moves = 0;
  int _score = 0;
  int _combo = 0;
  int _streak = 0;
  bool _isLocked = false;
  bool _showingSequence = false;
  int _currentLevel = 1;
  bool _levelCompleted = false;
  bool _isPaused = false;
  bool _showHint = false;
  int _hintsRemaining = 3;
  final List<CardMove> _moveHistory = [];

  // New reward systems
  int _timeBonus = 0;
  int _comboMultiplier = 1;
  bool _perfectRun = true;

  // Animation controllers
  late AnimationController _flipController;
  late AnimationController _shakeController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _sequenceController;
  late AnimationController _comboController;
  late AnimationController _celebrationController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _comboScaleAnimation;

  // Game mode
  late GameMode _gameMode;

  // Sequence for memory mode
  List<int> _sequence = [];
  int _sequenceStep = 0;
  bool _isPlayerTurn = false;

  // Timer for sequence display and game timer
  late AnimationController _timerController;
  late AnimationController _gameTimerController;
  int _gameTimeSeconds = 0;
  late Animation<Color?> _timerColorAnimation;

  // Celebration particles
  final List<CelebrationParticle> _celebrationParticles = [];
  final Random _random = Random();

  // Physical properties for cards
  final double _cardDepth = 8.0;

  // Tutorial state
  bool _showingTutorial = false;
  int _tutorialStep = 0;
  List<String> _tutorialMessages = [];

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation = Tween<double>(
      begin: -10.0,
      end: 10.0,
    ).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.elasticIn,
      ),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _sequenceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _comboController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _comboScaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _comboController,
        curve: Curves.elasticOut,
      ),
    );

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        if (_timerController.isCompleted && _isPlayerTurn && !_isPaused) {
          _handleTimeOut();
        }
      });

    // Game timer with configurable duration based on level
    final gameDuration = Duration(seconds: _getLevelTimeLimit());
    _gameTimerController = AnimationController(
      vsync: this,
      duration: gameDuration,
    );

    _gameTimerController.addListener(() {
      if (!_isPaused && !_levelCompleted) {
        setState(() {
          _gameTimeSeconds = (gameDuration.inSeconds * (1 - _gameTimerController.value)).floor();
        });

        // Add time pressure with sounds as time runs low
        if (_gameTimeSeconds <= 10 && _gameTimeSeconds > 0 && _gameTimerController.value > 0) {
          if (_gameTimeSeconds <= 5) {
            ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
          } else if (_gameTimeSeconds % 2 == 0) {
            ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
          }
        }

        // Game over when time runs out
        if (_gameTimerController.isCompleted && !_levelCompleted) {
          _handleGameOver();
        }
      }
    });

    _timerColorAnimation = ColorTween(
      begin: Colors.green,
      end: Colors.red,
    ).animate(_gameTimerController);

    // Determine game mode based on level
    _determineGameMode();

    // Initialize game
    _initializeGame();

    // Start the game timer
    if (_gameMode != GameMode.sequenceMemory) {
      _gameTimerController.forward();
    }

    // Setup tutorial for first levels
    if (widget.puzzle.level <= 2) {
      _setupTutorial();
      _showingTutorial = true;
    }

    // Generate celebration particles
    _generateCelebrationParticles();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _shakeController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _sequenceController.dispose();
    _timerController.dispose();
    _gameTimerController.dispose();
    _comboController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  int _getLevelTimeLimit() {
    // Scale time limit with level difficulty
    final baseTime = 120; // Base time in seconds for early levels
    final level = widget.puzzle.level;

    if (level <= 5) return baseTime;
    if (level <= 10) return (baseTime * 0.9).floor();
    if (level <= 15) return (baseTime * 0.8).floor();
    return (baseTime * 0.7).floor(); // More challenging time limit for advanced levels
  }

  void _setupTutorial() {
    switch (_gameMode) {
      case GameMode.classicMatch:
        _tutorialMessages = [
          "Welcome to Color Memory! Tap cards to flip them over.",
          "Try to find matching pairs of the same color.",
          "Remember card positions to find matches with fewer moves.",
          "Match all pairs to complete the level!",
        ];
        break;
      case GameMode.complementaryMatch:
        _tutorialMessages = [
          "This is Complementary Match mode!",
          "Each color has a matching complementary color on the opposite side of the color wheel.",
          "Find color pairs that complement each other.",
          "For example, red pairs with cyan, blue with yellow.",
        ];
        break;
      case GameMode.sequenceMemory:
        _tutorialMessages = [
          "This is Sequence Memory mode!",
          "Watch the sequence of colors that light up.",
          "After the sequence finishes, repeat it in the same order.",
          "The sequences will get longer as you progress.",
        ];
        break;
      case GameMode.mixingMemory:
        _tutorialMessages = [
          "This is Color Mixing mode!",
          "Find the component colors that create each mix.",
          "The mixed colors are shown - find the two colors that create them.",
          "For example, red and yellow create orange.",
        ];
        break;
    }
  }

  void _nextTutorialStep() {
    if (_tutorialStep < _tutorialMessages.length - 1) {
      setState(() {
        _tutorialStep++;
      });
    } else {
      setState(() {
        _showingTutorial = false;
        _tutorialStep = 0;
      });
      // Play start sound
      ref.read(soundControllerProvider.notifier).playEffect(SoundType.match);
    }
  }

  void _determineGameMode() {
    final level = widget.puzzle.level;

    if (level <= 5) {
      _gameMode = GameMode.classicMatch;
    } else if (level <= 10) {
      _gameMode = GameMode.complementaryMatch;
    } else if (level <= 15) {
      _gameMode = GameMode.sequenceMemory;
    } else {
      _gameMode = GameMode.mixingMemory;
    }

    _currentLevel = level;
  }

  void _generateCelebrationParticles() {
    _celebrationParticles.clear();

    for (int i = 0; i < 50; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final velocity = 2.0 + _random.nextDouble() * 4.0;

      _celebrationParticles.add(CelebrationParticle(
        position: Offset.zero,
        velocity: Offset(cos(angle) * velocity, sin(angle) * velocity),
        color: _getRandomCelebrationColor(),
        size: 5.0 + _random.nextDouble() * 10.0,
        lifespan: 0.3 + _random.nextDouble() * 0.7,
      ));
    }
  }

  Color _getRandomCelebrationColor() {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];

    return colors[_random.nextInt(colors.length)];
  }

  void _initializeGame() {
    final random = Random();

    switch (_gameMode) {
      case GameMode.classicMatch:
        _initializeClassicMatch();
        break;

      case GameMode.complementaryMatch:
        _initializeComplementaryMatch();
        break;

      case GameMode.sequenceMemory:
        _initializeSequenceMemory();
        break;

      case GameMode.mixingMemory:
        _initializeMixingMemory();
        break;
    }

    // Shuffle cards
    _cards.shuffle(random);

    // Start with intro animation
    _scaleController.forward();

    // Play start sound
    ref.read(soundControllerProvider.notifier).playEffect(SoundType.bonus);
  }

  void _initializeClassicMatch() {
    // Create pairs of identical colors
    final gridSize = _getGridSize();
    final pairCount = (gridSize * gridSize) ~/ 2;

    // Select colors from available palette
    final selectedColors = _selectColors(pairCount);

    _cards = [];

    // Create pairs of cards
    for (int i = 0; i < pairCount; i++) {
      final color = selectedColors[i];

      // Add two cards with the same color
      _cards.add(MemoryCard(
        id: i * 2,
        frontColor: color,
        backColor: Colors.indigo,
        isFlipped: false,
        isMatched: false,
      ));

      _cards.add(MemoryCard(
        id: i * 2 + 1,
        frontColor: color,
        backColor: Colors.indigo,
        isFlipped: false,
        isMatched: false,
      ));
    }
  }

  void _initializeComplementaryMatch() {
    // Create pairs of complementary colors
    final gridSize = _getGridSize();
    final pairCount = (gridSize * gridSize) ~/ 2;

    // Select base colors from which we'll create complementary pairs
    final baseColors = _selectColors(pairCount);

    _cards = [];

    // Create pairs of complementary cards
    for (int i = 0; i < pairCount; i++) {
      final baseColor = baseColors[i];
      final complementaryColor = ColorMixer.getComplementary(baseColor);

      // Add original color
      _cards.add(MemoryCard(
        id: i * 2,
        frontColor: baseColor,
        backColor: Colors.indigo,
        isFlipped: false,
        isMatched: false,
        matchId: i, // Cards with same matchId form a pair
      ));

      // Add complementary color
      _cards.add(MemoryCard(
        id: i * 2 + 1,
        frontColor: complementaryColor,
        backColor: Colors.indigo,
        isFlipped: false,
        isMatched: false,
        matchId: i, // Cards with same matchId form a pair
      ));
    }
  }

  void _initializeSequenceMemory() {
    // This mode shows a sequence of colors that the player must memorize and reproduce
    final sequenceLength = _currentLevel - 10 + 3; // Starting with 3 for level 11
    final sequenceLength2 = sequenceLength.clamp(3, 8); // Max sequence of 8

    // Select colors for the sequence
    final availableColors = widget.puzzle.availableColors;
    final random = Random();

    _cards = [];
    // Create a grid of color cards to choose from
    for (int i = 0; i < availableColors.length; i++) {
      _cards.add(MemoryCard(
        id: i,
        frontColor: availableColors[i],
        backColor: Colors.indigo,
        isFlipped: true, // Start with colors visible
        isMatched: false,
      ));
    }

    // Generate a random sequence
    _sequence = [];
    for (int i = 0; i < sequenceLength2; i++) {
      _sequence.add(random.nextInt(availableColors.length));
    }

    // Start by showing the sequence
    _showingSequence = true;
    _sequenceStep = 0;

    // Begin sequence display after short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _showNextInSequence();
      }
    });
  }

  void _initializeMixingMemory() {
    // This mode shows color mixes and the player must identify the component colors
    final gridSize = _getGridSize();
    final mixCount = gridSize; // Number of mixes to create

    // Select base colors for mixing
    final baseColors = _selectColors(mixCount * 2); // Need more colors for mixing

    _cards = [];
    final mixes = <Color>[];

    // Create color mixes
    for (int i = 0; i < mixCount; i++) {
      final color1 = baseColors[i * 2];
      final color2 = baseColors[i * 2 + 1];

      // Mix the two colors
      final mixedColor = ColorMixer.mixSubtractive([color1, color2]);
      mixes.add(mixedColor);

      // Add component colors
      _cards.add(MemoryCard(
        id: i * 3,
        frontColor: color1,
        backColor: Colors.indigo,
        isFlipped: false,
        isMatched: false,
        matchId: i, // Cards with same matchId form a set
      ));

      _cards.add(MemoryCard(
        id: i * 3 + 1,
        frontColor: color2,
        backColor: Colors.indigo,
        isFlipped: false,
        isMatched: false,
        matchId: i, // Cards with same matchId form a set
      ));

      // Add mixed color card
      _cards.add(MemoryCard(
        id: i * 3 + 2,
        frontColor: mixedColor,
        backColor: Colors.indigo,
        isFlipped: true, // Start with mixed colors visible
        isMatched: false,
        matchId: i, // Cards with same matchId form a set
        isMix: true, // This is a mixed color card
      ));
    }

    // Remove mixed cards from gameplay cards but show them separately
    final mixCards = _cards.where((card) => card.isMix).toList();
    _cards = _cards.where((card) => !card.isMix).toList();

    // Add mix cards to the top of the screen
    setState(() {
      for (final mixCard in mixCards) {
        mixCard.isReference = true;
      }
      _cards.insertAll(0, mixCards);
    });

    // Shuffle the playable cards (non-mix cards)
    final playableCards = _cards.where((card) => !card.isReference).toList();
    playableCards.shuffle(Random());

    // Reconstruct the cards list with references at top and shuffled playable cards
    _cards = [
      ..._cards.where((card) => card.isReference).toList(),
      ...playableCards,
    ];
  }

  List<Color> _selectColors(int count) {
    // Select a subset of colors from available colors
    final availableColors = widget.puzzle.availableColors;
    final selectedColors = <Color>[];
    final random = Random();

    // If we need more colors than available, we'll create variations
    if (count > availableColors.length) {
      // Add all available colors
      selectedColors.addAll(availableColors);

      // Create variations of existing colors to get the required count
      while (selectedColors.length < count) {
        final baseColor = availableColors[random.nextInt(availableColors.length)];

        // Create a variation by adjusting brightness or saturation
        final hsvColor = HSVColor.fromColor(baseColor);
        final variation = hsvColor
            .withSaturation((hsvColor.saturation * (0.7 + random.nextDouble() * 0.6)).clamp(0.2, 1.0))
            .withValue((hsvColor.value * (0.7 + random.nextDouble() * 0.6)).clamp(0.3, 1.0))
            .toColor();

        selectedColors.add(variation);
      }
    } else {
      // Randomly select count colors from available
      final tempList = List<Color>.from(availableColors);
      tempList.shuffle(random);
      selectedColors.addAll(tempList.take(count));
    }

    return selectedColors;
  }

  int _getGridSize() {
    // Determine grid size based on level
    final level = widget.puzzle.level;

    if (level <= 3) return 2; // 2x2 grid
    if (level <= 8) return 3; // 3x3 grid
    if (level <= 12) return 4; // 4x4 grid
    return 5; // 5x5 grid for higher levels
  }

  void _handleCardTap(int index) {
    // Don't allow interaction during tutorial
    if (_showingTutorial) {
      _nextTutorialStep();
      return;
    }

    // Don't allow interaction with reference cards in mixing mode
    if (_cards[index].isReference) {
      // Show an informative bounce animation on the reference card
      final cardIndex = index;
      setState(() {
        _cards[cardIndex].isHighlighted = true;
      });

      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _cards[cardIndex].isHighlighted = false;
          });
        }
      });

      // Give hint feedback
      if (!_isPaused) {
        ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
      }

      return;
    }

    if (_isPaused || _isLocked || _cards[index].isFlipped || _cards[index].isMatched || _showingSequence) {
      return;
    }

    // Haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 20, amplitude: 40);
      }
    });

    // Play flip sound
    ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);

    setState(() {
      // Flip the card
      _cards[index].isFlipped = true;
      _selectedIndices.add(index);

      // Record the move for history/undo
      _moveHistory.add(CardMove(cardIndex: index, wasFlipped: false));

      // Update selected color for parent
      widget.onColorSelected(_cards[index].frontColor);
    });

    if (_gameMode == GameMode.sequenceMemory) {
      _checkSequenceProgress(index);
      return;
    }

    if (_gameMode == GameMode.mixingMemory) {
      if (_selectedIndices.length == 2) {
        _isLocked = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          _checkMixMatch();
        });
      }
      return;
    }

    // Check for pairs in regular matching modes
    if (_selectedIndices.length == 2) {
      _isLocked = true;
      _moves++;

      Future.delayed(const Duration(milliseconds: 800), () {
        _checkMatch();
      });
    }
  }

  void _checkMatch() {
    if (_selectedIndices.length != 2) return;

    final index1 = _selectedIndices[0];
    final index2 = _selectedIndices[1];

    bool isMatch = false;

    if (_gameMode == GameMode.classicMatch) {
      // Match identical colors
      isMatch = _cards[index1].frontColor == _cards[index2].frontColor;
    } else if (_gameMode == GameMode.complementaryMatch) {
      // Match cards with the same matchId (complementary pairs)
      isMatch = _cards[index1].matchId == _cards[index2].matchId;
    }

    setState(() {
      if (isMatch) {
        // Mark cards as matched
        _cards[index1].isMatched = true;
        _cards[index2].isMatched = true;
        _matchedPairs++;

        // Update combo system
        _combo++;
        _streak++;
        _comboMultiplier = min(3, 1 + (_combo ~/ 3)); // Cap at 3x

        // Calculate score with combo multiplier
        final basePoints = 100 * _currentLevel;
        final comboPoints = basePoints * _comboMultiplier;
        _score += comboPoints;

        // Animate combo text
        _comboController.reset();
        _comboController.forward();

        // Update score
        widget.onScoreUpdate(_score);

        // Play match sound
        ref.read(soundControllerProvider.notifier).playEffect(SoundType.match);

        // Provide haptic feedback
        Vibration.hasVibrator().then((hasVibrator) {
          if (hasVibrator ?? false) {
            Vibration.vibrate(duration: 100, amplitude: 128);
          }
        });

        // Check for level completion
        if (_matchedPairs == _cards.length ~/ 2) {
          _levelCompleted = true;
          // Calculate time bonus
          if (_gameTimeSeconds > 0) {
            _timeBonus = min(1000, _gameTimeSeconds * 10 * _currentLevel ~/ 2);
            _score += _timeBonus;
            widget.onScoreUpdate(_score);
          }

          // Perfect run bonus
          if (_perfectRun) {
            final perfectBonus = 500 * _currentLevel;
            _score += perfectBonus;
            widget.onScoreUpdate(_score);
          }

          // Start celebration animation
          _celebrationController.reset();
          _celebrationController.forward();

          // Schedule level completion after showing the match
          Future.delayed(const Duration(milliseconds: 1500), () {
            _handleLevelComplete();
          });
        }
      } else {
        // Flip cards back
        _cards[index1].isFlipped = false;
        _cards[index2].isFlipped = false;

        // Reset combo on failure
        _combo = 0;
        _perfectRun = false;

        // Record this as a failed attempt
        _moveHistory.add(CardMove(cardIndex: index1, wasFlipped: true));
        _moveHistory.add(CardMove(cardIndex: index2, wasFlipped: true));

        // Play mismatch sound
        ref.read(soundControllerProvider.notifier).playEffect(SoundType.failure);

        // Shake animation
        _shakeController.reset();
        _shakeController.forward();

        // Penalty for wrong match
        _score = max(0, _score - 10);
        widget.onScoreUpdate(_score);
      }

      _selectedIndices.clear();
      _isLocked = false;
    });
  }

  void _checkSequenceProgress(int tappedIndex) {
    if (!_isPlayerTurn) return;

    final correctIndex = _sequence[_sequenceStep];
    final isCorrect = _cards[tappedIndex].id == correctIndex;

    setState(() {
      if (isCorrect) {
        // Progress to next step in sequence
        _sequenceStep++;

        // Update combo
        _combo++;
        _comboMultiplier = min(3, 1 + (_combo ~/ 3));

        // Check if sequence is complete
        if (_sequenceStep >= _sequence.length) {
          // Sequence complete!
          final basePoints = 150 * _currentLevel;
          final comboPoints = basePoints * _comboMultiplier;
          _score += comboPoints;
          widget.onScoreUpdate(_score);

          // Provide success feedback
          Vibration.hasVibrator().then((hasVibrator) {
            if (hasVibrator ?? false) {
              Vibration.vibrate(duration: 200, amplitude: 200);
            }
          });

          // Play success sound
          ref.read(soundControllerProvider.notifier).playEffect(SoundType.success);

          // Start celebration animation
          _celebrationController.reset();
          _celebrationController.forward();

          // Level complete
          _levelCompleted = true;
          Future.delayed(const Duration(milliseconds: 1500), () {
            _handleLevelComplete();
          });
        } else {
          // Play correct step sound
          ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
        }
      } else {
        // Wrong sequence step
        _shakeController.reset();
        _shakeController.forward();

        // Reset combo on failure
        _combo = 0;
        _perfectRun = false;

        // Penalty
        _score = max(0, _score - 30);
        widget.onScoreUpdate(_score);

        // Play failure sound
        ref.read(soundControllerProvider.notifier).playEffect(SoundType.failure);

        // Reset sequence
        _isPlayerTurn = false;
        _sequenceStep = 0;

        // Show sequence again after delay
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            _showNextInSequence();
          }
        });
      }
    });
  }

  void _showNextInSequence() {
    if (_sequenceStep >= _sequence.length) {
      // End of sequence, player's turn
      setState(() {
        _showingSequence = false;
        _isPlayerTurn = true;
        _sequenceStep = 0;
      });

      // Reset all card highlights
      for (final card in _cards) {
        card.isHighlighted = false;
      }

      // Play ready sound
      ref.read(soundControllerProvider.notifier).playEffect(SoundType.bonus);

      // Start timer for player's turn
      _timerController.reset();
      _timerController.forward();

      // Start game timer for sequence memory mode
      _gameTimerController.forward();
      return;
    }

    // Reset all card highlights
    for (final card in _cards) {
      card.isHighlighted = false;
    }

    // Highlight the current card in sequence
    setState(() {
      _showingSequence = true;
      final cardIndex = _sequence[_sequenceStep];
      _cards[cardIndex].isHighlighted = true;
    });

    // Play sequence sound
    ref.read(soundControllerProvider.notifier).playEffect(_sequenceStep % 2 == 0 ? SoundType.click : SoundType.match);

    // Move to next step after delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _sequenceStep++;
        });
        _showNextInSequence();
      }
    });
  }

  void _handleTimeOut() {
    if (!mounted) return;

    // Time ran out for player's sequence reproduction
    setState(() {
      _isPlayerTurn = false;
      _sequenceStep = 0;
      _perfectRun = false;

      // Penalty
      _score = max(0, _score - 50);
      widget.onScoreUpdate(_score);
    });

    // Play timeout sound
    ref.read(soundControllerProvider.notifier).playEffect(SoundType.failure);

    // Shake as feedback
    _shakeController.reset();
    _shakeController.forward();

    // Show sequence again after delay
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _showNextInSequence();
      }
    });
  }

  void _handleGameOver() {
    if (_levelCompleted) return;

    // Game over when timer runs out
    setState(() {
      _isPaused = true;
    });

    // Show game over dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.indigo.shade900,
        title: const Text(
          'Time\'s Up!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            const Text(
              'You ran out of time!',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'Final Score: $_score',
              style: const TextStyle(color: Colors.orange, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.indigo,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _resetGame();
            },
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.orange,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onLevelComplete();
            },
            child: const Text('Next Level'),
          ),
        ],
      ),
    );
  }

  void _checkMixMatch() {
    if (_selectedIndices.length != 2) return;

    final index1 = _selectedIndices[0];
    final index2 = _selectedIndices[1];

    // Check if these are components of the same mix
    final isMatch = _cards[index1].matchId == _cards[index2].matchId;

    setState(() {
      if (isMatch) {
        // Mark cards as matched
        _cards[index1].isMatched = true;
        _cards[index2].isMatched = true;
        _matchedPairs++;

        // Update combo
        _combo++;
        _streak++;
        _comboMultiplier = min(3, 1 + (_combo ~/ 3));

        // Animate combo text
        _comboController.reset();
        _comboController.forward();

        // Update score with combo multiplier
        final basePoints = 120 * _currentLevel;
        final comboPoints = basePoints * _comboMultiplier;
        _score += comboPoints;
        widget.onScoreUpdate(_score);

        // Also highlight the reference mixed color card
        final referenceIndex = _cards.indexWhere((card) => card.isReference && card.matchId == _cards[index1].matchId);

        if (referenceIndex != -1) {
          _cards[referenceIndex].isSuccessHighlighted = true;

          // Clear success highlight after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _cards[referenceIndex].isSuccessHighlighted = false;
              });
            }
          });
        }

        // Play match sound
        ref.read(soundControllerProvider.notifier).playEffect(SoundType.match);

        // Provide haptic feedback
        Vibration.hasVibrator().then((hasVibrator) {
          if (hasVibrator ?? false) {
            Vibration.vibrate(duration: 100, amplitude: 128);
          }
        });

        // Check for level completion
        if (_matchedPairs == (_cards.length - _cards.where((c) => c.isReference).length) ~/ 2) {
          _levelCompleted = true;

          // Calculate time bonus
          if (_gameTimeSeconds > 0) {
            _timeBonus = min(1000, _gameTimeSeconds * 10 * _currentLevel ~/ 2);
            _score += _timeBonus;
            widget.onScoreUpdate(_score);
          }

          // Perfect run bonus
          if (_perfectRun) {
            final perfectBonus = 500 * _currentLevel;
            _score += perfectBonus;
            widget.onScoreUpdate(_score);
          }

          // Start celebration animation
          _celebrationController.reset();
          _celebrationController.forward();

          // Schedule level completion after showing the match
          Future.delayed(const Duration(milliseconds: 1500), () {
            _handleLevelComplete();
          });
        }
      } else {
        // Flip cards back
        _cards[index1].isFlipped = false;
        _cards[index2].isFlipped = false;

        // Reset combo on failure
        _combo = 0;
        _perfectRun = false;

        // Shake animation
        _shakeController.reset();
        _shakeController.forward();

        // Play failure sound
        ref.read(soundControllerProvider.notifier).playEffect(SoundType.failure);

        // Penalty for wrong match
        _score = max(0, _score - 15);
        widget.onScoreUpdate(_score);
      }

      _selectedIndices.clear();
      _isLocked = false;
    });
  }

  void _handleLevelComplete() {
    // Stop game timer
    _gameTimerController.stop();

    // Play success sound
    ref.read(soundControllerProvider.notifier).playEffect(SoundType.levelComplete);

    // Animate card celebration
    _rotationController.reset();
    _rotationController.forward();

    // Notify parent
    widget.onLevelComplete();
  }

  void _useHint() {
    if (_hintsRemaining <= 0 || _isPaused || _levelCompleted || _showingSequence) return;

    setState(() {
      _hintsRemaining--;
      _showHint = true;

      // Different hint behavior based on game mode
      if (_gameMode == GameMode.classicMatch || _gameMode == GameMode.complementaryMatch) {
        // Briefly show all cards
        for (final card in _cards) {
          if (!card.isMatched) {
            card.isHintShown = true;
          }
        }

        // Hide hint after a short period
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              for (final card in _cards) {
                card.isHintShown = false;
              }
              _showHint = false;
            });
          }
        });
      } else if (_gameMode == GameMode.sequenceMemory) {
        // Show the next step in the sequence
        if (_isPlayerTurn && _sequenceStep < _sequence.length) {
          final correctIndex = _sequence[_sequenceStep];
          _cards[correctIndex].isPulsing = true;

          // Stop pulsing after a delay
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              setState(() {
                _cards[correctIndex].isPulsing = false;
                _showHint = false;
              });
            }
          });
        }
      } else if (_gameMode == GameMode.mixingMemory) {
        // Highlight a correct pair
        final unmatched = _cards.where((card) => !card.isMatched && !card.isReference).toList();

        if (unmatched.isNotEmpty) {
          final matchId = unmatched.first.matchId;
          final matchingCards = unmatched.where((card) => card.matchId == matchId).toList();

          if (matchingCards.length >= 2) {
            matchingCards[0].isPulsing = true;
            matchingCards[1].isPulsing = true;

            // Stop pulsing after a delay
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                setState(() {
                  for (final card in _cards) {
                    card.isPulsing = false;
                  }
                  _showHint = false;
                });
              }
            });
          }
        }
      }
    });

    // Play hint sound
    ref.read(soundControllerProvider.notifier).playEffect(SoundType.bonus);
  }

  void _pauseGame() {
    if (_levelCompleted) return;

    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _gameTimerController.stop();
      // Play pause sound
      ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
    } else {
      _gameTimerController.forward();
      // Play resume sound
      ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
    }
  }

  void _undoMove() {
    if (_moveHistory.isEmpty || _isPaused || _levelCompleted || _showingSequence) return;

    // Get the last move
    final lastMove = _moveHistory.removeLast();

    if (lastMove.wasFlipped) {
      // This was a failed match that was flipped back, so we need to flip it again
      setState(() {
        _cards[lastMove.cardIndex].isFlipped = true;
        _selectedIndices.add(lastMove.cardIndex);
      });

      // We need the second card too
      if (_moveHistory.isNotEmpty) {
        final secondLastMove = _moveHistory.removeLast();
        if (secondLastMove.wasFlipped) {
          setState(() {
            _cards[secondLastMove.cardIndex].isFlipped = true;
            _selectedIndices.add(secondLastMove.cardIndex);
          });

          // Now we need to check if these match
          _isLocked = true;
          Future.delayed(const Duration(milliseconds: 800), () {
            _checkMatch();
          });
        }
      }
    } else {
      // This was a card that was flipped, so flip it back
      setState(() {
        _cards[lastMove.cardIndex].isFlipped = false;
        _selectedIndices.remove(lastMove.cardIndex);
      });
    }

    // Play sound
    ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
  }

  void _resetGame() {
    _gameTimerController.reset();

    setState(() {
      _selectedIndices.clear();
      _matchedPairs = 0;
      _moves = 0;
      _isLocked = false;
      _levelCompleted = false;
      _isPaused = false;
      _score = 0;
      _combo = 0;
      _streak = 0;
      _comboMultiplier = 1;
      _perfectRun = true;
      _moveHistory.clear();
      _hintsRemaining = 3;

      // Reset all cards
      for (final card in _cards) {
        card.isFlipped = card.isReference;
        card.isMatched = false;
        card.isHighlighted = false;
        card.isHintShown = false;
        card.isPulsing = false;
        card.isSuccessHighlighted = false;
      }
    });

    // Shuffle cards that aren't references
    final nonReferenceCards = _cards.where((card) => !card.isReference).toList();
    nonReferenceCards.shuffle(Random());

    setState(() {
      // Reconstruct the deck with references at the top
      _cards = [
        ..._cards.where((card) => card.isReference).toList(),
        ...nonReferenceCards,
      ];
    });

    // Start with intro animation
    _scaleController.reset();
    _scaleController.forward();

    // Start game timer
    if (_gameMode != GameMode.sequenceMemory) {
      _gameTimerController.forward();
    } else {
      // For sequence mode, we need to show the sequence first
      _showingSequence = true;
      _sequenceStep = 0;

      // Begin sequence display after short delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _showNextInSequence();
        }
      });
    }

    // Reset score display
    widget.onScoreUpdate(0);

    // Play start sound
    ref.read(soundControllerProvider.notifier).playEffect(SoundType.bonus);
  }

  @override
  Widget build(BuildContext context) {
    final gridSize = _getGridSize();
    final hasSequence = _gameMode == GameMode.sequenceMemory;
    final hasMixedCards = _gameMode == GameMode.mixingMemory;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Game stats and info
        _buildGameInfo(),

        const SizedBox(height: 16),

        // For color mixing mode, show reference cards at top
        if (hasMixedCards && _cards.any((card) => card.isReference))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _cards.where((card) => card.isReference).map((card) => _buildReferenceCard(card)).toList(),
              ),
            ),
          ),

        // Card grid
        Expanded(
          child: Center(
            child: Stack(
              children: [
                // Main game grid
                AspectRatio(
                  aspectRatio: 1.0,
                  child: AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          _shakeController.isAnimating ? _shakeAnimation.value : 0.0,
                          0.0,
                        ),
                        child: child,
                      );
                    },
                    child: AnimatedBuilder(
                      animation: _scaleController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleController.value,
                          child: child,
                        );
                      },
                      child: hasMixedCards
                          ? GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridSize,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: _cards.where((card) => !card.isReference).length,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                final nonReferenceCards = _cards.where((card) => !card.isReference).toList();
                                final actualIndex = _cards.indexOf(nonReferenceCards[index]);
                                return _buildCard(actualIndex);
                              },
                            )
                          : GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridSize,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: _cards.length,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                return _buildCard(index);
                              },
                            ),
                    ),
                  ),
                ),

                // Combo counter overlay
                if (_combo > 1)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: AnimatedBuilder(
                      animation: _comboScaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _comboScaleAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.flash_on, color: Colors.white, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              'COMBO x$_combo',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Celebration particles
                if (_celebrationController.isAnimating)
                  AnimatedBuilder(
                    animation: _celebrationController,
                    builder: (context, child) {
                      // Update particle positions
                      for (final particle in _celebrationParticles) {
                        if (_celebrationController.value <= particle.lifespan) {
                          particle.position += particle.velocity;
                          particle.velocity += const Offset(0, 0.1); // gravity
                          particle.opacity = 1.0 - (_celebrationController.value / particle.lifespan);
                        }
                      }

                      return CustomPaint(
                        size: Size.infinite,
                        painter: CelebrationPainter(
                          particles: _celebrationParticles,
                          animationValue: _celebrationController.value,
                        ),
                      );
                    },
                  ),

                // Pause overlay
                if (_isPaused)
                  GestureDetector(
                    onTap: _pauseGame,
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.pause_circle_filled,
                              color: Colors.white,
                              size: 60,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'PAUSED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _pauseGame,
                              child: const Text('RESUME'),
                            ),
                            const SizedBox(height: 15),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isPaused = false;
                                });
                                _resetGame();
                              },
                              child: const Text(
                                'Restart Level',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Tutorial overlay
                if (_showingTutorial)
                  GestureDetector(
                    onTap: _nextTutorialStep,
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.all(30),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade900,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.indigo.shade300,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _tutorialStep == 0 ? Icons.lightbulb_outline : Icons.tips_and_updates,
                                color: Colors.yellow,
                                size: 40,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _tutorialMessages[_tutorialStep],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 30),
                              Text(
                                'Tap to continue (${_tutorialStep + 1}/${_tutorialMessages.length})',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        if (hasSequence && _isPlayerTurn)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(
              value: _timerController.value,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                _timerController.value > 0.5
                    ? Colors.green
                    : (_timerController.value > 0.2 ? Colors.orange : Colors.red),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Game timer and controls
        _buildGameControls(),
      ],
    );
  }

  Widget _buildReferenceCard(MemoryCard card) {
    final isSuccessHighlight = card.isSuccessHighlighted;
    final isHighlighted = card.isHighlighted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () {
          // Show a quick highlight animation when tapping a reference card
          setState(() {
            card.isHighlighted = true;
          });

          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              setState(() {
                card.isHighlighted = false;
              });
            }
          });

          // Play click sound
          ref.read(soundControllerProvider.notifier).playEffect(SoundType.click);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: card.frontColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSuccessHighlight
                  ? Colors.green.shade300
                  : (isHighlighted ? Colors.white : Colors.white.withOpacity(0.3)),
              width: isSuccessHighlight || isHighlighted ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSuccessHighlight ? Colors.green.withOpacity(0.5) : Colors.black.withOpacity(0.2),
                blurRadius: 5,
                spreadRadius: isSuccessHighlight ? 2 : 0,
              ),
            ],
          ),
          child: isSuccessHighlight
              ? const Center(
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 30,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildGameInfo() {
    String modeName;

    switch (_gameMode) {
      case GameMode.classicMatch:
        modeName = 'Classic Match';
        break;
      case GameMode.complementaryMatch:
        modeName = 'Complementary Pairs';
        break;
      case GameMode.sequenceMemory:
        modeName = 'Color Sequence';
        break;
      case GameMode.mixingMemory:
        modeName = 'Color Mixing';
        break;
    }

    return Card(
      color: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.indigo.shade300.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Mode info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      _getModeIcon(),
                      color: Colors.indigo.shade200,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Level ${widget.puzzle.level}: $modeName',
                      style: TextStyle(
                        color: Colors.indigo.shade200,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _gameMode != GameMode.sequenceMemory
                    ? Text(
                        'Moves: $_moves | Pairs: $_matchedPairs/${(_cards.length - _cards.where((c) => c.isReference).length) ~/ 2}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      )
                    : Text(
                        _isPlayerTurn ? 'Sequence: ${_sequenceStep}/${_sequence.length}' : 'Watch the sequence...',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
              ],
            ),

            // Score display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _comboMultiplier > 1 ? Colors.orange.withOpacity(0.3) : Colors.indigo.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      _comboMultiplier > 1 ? Colors.orange.withOpacity(0.7) : Colors.indigo.shade300.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'SCORE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_comboMultiplier > 1)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'x$_comboMultiplier',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '$_score',
                    style: TextStyle(
                      color: _comboMultiplier > 1 ? Colors.orange.shade200 : Colors.indigo.shade200,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameControls() {
    return Card(
      color: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.indigo.shade300.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Timer bar
            if (!_showingSequence && _gameMode != GameMode.sequenceMemory)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TIME',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$_gameTimeSeconds s',
                          style: TextStyle(
                            color: _gameTimeSeconds > 10 ? Colors.white70 : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: 1.0 - _gameTimerController.value,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade800,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _timerColorAnimation.value ?? Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: Icons.pause,
                  label: 'Pause',
                  onPressed: _pauseGame,
                  color: Colors.blue,
                ),
                _buildControlButton(
                  icon: Icons.refresh,
                  label: 'Restart',
                  onPressed: _resetGame,
                  color: Colors.red,
                ),
                _buildControlButton(
                  icon: Icons.lightbulb_outline,
                  label: 'Hint ($_hintsRemaining)',
                  onPressed: _hintsRemaining > 0 ? _useHint : null,
                  color: Colors.amber,
                ),
                _buildControlButton(
                  icon: Icons.undo,
                  label: 'Undo',
                  onPressed: _moveHistory.isNotEmpty ? _undoMove : null,
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    final isDisabled = onPressed == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        splashColor: color.withOpacity(0.3),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isDisabled ? Colors.grey : color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isDisabled ? Colors.grey : Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getModeIcon() {
    switch (_gameMode) {
      case GameMode.classicMatch:
        return Icons.grid_view;
      case GameMode.complementaryMatch:
        return Icons.swap_horiz;
      case GameMode.sequenceMemory:
        return Icons.format_list_numbered;
      case GameMode.mixingMemory:
        return Icons.palette;
    }
  }

  Widget _buildCard(int index) {
    final card = _cards[index];

    // Skip reference cards in the main grid
    if (card.isReference) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        double extraRotation = 0.0;
        if (_levelCompleted && _rotationController.isAnimating) {
          extraRotation = sin(_rotationController.value * 3 * pi) * 0.1;
        }

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateY(extraRotation),
          alignment: Alignment.center,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () => _handleCardTap(index),
        child: _buildFlipCard(card),
      ),
    );
  }

  Widget _buildFlipCard(MemoryCard card) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final rotateAnimation = Tween<double>(begin: pi, end: 0.0).animate(animation);
        return AnimatedBuilder(
          animation: rotateAnimation,
          child: child,
          builder: (context, child) {
            final isBack = !card.isFlipped || card.isHintShown;

            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // Perspective
                ..rotateY(rotateAnimation.value),
              alignment: Alignment.center,
              child: isBack
                  ? _buildCardFace(card.backColor, false, card.isMatched)
                  : _buildCardFace(
                      card.frontColor,
                      true,
                      card.isMatched,
                      card.isHighlighted || card.isHintShown || card.isPulsing,
                    ),
            );
          },
        );
      },
      child: (card.isFlipped || card.isHintShown)
          ? _buildCardFace(
              card.frontColor, true, card.isMatched, card.isHighlighted || card.isHintShown || card.isPulsing)
          : _buildCardFace(card.backColor, false, card.isMatched),
    );
  }

  Widget _buildCardFace(Color color, bool isFront, bool isMatched, [bool isHighlighted = false]) {
    // For pulsing animation
    Widget cardWidget = Container(
      key: ValueKey<bool>(isFront),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 5,
            offset: Offset(0, _cardDepth / 2),
          ),
        ],
        border: isHighlighted
            ? Border.all(color: Colors.white, width: 4)
            : isMatched
                ? Border.all(color: Colors.greenAccent, width: 3)
                : Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: isFront
          ? Center(
              child: isMatched
                  ? const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 30,
                    )
                  : null,
            )
          : Center(
              child: Icon(
                Icons.question_mark,
                color: Colors.white.withOpacity(0.7),
                size: 30,
              ),
            ),
    );

    // Apply pulsing animation if needed
    if (isHighlighted) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: 1.2),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}

// The different game modes
enum GameMode {
  classicMatch, // Match identical colors
  complementaryMatch, // Match complementary colors
  sequenceMemory, // Remember and reproduce a color sequence
  mixingMemory, // Match mixed colors with their components
}

// Class to represent a memory card
class MemoryCard {
  final int id;
  final Color frontColor;
  final Color backColor;
  bool isFlipped;
  bool isMatched;
  bool isHighlighted;
  bool isHintShown;
  bool isPulsing;
  bool isReference;
  bool isSuccessHighlighted;
  int? matchId; // For matching specific pairs (complementary or mixing)
  bool isMix; // Is this a mixed color card

  MemoryCard({
    required this.id,
    required this.frontColor,
    required this.backColor,
    required this.isFlipped,
    required this.isMatched,
    this.isHighlighted = false,
    this.isHintShown = false,
    this.isPulsing = false,
    this.isReference = false,
    this.isSuccessHighlighted = false,
    this.matchId,
    this.isMix = false,
  });
}

// Record move history for undo functionality
class CardMove {
  final int cardIndex;
  final bool wasFlipped; // true if this card was flipped back (failed match)

  CardMove({required this.cardIndex, required this.wasFlipped});
}

// Class for celebration particles
class CelebrationParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double lifespan;
  double opacity = 1.0;

  CelebrationParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.lifespan,
  });
}

// Painter for celebration particles
class CelebrationPainter extends CustomPainter {
  final List<CelebrationParticle> particles;
  final double animationValue;

  CelebrationPainter({
    required this.particles,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in particles) {
      if (animationValue <= particle.lifespan) {
        final paint = Paint()
          ..color = particle.color.withOpacity(particle.opacity)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          center + particle.position,
          particle.size,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CelebrationPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
