import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_master/core/color_models/color_mixer.dart';
import 'package:palette_master/features/puzzles/models/puzzle.dart';
import 'package:vibration/vibration.dart';

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
  bool _isLocked = false;
  bool _showingSequence = false;
  int _currentLevel = 1;
  bool _levelCompleted = false;

  // Animation controllers
  late AnimationController _flipController;
  late AnimationController _shakeController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _sequenceController;
  late Animation<double> _shakeAnimation;

  // Game mode
  late GameMode _gameMode;

  // Sequence for memory mode
  List<int> _sequence = [];
  int _sequenceStep = 0;
  bool _isPlayerTurn = false;

  // Timer for sequence display
  late AnimationController _timerController;

  // Physical properties for cards
  final double _cardDepth = 8.0;

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

    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        if (_timerController.isCompleted && _isPlayerTurn) {
          _handleTimeOut();
        }
      });

    // Determine game mode based on level
    _determineGameMode();

    // Initialize game
    _initializeGame();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _shakeController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _sequenceController.dispose();
    _timerController.dispose();
    super.dispose();
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
    _cards = _cards.where((card) => !card.isMix).toList();

    // Shuffle the cards
    _cards.shuffle(Random());
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
    if (_isLocked || _cards[index].isFlipped || _cards[index].isMatched || _showingSequence) {
      return;
    }

    // Haptic feedback
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator ?? false) {
        Vibration.vibrate(duration: 20, amplitude: 40);
      }
    });

    setState(() {
      // Flip the card
      _cards[index].isFlipped = true;
      _selectedIndices.add(index);

      // Update selected color for parent
      widget.onColorSelected(_cards[index].frontColor);
    });

    // Play flip sound
    // _playSound('card_flip.mp3');

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

        // Update score
        _score += 100 * _currentLevel;
        widget.onScoreUpdate(_score);

        // Play match sound
        // _playSound('match.mp3');

        // Provide haptic feedback
        Vibration.hasVibrator().then((hasVibrator) {
          if (hasVibrator ?? false) {
            Vibration.vibrate(duration: 100, amplitude: 128);
          }
        });

        // Check for level completion
        if (_matchedPairs == _cards.length ~/ 2) {
          _levelCompleted = true;
          // Schedule level completion after showing the match
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleLevelComplete();
          });
        }
      } else {
        // Flip cards back
        _cards[index1].isFlipped = false;
        _cards[index2].isFlipped = false;

        // Play mismatch sound
        // _playSound('mismatch.mp3');

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

        // Check if sequence is complete
        if (_sequenceStep >= _sequence.length) {
          // Sequence complete!
          _score += 150 * _currentLevel;
          widget.onScoreUpdate(_score);

          // Provide success feedback
          Vibration.hasVibrator().then((hasVibrator) {
            if (hasVibrator ?? false) {
              Vibration.vibrate(duration: 200, amplitude: 200);
            }
          });

          // Level complete
          _levelCompleted = true;
          Future.delayed(const Duration(milliseconds: 800), () {
            _handleLevelComplete();
          });
        }
      } else {
        // Wrong sequence step
        _shakeController.reset();
        _shakeController.forward();

        // Penalty
        _score = max(0, _score - 30);
        widget.onScoreUpdate(_score);

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

      // Start timer for player's turn
      _timerController.reset();
      _timerController.forward();
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
    // _playSound('sequence_tone.mp3');

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

      // Penalty
      _score = max(0, _score - 50);
      widget.onScoreUpdate(_score);
    });

    // Play timeout sound
    // _playSound('timeout.mp3');

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

        // Update score
        _score += 120 * _currentLevel;
        widget.onScoreUpdate(_score);

        // Provide haptic feedback
        Vibration.hasVibrator().then((hasVibrator) {
          if (hasVibrator ?? false) {
            Vibration.vibrate(duration: 100, amplitude: 128);
          }
        });

        // Check for level completion
        if (_matchedPairs == _cards.length ~/ 2) {
          _levelCompleted = true;
          // Schedule level completion after showing the match
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleLevelComplete();
          });
        }
      } else {
        // Flip cards back
        _cards[index1].isFlipped = false;
        _cards[index2].isFlipped = false;

        // Shake animation
        _shakeController.reset();
        _shakeController.forward();

        // Penalty for wrong match
        _score = max(0, _score - 15);
        widget.onScoreUpdate(_score);
      }

      _selectedIndices.clear();
      _isLocked = false;
    });
  }

  void _handleLevelComplete() {
    // Animate card celebration
    _rotationController.reset();
    _rotationController.forward();

    // Notify parent
    widget.onLevelComplete();
  }

  void _resetGame() {
    setState(() {
      _selectedIndices.clear();
      _matchedPairs = 0;
      _moves = 0;
      _isLocked = false;
      _levelCompleted = false;

      // Reset all cards
      for (final card in _cards) {
        card.isFlipped = false;
        card.isMatched = false;
        card.isHighlighted = false;
      }
    });

    // Shuffle cards
    setState(() {
      _cards.shuffle(Random());
    });

    // Start with intro animation
    _scaleController.reset();
    _scaleController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final gridSize = _getGridSize();
    final hasSequence = _gameMode == GameMode.sequenceMemory;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Game stats and info
        _buildGameInfo(),

        const SizedBox(height: 16),

        // Card grid
        Expanded(
          child: Center(
            child: AspectRatio(
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
                  child: GridView.builder(
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

        // Game instructions
        _buildInstructions(),
      ],
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Mode info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                _getModeIcon(),
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                modeName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Game stats (moves, pairs)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: _gameMode != GameMode.sequenceMemory
              ? Text(
                  'Moves: $_moves | Pairs: $_matchedPairs/${_cards.length ~/ 2}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Text(
                  'Sequence: ${_sequenceStep}/${_sequence.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
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
            final isBack = rotateAnimation.value > (pi / 2);
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // Perspective
                ..rotateY(rotateAnimation.value),
              alignment: Alignment.center,
              child: isBack
                  ? _buildCardFace(card.backColor, false, card.isMatched)
                  : _buildCardFace(card.frontColor, true, card.isMatched, card.isHighlighted),
            );
          },
        );
      },
      child: card.isFlipped
          ? _buildCardFace(card.frontColor, true, card.isMatched, card.isHighlighted)
          : _buildCardFace(card.backColor, false, card.isMatched),
    );
  }

  Widget _buildCardFace(Color color, bool isFront, bool isMatched, [bool isHighlighted = false]) {
    return Container(
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
  }

  Widget _buildInstructions() {
    String instruction = '';

    switch (_gameMode) {
      case GameMode.classicMatch:
        instruction = 'Find matching pairs of identical colors';
        break;
      case GameMode.complementaryMatch:
        instruction = 'Match each color with its complementary color';
        break;
      case GameMode.sequenceMemory:
        if (_showingSequence) {
          instruction = 'Watch the color sequence carefully...';
        } else if (_isPlayerTurn) {
          instruction = 'Now repeat the sequence in order!';
        } else {
          instruction = 'Remember the sequence of colors shown';
        }
        break;
      case GameMode.mixingMemory:
        instruction = 'Find the component colors that create each mix';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        instruction,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
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
  int? matchId; // For matching specific pairs (complementary or mixing)
  bool isMix; // Is this a mixed color card

  MemoryCard({
    required this.id,
    required this.frontColor,
    required this.backColor,
    required this.isFlipped,
    required this.isMatched,
    this.isHighlighted = false,
    this.matchId,
    this.isMix = false,
  });
}
