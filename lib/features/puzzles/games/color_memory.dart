import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/color_models/color_mixer.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:palette_master/features/puzzles/widgets/color_preview.dart';
import 'package:vibration/vibration.dart';

class ColorMemoryGame extends ConsumerStatefulWidget {
  final Puzzle puzzle;
  final Color userColor;
  final Function(Color) onColorMixed;

  const ColorMemoryGame({
    super.key,
    required this.puzzle,
    required this.userColor,
    required this.onColorMixed,
  });

  @override
  ConsumerState<ColorMemoryGame> createState() => _ColorMemoryGameState();
}

class _ColorMemoryGameState extends ConsumerState<ColorMemoryGame> with TickerProviderStateMixin {
  // Game states
  late GameMode _gameMode;
  GameState _gameState = GameState.notStarted;
  int _currentLevel = 0;
  int _score = 0;
  int _consecutiveCorrect = 0;
  double _similarity = 0.0;

  // Game board
  late List<MemoryCard> _cards;
  List<MemoryCard> _selectedCards = [];
  List<MemoryCard> _matchedCards = [];
  List<int> _colorSequence = [];
  int _sequenceIndex = 0;

  // Timers
  Timer? _gameTimer;
  Timer? _sequenceTimer;
  int _remainingTime = 0;
  bool _isShowingSequence = false;

  // Animation controllers
  late AnimationController _boardAnimationController;
  late Animation<double> _boardAnimation;
  late AnimationController _cardFlipController;
  Animation<double>? _cardFlipAnimation;
  late AnimationController _feedbackAnimationController;
  late Animation<double> _feedbackAnimation;

  // Game metrics
  int _moves = 0;
  int _correctMatches = 0;
  int _mistakes = 0;
  int _remainingPairs = 0;
  int _revealedCount = 0;

  // Current target color in color sequence mode
  Color _targetColor = Colors.white;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _boardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _boardAnimation = CurvedAnimation(
      parent: _boardAnimationController,
      curve: Curves.easeOutBack,
    );

    _cardFlipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _feedbackAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _feedbackAnimation = CurvedAnimation(
      parent: _feedbackAnimationController,
      curve: Curves.elasticOut,
    );

    // Determine game mode based on level
    _determineGameMode();

    // Initialize the game
    _initializeGame();

