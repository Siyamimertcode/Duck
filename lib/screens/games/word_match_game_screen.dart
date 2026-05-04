import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import '../../services/word_service.dart';
import '../../services/user_preferences.dart';
import '../../services/duck_theme.dart';
import '../../services/sound_service.dart';
import '../../services/app_localizations.dart';

class WordMatchGameScreen extends StatefulWidget {
  const WordMatchGameScreen({super.key});

  @override
  State<WordMatchGameScreen> createState() => _WordMatchGameScreenState();
}

class _WordMatchGameScreenState extends State<WordMatchGameScreen>
    with TickerProviderStateMixin {
  // Brand Colors (dynamic theming)
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get lightGreen => _c.lightGreen;
  Color get orange => _c.orange;
  Color get lightOrange => _c.lightOrange;
  Color get cream => _c.cream;
  Color get correctGreen => _c.correctGreen;
  Color get wrongRed => _c.wrongRed;

  // Game state
  List<WordItem> _words = [];
  List<WordItem> _gameWords = []; // 8 words for the game
  List<String> _englishCards = [];
  List<String> _turkishCards = [];
  List<bool> _englishRevealed = [];
  List<bool> _turkishRevealed = [];
  List<bool> _englishMatched = [];
  List<bool> _turkishMatched = [];

  int? _selectedEnglishIndex;
  int? _selectedTurkishIndex;

  bool _isLoading = true;
  bool _gameOver = false;
  bool _isPreviewPhase = true;
  bool _showCountdownOnly = false;
  bool _isProcessing = false;
  String _userLevel = 'A1';

  // Stats
  int _score = 0;
  int _correctMatches = 0;
  int _wrongMatches = 0;
  int _elapsedSeconds = 0;
  Timer? _gameTimer;

  // Preview countdown
  int _previewCountdown = 5;
  Timer? _previewTimer;

  // Animation controllers
  late AnimationController _cardAnimationController;
  late ConfettiController _confettiController;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadGameData();
  }

  void _initAnimations() {
    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 800),
    );
  }

  Future<void> _loadGameData() async {
    final level = await UserPreferences.getEnglishLevel();
    _userLevel = level ?? 'A1';

    final words = await WordService.getWordsForLevel(_userLevel);

    if (words.isEmpty) {
      final fallbackWords = await WordService.getWordsForLevel('A1');
      _words = fallbackWords;
    } else {
      _words = words;
    }

    _words.shuffle();
    _setupGame();

    setState(() {
      _isLoading = false;
    });

    _startPreviewPhase();
  }

  void _setupGame() {
    // Select 8 unique words
    _gameWords = _words.take(8).toList();

    // Create card lists
    _englishCards = _gameWords.map((w) => w.english).toList();
    _turkishCards = _gameWords.map((w) => w.turkish).toList();

    // Shuffle both lists independently
    _englishCards.shuffle(_random);
    _turkishCards.shuffle(_random);

    // Initialize reveal and match states
    _englishRevealed = List.filled(8, true); // Start revealed for preview
    _turkishRevealed = List.filled(8, true);
    _englishMatched = List.filled(8, false);
    _turkishMatched = List.filled(8, false);

    _selectedEnglishIndex = null;
    _selectedTurkishIndex = null;
  }

  void _startPreviewPhase() {
    // First phase: Show big box for 1 second
    _previewTimer = Timer(const Duration(seconds: 1), () {
      // Transition to countdown-only phase
      setState(() {
        _showCountdownOnly = true;
      });
      _startCountdownPhase();
    });
  }

  void _startCountdownPhase() {
    _previewCountdown = 5;
    _previewTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_previewCountdown > 1) {
        setState(() {
          _previewCountdown--;
        });
      } else {
        timer.cancel();
        _endPreviewPhase();
      }
    });
  }

  void _endPreviewPhase() {
    setState(() {
      _isPreviewPhase = false;
      _showCountdownOnly = false;
      // Hide all cards
      _englishRevealed = List.filled(8, false);
      _turkishRevealed = List.filled(8, false);
    });
    _startGameTimer();
  }

  void _startGameTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_gameOver) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _onEnglishCardTap(int index) {
    if (_isPreviewPhase || _isProcessing || _englishMatched[index]) return;

    HapticFeedback.lightImpact();

    setState(() {
      // If already selected, deselect
      if (_selectedEnglishIndex == index) {
        _selectedEnglishIndex = null;
        _englishRevealed[index] = false;
      } else {
        // Deselect previous English card if any
        if (_selectedEnglishIndex != null) {
          _englishRevealed[_selectedEnglishIndex!] = false;
        }
        _selectedEnglishIndex = index;
        _englishRevealed[index] = true;
      }
    });

    _checkMatch();
  }

  void _onTurkishCardTap(int index) {
    if (_isPreviewPhase || _isProcessing || _turkishMatched[index]) return;

    HapticFeedback.lightImpact();

    setState(() {
      // If already selected, deselect
      if (_selectedTurkishIndex == index) {
        _selectedTurkishIndex = null;
        _turkishRevealed[index] = false;
      } else {
        // Deselect previous Turkish card if any
        if (_selectedTurkishIndex != null) {
          _turkishRevealed[_selectedTurkishIndex!] = false;
        }
        _selectedTurkishIndex = index;
        _turkishRevealed[index] = true;
      }
    });

    _checkMatch();
  }

  void _checkMatch() {
    if (_selectedEnglishIndex == null || _selectedTurkishIndex == null) return;

    _isProcessing = true;

    final englishWord = _englishCards[_selectedEnglishIndex!];
    final turkishWord = _turkishCards[_selectedTurkishIndex!];

    // Find the original word to check match
    final matchingWord = _gameWords.firstWhere((w) => w.english == englishWord);

    final isCorrect = matchingWord.turkish == turkishWord;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      setState(() {
        if (isCorrect) {
          // Mark as matched
          _englishMatched[_selectedEnglishIndex!] = true;
          _turkishMatched[_selectedTurkishIndex!] = true;
          _correctMatches++;
          _score += _calculatePoints();

          HapticFeedback.mediumImpact();
          SoundService().playMatch();

          // Check if game is over
          if (_correctMatches == 8) {
            _endGame();
          }
        } else {
          // Wrong match - hide cards
          _englishRevealed[_selectedEnglishIndex!] = false;
          _turkishRevealed[_selectedTurkishIndex!] = false;
          _wrongMatches++;

          HapticFeedback.heavyImpact();
          SoundService().playWrong();
        }

        _selectedEnglishIndex = null;
        _selectedTurkishIndex = null;
        _isProcessing = false;
      });
    });
  }

  int _calculatePoints() {
    // Base points + time bonus
    int basePoints = 10;
    int timeBonus = max(0, 5 - (_elapsedSeconds ~/ 10));
    return basePoints + timeBonus;
  }

  void _endGame() {
    _gameTimer?.cancel();
    setState(() {
      _gameOver = true;
    });

    if (_correctMatches == 8 && _wrongMatches <= 2) {
      _confettiController.play();
    }

    _saveGameProgress();
  }

  Future<void> _saveGameProgress() async {
    // Record game played
    await UserPreferences.recordGamePlayed();

    // Award XP based on performance
    int xpReward = 5; // Base XP
    if (_wrongMatches == 0)
      xpReward = 25;
    else if (_wrongMatches <= 2)
      xpReward = 15;
    else if (_wrongMatches <= 4)
      xpReward = 10;
    await UserPreferences.addXP(xpReward);

    // Track error-free game
    if (_wrongMatches == 0) {
      await UserPreferences.recordErrorFreeTask();
    }

    // Track words learned
    await UserPreferences.recordWordsLearned(count: _correctMatches);
  }

  void _restartGame() {
    _gameTimer?.cancel();
    _previewTimer?.cancel();

    setState(() {
      _score = 0;
      _correctMatches = 0;
      _wrongMatches = 0;
      _elapsedSeconds = 0;
      _gameOver = false;
      _isPreviewPhase = true;
      _isProcessing = false;
    });

    _words.shuffle();
    _setupGame();
    _startPreviewPhase();
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    _confettiController.dispose();
    _gameTimer?.cancel();
    _previewTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Stack(
          children: [
            _buildBackgroundDecorations(),
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _gameOver
                      ? _buildGameOverScreen()
                      : _buildGameContent(),
                ),
              ],
            ),
            // Confetti
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2,
                emissionFrequency: 0.05,
                numberOfParticles: 30,
                gravity: 0.2,
                shouldLoop: false,
                colors: [correctGreen, lightGreen, orange, lightOrange],
              ),
            ),
            // Preview overlay
            if (_isPreviewPhase && !_isLoading && !_showCountdownOnly)
              _buildPreviewOverlay(),
            // Countdown only overlay
            if (_showCountdownOnly && !_isLoading) _buildCountdownOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  lightGreen.withOpacity(0.1),
                  lightGreen.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          left: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [orange.withOpacity(0.08), orange.withOpacity(0.0)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cream,
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildIconButton(
            icon: Icons.close_rounded,
            onTap: () => _showExitDialog(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.get('wm_title'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStatChip(
                      Icons.check_circle_outline,
                      '$_correctMatches/8',
                      correctGreen,
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      Icons.cancel_outlined,
                      '$_wrongMatches',
                      wrongRed,
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      Icons.timer_outlined,
                      _formatTime(_elapsedSeconds),
                      orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.star_rounded, color: orange, size: 18),
                const SizedBox(width: 4),
                Text(
                  '$_score',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _c.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: darkGreen.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: darkGreen, size: 22),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: lightGreen),
          const SizedBox(height: 16),
          Text(
            S.get('wm_loading'),
            style: TextStyle(color: darkGreen.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(
              parent: AlwaysStoppedAnimation(1.0),
              curve: Curves.elasticOut,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: _c.cardColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.memory_rounded, color: orange, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  S.get('wm_memorize'),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  S.get('wm_study_cards'),
                  style: TextStyle(
                    fontSize: 14,
                    color: darkGreen.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.2),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 50),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: Tween<double>(begin: 0.5, end: 1.2).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.elasticOut,
                      ),
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Container(
                  key: ValueKey(_previewCountdown),
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [orange.withOpacity(0.95), orange],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: orange.withOpacity(0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$_previewCountdown',
                      style: const TextStyle(
                        fontSize: 63,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _previewCountdown == 1
                    ? S.get('wm_ready')
                    : S.get('wm_cards_closing'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // English cards label
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: darkGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text('🇬🇧', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        S.get('wm_english'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: darkGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // English cards grid (2x4)
          Expanded(
            child: _buildCardGrid(
              cards: _englishCards,
              revealed: _englishRevealed,
              matched: _englishMatched,
              selectedIndex: _selectedEnglishIndex,
              onTap: _onEnglishCardTap,
              isEnglish: true,
            ),
          ),

          const SizedBox(height: 8),

          // Divider
          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  darkGreen.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Turkish cards label
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text('🇹🇷', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        S.get('wm_turkish'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Turkish cards grid (2x4)
          Expanded(
            child: _buildCardGrid(
              cards: _turkishCards,
              revealed: _turkishRevealed,
              matched: _turkishMatched,
              selectedIndex: _selectedTurkishIndex,
              onTap: _onTurkishCardTap,
              isEnglish: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGrid({
    required List<String> cards,
    required List<bool> revealed,
    required List<bool> matched,
    required int? selectedIndex,
    required Function(int) onTap,
    required bool isEnglish,
  }) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return _buildCard(
          text: cards[index],
          isRevealed: revealed[index],
          isMatched: matched[index],
          isSelected: selectedIndex == index,
          onTap: () => onTap(index),
          isEnglish: isEnglish,
        );
      },
    );
  }

  Widget _buildCard({
    required String text,
    required bool isRevealed,
    required bool isMatched,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isEnglish,
  }) {
    final Color cardColor = isMatched
        ? correctGreen.withOpacity(0.2)
        : isSelected
        ? (isEnglish ? darkGreen : orange).withOpacity(0.15)
        : isRevealed
        ? (isEnglish ? darkGreen.withOpacity(0.05) : orange.withOpacity(0.05))
        : _c.cardColor;

    final Color borderColor = isMatched
        ? correctGreen
        : isSelected
        ? (isEnglish ? darkGreen : orange)
        : Colors.grey.withOpacity(0.2);

    return GestureDetector(
      onTap: isMatched ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isSelected || isMatched ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isEnglish ? darkGreen : orange).withOpacity(
                isSelected ? 0.15 : 0.05,
              ),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isRevealed || isMatched
                ? Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      text,
                      key: ValueKey('revealed_$text'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _calculateFontSize(text),
                        fontWeight: FontWeight.w600,
                        color: isMatched
                            ? correctGreen
                            : (isEnglish ? darkGreen : orange),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : Container(
                    key: const ValueKey('hidden'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isEnglish
                            ? [darkGreen, lightGreen]
                            : [orange, lightOrange],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.all(4),
                    child: Center(
                      child: Icon(
                        Icons.help_outline_rounded,
                        color: Colors.white.withOpacity(0.8),
                        size: 24,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  double _calculateFontSize(String text) {
    if (text.length <= 5) return 13;
    if (text.length <= 8) return 11;
    if (text.length <= 12) return 10;
    return 9;
  }

  Widget _buildGameOverScreen() {
    final accuracy = _correctMatches + _wrongMatches > 0
        ? ((_correctMatches / (_correctMatches + _wrongMatches)) * 100).round()
        : 0;

    String message;
    String emoji;
    if (_wrongMatches == 0) {
      message = S.get('wm_perfect');
      emoji = '🏆';
    } else if (_wrongMatches <= 2) {
      message = S.get('wm_great');
      emoji = '🌟';
    } else if (_wrongMatches <= 4) {
      message = S.get('wm_good');
      emoji = '👍';
    } else {
      message = S.get('wm_keep_going');
      emoji = '💪';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // Trophy/Emoji
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 50)),
            ),
          ),
          const SizedBox(height: 24),

          // Message
          Text(
            message,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.get('wm_game_complete'),
            style: TextStyle(fontSize: 16, color: darkGreen.withOpacity(0.7)),
          ),
          const SizedBox(height: 32),

          // Stats card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _c.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildStatRow(
                  Icons.star_rounded,
                  S.get('wm_total_score'),
                  '$_score',
                  orange,
                ),
                const Divider(height: 24),
                _buildStatRow(
                  Icons.timer_rounded,
                  S.get('wm_time'),
                  _formatTime(_elapsedSeconds),
                  lightGreen,
                ),
                const Divider(height: 24),
                _buildStatRow(
                  Icons.check_circle_rounded,
                  S.get('wm_correct_match'),
                  '$_correctMatches',
                  correctGreen,
                ),
                const Divider(height: 24),
                _buildStatRow(
                  Icons.cancel_rounded,
                  S.get('wm_wrong_attempt'),
                  '$_wrongMatches',
                  wrongRed,
                ),
                const Divider(height: 24),
                _buildStatRow(
                  Icons.percent_rounded,
                  S.get('wm_success_rate'),
                  '%$accuracy',
                  darkGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Buttons
          Row(
            children: [
              Expanded(
                child: _buildButton(
                  S.get('play_again'),
                  Icons.refresh_rounded,
                  lightGreen,
                  _restartGame,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildButton(
                  S.get('exit'),
                  Icons.home_rounded,
                  orange,
                  () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: darkGreen.withOpacity(0.7)),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: orange),
            const SizedBox(width: 8),
            Text(S.get('wm_exit_title')),
          ],
        ),
        content: Text(S.get('wm_exit_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.get('cancel'), style: TextStyle(color: darkGreen)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(S.get('exit'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
