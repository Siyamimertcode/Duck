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

class FastWordGameScreen extends StatefulWidget {
  const FastWordGameScreen({super.key});

  @override
  State<FastWordGameScreen> createState() => _FastWordGameScreenState();
}

class _FastWordGameScreenState extends State<FastWordGameScreen>
    with TickerProviderStateMixin {
  // Dynamic theme colors
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get lightGreen => _c.lightGreen;
  Color get orange => _c.orange;
  Color get lightOrange => _c.lightOrange;
  Color get cream => _c.cream;
  Color get correctGreen => _c.correctGreen;
  Color get wrongRed => _c.wrongRed;

  // Game state
  List<WordItem> _allWords = [];
  List<WordItem> _gameWords = [];
  WordItem? _currentWord;
  List<String> _options = [];
  String _userLevel = 'A1';
  bool _isLoading = true;
  bool _gameOver = false;

  // Progress
  int _currentRound = 0;
  final int _totalRounds = 10;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;

  // Timer (counts up from 0)
  int _elapsedSeconds = 0;
  Timer? _gameTimer;

  // Feedback
  bool _showingFeedback = false;
  String? _selectedAnswer;

  // Animations
  late AnimationController _cardAnimationController;
  late Animation<double> _cardScaleAnimation;
  late ConfettiController _confettiController;
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadGameData();
  }

  void _initAnimations() {
    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _cardScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.elasticOut,
      ),
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
      _allWords = await WordService.getWordsForLevel('A1');
    } else {
      _allWords = words;
    }

    _allWords.shuffle();
    _setupGame();

    setState(() {
      _isLoading = false;
    });

    _startTimer();
    _cardAnimationController.forward();
  }

  void _setupGame() {
    _gameWords = _allWords.take(_totalRounds).toList();
    _loadRound();
  }

  void _loadRound() {
    if (_currentRound >= _totalRounds) {
      _endGame();
      return;
    }

    _currentWord = _gameWords[_currentRound];
    _generateOptions();
    _cardAnimationController.forward(from: 0);

    // Auto-speak the English word
    if (_currentWord != null) {
      _tts.speakEnglish(_currentWord!.english);
    }
  }

  void _generateOptions() {
    _options = [_currentWord!.turkish];

    // Get 3 wrong options (total 4 options)
    final wrongOptions =
        _allWords.where((w) => w.turkish != _currentWord!.turkish).toList()
          ..shuffle();

    for (int i = 0; i < 3 && i < wrongOptions.length; i++) {
      _options.add(wrongOptions[i].turkish);
    }

    _options.shuffle();
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_gameOver) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _onOptionSelected(String option) {
    if (_showingFeedback || _gameOver) return;

    HapticFeedback.lightImpact();

    final isCorrect = option == _currentWord!.turkish;

    setState(() {
      _showingFeedback = true;
      _selectedAnswer = option;

      if (isCorrect) {
        _correctAnswers++;
      } else {
        _wrongAnswers++;
      }
    });

    if (isCorrect) {
      _confettiController.play();
      HapticFeedback.mediumImpact();
      SoundService().playCorrect();
    } else {
      HapticFeedback.heavyImpact();
      SoundService().playWrong();
    }

    // Next round after delay
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      setState(() {
        _showingFeedback = false;
        _selectedAnswer = null;
        _currentRound++;
      });

      _loadRound();
    });
  }

  void _endGame() {
    _gameTimer?.cancel();
    setState(() {
      _gameOver = true;
    });

    if (_correctAnswers >= _totalRounds * 0.7) {
      _confettiController.play();
    }

    _saveGameProgress();
  }

  Future<void> _saveGameProgress() async {
    // Record game played
    await UserPreferences.recordGamePlayed();

    // Award XP based on performance
    final percentage = (_correctAnswers / _totalRounds * 100).round();
    int xpReward = 5; // Base XP
    if (percentage >= 90)
      xpReward = 25;
    else if (percentage >= 70)
      xpReward = 15;
    else if (percentage >= 50)
      xpReward = 10;
    await UserPreferences.addXP(xpReward);

    // Track error-free game
    if (_wrongAnswers == 0) {
      await UserPreferences.recordErrorFreeTask();
    }

    // Track correct/wrong answers for streak quests
    for (int i = 0; i < _correctAnswers; i++) {
      await UserPreferences.recordCorrectAnswer();
    }
    if (_wrongAnswers > 0) {
      await UserPreferences.recordWrongAnswer();
    }
  }

  int _calculateScore() {
    // Base score from correct answers (max 500)
    final correctScore = (_correctAnswers / _totalRounds * 500).round();

    // Time bonus (faster = more points, max 500)
    // Perfect time: 30 seconds for 10 rounds = 3s per round
    final perfectTime = _totalRounds * 3;
    final timeBonus = _elapsedSeconds <= perfectTime
        ? 500
        : max(0, 500 - ((_elapsedSeconds - perfectTime) * 10));

    return correctScore + timeBonus;
  }

  void _restartGame() {
    _gameTimer?.cancel();

    setState(() {
      _currentRound = 0;
      _correctAnswers = 0;
      _wrongAnswers = 0;
      _elapsedSeconds = 0;
      _gameOver = false;
      _showingFeedback = false;
      _selectedAnswer = null;
    });

    _allWords.shuffle();
    _setupGame();
    _startTimer();
    _cardAnimationController.forward(from: 0);
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _tts.stop();
    _cardAnimationController.dispose();
    _confettiController.dispose();
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
                numberOfParticles: 25,
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
          // Close button
          _buildIconButton(
            icon: Icons.close_rounded,
            onTap: () => _showExitDialog(),
          ),
          const SizedBox(width: 16),

          // Progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      S.get(
                        'fw_question_n',
                        args: {
                          'n': '${_currentRound + 1}',
                          'total': '$_totalRounds',
                        },
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: darkGreen.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      _userLevel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _totalRounds > 0 ? _currentRound / _totalRounds : 0,
                    backgroundColor: darkGreen.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(darkGreen),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Timer (counts up)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [darkGreen, lightGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  _formatTime(_elapsedSeconds),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
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
            S.get('fw_loading'),
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
        const Spacer(flex: 1),

        // English word card
        ScaleTransition(
          scale: _cardScaleAnimation,
          child: _buildEnglishWordCard(),
        ),

        const SizedBox(height: 24),

        // Instruction
        Text(
          S.get('fw_instruction'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: darkGreen.withOpacity(0.6),
          ),
        ),

        const Spacer(flex: 1),

        // Turkish options grid (4 options)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildOptionsGrid(),
        ),

        const SizedBox(height: 24),

        // Score info
        _buildScoreInfo(),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEnglishWordCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [darkGreen, lightGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🇬🇧', style: TextStyle(fontSize: 36)),
              const SizedBox(width: 12),
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentWord?.english ?? '',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemCount: _options.length,
      itemBuilder: (context, index) {
        return _buildOptionCard(_options[index]);
      },
    );
  }

  Widget _buildOptionCard(String option) {
    final isSelected = _selectedAnswer == option;
    final isCorrect = option == _currentWord?.turkish;
    final showResult = _showingFeedback && (isSelected || isCorrect);

    Color backgroundColor = _c.cardColor;
    Color borderColor = darkGreen.withOpacity(0.15);
    Color textColor = darkGreen;

    if (showResult) {
      if (isCorrect) {
        backgroundColor = correctGreen.withOpacity(0.15);
        borderColor = correctGreen;
        textColor = correctGreen;
      } else if (isSelected && !isCorrect) {
        backgroundColor = wrongRed.withOpacity(0.15);
        borderColor = wrongRed;
        textColor = wrongRed;
      }
    }

    return GestureDetector(
      onTap: () => _onOptionSelected(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: showResult ? 2.5 : 1.5),
          boxShadow: [
            BoxShadow(
              color: showResult
                  ? (isCorrect ? correctGreen : wrongRed).withOpacity(0.15)
                  : darkGreen.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showResult) ...[
                Icon(
                  isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isCorrect ? correctGreen : wrongRed,
                  size: 20,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _c.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildScoreStat(
            '✅',
            '$_correctAnswers',
            S.get('fw_correct'),
            correctGreen,
          ),
          Container(width: 1, height: 30, color: darkGreen.withOpacity(0.1)),
          _buildScoreStat('❌', '$_wrongAnswers', S.get('fw_wrong'), wrongRed),
          Container(width: 1, height: 30, color: darkGreen.withOpacity(0.1)),
          _buildScoreStat(
            '⏱️',
            _formatTime(_elapsedSeconds),
            S.get('fw_time'),
            darkGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreStat(
    String emoji,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: darkGreen.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildGameOverScreen() {
    final score = _calculateScore();
    final percentage = ((_correctAnswers / _totalRounds) * 100).round();

    String message;
    String emoji;
    if (percentage >= 90) {
      message = S.get('fw_perfect');
      emoji = '🏆';
    } else if (percentage >= 70) {
      message = S.get('fw_great');
      emoji = '⭐';
    } else if (percentage >= 50) {
      message = S.get('fw_good');
      emoji = '👍';
    } else {
      message = S.get('fw_practice');
      emoji = '💪';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Trophy
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: percentage >= 70
                    ? [correctGreen, lightGreen]
                    : [orange, lightOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (percentage >= 70 ? correctGreen : orange).withOpacity(
                    0.4,
                  ),
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
            S.get('fw_game_over'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: darkGreen.withOpacity(0.6),
            ),
          ),

          const SizedBox(height: 32),

          // Score card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [orange, lightOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: orange.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  S.get('fw_total_score'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$score',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  S.get('fw_fast_tip'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  S.get('fw_correct'),
                  '$_correctAnswers/$_totalRounds',
                  Icons.check_circle_rounded,
                  correctGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  S.get('fw_time'),
                  _formatTime(_elapsedSeconds),
                  Icons.timer_rounded,
                  darkGreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  S.get('fw_success'),
                  '%$percentage',
                  Icons.percent_rounded,
                  lightGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  S.get('fw_level'),
                  _userLevel,
                  Icons.school_rounded,
                  orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Buttons
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
                    style: TextStyle(
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
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
              S.get('fw_exit_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
          ],
        ),
        content: Text(
          S.get('fw_exit_msg'),
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
              Navigator.pop(context);
              Navigator.pop(context);
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
