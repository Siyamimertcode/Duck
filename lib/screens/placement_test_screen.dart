import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import '../services/user_preferences.dart';
import '../services/duck_theme.dart';
import '../services/app_localizations.dart';
import '../services/navigation_helper.dart';
import 'home_screen.dart';

class PlacementTestScreen extends StatefulWidget {
  const PlacementTestScreen({super.key});

  @override
  State<PlacementTestScreen> createState() => _PlacementTestScreenState();
}

class _PlacementTestScreenState extends State<PlacementTestScreen>
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

  // Test state
  List<Map<String, dynamic>> _allQuestions = [];
  List<Map<String, dynamic>> _testQuestions = [];
  final Map<int, String?> _userAnswers = {};
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _showIntro = true;
  bool _testCompleted = false;
  bool _showResults = false;
  String? _loadError;

  // Timer
  int _remainingSeconds = 30 * 60; // 30 minutes
  Timer? _timer;

  // Animation controllers
  late AnimationController _introAnimController;
  late AnimationController _cardAnimController;
  late AnimationController _progressAnimController;
  late ConfettiController _confettiController;

  // Animations
  late Animation<double> _introScaleAnimation;
  late Animation<double> _cardScaleAnimation;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadQuestions();
  }

  void _initAnimations() {
    _introAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _introScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _introAnimController, curve: Curves.elasticOut),
    );

    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _cardScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutBack),
    );

    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    _introAnimController.forward();
  }

  Future<void> _loadQuestions() async {
    try {
      debugPrint('Loading questions from json/cpt.json...');
      final jsonString = await rootBundle.loadString('json/cpt.json');
      debugPrint('JSON loaded successfully. Length: ${jsonString.length}');

      final data = json.decode(jsonString);
      debugPrint('JSON parsed. Keys: ${data.keys}');

      final questionsList = data['questions'];
      if (questionsList == null) {
        throw Exception('Questions field not found in JSON');
      }

      _allQuestions = List<Map<String, dynamic>>.from(questionsList);
      debugPrint('Loaded ${_allQuestions.length} questions from JSON');

      // Select 50 questions - one from each group (1-50), randomly pick a, b, or c
      _selectTestQuestions();
      debugPrint('Selected ${_testQuestions.length} test questions');

      if (_testQuestions.isEmpty) {
        throw Exception(S.get('pt_select_error'));
      }

      setState(() {
        _isLoading = false;
        _loadError = null;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading questions: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = S.get('pt_load_error', args: {'e': e.toString()});
      });
    }
  }

  void _selectTestQuestions() {
    _testQuestions = [];

    for (int groupId = 1; groupId <= 50; groupId++) {
      // Get all questions for this group
      final groupQuestions = _allQuestions
          .where((q) => q['group_id'] == groupId)
          .toList();

      if (groupQuestions.isNotEmpty) {
        // Randomly select one (a, b, or c)
        final selectedQuestion =
            groupQuestions[_random.nextInt(groupQuestions.length)];
        _testQuestions.add(selectedQuestion);
      }
    }

    // Shuffle for variety
    _testQuestions.shuffle(_random);
  }

  void _startTest() {
    setState(() {
      _showIntro = false;
    });
    _cardAnimController.forward();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _finishTest();
      }
    });
  }

  void _selectAnswer(String answer) {
    HapticFeedback.lightImpact();
    setState(() {
      _userAnswers[_currentIndex] = answer;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _testQuestions.length - 1) {
      _cardAnimController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _currentIndex++;
        });
        _cardAnimController.forward();
      });
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      _cardAnimController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _currentIndex--;
        });
        _cardAnimController.forward();
      });
    }
  }

  void _finishTest() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _testCompleted = true;
    });

    // Calculate results after delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _showResults = true;
      });
      _confettiController.play();
    });
  }

  int _calculateScore() {
    int score = 0;
    for (int i = 0; i < _testQuestions.length; i++) {
      if (_userAnswers[i] == _testQuestions[i]['correct_answer']) {
        score += (_testQuestions[i]['points'] as int?) ?? 1;
      }
    }
    return score;
  }

  int _getCorrectCount() {
    int count = 0;
    for (int i = 0; i < _testQuestions.length; i++) {
      if (_userAnswers[i] == _testQuestions[i]['correct_answer']) {
        count++;
      }
    }
    return count;
  }

  String _determineLevel(int score) {
    if (score < 18) return 'A1';
    if (score < 40) return 'A2';
    if (score < 70) return 'B1';
    if (score < 112) return 'B2';
    return 'C1';
  }

  String _getLevelDescription(String level) {
    switch (level) {
      case 'A1':
        return S.get('pt_beginner');
      case 'A2':
        return S.get('pt_elementary');
      case 'B1':
        return S.get('pt_intermediate');
      case 'B2':
        return S.get('pt_upper_intermediate');
      case 'C1':
        return S.get('pt_advanced');
      default:
        return '';
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'A1':
        return Colors.blue;
      case 'A2':
        return lightGreen;
      case 'B1':
        return orange;
      case 'B2':
        return Colors.purple;
      case 'C1':
        return darkGreen;
      default:
        return darkGreen;
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _saveAndContinue() async {
    final level = _determineLevel(_calculateScore());
    await UserPreferences.saveEnglishLevel(level);
    await UserPreferences.saveCurrentLevel(level);

    final userName =
        await UserPreferences.getUserName() ?? S.get('home_default_user');

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomeScreen(userName: userName)),
      );
    }
  }

  @override
  void dispose() {
    _introAnimController.dispose();
    _cardAnimController.dispose();
    _progressAnimController.dispose();
    _confettiController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showResults) {
          _saveAndContinue();
        } else {
          _showExitDialog();
        }
      },
      child: Scaffold(
        backgroundColor: cream,
        body: SafeArea(
          child: Stack(
            children: [
              _buildBackgroundDecorations(),
              if (_isLoading)
                _buildLoadingState()
              else if (_loadError != null)
                _buildErrorState()
              else if (_showIntro)
                _buildIntroScreen()
              else if (_showResults)
                _buildResultsScreen()
              else
                _buildTestScreen(),
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
      ),
    );
  }

  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  lightGreen.withOpacity(0.12),
                  lightGreen.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -120,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [orange.withOpacity(0.1), orange.withOpacity(0.0)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _c.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: CircularProgressIndicator(color: lightGreen, strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            S.get('pt_loading'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: darkGreen.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: wrongRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.error_outline, color: wrongRed, size: 60),
            ),
            const SizedBox(height: 24),
            Text(
              S.get('pt_load_fail'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _loadError ?? S.get('unknown_error'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: darkGreen.withOpacity(0.6)),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _loadError = null;
                });
                _loadQuestions();
              },
              icon: const Icon(Icons.refresh),
              label: Text(S.get('pt_retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: lightGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(S.get('pt_back'), style: TextStyle(color: darkGreen)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroScreen() {
    return ScaleTransition(
      scale: _introScaleAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Header icon
            Container(
              width: 100,
              height: 100,
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
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              S.get('pt_title'),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              S.get('pt_subtitle'),
              style: TextStyle(fontSize: 16, color: darkGreen.withOpacity(0.6)),
            ),
            const SizedBox(height: 40),

            // Info cards
            _buildInfoCard(
              Icons.help_outline_rounded,
              S.get('pt_50_questions'),
              S.get('pt_50_desc'),
              lightGreen,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              Icons.timer_outlined,
              S.get('pt_30_min'),
              S.get('pt_max_time'),
              orange,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              Icons.trending_up_rounded,
              S.get('pt_determine'),
              S.get('pt_assessment_desc'),
              Colors.purple,
            ),
            const SizedBox(height: 40),

            // Start button
            _buildGradientButton(
              S.get('pt_start'),
              Icons.play_arrow_rounded,
              _startTest,
            ),
            const SizedBox(height: 16),

            // Back button
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back_rounded, color: darkGreen),
              label: Text(
                S.get('pt_back'),
                style: TextStyle(color: darkGreen, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String title,
    String subtitle,
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
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: darkGreen.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestScreen() {
    if (_testQuestions.isEmpty || _currentIndex >= _testQuestions.length) {
      return Center(
        child: Text(
          S.get('pt_questions_fail'),
          style: TextStyle(fontSize: 16, color: darkGreen),
        ),
      );
    }

    final question = _testQuestions[_currentIndex];
    final options = List<String>.from(question['options']);
    final selectedAnswer = _userAnswers[_currentIndex];

    return Column(
      children: [
        // Header
        _buildTestHeader(),

        // Progress bar
        _buildProgressBar(),

        // Question card
        Expanded(
          child: ScaleTransition(
            scale: _cardScaleAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Question info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getLevelColor(
                            question['level'],
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          question['level'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getLevelColor(question['level']),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        S.get(
                          'pt_points',
                          args: {'n': '${question['points']}'},
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: darkGreen.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Question card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _c.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: darkGreen.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          S.get(
                            'pt_question_n',
                            args: {'n': '${_currentIndex + 1}'},
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: orange,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          question['question'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: darkGreen,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Options
                  ...options.map(
                    (option) =>
                        _buildOptionButton(option, selectedAnswer == option),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Navigation buttons
        _buildNavigationButtons(),
      ],
    );
  }

  Widget _buildTestHeader() {
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
          GestureDetector(
            onTap: () => _showExitDialog(),
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
              child: Icon(Icons.close_rounded, color: darkGreen, size: 22),
            ),
          ),
          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Text(
              S.get('pt_test'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
          ),

          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _remainingSeconds < 300
                  ? wrongRed.withOpacity(0.1)
                  : orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: _remainingSeconds < 300 ? wrongRed : orange,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTime(_remainingSeconds),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _remainingSeconds < 300 ? wrongRed : orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final answeredCount = _userAnswers.length;
    final progress = (_currentIndex + 1) / _testQuestions.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentIndex + 1} / ${_testQuestions.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: darkGreen,
                ),
              ),
              Text(
                S.get('pt_answered', args: {'n': '$answeredCount'}),
                style: TextStyle(
                  fontSize: 12,
                  color: darkGreen.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: darkGreen.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(lightGreen),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(String option, bool isSelected) {
    return GestureDetector(
      onTap: () => _selectAnswer(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? lightGreen.withOpacity(0.1) : _c.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? lightGreen : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? lightGreen.withOpacity(0.15)
                  : darkGreen.withOpacity(0.05),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? lightGreen : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? lightGreen : darkGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final isFirstQuestion = _currentIndex == 0;
    final isLastQuestion = _currentIndex == _testQuestions.length - 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _c.cardColor,
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous button
          Expanded(
            child: GestureDetector(
              onTap: isFirstQuestion ? null : _previousQuestion,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isFirstQuestion
                      ? Colors.grey.withOpacity(0.1)
                      : darkGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      color: isFirstQuestion ? Colors.grey : darkGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      S.get('pt_previous'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isFirstQuestion ? Colors.grey : darkGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Next/Finish button
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: isLastQuestion ? _finishTest : _nextQuestion,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isLastQuestion
                        ? [orange, lightOrange]
                        : [lightGreen, darkGreen],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (isLastQuestion ? orange : lightGreen).withOpacity(
                        0.4,
                      ),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLastQuestion ? S.get('pt_finish') : S.get('pt_next'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLastQuestion
                          ? Icons.check_circle_rounded
                          : Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsScreen() {
    final score = _calculateScore();
    final correctCount = _getCorrectCount();
    final level = _determineLevel(score);
    final levelColor = _getLevelColor(level);
    final levelDesc = _getLevelDescription(level);
    final percentage = (correctCount / _testQuestions.length * 100).round();
    final timeTaken = (30 * 60) - _remainingSeconds;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Result badge
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [levelColor, levelColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: levelColor.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  level,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  levelDesc,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Congratulations text
          Text(
            S.get('pt_congrats'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.get('pt_complete'),
            style: TextStyle(fontSize: 16, color: darkGreen.withOpacity(0.6)),
          ),
          const SizedBox(height: 32),

          // Stats cards
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _c.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildResultRow(
                  Icons.star_rounded,
                  S.get('pt_total_score'),
                  '$score / 150',
                  orange,
                ),
                const Divider(height: 24),
                _buildResultRow(
                  Icons.check_circle_rounded,
                  S.get('pt_correct_answers'),
                  '$correctCount / 50',
                  correctGreen,
                ),
                const Divider(height: 24),
                _buildResultRow(
                  Icons.percent_rounded,
                  S.get('pt_success_rate'),
                  '%$percentage',
                  lightGreen,
                ),
                const Divider(height: 24),
                _buildResultRow(
                  Icons.timer_rounded,
                  S.get('pt_elapsed'),
                  _formatTime(timeTaken),
                  Colors.purple,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Level explanation card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: levelColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      level,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: levelColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.get('pt_your_level', args: {'level': level}),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: levelColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        levelDesc,
                        style: TextStyle(
                          fontSize: 13,
                          color: darkGreen.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Continue button
          _buildGradientButton(
            S.get('continue_btn'),
            Icons.arrow_forward_rounded,
            _saveAndContinue,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildResultRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
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

  Widget _buildGradientButton(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [orange, lightOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: orange.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: orange),
            const SizedBox(width: 10),
            Text(S.get('pt_exit_title')),
          ],
        ),
        content: Text(S.get('pt_exit_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.get('cancel'), style: TextStyle(color: darkGreen)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              NavigationHelper.safePopOrHome(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              S.get('exit_btn'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
