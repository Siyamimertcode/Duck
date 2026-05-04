import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import '../../services/word_service.dart';
import '../../services/user_preferences.dart';
import '../../services/tts_service.dart';
import '../../services/sound_service.dart';
import '../../services/duck_theme.dart';
import '../../services/app_localizations.dart';

class TrueFalseGameScreen extends StatefulWidget {
  const TrueFalseGameScreen({super.key});

  @override
  State<TrueFalseGameScreen> createState() => _TrueFalseGameScreenState();
}

class _TrueFalseGameScreenState extends State<TrueFalseGameScreen>
    with TickerProviderStateMixin {
  // Brand Colors — dynamic from theme
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
  int _currentIndex = 0;
  int _score = 0;
  int _correctAnswers = 0; // Track correct answers for percentage
  int _streak = 0;
  int _bestStreak = 0;
  int _totalQuestions = 0;
  bool _isLoading = true;
  bool _gameOver = false;
  bool _showingFeedback = false;
  bool? _lastAnswerCorrect;
  String _userLevel = 'A1';
  late List<bool> _questionAnswers =
      []; // Pre-generated random answers (true/false)

  // Timer
  int _remainingSeconds = 60; // 60 seconds per game
  Timer? _gameTimer;

  // Current question
  WordItem? _currentWord;
  String _displayedTranslation = '';
  bool _isCorrectTranslation = false;

  // Animation controllers
  late AnimationController _cardAnimationController;
  late AnimationController _feedbackAnimationController;
  late AnimationController _scoreAnimationController;
  late Animation<double> _cardScaleAnimation;
  late Animation<double> _feedbackOpacityAnimation;
  late Animation<double> _scoreScaleAnimation;

  // Confetti
  late ConfettiController _confettiController;
  final TtsService _tts = TtsService();

  // Timer
  Timer? _feedbackTimer;

  // Random
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
    _cardScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _feedbackAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _feedbackOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _feedbackAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _scoreAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scoreScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _scoreAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 800),
    );
  }

  Future<void> _loadGameData() async {
    // Get user's English level
    final level = await UserPreferences.getEnglishLevel();
    _userLevel = level ?? 'A1';

    // Load words for the level
    final words = await WordService.getWordsForLevel(_userLevel);

    if (words.isEmpty) {
      // Fallback to A1 if no words found
      final fallbackWords = await WordService.getWordsForLevel('A1');
      _words = fallbackWords;
    } else {
      _words = words;
    }

    // Shuffle words
    _words.shuffle();

    setState(() {
      _isLoading = false;
      _totalQuestions = min(20, _words.length); // 20 questions per game
    });

    // Generate randomized true/false answers with 45-55% ratio
    _generateRandomizedAnswers(_totalQuestions);

    _generateQuestion();
    _cardAnimationController.forward();
    _startTimer();
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _endGame();
      }
    });
  }

  void _generateRandomizedAnswers(int count) {
    // Generate random true/false sequence with 45-55% ratio
    // This ensures variety - not alternating pattern
    _questionAnswers = [];

    // Calculate target counts to maintain 45-55% ratio
    int trueCount = (count * 0.45).ceil(); // Could be 45% or less
    int falseCount = count - trueCount;

    // Alternative: randomize which one is more frequent
    if (_random.nextBool()) {
      // Swap to get 55% true or 45% true
      final temp = trueCount;
      trueCount = falseCount;
      falseCount = temp;
    }

    // Create list with desired ratio
    _questionAnswers = [
      ...List.filled(trueCount, true),
      ...List.filled(falseCount, false),
    ];

    // Shuffle to randomize order (not alternating)
    _questionAnswers.shuffle(_random);
  }

  void _generateQuestion() {
    if (_currentIndex >= _totalQuestions || _words.isEmpty) {
      _endGame();
      return;
    }

    _currentWord = _words[_currentIndex];

    // Use pre-generated random answers for variety (not alternating)
    _isCorrectTranslation = _questionAnswers[_currentIndex];

    if (_isCorrectTranslation) {
      _displayedTranslation = _currentWord!.turkish;
    } else {
      // Get a random wrong translation
      final wrongTranslations = WordService.getWrongTranslations(
        _currentWord!,
        _words,
        1,
      );
      if (wrongTranslations.isNotEmpty) {
        _displayedTranslation = wrongTranslations.first;
      } else {
        // Fallback - show correct
        _displayedTranslation = _currentWord!.turkish;
        _isCorrectTranslation = true;
      }
    }

    // Auto-speak the English word
    if (_currentWord != null) {
      _tts.speakEnglish(_currentWord!.english);
    }

    setState(() {});
  }

  void _handleAnswer(bool userSaidTrue) {
    if (_showingFeedback || _gameOver) return;

    HapticFeedback.lightImpact();

    // Check if answer is correct
    final isCorrect = userSaidTrue == _isCorrectTranslation;

    setState(() {
      _showingFeedback = true;
      _lastAnswerCorrect = isCorrect;
    });

    _feedbackAnimationController.forward();

    if (isCorrect) {
      _score += 5; // Fixed 5 points per correct answer
      _correctAnswers++; // Track correct answers
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
      _scoreAnimationController.forward().then((_) {
        _scoreAnimationController.reverse();
      });

      // Confetti for streaks of 3+
      if (_streak >= 3 && _streak % 3 == 0) {
        _confettiController.play();
        SoundService().playStreak();
      } else {
        SoundService().playCorrect();
      }
    } else {
      _streak = 0;
      HapticFeedback.heavyImpact();
      SoundService().playWrong();
    }

    // Move to next question after delay
    _feedbackTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      _feedbackAnimationController.reverse();
      _cardAnimationController.reverse().then((_) {
        setState(() {
          _currentIndex++;
          _showingFeedback = false;
          _lastAnswerCorrect = null;
        });
        _generateQuestion();
        _cardAnimationController.forward();
      });
    });
  }

  void _endGame() {
    setState(() {
      _gameOver = true;
    });

    final percentage = _totalQuestions > 0
        ? ((_correctAnswers / _totalQuestions) * 100).round()
        : 0;

    // Play confetti for good scores
    if (_score >= 100) {
      _confettiController.play();
    }

    // Play sound effect based on performance
    if (percentage >= 80) {
      // Excellent performance: play success/celebration sound
      SoundService().playComplete();
    } else if (percentage >= 50) {
      // Good/fair performance: play encouraging sound
      SoundService().playLevelUp();
    } else {
      // Poor performance: play discouraging sound
      SoundService().playWrong();
    }

    // Save high score if needed
    _saveGameStats();
  }

  Future<void> _saveGameStats() async {
    // Record game played
    await UserPreferences.recordGamePlayed();

    // Award XP based on performance
    final percentage = _totalQuestions > 0
        ? ((_correctAnswers / _totalQuestions) * 100).round()
        : 0;
    int xpReward = 5; // Base XP
    if (percentage >= 80) {
      xpReward = 25;
    } else if (percentage >= 60)
      xpReward = 15;
    else if (percentage >= 40)
      xpReward = 10;
    await UserPreferences.addXP(xpReward);

    // Track error-free game
    if (_correctAnswers == _totalQuestions && _totalQuestions > 0) {
      await UserPreferences.recordErrorFreeTask();
    }

    // Track correct/wrong answers for streak quests
    for (int i = 0; i < _correctAnswers; i++) {
      await UserPreferences.recordCorrectAnswer();
    }
    if (_correctAnswers < _totalQuestions) {
      await UserPreferences.recordWrongAnswer();
    }
  }

  void _restartGame() {
    _feedbackTimer?.cancel();
    _gameTimer?.cancel();

    setState(() {
      _currentIndex = 0;
      _score = 0;
      _correctAnswers = 0;
      _streak = 0;
      _remainingSeconds = 60;
      _gameOver = false;
      _showingFeedback = false;
      _lastAnswerCorrect = null;
    });

    // Reshuffle words
    _words.shuffle();

    // Generate new randomized answers
    _generateRandomizedAnswers(_totalQuestions);

    _generateQuestion();
    _cardAnimationController.forward();
    _startTimer();
  }

  @override
  void dispose() {
    _tts.stop();
    _cardAnimationController.dispose();
    _feedbackAnimationController.dispose();
    _scoreAnimationController.dispose();
    _confettiController.dispose();
    _feedbackTimer?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Stack(
          children: [
            // Background decorations
            _buildBackgroundDecorations(),

            // Main content
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
          // Back button
          _buildIconButton(
            icon: Icons.close_rounded,
            onTap: () => _showExitDialog(),
          ),
          const SizedBox(width: 12),

          // Progress bar and info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      S.get(
                        'tf_question_n',
                        args: {
                          'n': '${_currentIndex + 1}',
                          'total': '$_totalQuestions',
                        },
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: darkGreen.withOpacity(0.6),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _remainingSeconds <= 10
                            ? wrongRed.withOpacity(0.15)
                            : darkGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            size: 12,
                            color: _remainingSeconds <= 10
                                ? wrongRed
                                : darkGreen,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${_remainingSeconds}s',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _remainingSeconds <= 10
                                  ? wrongRed
                                  : darkGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _userLevel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _totalQuestions > 0
                        ? (_currentIndex + 1) / _totalQuestions
                        : 0,
                    backgroundColor: darkGreen.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(darkGreen),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  S.get('tf_points_info'),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: orange.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Score
          ScaleTransition(
            scale: _scoreScaleAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [orange, lightOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: orange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$_score',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
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
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Icon(icon, color: darkGreen, size: 22),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _c.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(darkGreen),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            S.get('tf_loading'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: darkGreen.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent() {
    return Column(
      children: [
        // Streak indicator
        if (_streak >= 2) _buildStreakIndicator(),

        const Spacer(flex: 1),

        // Word card
        ScaleTransition(scale: _cardScaleAnimation, child: _buildWordCard()),

        const Spacer(flex: 1),

        // Feedback overlay (shown after answer)
        if (_showingFeedback)
          FadeTransition(
            opacity: _feedbackOpacityAnimation,
            child: _buildFeedbackOverlay(),
          ),

        // Instructions
        if (!_showingFeedback)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              S.get('tf_is_correct'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: darkGreen.withOpacity(0.7),
              ),
            ),
          ),

        const Spacer(flex: 1),

        // Answer buttons
        _buildAnswerButtons(),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStreakIndicator() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [correctGreen, lightGreen]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: correctGreen.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            S.get('tf_streak', args: {'n': '$_streak'}),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _c.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: darkGreen.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: darkGreen.withOpacity(0.08), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // English word
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [darkGreen, lightGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🇬🇧', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (_currentWord != null) {
                            _tts.speakEnglish(_currentWord!.english);
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _currentWord?.english ?? '',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Equals sign
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.swap_vert_rounded, color: orange, size: 28),
          ),

          const SizedBox(height: 20),

          // Turkish translation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: cream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: darkGreen.withOpacity(0.15), width: 2),
            ),
            child: Column(
              children: [
                const Text('🇹🇷', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  _displayedTranslation,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: darkGreen,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackOverlay() {
    final isCorrect = _lastAnswerCorrect ?? false;
    final color = isCorrect ? correctGreen : wrongRed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isCorrect ? S.get('tf_correct_msg') : S.get('tf_wrong_msg'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (!isCorrect)
                Text(
                  S.get(
                    'tf_correct_answer',
                    args: {'answer': _currentWord?.turkish ?? ''},
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color.withOpacity(0.8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // TRUE button (Left - Green)
          Expanded(
            child: _buildAnswerButton(
              label: S.get('tf_true'),
              icon: Icons.check_rounded,
              color: correctGreen,
              onPressed: () => _handleAnswer(true),
            ),
          ),
          const SizedBox(width: 16),
          // FALSE button (Right - Red)
          Expanded(
            child: _buildAnswerButton(
              label: S.get('tf_false'),
              icon: Icons.close_rounded,
              color: wrongRed,
              onPressed: () => _handleAnswer(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final isDisabled = _showingFeedback;

    return GestureDetector(
      onTap: isDisabled ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: isDisabled
              ? LinearGradient(
                  colors: [Colors.grey.shade300, Colors.grey.shade400],
                )
              : LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    // Calculate success percentage based on correct answers
    final percentage = _totalQuestions > 0
        ? ((_correctAnswers / _totalQuestions) * 100).round().clamp(0, 100)
        : 0;

    String message;
    String emoji;
    if (percentage >= 80) {
      message = S.get('tf_perfect');
      emoji = '🏆';
    } else if (percentage >= 60) {
      message = S.get('tf_great');
      emoji = '⭐';
    } else if (percentage >= 40) {
      message = S.get('tf_good');
      emoji = '👍';
    } else {
      message = S.get('tf_practice');
      emoji = '💪';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Trophy/Result icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [orange, lightOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: orange.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 60)),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            message,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: darkGreen,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            S.get('tf_game_over'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: darkGreen.withOpacity(0.6),
            ),
          ),

          const SizedBox(height: 32),

          // Stats cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  S.get('tf_score'),
                  '$_score',
                  Icons.star_rounded,
                  orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  S.get('tf_best_streak'),
                  '$_bestStreak',
                  Icons.local_fire_department_rounded,
                  correctGreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  S.get('tf_level'),
                  _userLevel,
                  Icons.school_rounded,
                  lightGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  S.get('tf_success'),
                  '$percentage%',
                  Icons.percent_rounded,
                  darkGreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Play again button
          GestureDetector(
            onTap: _restartGame,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [darkGreen, lightGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: darkGreen.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.replay_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    S.get('play_again'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Back to home button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: _c.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: darkGreen.withOpacity(0.2), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: darkGreen.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_rounded, color: darkGreen, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    S.get('main_menu'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: darkGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: darkGreen.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: wrongRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.exit_to_app_rounded, color: wrongRed, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              S.get('tf_exit_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
          ],
        ),
        content: Text(
          S.get('tf_exit_msg'),
          style: TextStyle(fontSize: 15, color: darkGreen.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              S.get('continue_playing'),
              style: TextStyle(
                color: darkGreen.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit game
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: wrongRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(S.get('exit_btn')),
          ),
        ],
      ),
    );
  }
}