    // Start the animation
    _boardAnimationController.forward();
  }

  void _determineGameMode() {
    final level = widget.puzzle.level;

    if (level <= 3) {
      _gameMode = GameMode.colorMatching; // Simple matching pairs
    } else if (level <= 6) {
      _gameMode = GameMode.colorSequence; // Remember color sequence
    } else if (level <= 9) {
      _gameMode = GameMode.colorRelationships; // Match color relationships
    } else {
      _gameMode = GameMode.mixedMode; // Mix of different challenges
    }
  }

  void _initializeGame() {
    // Reset game state
    _gameState = GameState.notStarted;
    _currentLevel = 1;
    _score = 0;
    _consecutiveCorrect = 0;
    _moves = 0;
    _correctMatches = 0;
    _mistakes = 0;
    _selectedCards = [];
    _matchedCards = [];

    // Cancel any active timers
    _gameTimer?.cancel();
    _sequenceTimer?.cancel();

    // Create the game board based on game mode
    _createGameBoard();

    // Initial target color (used in some game modes)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_gameMode == GameMode.colorSequence) {
        _targetColor = widget.puzzle.targetColor;
        widget.onColorMixed(_targetColor);
      } else {
        _targetColor = Colors.white;
        widget.onColorMixed(_targetColor);
      }
    });
  }

  void _createGameBoard() {
    final random = Random();

    // Determine grid size based on level
    int gridSize = 4; // Default 4x4 grid
    if (widget.puzzle.level > 5) {
      gridSize = 5; // 5x5 for higher levels
    }
    if (widget.puzzle.level > 10) {
      gridSize = 6; // 6x6 for very high levels
    }

    // Initialize empty card list
    _cards = [];

    switch (_gameMode) {
      case GameMode.colorMatching:
        _createColorMatchingBoard(gridSize, random);
        break;
      case GameMode.colorSequence:
        _createColorSequenceBoard(gridSize, random);
        break;
      case GameMode.colorRelationships:
        _createColorRelationshipsBoard(gridSize, random);
        break;
      case GameMode.mixedMode:
        // Randomly choose between the three modes
        final randomMode = random.nextInt(3);
        switch (randomMode) {
          case 0:
            _createColorMatchingBoard(gridSize, random);
            break;
          case 1:
            _createColorSequenceBoard(gridSize, random);
            break;
          case 2:
            _createColorRelationshipsBoard(gridSize, random);
            break;
        }
        break;
    }

    // Shuffle the cards
    _shuffleCards();
  }

  void _createColorMatchingBoard(int gridSize, Random random) {
    // Simple memory game with matching pairs
    // Create pairs of cards with the same colors

    // Calculate how many pairs we need
    int numberOfPairs = (gridSize * gridSize) ~/ 2;
    _remainingPairs = numberOfPairs;

    // Get available colors from puzzle
    final availableColors = List<Color>.from(widget.puzzle.availableColors);

    // If we don't have enough colors, generate more by mixing
    while (availableColors.length < numberOfPairs) {
      // Mix two random colors
      final color1 = availableColors[random.nextInt(availableColors.length)];
      final color2 = availableColors[random.nextInt(availableColors.length)];
      final mixedColor = ColorMixer.mixSubtractive([color1, color2]);

      // Check if this color is sufficiently different from existing colors
      bool isDifferentEnough = true;
      for (final existingColor in availableColors) {
        if (_calculateColorSimilarity(mixedColor, existingColor) > 0.8) {
          isDifferentEnough = false;
          break;
        }
      }

      if (isDifferentEnough) {
        availableColors.add(mixedColor);
      }
    }

    // Shuffle the available colors and take the number we need
    availableColors.shuffle();
    final selectedColors = availableColors.take(numberOfPairs).toList();

    // Create the pairs
    for (int i = 0; i < numberOfPairs; i++) {
      final color = selectedColors[i];

      // Create first card of the pair
      _cards.add(MemoryCard(
        id: i * 2,
        color: color,
        isFlipped: false,
        isMatched: false,
        pairId: i,
        type: CardType.color,
      ));

      // Create second card of the pair
      _cards.add(MemoryCard(
        id: i * 2 + 1,
        color: color,
        isFlipped: false,
        isMatched: false,
        pairId: i,
        type: CardType.color,
      ));
    }
  }

  void _createColorSequenceBoard(int gridSize, Random random) {
    // Create a sequence of colors that the player needs to memorize and repeat

    // For sequence mode, we'll use a simplified grid
    gridSize = 3; // 3x3 grid for sequence mode

    // Get available colors from puzzle
    final availableColors = List<Color>.from(widget.puzzle.availableColors);

    // Add variation for more color choices
    for (int i = 0; i < 3 && availableColors.length < 9; i++) {
      if (availableColors.length >= 2) {
        final color1 = availableColors[random.nextInt(availableColors.length)];
        final color2 = availableColors[random.nextInt(availableColors.length)];
        final mixedColor = ColorMixer.mixSubtractive([color1, color2]);
        availableColors.add(mixedColor);
      }
    }

    // Ensure we have at least gridSize^2 colors
    while (availableColors.length < gridSize * gridSize) {
      availableColors.add(Colors.primaries[random.nextInt(Colors.primaries.length)]);
    }

    // Shuffle and select colors for the grid
    availableColors.shuffle();
    final selectedColors = availableColors.take(gridSize * gridSize).toList();

    // Create cards for each color
    for (int i = 0; i < selectedColors.length; i++) {
      _cards.add(MemoryCard(
        id: i,
        color: selectedColors[i],
        isFlipped: false,
        isMatched: false,
        pairId: -1, // Not used in sequence mode
        type: CardType.color,
      ));
    }

    // Generate a sequence based on level difficulty
    _colorSequence = [];
    int sequenceLength = 3 + (widget.puzzle.level ~/ 2).clamp(0, 6);

    for (int i = 0; i < sequenceLength; i++) {
      _colorSequence.add(random.nextInt(_cards.length));
    }

    // Reset sequence index
    _sequenceIndex = 0;

    // Set target color to first in sequence
    if (_colorSequence.isNotEmpty) {
      _targetColor = _cards[_colorSequence[0]].color;
      widget.onColorMixed(_targetColor);
    }
  }

  void _createColorRelationshipsBoard(int gridSize, Random random) {
    // Create a board where players need to find color relationships
    // (complementary, analogous, etc.)

    // Get available colors from puzzle
    final availableColors = List<Color>.from(widget.puzzle.availableColors);

    // Ensure we have enough colors
    while (availableColors.length < 8) {
      availableColors.add(Colors.primaries[random.nextInt(Colors.primaries.length)]);
    }

    // Shuffle colors
    availableColors.shuffle();

    // Calculate number of pairs
    int numberOfPairs = (gridSize * gridSize) ~/ 2;
    _remainingPairs = numberOfPairs;

    // Create pairs based on color relationships
    for (int i = 0; i < numberOfPairs; i++) {
      // Choose relationship type based on index
      RelationshipType relationshipType;

      if (i % 3 == 0) {
        relationshipType = RelationshipType.complementary;
      } else if (i % 3 == 1) {
        relationshipType = RelationshipType.analogous;
      } else {
        relationshipType = RelationshipType.monochromatic;
      }

      // Get a base color
      final baseColor = availableColors[i % availableColors.length];

      // Create related color based on relationship type
      Color relatedColor;
      String relationshipName;

      switch (relationshipType) {
        case RelationshipType.complementary:
          relatedColor = ColorMixer.getComplementary(baseColor);
          relationshipName = "Complementary";
          break;
        case RelationshipType.analogous:
          final analogousColors = ColorMixer.getAnalogous(baseColor);
          relatedColor = analogousColors.length > 1 ? analogousColors[1] : baseColor;
          relationshipName = "Analogous";
          break;
        case RelationshipType.monochromatic:
          // Create a lighter/darker version of the base color
          final hsvColor = HSVColor.fromColor(baseColor);
          final newValue = (hsvColor.value + 0.3).clamp(0.0, 1.0);
          relatedColor = hsvColor.withValue(newValue).toColor();
          relationshipName = "Monochromatic";
          break;
      }

      // Add the base color card
      _cards.add(MemoryCard(
        id: i * 2,
        color: baseColor,
        isFlipped: false,
        isMatched: false,
        pairId: i,
        type: CardType.color,
        relationshipType: relationshipType,
        relationshipName: relationshipName,
      ));

      // Add the related color card
      _cards.add(MemoryCard(
        id: i * 2 + 1,
        color: relatedColor,
        isFlipped: false,
        isMatched: false,
        pairId: i,
        type: CardType.relatedColor,
        relationshipType: relationshipType,
        relationshipName: relationshipName,
      ));
    }
  }

  void _shuffleCards() {
    // Shuffle the cards
    _cards.shuffle();

    // Assign grid positions
    int gridSize = sqrt(_cards.length).ceil();

    for (int i = 0; i < _cards.length; i++) {
      int row = i ~/ gridSize;
      int col = i % gridSize;

      _cards[i].gridX = col;
      _cards[i].gridY = row;
    }
  }

  void _startGame() {
    setState(() {
      _gameState = GameState.playing;

      // Set timer based on game mode and level
      switch (_gameMode) {
        case GameMode.colorMatching:
          _remainingTime = 60 + (widget.puzzle.level * 5); // More time for higher levels
          break;
        case GameMode.colorSequence:
          // Will be handled separately in _showColorSequence
          break;
        case GameMode.colorRelationships:
          _remainingTime = 90 + (widget.puzzle.level * 5); // More time for relationship mode
          break;
        case GameMode.mixedMode:
          _remainingTime = 120; // Fixed time for mixed mode
          break;
      }
    });

    // Start timer for modes that need it
    if (_gameMode != GameMode.colorSequence) {
      _startGameTimer();
    } else {
      _showColorSequence();
    }
  }

  void _startGameTimer() {
    // Cancel any existing timer
    _gameTimer?.cancel();

    // Start a new timer
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          // Time's up
          _endGame(false);
        }
      });
    });
  }

  void _showColorSequence() {
    setState(() {
      _isShowingSequence = true;
      // Reset all cards
      for (final card in _cards) {
        card.isFlipped = false;
      }
      _sequenceIndex = 0;
    });

    // Show the sequence one by one
    _showNextInSequence();
  }

  void _showNextInSequence() {
    if (_sequenceIndex < _colorSequence.length) {
      // Get the card to show
      final cardIndex = _colorSequence[_sequenceIndex];

      // Flip the card
      setState(() {
        _cards[cardIndex].isFlipped = true;
        _targetColor = _cards[cardIndex].color;
      });

      // Update mixed color for the puzzle
      widget.onColorMixed(_targetColor);

      // Provide haptic feedback
      Vibration.hasVibrator().then((hasVibrator) {
        if (hasVibrator ?? false) {
          Vibration.vibrate(duration: 20, amplitude: 40);
        }
      });

      // Schedule hiding the card
      _sequenceTimer = Timer(const Duration(milliseconds: 1000), () {
        setState(() {
          _cards[cardIndex].isFlipped = false;
        });

        // Schedule showing the next card
        _sequenceTimer = Timer(const Duration(milliseconds: 500), () {
          _sequenceIndex++;
          _showNextInSequence();
        });
      });
    } else {
      // Sequence complete, start the player's turn
      setState(() {
        _isShowingSequence = false;
        _sequenceIndex = 0;
        _gameState = GameState.playing;
        _remainingTime = 60 + (_colorSequence.length * 5); // Time based on sequence length
      });

      // Set the target to the first color in sequence
      if (_colorSequence.isNotEmpty) {
        setState(() {
          _targetColor = _cards[_colorSequence[0]].color;
        });
        widget.onColorMixed(_targetColor);
      }

      // Start the game timer
      _startGameTimer();
    }
  }

  void _onCardTap(MemoryCard card) {
    // Ignore taps when game is not in playing state or card is already flipped/matched
    if (_gameState != GameState.playing || card.isFlipped || card.isMatched || _isShowingSequence) {
      return;
    }

    // Handle card tap based on game mode
    switch (_gameMode) {
      case GameMode.colorMatching:
        _handleColorMatchingTap(card);
        break;
      case GameMode.colorSequence:
        _handleColorSequenceTap(card);
        break;
      case GameMode.colorRelationships:
        _handleColorRelationshipsTap(card);
        break;
      case GameMode.mixedMode:
        // Determine which handler to use based on the current board
        if (_colorSequence.isNotEmpty) {
          _handleColorSequenceTap(card);
        } else if (_cards.any((c) => c.relationshipType != null)) {
          _handleColorRelationshipsTap(card);
        } else {
          _handleColorMatchingTap(card);
        }
        break;
    }
  }

  void _handleColorMatchingTap(MemoryCard card) {
    // Flip the card
    setState(() {
      card.isFlipped = true;
      _selectedCards.add(card);
    });

    // Animate card flip
    _playCardFlipAnimation();

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 20, amplitude: 40);
      }
    });

    // If two cards are selected, check for a match
    if (_selectedCards.length == 2) {
      _moves++;

      // Check if cards match
      if (_selectedCards[0].pairId == _selectedCards[1].pairId) {
        // Match found
        _handleMatch();
      } else {
        // No match, flip back after delay
        _handleMismatch();
      }
    }
  }

  void _handleColorSequenceTap(MemoryCard card) {
    // Check if the tapped card matches the expected card in sequence
    if (_colorSequence.isEmpty || _sequenceIndex >= _colorSequence.length) {
      return;
    }

    // Get the expected card
    final expectedCardIndex = _colorSequence[_sequenceIndex];
    final expectedCard = _cards[expectedCardIndex];

    // Flip the card
    setState(() {
      card.isFlipped = true;
    });

    // Animate card flip
    _playCardFlipAnimation();

    // Check if it's the correct card
    if (card.id == expectedCard.id) {
      // Correct card in sequence
      _handleSequenceMatch(card);
    } else {
      // Wrong card selected
      _handleSequenceMismatch(card);
    }
  }

  void _handleColorRelationshipsTap(MemoryCard card) {
    // Similar to color matching but checking for relationship matches
    setState(() {
      card.isFlipped = true;
      _selectedCards.add(card);
    });

    // Animate card flip
    _playCardFlipAnimation();

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 20, amplitude: 40);
      }
    });

    // If two cards are selected, check for a relationship match
    if (_selectedCards.length == 2) {
      _moves++;

      // Check if cards have the same relationship ID
      if (_selectedCards[0].pairId == _selectedCards[1].pairId) {
        // Match found
        _handleMatch();

        // Show relationship info briefly
        _showRelationshipInfo(_selectedCards[0].relationshipName ?? "Related Colors");
      } else {
        // No match, flip back after delay
        _handleMismatch();
      }
    }
  }

  void _showRelationshipInfo(String relationshipName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$relationshipName Colors Match!'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleMatch() {
    // Mark the matched cards
    setState(() {
      for (final card in _selectedCards) {
        card.isMatched = true;
      }
      _matchedCards.addAll(_selectedCards);
      _selectedCards = [];
      _correctMatches++;
      _consecutiveCorrect++;
      _remainingPairs--;
    });

    // Update score
    _updateScore(true);

    // Play success animation
    _feedbackAnimationController.reset();
    _feedbackAnimationController.forward();

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 50, amplitude: 100);
      }
    });

    // Check if the game is complete
    if (_remainingPairs <= 0) {
      _endGame(true);
    }
  }

  void _handleMismatch() {
    // Flip the cards back after a delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          for (final card in _selectedCards) {
            card.isFlipped = false;
          }
          _selectedCards = [];
          _mistakes++;
          _consecutiveCorrect = 0;
        });
      }
    });

    // Update score
    _updateScore(false);
  }

  void _handleSequenceMatch(MemoryCard card) {
    setState(() {
      card.isMatched = true;
      _revealedCount++;
      _sequenceIndex++;
      _consecutiveCorrect++;
    });

    // Play success animation
    _feedbackAnimationController.reset();
    _feedbackAnimationController.forward();

    // Provide haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 50, amplitude: 100);
      }
    });

    // Update score
    _updateScore(true);

    // Update the target color to the next in sequence if there is one
    if (_sequenceIndex < _colorSequence.length) {
      final nextCardIndex = _colorSequence[_sequenceIndex];
      setState(() {
        _targetColor = _cards[nextCardIndex].color;
      });
      widget.onColorMixed(_targetColor);
    }

    // Check if the sequence is complete
    if (_sequenceIndex >= _colorSequence.length) {
      _endGame(true);
    }
  }

  void _handleSequenceMismatch(MemoryCard card) {
    // Flip the card back after a delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          card.isFlipped = false;
          _mistakes++;
          _consecutiveCorrect = 0;
        });
      }
    });

    // Update score
    _updateScore(false);

    // Penalize with time reduction
    setState(() {
      _remainingTime = (_remainingTime - 5).clamp(0, 1000);
    });
  }

  void _updateScore(bool isCorrect) {
    if (isCorrect) {
      // Calculate points based on speed, consecutive correct answers, and level
      int basePoints = 10;
      int timeBonus = (_remainingTime ~/ 10).clamp(1, 10);
      int streakBonus = _consecutiveCorrect.clamp(1, 5);
      int levelBonus = widget.puzzle.level;

      int totalPoints = basePoints * timeBonus * streakBonus + levelBonus;

      setState(() {
        _score += totalPoints;
      });
    } else {
      // Penalty for mistakes
      setState(() {
        _score = (_score - 5).clamp(0, 1000000);
      });
    }
  }

  void _playCardFlipAnimation() {
    _cardFlipController.reset();

    // Create the animation
    _cardFlipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardFlipController,
        curve: Curves.easeInOut,
      ),
    );

    // Start the animation
    _cardFlipController.forward();
  }

  void _endGame(bool isSuccess) {
    // Stop the timers
    _gameTimer?.cancel();
    _sequenceTimer?.cancel();

    setState(() {
      _gameState = isSuccess ? GameState.success : GameState.failed;
    });

    // Calculate similarity based on game performance
    double similarityFactor;

    if (isSuccess) {
      // High similarity for success
      similarityFactor = 0.8 + (0.2 * (1 - (_mistakes / ((_correctMatches + _mistakes) * 2))));
    } else {
      // Lower similarity for failure, but still proportional to progress
      similarityFactor = 0.3 + (0.5 * (1 - (_remainingPairs / (_remainingPairs + _correctMatches))));
    }

    // Clamp similarity between 0.3 and 1.0
    similarityFactor = similarityFactor.clamp(0.3, 1.0);

    // Create a color that's a blend between white and the target color
    final resultColor = Color.lerp(Colors.white, widget.puzzle.targetColor, similarityFactor) ?? Colors.white;

    // Update similarity
    setState(() {
      _similarity = similarityFactor;
    });

    // Update mixed color for puzzle completion
    widget.onColorMixed(resultColor);

    // Show the game result dialog
    Future.delayed(const Duration(milliseconds: 500), () {
      _showGameResultDialog(isSuccess);
    });
  }

  void _showGameResultDialog(bool isSuccess) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(isSuccess ? 'Level Complete!' : 'Time\'s Up!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score: $_score'),
            const SizedBox(height: 8),
            Text('Matches: $_correctMatches'),
            const SizedBox(height: 8),
            Text('Mistakes: $_mistakes'),
            const SizedBox(height: 16),
            Text(
              'Color Memory Rating: ${(_similarity * 100).round()}%',
              style: TextStyle(
                color: _getSimilarityColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You\'ve enhanced your color recognition and memory skills!',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restartGame();
            },
            child: const Text('Play Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _restartGame() {
    // Reset the game
    setState(() {
      _currentLevel++;
      _selectedCards = [];
      _matchedCards = [];
      _colorSequence = [];
      _sequenceIndex = 0;
      _moves = 0;
      _correctMatches = 0;
      _mistakes = 0;
      _revealedCount = 0;
      _gameState = GameState.notStarted;
    });

    // Create a new game board
    _createGameBoard();

    // Start the game again
    _startGame();
  }

  double _calculateColorSimilarity(Color a, Color b) {
    // Calculate color similarity (normalized between 0 and 1)
    final dr = (a.red - b.red) / 255.0;
    final dg = (a.green - b.green) / 255.0;
    final db = (a.blue - b.blue) / 255.0;

    // Human eyes are more sensitive to green, less to blue
    final distance = (dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11);
    return (1.0 - sqrt(distance)).clamp(0.0, 1.0);
  }

  Color _getSimilarityColor() {
    if (_similarity >= widget.puzzle.accuracyThreshold) {
      return Colors.green;
    } else if (_similarity >= 0.8) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  void dispose() {
    // Cancel timers
    _gameTimer?.cancel();
    _sequenceTimer?.cancel();

    // Dispose animation controllers
    _boardAnimationController.dispose();
    _cardFlipController.dispose();
    _feedbackAnimationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Game header with status
        _buildGameHeader(),

        const SizedBox(height: 8),

        // Game board
        Expanded(
          child: _buildGameBoard(),
        ),

        // Game controls
        _buildGameControls(),
      ],
    );
  }

  Widget _buildGameHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Game stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Score
              Row(
                children: [
                  Icon(
                    Icons.score,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Score: $_score',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Time if applicable
              if (_gameState == GameState.playing && _remainingTime > 0)
                Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: _remainingTime < 10 ? Colors.red : Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_remainingTime s',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _remainingTime < 10 ? Colors.red : null,
                      ),
                    ),
                  ],
                )
              else if (_gameMode == GameMode.colorSequence && _isShowingSequence)
                const Text(
                  'Memorize the sequence!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),

              // Matches/Pairs
              if (_gameMode != GameMode.colorSequence)
                Row(
                  children: [
                    Icon(
                      Icons.grid_view,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pairs: ${_correctMatches}/${_correctMatches + _remainingPairs}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sequence: ${_revealedCount}/${_colorSequence.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Target color display for sequence mode
          if (_gameMode == GameMode.colorSequence && (_gameState == GameState.playing || _isShowingSequence))
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Find this color: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _targetColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _targetColor.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGameBoard() {
    // Calculate grid dimensions
    int gridSize = sqrt(_cards.length).ceil();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AnimatedBuilder(
        animation: _boardAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _boardAnimation.value,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _gameState == GameState.notStarted
                      ? _buildStartGamePrompt()
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridSize,
                            childAspectRatio: 1.0,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                          itemCount: _cards.length,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, index) {
                            return _buildCard(_cards[index]);
                          },
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStartGamePrompt() {
    String gameModeDescription;
    IconData gameModeIcon;

    switch (_gameMode) {
      case GameMode.colorMatching:
        gameModeDescription = 'Find matching color pairs';
        gameModeIcon = Icons.palette;
        break;
      case GameMode.colorSequence:
        gameModeDescription = 'Memorize and repeat color sequences';
        gameModeIcon = Icons.repeat;
        break;
      case GameMode.colorRelationships:
        gameModeDescription = 'Find related color pairs';
        gameModeIcon = Icons.compare_arrows;
        break;
      case GameMode.mixedMode:
        gameModeDescription = 'Mixed color challenges';
        gameModeIcon = Icons.auto_awesome;
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            gameModeIcon,
            size: 60,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            _gameMode.toString().split('.').last,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            gameModeDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _startGame,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Game'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(MemoryCard card) {
    final isFlipped = card.isFlipped || card.isMatched;

    return AnimatedBuilder(
      animation: _cardFlipController,
      builder: (context, child) {
        // Calculate rotation for the flip animation
        double flipValue = 0.0;
        if (_cardFlipAnimation != null && _selectedCards.contains(card)) {
          flipValue = _cardFlipAnimation!.value;
        } else if (isFlipped) {
          flipValue = 1.0;
        }

        return GestureDetector(
          onTap: () => _onCardTap(card),
          child: AnimatedScale(
            scale: card.isMatched ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // Perspective
                ..rotateY(flipValue * pi),
              alignment: Alignment.center,
              child: flipValue < 0.5
                  ? _buildCardBack(card)
                  : Transform(
                      transform: Matrix4.identity()..rotateY(pi),
                      alignment: Alignment.center,
                      child: _buildCardFront(card),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardBack(MemoryCard card) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.question_mark,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildCardFront(MemoryCard card) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: card.color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: card.isMatched
            ? Border.all(
                color: Colors.white,
                width: 2,
              )
            : null,
      ),
      child: Center(
        child: card.isMatched
            ? const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 24,
              )
            : null,
      ),
    );
  }

  Widget _buildGameControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _feedbackAnimation,
        builder: (context, child) {
          final scale = _feedbackAnimationController.isAnimating ? 1.0 + (_feedbackAnimation.value * 0.1) : 1.0;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Color preview
              if (_gameState == GameState.playing || _gameState == GameState.success || _gameState == GameState.failed)
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _targetColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _targetColor.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(width: 16),

              // Game instructions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getGameModeTitle(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      _getGameModeInstruction(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Restart button if game is in progress or complete
              if (_gameState == GameState.playing || _gameState == GameState.success || _gameState == GameState.failed)
                TextButton.icon(
                  onPressed: _restartGame,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Restart'),
                ),
            ],
          );
        },
      ),
    );
  }

  String _getGameModeTitle() {
    switch (_gameState) {
      case GameState.notStarted:
        return 'Get Ready to Play!';
      case GameState.playing:
        switch (_gameMode) {
          case GameMode.colorMatching:
            return 'Find Matching Pairs';
          case GameMode.colorSequence:
            return 'Remember the Sequence';
          case GameMode.colorRelationships:
            return 'Match Related Colors';
          case GameMode.mixedMode:
            return 'Color Challenge';
        }
      case GameState.success:
        return 'Great Job!';
      case GameState.failed:
        return 'Time\'s Up!';
    }
  }

  String _getGameModeInstruction() {
    switch (_gameState) {
      case GameState.notStarted:
        return 'Press Start Game to begin the challenge';
      case GameState.playing:
        switch (_gameMode) {
          case GameMode.colorMatching:
            return 'Tap cards to find matching color pairs';
          case GameMode.colorSequence:
            return 'Tap the colors in the same order they were shown';
          case GameMode.colorRelationships:
            return 'Find pairs of colors that have a relationship';
          case GameMode.mixedMode:
            return 'Complete the current color challenge';
        }
      case GameState.success:
        return 'You completed the challenge! Great color memory.';
      case GameState.failed:
        return 'You ran out of time. Try again!';
    }
  }
}

// Enums for game state
enum GameState {
  notStarted,
  playing,
  success,
  failed,
}

// Enums for game modes
enum GameMode {
  colorMatching,
  colorSequence,
  colorRelationships,
  mixedMode,
}

// Enums for card types
enum CardType {
  color,
  relatedColor,
}

// Enums for color relationships
enum RelationshipType {
  complementary,
  analogous,
  monochromatic,
}

// Class to represent a memory card
class MemoryCard {
  final int id;
  final Color color;
  bool isFlipped;
  bool isMatched;
  final int pairId;
  final CardType type;
  int gridX = 0;
  int gridY = 0;
  RelationshipType? relationshipType;
  String? relationshipName;

  MemoryCard({
    required this.id,
    required this.color,
    required this.isFlipped,
    required this.isMatched,
    required this.pairId,
    required this.type,
    this.relationshipType,
    this.relationshipName,
  });
}
