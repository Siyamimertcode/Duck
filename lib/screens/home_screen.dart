import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:confetti/confetti.dart';
import 'settings_screen.dart';
import 'exercise_screen.dart';
import 'games/true_false_game_screen.dart';
import 'games/fast_word_game_screen.dart';
import 'games/word_match_game_screen.dart';
import 'vocabulary_screen.dart';
import '../services/user_preferences.dart';
import '../services/quest_service.dart';
import '../services/achievement_service.dart';
import '../services/progress_service.dart';
import '../services/tts_service.dart';
import '../services/duck_theme.dart';
import '../services/app_localizations.dart';
import '../services/sound_service.dart';
import '../services/celebration_service.dart';

class HomeScreen extends StatefulWidget {
  final String userName;

  const HomeScreen({super.key, this.userName = 'Kullanıcı'});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Brand Colors — dynamic via theme
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get lightGreen => _c.lightGreen;
  Color get orange => _c.orange;
  Color get lightOrange => _c.lightOrange;
  Color get cream => _c.cream;

  // User name
  late String _userName;

  // English level
  String _englishLevel = 'A1';

  // Learning page state
  String? _expandedLevel; // Track which level is expanded
  List<String> _completedLevels = [];
  Map<String, int> _completedLessonsByLevel =
      {}; // Track completed lessons per level
  int _currentStreak = 0; // Daily streak count

  // Quest system
  Set<String> _completedQuests = {};
  Set<String> _claimedQuests = {};
  List<QuestTask> _dailyQuests = [];
  List<QuestTask> _weeklyQuests = [];

  // Achievement system
  List<Achievement> _achievements = [];
  Set<String> _completedAchievements = {};

  // Navigation - 0: Öğren, 1: Oyunlar, 2: Ana Sayfa (Duck), 3: Görevlerim, 4: Başarılarım
  int _currentIndex = 2; // Start at home (Duck)

  // Animation Controllers
  late final AnimationController _bubbleController;
  late final AnimationController _duckPulseController;
  late ConfettiController _confettiControllerLeft;
  late ConfettiController _confettiControllerRight;

  // XP Data - Dynamic from preferences
  int _currentXP = 0;
  int _maxXP = 100;
  int _level = 1;

  // Lesson data from JSON
  Map<String, List<Map<String, dynamic>>> _lessonTitlesPerLevel = {};
  bool _lessonTitlesLoaded = false;

  // Floating bubbles
  final List<_FloatingBubble> _bubbles = [];
  bool _bubblesInitialized = false;

  // Bounce animation for current lesson
  late final AnimationController _bounceController;

  // Celebration state
  bool _isBirthday = false;
  HolidayInfo? _todayHoliday;
  late ConfettiController _celebrationConfettiController;

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
    _initializeApp();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _duckPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Initialize confetti controllers
    _confettiControllerLeft = ConfettiController(
      duration: const Duration(milliseconds: 900),
    );
    _confettiControllerRight = ConfettiController(
      duration: const Duration(milliseconds: 900),
    );

    // Celebration confetti
    _celebrationConfettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bubblesInitialized) {
      _bubblesInitialized = true;
      _initBubbles();
    }
  }

  Future<void> _initializeApp() async {
    // Ensure daily/weekly resets
    await UserPreferences.ensureDailyWeeklyResets();

    // Record app open
    await UserPreferences.recordAppOpen();

    // Load user data
    await _loadUserName();
    await _loadStreak();
    await _loadXPAndLevel();
    await _loadQuests();
    await _loadAchievements();
    await _loadLessonTitles();
    await _syncProgressFromService();

    // Load celebration state
    await _loadCelebrationState();

    // Check and auto-complete achievements
    final oldCompletedCount = _completedAchievements.length;
    await AchievementService.checkAndCompleteAchievements();
    await _loadAchievements(); // Reload after checking

    // If new achievements were completed, trigger confetti
    if (_completedAchievements.length > oldCompletedCount && mounted) {
      _triggerConfetti();
    }

    // One-time app entry sound effect on very first usage
    if (await UserPreferences.shouldPlayFirstHomeEffect()) {
      if (mounted) {
        SoundService().playNavigation();
      }
      await UserPreferences.markFirstHomeEffectPlayed();
    }
  }

  Future<void> _loadUserName() async {
    final storedName = await UserPreferences.getUserName();
    final storedLevel = await UserPreferences.getEnglishLevel();
    if (mounted) {
      setState(() {
        if (storedName != null && storedName.isNotEmpty) {
          _userName = storedName;
        }
        if (storedLevel != null && storedLevel.isNotEmpty) {
          _englishLevel = storedLevel;
        }
      });

      // Speak welcome message
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          // If name is default, just say "Hoşgeldin"
          final text = _userName == 'Kullanıcı'
              ? 'Hoşgeldin'
              : 'Hoşgeldin $_userName';
          TtsService().speakTurkish(text);
        }
      });
    }
  }

  Future<void> _loadStreak() async {
    final streak = await UserPreferences.checkAndUpdateStreak();
    if (mounted) {
      setState(() {
        _currentStreak = streak;
      });
    }
  }

  Future<void> _loadXPAndLevel() async {
    final xp = await UserPreferences.getXP();
    final level = await UserPreferences.getUserLevel();
    if (mounted) {
      setState(() {
        _currentXP = xp;
        _level = level;
        _maxXP = 100; // Always 100 XP per level
      });
    }
  }

  Future<void> _loadQuests() async {
    // Load quest states from preferences
    final claimed = await UserPreferences.getClaimedQuests();

    // Load quests from JSON
    final daily = await QuestService.getDailyQuests();
    final weekly = await QuestService.getWeeklyQuests();

    // Check and auto-complete quests based on current progress
    await QuestService.checkAndCompleteQuests([...daily, ...weekly]);

    // Reload completed state after auto-check
    final updatedCompleted = await UserPreferences.getCompletedQuests();

    if (mounted) {
      setState(() {
        _completedQuests = updatedCompleted.toSet();
        _claimedQuests = claimed.toSet();
        _dailyQuests = daily;
        _weeklyQuests = weekly;
      });
    }
  }

  Future<void> _loadAchievements() async {
    final achievements = await AchievementService.getAllAchievements();
    final completed = await UserPreferences.getCompletedAchievements();

    if (mounted) {
      setState(() {
        _achievements = achievements;
        _completedAchievements = completed.toSet();
      });
    }
  }

  /// Load lesson titles from konular.json and exercises JSON for all levels.
  Future<void> _loadLessonTitles() async {
    if (_lessonTitlesLoaded) return;
    try {
      final jsonString = await rootBundle.loadString('json/konular.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final levels = data['levels'] as List<dynamic>? ?? [];
      final Map<String, List<Map<String, dynamic>>> result = {};
      for (var lvl in levels) {
        final levelName = lvl['level'] as String;
        final lessons = lvl['lessons'] as List<dynamic>? ?? [];
        result[levelName] = [];
        for (int i = 0; i < lessons.length; i++) {
          final rawTitle = lessons[i] as String;
          // Strip leading "1. " prefix
          final title = rawTitle.replaceFirst(RegExp(r'^\d+\.\s*'), '');
          result[levelName]!.add({'lessonInLevel': i + 1, 'title': title});
        }
      }
      if (mounted) {
        setState(() {
          _lessonTitlesPerLevel = result;
          _lessonTitlesLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading lesson titles: $e');
    }
  }

  /// Sync _completedLessonsByLevel with the centralized ProgressService.
  Future<void> _syncProgressFromService() async {
    final progressService = ProgressService();
    final allProgress = await progressService.getAllProgress();
    if (mounted) {
      setState(() {
        _completedLessonsByLevel = Map<String, int>.from(allProgress);
      });
    }
  }

  /// Get lesson title for a specific level and lesson number.
  String _getLessonTitle(String level, int lessonInLevel) {
    final lessons = _lessonTitlesPerLevel[level];
    if (lessons == null ||
        lessonInLevel < 1 ||
        lessonInLevel > lessons.length) {
      return 'Ders $lessonInLevel';
    }
    return lessons[lessonInLevel - 1]['title'] as String;
  }

  /// Show a beautiful bottom sheet when tapping a lesson node.
  void _showLessonBottomSheet({
    required String level,
    required int lessonInLevel,
    required bool isCompleted,
  }) {
    final title = _getLessonTitle(level, lessonInLevel);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _LessonBottomSheet(
          level: level,
          lessonInLevel: lessonInLevel,
          title: title,
          isCompleted: isCompleted,
          onStart: () {
            Navigator.pop(ctx);
            _navigateToExercise(level, lessonInLevel, title);
          },
        );
      },
    );
  }

  /// Navigate to ExerciseScreen and handle result.
  Future<void> _navigateToExercise(
    String level,
    int lessonInLevel,
    String title,
  ) async {
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ExerciseScreen(
          level: level,
          lessonInLevel: lessonInLevel,
          title: title,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.0, 0.3),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    // Refresh progress on return
    if (result == true && mounted) {
      await _syncProgressFromService();
      await _loadXPAndLevel();
      await _loadStreak();
      await _loadQuests();

      // Check if level is complete
      final progressService = ProgressService();
      final isLevelComplete = await progressService.isLevelCompleted(level);
      if (isLevelComplete && mounted) {
        _triggerConfetti();
      }
    }
  }

  void _initBubbles() {
    final random = Random();
    final colors = [
      darkGreen.withOpacity(0.05),
      lightGreen.withOpacity(0.06),
      orange.withOpacity(0.05),
      lightOrange.withOpacity(0.06),
    ];

    for (int i = 0; i < 12; i++) {
      final gridX = (i % 4) / 4.0;
      final gridY = (i ~/ 4) / 3.0;
      final randomOffsetX = (random.nextDouble() - 0.5) * 0.2;
      final randomOffsetY = (random.nextDouble() - 0.5) * 0.25;

      _bubbles.add(
        _FloatingBubble(
          x: (gridX + randomOffsetX).clamp(0.05, 0.95),
          y: (gridY + randomOffsetY).clamp(0.05, 0.95),
          size: (random.nextDouble() * 30 + 10) * 0.6,
          speed: random.nextDouble() * 0.3 + 0.1,
          color: colors[random.nextInt(colors.length)],
          wobbleOffset: random.nextDouble() * 2 * pi,
          wobbleSpeed: random.nextDouble() * 0.5 + 0.3,
        ),
      );
    }
  }

  Future<void> _loadCelebrationState() async {
    final birthday = await UserPreferences.getBirthday();
    final isBday = CelebrationService.isBirthday(birthday);
    final holiday = CelebrationService.getTodayHoliday();
    if (mounted) {
      setState(() {
        _isBirthday = isBday;
        _todayHoliday = holiday;
      });
      // Auto-play celebration confetti
      if (_isBirthday || _todayHoliday != null) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _celebrationConfettiController.play();
        });
      }
    }
  }

  void _triggerConfetti() {
    // Play both left and right confetti
    _confettiControllerLeft.play();
    _confettiControllerRight.play();
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    _duckPulseController.dispose();
    _bounceController.dispose();
    _confettiControllerLeft.dispose();
    _confettiControllerRight.dispose();
    _celebrationConfettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Stack(
          children: [
            // Floating bubbles background
            _buildFloatingBubbles(),

            // Background decorations
            _buildBackgroundDecorations(),

            // Main content
            Column(
              children: [
                // Top bar with XP and settings
                _buildTopBar(),

                // Page content
                Expanded(child: _buildPageContent()),
              ],
            ),

            // Confetti widgets
            Align(
              alignment: Alignment.topLeft,
              child: ConfettiWidget(
                confettiController: _confettiControllerLeft,
                blastDirection: pi / 4, // 45 degrees to the right
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.3,
                shouldLoop: false,
                colors: const [
                  Color(0xFF1D6755),
                  Color(0xFF2A8A6E),
                  Color(0xFFEA8018),
                  Color(0xFFF5A623),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: ConfettiWidget(
                confettiController: _confettiControllerRight,
                blastDirection: 3 * pi / 4, // 135 degrees to the left
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.3,
                shouldLoop: false,
                colors: const [
                  Color(0xFF1D6755),
                  Color(0xFF2A8A6E),
                  Color(0xFFEA8018),
                  Color(0xFFF5A623),
                ],
              ),
            ),

            // Celebration confetti (center burst)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _celebrationConfettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.03,
                numberOfParticles: 30,
                gravity: 0.2,
                shouldLoop: false,
                colors: const [
                  Color(0xFFFF6B6B),
                  Color(0xFFFFD93D),
                  Color(0xFF6BCB77),
                  Color(0xFF4D96FF),
                  Color(0xFFEA8018),
                  Color(0xFF9B59B6),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildFloatingBubbles() {
    return AnimatedBuilder(
      animation: _bubbleController,
      builder: (context, _) {
        return CustomPaint(
          painter: _BubblePainter(
            bubbles: _bubbles,
            animationValue: _bubbleController.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [orange.withOpacity(0.08), orange.withOpacity(0.0)],
              ),
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -60,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  lightGreen.withOpacity(0.08),
                  lightGreen.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // XP Bar Section
          Expanded(child: _buildXPSection()),

          const SizedBox(width: 16),

          // Settings Button
          _buildSettingsButton(),
        ],
      ),
    );
  }

  Widget _buildXPSection() {
    final double progress = _currentXP / _maxXP;

    return Row(
      children: [
        // Star Level Badge - Custom Star Shape
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Subtle outer glow
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: orange.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            // Star shape using custom painter
            CustomPaint(
              size: const Size(50, 50),
              painter: _StarPainter(
                fillColor: orange,
                strokeColor: lightOrange,
                shadowColor: orange.withOpacity(0.3),
              ),
            ),
            // Level number inside star - Gaming style font
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer stroke effect
                Text(
                  '$_level',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 3
                      ..color = const Color(0xFFB85A00),
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
                // Inner fill with gradient
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFFFF3CD)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: const Text(
                    '1', // Will be replaced dynamically
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0,
                      height: 1,
                    ),
                  ),
                ),
                // Actual text
                Text(
                  '$_level',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: Color(0x80000000),
                        blurRadius: 1,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(width: 14),

        // XP Progress Section - Clean and Modern
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // XP Label Row
              Row(
                children: [
                  // Lightning XP Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: darkGreen.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: lightGreen.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          '$_currentXP',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: darkGreen,
                          ),
                        ),
                        Text(
                          ' / $_maxXP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: darkGreen.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // English Level Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📚', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text(
                          _englishLevel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Premium Progress Bar with visible empty section
              Container(
                height: 12,
                decoration: BoxDecoration(
                  // Empty section - VISIBLE light green (always visible)
                  color: lightGreen.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: lightGreen.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Stack(
                    children: [
                      // Progress fill - dark green gradient
                      FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [darkGreen, lightGreen],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _c.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: lightGreen.withOpacity(0.1), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsScreen(userName: _userName),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            Icons.settings_rounded,
            color: darkGreen.withOpacity(0.6),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    switch (_currentIndex) {
      case 0:
        return _buildLearnPage();
      case 1:
        return _buildGamesPage();
      case 2:
        return _buildHomePage(); // Duck Home
      case 3:
        return _buildQuestsPage();
      case 4:
        return _buildAchievementsPage();
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Duck Title
          Center(
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [darkGreen, lightGreen],
                  ).createShader(bounds),
                  child: const Text(
                    'Duck',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  S.get('home_learn_english'),
                  style: TextStyle(
                    fontSize: 14,
                    color: darkGreen.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Celebration card (birthday or holiday)
          if (_isBirthday || _todayHoliday != null) ...[
            _buildCelebrationCard(),
            const SizedBox(height: 20),
          ],

          // Continue Learning Card
          _buildContinueLearningCard(),

          const SizedBox(height: 20),

          // Daily Goals Section
          _buildSectionTitle(S.get('home_daily_goals'), '🎯'),
          const SizedBox(height: 12),
          _buildDailyGoalsCard(),

          const SizedBox(height: 24),

          // Quick Actions
          _buildSectionTitle(S.get('home_quick_start'), '⚡'),
          const SizedBox(height: 12),
          _buildQuickActions(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLearnPage() {
    if (_expandedLevel != null) {
      // Show 25 lessons for the expanded level
      return _buildLevelLessons(_expandedLevel!);
    }

    // Show 5 main levels
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          _buildSectionTitle(S.get('home_pick_level'), '🎯'),
          const SizedBox(height: 8),
          Text(
            S.get('home_25_lessons'),
            style: TextStyle(fontSize: 13, color: darkGreen.withOpacity(0.6)),
          ),
          const SizedBox(height: 20),

          // 5 Level cards
          _buildLevelCard(
            'A1',
            S.get('home_beginner'),
            '🐣',
            const Color(0xFF4CAF50),
            S.get('home_beginner_desc'),
          ),
          const SizedBox(height: 12),
          _buildLevelCard(
            'A2',
            S.get('home_elementary'),
            '🦆',
            const Color(0xFF8BC34A),
            S.get('home_elementary_desc'),
          ),
          const SizedBox(height: 12),
          _buildLevelCard(
            'B1',
            S.get('home_intermediate'),
            '🦅',
            const Color(0xFFFF9800),
            S.get('home_intermediate_desc'),
          ),
          const SizedBox(height: 12),
          _buildLevelCard(
            'B2',
            S.get('home_upper_intermediate'),
            '🦉',
            const Color(0xFFFF5722),
            S.get('home_upper_intermediate_desc'),
          ),
          const SizedBox(height: 12),
          _buildLevelCard(
            'C1',
            S.get('home_advanced'),
            '👑',
            const Color(0xFF9C27B0),
            S.get('home_advanced_desc'),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLevelCard(
    String level,
    String title,
    String emoji,
    Color color,
    String description,
  ) {
    final levels = ['A1', 'A2', 'B1', 'B2', 'C1'];
    final selectedIndex = levels.indexOf(_englishLevel);
    final levelIndex = levels.indexOf(level);
    final isLocked = levelIndex > selectedIndex;
    final isCompleted = _completedLevels.contains(level);
    final isCurrent = _englishLevel == level;

    return GestureDetector(
      onTap: isLocked
          ? null
          : () {
              setState(() {
                _expandedLevel = level;
              });
            },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isLocked
              ? (context.isDarkMode
                    ? _c.cardColor.withOpacity(0.5)
                    : Colors.grey.shade200)
              : isCompleted
              ? lightGreen.withOpacity(0.15)
              : isCurrent
              ? orange.withOpacity(0.15)
              : _c.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLocked
                ? (context.isDarkMode ? _c.divider : Colors.grey.shade300)
                : isCompleted
                ? lightGreen
                : isCurrent
                ? orange
                : color.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isLocked ? Colors.grey : color).withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Emoji icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isLocked
                    ? (context.isDarkMode ? _c.shimmer : Colors.grey.shade300)
                    : color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isLocked
                    ? Icon(
                        Icons.lock_rounded,
                        size: 28,
                        color: context.isDarkMode
                            ? _c.textSecondary
                            : Colors.grey.shade600,
                      )
                    : Text(emoji, style: const TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(width: 16),

            // Level info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        level,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isLocked
                              ? (context.isDarkMode
                                    ? _c.textSecondary
                                    : Colors.grey.shade600)
                              : darkGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isLocked
                              ? (context.isDarkMode
                                    ? _c.textSecondary
                                    : Colors.grey.shade500)
                              : darkGreen.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isLocked
                          ? (context.isDarkMode
                                ? _c.textSecondary
                                : Colors.grey.shade500)
                          : darkGreen.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isLocked
                              ? (context.isDarkMode
                                    ? _c.shimmer
                                    : Colors.grey.shade300)
                              : color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '25 ders',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isLocked
                                ? (context.isDarkMode
                                      ? _c.textSecondary
                                      : Colors.grey.shade600)
                                : color,
                          ),
                        ),
                      ),
                      if (isCompleted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: lightGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                S.get('home_completed'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (isCurrent && !isCompleted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.play_circle_filled,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                S.get('home_continue'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Arrow icon
            if (!isLocked)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 20,
                color: darkGreen.withOpacity(0.4),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelLessons(String level) {
    // Get lessons for this level
    final levelLessons = _generateLessonsForLevel(level);
    final completed = _completedLessonsByLevel[level] ?? 0;
    final progressPercent = (completed / 25 * 100).round();

    return Column(
      children: [
        // Back button and header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: cream,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 24),
                color: darkGreen,
                onPressed: () {
                  setState(() {
                    _expandedLevel = null;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seviye $level',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkGreen,
                      ),
                    ),
                    Text(
                      '$completed / 25 ders · %$progressPercent',
                      style: TextStyle(
                        fontSize: 13,
                        color: darkGreen.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Mini progress indicator
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: completed / 25,
                      strokeWidth: 4,
                      backgroundColor: _c.shimmer,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completed == 25 ? lightGreen : orange,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        '$completed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: darkGreen.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Lessons path - Candy Crush style
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: 2500,
                  width: constraints.maxWidth,
                  child: Stack(
                    children: _buildLessonPath(
                      levelLessons,
                      level,
                      constraints.maxWidth,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _generateLessonsForLevel(String level) {
    final lessons = <Map<String, dynamic>>[];
    final emojiMap = {
      'A1': '🐣',
      'A2': '🦆',
      'B1': '🦅',
      'B2': '🦉',
      'C1': '👑',
    };
    final colorMap = {
      'A1': const Color(0xFF4CAF50),
      'A2': const Color(0xFF8BC34A),
      'B1': const Color(0xFFFF9800),
      'B2': const Color(0xFFFF5722),
      'C1': const Color(0xFF9C27B0),
    };

    for (int i = 0; i < 25; i++) {
      lessons.add({
        'lessonNumber': i + 1,
        'level': level,
        'emoji': emojiMap[level],
        'color': colorMap[level],
        'lessonInLevel': i + 1,
        'title': _getLessonTitle(level, i + 1),
      });
    }

    return lessons;
  }

  List<Widget> _buildLessonPath(
    List<Map<String, dynamic>> lessons,
    String level,
    double screenWidth,
  ) {
    final pathItems = <Widget>[];

    // Get completed lessons for this level
    final completedInLevel = _completedLessonsByLevel[level] ?? 0;

    // Check if user's level matches current level
    final levels = ['A1', 'A2', 'B1', 'B2', 'C1'];
    final userLevelIndex = levels.indexOf(_englishLevel);
    final currentLevelIndex = levels.indexOf(level);
    final isUserLevel = userLevelIndex == currentLevelIndex;
    final isLockedLevel = currentLevelIndex > userLevelIndex;

    // Düzensiz pozisyonlar - Candy Crush tarzı (0.0 - 1.0 arası, merkeze göre)
    final positions = [
      {'x': 0.5, 'y': 50.0}, // 1 - üstte merkez
      {'x': 0.7, 'y': 140.0}, // 2 - sağda
      {'x': 0.5, 'y': 230.0}, // 3 - merkez
      {'x': 0.3, 'y': 320.0}, // 4 - solda
      {'x': 0.2, 'y': 410.0}, // 5 - daha solda
      {'x': 0.35, 'y': 500.0}, // 6 - orta sol
      {'x': 0.5, 'y': 590.0}, // 7 - merkez
      {'x': 0.65, 'y': 680.0}, // 8 - orta sağ
      {'x': 0.8, 'y': 770.0}, // 9 - çok sağda
      {'x': 0.7, 'y': 860.0}, // 10 - sağda
      {'x': 0.5, 'y': 950.0}, // 11 - merkez
      {'x': 0.3, 'y': 1040.0}, // 12 - solda
      {'x': 0.2, 'y': 1130.0}, // 13 - daha solda
      {'x': 0.35, 'y': 1220.0}, // 14 - orta sol
      {'x': 0.5, 'y': 1310.0}, // 15 - merkez
      {'x': 0.65, 'y': 1400.0}, // 16 - orta sağ
      {'x': 0.8, 'y': 1490.0}, // 17 - çok sağda
      {'x': 0.7, 'y': 1580.0}, // 18 - sağda
      {'x': 0.5, 'y': 1670.0}, // 19 - merkez
      {'x': 0.3, 'y': 1760.0}, // 20 - solda
      {'x': 0.5, 'y': 1850.0}, // 21 - merkez
      {'x': 0.7, 'y': 1940.0}, // 22 - sağda
      {'x': 0.8, 'y': 2030.0}, // 23 - çok sağda
      {'x': 0.6, 'y': 2120.0}, // 24 - orta sağ
      {'x': 0.5, 'y': 2210.0}, // 25 - son, merkez
    ];

    // Merkeze hizalama için offset hesapla
    final centerOffset = screenWidth / 2;
    final pathWidth = 300.0;
    final leftOffset = centerOffset - (pathWidth / 2);

    // Kesikli çizgiler çiz
    for (int i = 0; i < lessons.length - 1 && i < positions.length - 1; i++) {
      final isCompleted = i < completedInLevel;

      pathItems.add(
        _buildDottedConnector(
          from: positions[i],
          to: positions[i + 1],
          isCompleted: isCompleted,
          leftOffset: leftOffset,
        ),
      );
    }

    // Lesson node'ları çiz
    for (int i = 0; i < lessons.length && i < positions.length; i++) {
      final lesson = lessons[i];
      final isCompleted = i < completedInLevel;
      final isCurrent = isUserLevel && i == completedInLevel;
      final isLocked = isLockedLevel || (isUserLevel && i > completedInLevel);

      pathItems.add(
        Positioned(
          left: leftOffset + (positions[i]['x']! * pathWidth) - 35,
          top: positions[i]['y']!,
          child: _buildLessonNode(
            lesson: lesson,
            isCompleted: isCompleted,
            isCurrent: isCurrent,
            isLocked: isLocked,
            level: level,
          ),
        ),
      );
    }

    return pathItems;
  }

  Widget _buildLessonNode({
    required Map<String, dynamic> lesson,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLocked,
    required String level,
  }) {
    const size = 70.0;
    final lessonInLevel = lesson['lessonInLevel'] as int;
    final title = lesson['title'] as String? ?? 'Ders $lessonInLevel';

    Widget nodeWidget = GestureDetector(
      onTap: isLocked
          ? null
          : () {
              // Both current and completed lessons can be tapped
              _showLessonBottomSheet(
                level: level,
                lessonInLevel: lessonInLevel,
                isCompleted: isCompleted,
              );
            },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Glow effect for current lesson
          if (isCurrent)
            Container(
              width: size + 20,
              height: size + 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: orange.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          // Main circle with gradient
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: isLocked
                  ? null
                  : isCompleted
                  ? LinearGradient(
                      colors: [lightGreen, lightGreen.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : isCurrent
                  ? LinearGradient(
                      colors: [orange, lightOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isLocked
                  ? (context.isDarkMode ? _c.shimmer : Colors.grey.shade200)
                  : (!isCompleted && !isCurrent ? _c.cardColor : null),
              shape: BoxShape.circle,
              border: Border.all(
                color: isLocked
                    ? (context.isDarkMode ? _c.divider : Colors.grey.shade300)
                    : isCompleted
                    ? darkGreen
                    : isCurrent
                    ? orange
                    : (lesson['color'] as Color).withOpacity(0.6),
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (isCompleted
                              ? lightGreen
                              : isCurrent
                              ? orange
                              : lesson['color'] as Color)
                          .withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: isLocked
                  ? Icon(
                      Icons.lock_rounded,
                      size: 32,
                      color: context.isDarkMode
                          ? _c.textSecondary
                          : Colors.grey.shade400,
                    )
                  : isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 36,
                      color: Colors.white,
                    )
                  : Text(lesson['emoji'], style: const TextStyle(fontSize: 32)),
            ),
          ),
          // Lesson number badge
          Positioned(
            bottom: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted
                    ? darkGreen
                    : isCurrent
                    ? orange
                    : lesson['color'] as Color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _c.cream, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${lesson['lessonInLevel']}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Lesson title tooltip for current/completed
          if (!isLocked)
            Positioned(
              top: -28,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 120),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _c.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: darkGreen.withOpacity(0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );

    // Add bounce animation for current lesson
    if (isCurrent) {
      nodeWidget = AnimatedBuilder(
        animation: _bounceController,
        builder: (context, child) {
          final bounceValue = sin(_bounceController.value * pi) * 4;
          return Transform.translate(
            offset: Offset(0, -bounceValue),
            child: child,
          );
        },
        child: nodeWidget,
      );
    }

    return nodeWidget;
  }

  Widget _buildDottedConnector({
    required Map<String, double> from,
    required Map<String, double> to,
    required bool isCompleted,
    required double leftOffset,
  }) {
    final pathWidth = 300.0;
    final startX = leftOffset + (from['x']! * pathWidth);
    final startY = from['y']! + 35;
    final endX = leftOffset + (to['x']! * pathWidth);
    final endY = to['y']! + 35;

    return Positioned(
      left: 0,
      top: 0,
      child: CustomPaint(
        size: Size(leftOffset * 2 + pathWidth, 2500),
        painter: _DottedLinePainter(
          startX: startX,
          startY: startY,
          endX: endX,
          endY: endY,
          color: isCompleted ? lightGreen : darkGreen.withOpacity(0.3),
          isCompleted: isCompleted,
        ),
      ),
    );
  }

  Widget _buildLessonCard(
    String title,
    String subtitle,
    double progress,
    bool unlocked,
    String emoji,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked ? _c.cardColor : _c.cardColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(unlocked ? 0.06 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: unlocked
              ? (progress > 0
                    ? lightGreen.withOpacity(0.3)
                    : lightGreen.withOpacity(0.15))
              : Colors.grey.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Emoji Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: unlocked
                  ? (progress > 0
                        ? lightGreen.withOpacity(0.12)
                        : orange.withOpacity(0.1))
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                unlocked ? emoji : '🔒',
                style: TextStyle(fontSize: unlocked ? 24 : 20),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: unlocked ? darkGreen : darkGreen.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: unlocked
                        ? darkGreen.withOpacity(0.5)
                        : darkGreen.withOpacity(0.3),
                  ),
                ),
                if (unlocked && progress > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: lightGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [darkGreen, lightGreen],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: darkGreen.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Arrow or Lock
          if (unlocked)
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: darkGreen.withOpacity(0.3),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String emoji) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: darkGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildCelebrationCard() {
    final isBday = _isBirthday;
    final holiday = _todayHoliday;

    // Determine content
    String title;
    String message;
    String emoji;
    List<Color> gradientColors;

    if (isBday) {
      title = 'Doğum Günün Kutlu Olsun! 🎉';
      message = 'Harika bir gün geçirmeni diliyoruz, $_userName! 🥳🎂';
      emoji = '🎂';
      gradientColors = [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)];
    } else if (holiday != null) {
      title = holiday.title;
      message = holiday.message;
      emoji = holiday.emoji;
      gradientColors = [darkGreen, const Color(0xFF2A8A6E)];
    } else {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _celebrationConfettiController.play(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Emoji row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 8),
                if (isBday) ...[
                  const Text('🎈', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 8),
                  const Text('🎉', style: TextStyle(fontSize: 28)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Message
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (isBday) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (_) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Text('🎈', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContinueLearningCard() {
    // Calculate actual progress
    final completedInCurrentLevel =
        _completedLessonsByLevel[_englishLevel] ?? 0;
    final totalLessonsInLevel = 25;
    final progressPercent =
        (completedInCurrentLevel / totalLessonsInLevel * 100).round();
    final currentLessonNumber = completedInCurrentLevel + 1;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = 0; // Switch to Learn page
          _expandedLevel = _englishLevel; // Open user's level
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [darkGreen, const Color(0xFF2A8A6E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: darkGreen.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            // Duck Avatar
            Container(
              width: 70,
              height: 70,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.asset('assets/duckavatar.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 16),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.get('home_continue_where'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentLessonNumber <= totalLessonsInLevel
                        ? S.get(
                            'home_level_lesson',
                            args: {
                              'level': _englishLevel,
                              'n': currentLessonNumber.toString(),
                            },
                          )
                        : S.get(
                            'home_level_complete',
                            args: {'level': _englishLevel},
                          ),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Progress
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progressPercent / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: lightOrange,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$progressPercent%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: lightOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Play Button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: orange,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: orange.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyGoalsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: lightGreen.withOpacity(0.12), width: 1.5),
      ),
      child: Row(
        children: [
          _buildGoalItem(
            '🔥',
            '$_currentStreak',
            S.get('home_day_streak'),
            _currentStreak > 0,
          ),
          _buildGoalDivider(),
          _buildGoalItem(
            '📚',
            '${_completedLessonsByLevel[_englishLevel] ?? 0}/25',
            S.get('home_lessons'),
            (_completedLessonsByLevel[_englishLevel] ?? 0) > 0,
          ),
          _buildGoalDivider(),
          _buildGoalItem(
            '⭐',
            '$_currentXP',
            S.get('home_total_xp'),
            _currentXP > 0,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalItem(
    String emoji,
    String value,
    String label,
    bool completed,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: completed ? darkGreen : darkGreen.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: darkGreen.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalDivider() {
    return Container(width: 1, height: 50, color: lightGreen.withOpacity(0.15));
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionCard(
            '📖',
            S.get('home_vocabulary'),
            S.get('home_vocabulary_desc'),
            lightGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VocabularyScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionCard(
            '🎧',
            S.get('home_listening'),
            S.get('home_listening_desc'),
            orange,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String emoji,
    String title,
    String subtitle,
    Color accentColor, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _c.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: accentColor.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: accentColor == lightGreen ? darkGreen : accentColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: darkGreen.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesPage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildSectionTitle(S.get('home_mini_games'), '🎮'),
          const SizedBox(height: 16),

          _buildGameCard(
            S.get('home_fast_word'),
            S.get('home_fast_word_desc'),
            '⚡',
            lightGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FastWordGameScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildGameCard(
            S.get('home_true_false'),
            S.get('home_true_false_desc'),
            '✅',
            darkGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TrueFalseGameScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildGameCard(
            S.get('home_word_match'),
            S.get('home_word_match_desc'),
            '🧩',
            lightOrange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WordMatchGameScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGameCard(
    String title,
    String subtitle,
    String emoji,
    Color accentColor, {
    bool comingSoon = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: comingSoon ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: comingSoon ? _c.cardColor.withOpacity(0.6) : _c.cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(comingSoon ? 0.05 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: accentColor.withOpacity(comingSoon ? 0.1 : 0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(comingSoon ? 0.08 : 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: comingSoon
                              ? darkGreen.withOpacity(0.4)
                              : darkGreen,
                        ),
                      ),
                      if (comingSoon) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            S.get('home_coming_soon'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: orange,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: darkGreen.withOpacity(comingSoon ? 0.3 : 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (!comingSoon)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestsPage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildSectionTitle(S.get('home_daily_quests'), '📋'),
          const SizedBox(height: 16),

          // Dynamic daily quests from JSON
          ..._dailyQuests.map(
            (quest) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildDynamicQuestCard(quest),
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionTitle(S.get('home_weekly_quests'), '🌟'),
          const SizedBox(height: 16),

          // Dynamic weekly quests from JSON
          ..._weeklyQuests.map(
            (quest) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildDynamicQuestCard(quest),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDynamicQuestCard(QuestTask quest) {
    return FutureBuilder<int>(
      future: QuestService.evaluateQuestProgress(quest),
      builder: (context, snapshot) {
        final current = snapshot.data ?? 0;
        return _buildQuestCard(
          quest.id,
          quest.title,
          quest.description,
          current,
          quest.target,
          quest.xp,
        );
      },
    );
  }

  Widget _buildQuestCard(
    String questId,
    String title,
    String subtitle,
    int current,
    int total,
    int xpReward,
  ) {
    final double progress = (current / total).clamp(0.0, 1.0);
    final bool isCompleted = current >= total;
    final bool isClaimed = _claimedQuests.contains(questId);
    final bool canCollect = isCompleted && !isClaimed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isClaimed
            ? Colors.grey.withOpacity(0.05)
            : canCollect
            ? lightGreen.withOpacity(0.12)
            : _c.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (canCollect ? lightGreen : darkGreen).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: canCollect
              ? lightGreen.withOpacity(0.5)
              : lightGreen.withOpacity(0.15),
          width: canCollect ? 2 : 1.5,
        ),
      ),
      child: Row(
        children: [
          // Check or Progress circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isClaimed
                  ? Colors.grey.withOpacity(0.2)
                  : isCompleted
                  ? lightGreen.withOpacity(0.2)
                  : lightGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isClaimed
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.grey,
                      size: 24,
                    )
                  : isCompleted
                  ? Icon(Icons.check_rounded, color: lightGreen, size: 24)
                  : Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: darkGreen.withOpacity(0.7),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isClaimed
                        ? Colors.grey
                        : canCollect
                        ? darkGreen
                        : darkGreen.withOpacity(0.8),
                    decoration: isClaimed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isClaimed
                      ? S.get('home_quest_done')
                      : '$current / $total - $subtitle',
                  style: TextStyle(
                    fontSize: 12,
                    color: isClaimed ? Colors.grey : darkGreen.withOpacity(0.5),
                  ),
                ),
                if (!isCompleted) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: lightGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [darkGreen, lightGreen],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Collect Button or XP Badge
          if (canCollect)
            GestureDetector(
              onTap: () async {
                // Record task completion
                await UserPreferences.recordTaskCompleted();

                // Award XP
                final oldLevel = _level;
                final newXP = await UserPreferences.addXP(xpReward);
                final newLevel = await UserPreferences.getUserLevel();
                await UserPreferences.markQuestClaimed(questId);
                final leveledUp = newLevel > oldLevel;

                // Update state
                setState(() {
                  _claimedQuests.add(questId);
                  _currentXP = newXP;
                  _level = newLevel;
                });

                // Trigger confetti celebration
                _triggerConfetti();

                // Reload quests to check for new completions
                await _loadQuests();

                // Show success message
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        leveledUp
                            ? S.get(
                                'home_xp_level_up',
                                args: {'xp': xpReward.toString()},
                              )
                            : S.get(
                                'home_xp_earned',
                                args: {'xp': xpReward.toString()},
                              ),
                      ),
                      backgroundColor: leveledUp ? orange : lightGreen,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [lightGreen, const Color(0xFF81C784)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: lightGreen.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      S.get('home_collect'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isClaimed
                    ? Colors.grey.withOpacity(0.1)
                    : orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isClaimed ? '✓' : '+$xpReward',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isClaimed ? Colors.grey : orange,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'XP',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isClaimed
                          ? Colors.grey.withOpacity(0.7)
                          : orange.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAchievementsPage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildSectionTitle(S.get('home_achievements'), '🏆'),
          const SizedBox(height: 16),

          // Achievement Grid
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              // Increase tile height to avoid bottom overflow on smaller screens
              childAspectRatio: 0.9,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _achievements.length,
            itemBuilder: (context, index) {
              final achievement = _achievements[index];
              final isCompleted = _completedAchievements.contains(
                achievement.idString,
              );
              final emoji = AchievementService.getEmojiForCondition(
                achievement.condition,
              );

              return FutureBuilder<int>(
                future: AchievementService.evaluateAchievementProgress(
                  achievement,
                ),
                builder: (context, snapshot) {
                  final progress = snapshot.data ?? 0;
                  return _buildAchievementCard(
                    achievement.title,
                    emoji,
                    achievement.description,
                    isCompleted,
                    progress,
                    achievement.target,
                  );
                },
              );
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(
    String title,
    String emoji,
    String description,
    bool unlocked,
    int progress,
    int target,
  ) {
    final progressPercent = target > 0
        ? (progress / target).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked ? _c.cardColor : _c.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (unlocked ? orange : darkGreen).withOpacity(
              unlocked ? 0.1 : 0.04,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: unlocked
              ? orange.withOpacity(0.25)
              : Colors.grey.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: unlocked
                  ? orange.withOpacity(0.12)
                  : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                unlocked ? emoji : '🔒',
                style: TextStyle(fontSize: unlocked ? 26 : 20),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: unlocked ? darkGreen : darkGreen.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: unlocked
                  ? darkGreen.withOpacity(0.5)
                  : darkGreen.withOpacity(0.3),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!unlocked) ...[
            const SizedBox(height: 6),
            // Progress bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progressPercent,
                child: Container(
                  decoration: BoxDecoration(
                    color: orange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$progress / $target',
              style: TextStyle(
                fontSize: 9,
                color: darkGreen.withOpacity(0.4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: _c.cardColor,
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _buildNavItem(
                  0,
                  Icons.menu_book_rounded,
                  S.get('home_tab_learn'),
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  1,
                  Icons.sports_esports_rounded,
                  S.get('home_tab_games'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildCenterDuckButton(),
              ),
              Expanded(
                child: _buildNavItem(
                  3,
                  Icons.assignment_rounded,
                  S.get('home_tab_quests'),
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  4,
                  Icons.emoji_events_rounded,
                  S.get('home_tab_achievements'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterDuckButton() {
    final isSelected = _currentIndex == 2;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 2),
      child: AnimatedBuilder(
        animation: _duckPulseController,
        builder: (context, child) {
          final pulse = isSelected
              ? 1.0 + (_duckPulseController.value * 0.04)
              : 1.0;

          return Transform.scale(
            scale: pulse,
            child: Container(
              width: 68,
              height: 68,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: cream,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: darkGreen.withOpacity(0.2),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: darkGreen.withOpacity(isSelected ? 0.15 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: isSelected ? darkGreen : lightGreen.withOpacity(0.5),
                  width: 3,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  'assets/duckavatar.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? darkGreen.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? darkGreen : darkGreen.withOpacity(0.35),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? darkGreen : darkGreen.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Floating bubble data class
class _FloatingBubble {
  final double x;
  final double y;
  final double size;
  final double speed;
  final Color color;
  final double wobbleOffset;
  final double wobbleSpeed;

  _FloatingBubble({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
    required this.wobbleOffset,
    required this.wobbleSpeed,
  });
}

// Custom painter for floating bubbles
class _BubblePainter extends CustomPainter {
  final List<_FloatingBubble> bubbles;
  final double animationValue;

  _BubblePainter({required this.bubbles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (final bubble in bubbles) {
      final paint = Paint()
        ..color = bubble.color
        ..style = PaintingStyle.fill;

      final time = animationValue * 2 * pi;
      final yMovement = sin(time * bubble.speed + bubble.wobbleOffset) * 0.08;
      final xWobble = sin(time * bubble.wobbleSpeed + bubble.wobbleOffset) * 15;

      final x = bubble.x * size.width + xWobble;
      final y = (bubble.y + yMovement) * size.height;

      canvas.drawCircle(Offset(x, y), bubble.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// Custom painter for star shape
class _StarPainter extends CustomPainter {
  final Color fillColor;
  final Color strokeColor;
  final Color shadowColor;

  _StarPainter({
    required this.fillColor,
    required this.strokeColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.45;

    // Create star path
    final path = Path();
    const points = 5;
    const rotation = -pi / 2; // Start from top

    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (i * pi / points) + rotation;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Draw shadow - more subtle
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);

    // Draw gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [fillColor, strokeColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Draw highlight - reduced opacity
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.center,
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, highlightPaint);

    // Draw subtle border
    final strokePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) {
    return fillColor != oldDelegate.fillColor;
  }
}

// Custom painter for dotted line connector
class _DottedLinePainter extends CustomPainter {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final Color color;
  final bool isCompleted;

  _DottedLinePainter({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.color,
    required this.isCompleted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = isCompleted ? 4 : 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Create curved path
    final path = Path();
    path.moveTo(startX, startY);

    // Calculate control points for smooth curve
    final midY = (startY + endY) / 2;
    final controlPoint1 = Offset(startX, midY);
    final controlPoint2 = Offset(endX, midY);

    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      endX,
      endY,
    );

    // Draw dotted path
    _drawDottedPath(canvas, path, paint);
  }

  void _drawDottedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final pathMetrics = path.computeMetrics();

    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final start = metric.getTangentForOffset(distance);
        final end = metric.getTangentForOffset(distance + dashWidth);

        if (start != null && end != null) {
          canvas.drawLine(start.position, end.position, paint);
        }

        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) {
    return color != oldDelegate.color || isCompleted != oldDelegate.isCompleted;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Beautiful Lesson Bottom Sheet Widget
// ────────────────────────────────────────────────────────────────────────────

class _LessonBottomSheet extends StatefulWidget {
  final String level;
  final int lessonInLevel;
  final String title;
  final bool isCompleted;
  final VoidCallback onStart;

  const _LessonBottomSheet({
    required this.level,
    required this.lessonInLevel,
    required this.title,
    required this.isCompleted,
    required this.onStart,
  });

  @override
  State<_LessonBottomSheet> createState() => _LessonBottomSheetState();
}

class _LessonBottomSheetState extends State<_LessonBottomSheet>
    with TickerProviderStateMixin {
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get lightGreen => _c.lightGreen;
  Color get orange => _c.orange;
  Color get lightOrange => _c.lightOrange;

  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> _exercises = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideController.forward();
    _loadExercisePreview();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadExercisePreview() async {
    try {
      final jsonString = await rootBundle.loadString(
        'json/${widget.level}_exercises.json',
      );
      final List<dynamic> allLessons = json.decode(jsonString);
      final targetId = widget.lessonInLevel - 1;

      final lessonData = allLessons.firstWhere(
        (l) => (l['lessonId'] ?? l['id']).toString() == targetId.toString(),
        orElse: () => null,
      );

      if (lessonData != null && mounted) {
        final exercises = lessonData['exercises'] as List<dynamic>? ?? [];
        setState(() {
          _exercises = exercises.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error loading exercise preview: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, int> _getExerciseTypeCounts() {
    final counts = <String, int>{};
    for (final ex in _exercises) {
      final type = ex['type'] as String? ?? 'unknown';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  static const Map<String, IconData> _typeIcons = {
    'quiz': Icons.quiz_rounded,
    'fill_blank': Icons.text_fields_rounded,
    'word_order': Icons.sort_rounded,
    'translation': Icons.translate_rounded,
    'speaking': Icons.mic_rounded,
    'matching': Icons.compare_arrows_rounded,
  };

  Map<String, String> get _typeNames => {
    'quiz': S.get('home_multiple_choice'),
    'fill_blank': S.get('home_fill_blank'),
    'word_order': S.get('home_word_order'),
    'translation': S.get('home_translation'),
    'speaking': S.get('home_speaking'),
    'matching': S.get('home_matching'),
  };

  static const Map<String, Color> _typeColors = {
    'quiz': Color(0xFF4CAF50),
    'fill_blank': Color(0xFF2196F3),
    'word_order': Color(0xFFFF9800),
    'translation': Color(0xFF9C27B0),
    'speaking': Color(0xFFE91E63),
    'matching': Color(0xFF00BCD4),
  };

  String _getEmojiForLevel(String level) {
    switch (level) {
      case 'A1':
        return '🐣';
      case 'A2':
        return '🦆';
      case 'B1':
        return '🦅';
      case 'B2':
        return '🦉';
      case 'C1':
        return '👑';
      default:
        return '📚';
    }
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _getEmojiForLevel(widget.level);

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return FadeTransition(opacity: _fadeAnimation, child: child);
      },
      child: Container(
        decoration: BoxDecoration(
          color: _c.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _c.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Header with emoji, level badge, and title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Emoji with glow
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = 1.0 + (_pulseController.value * 0.08);
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: widget.isCompleted
                                  ? [lightGreen, lightGreen.withOpacity(0.7)]
                                  : [
                                      orange.withOpacity(0.15),
                                      lightOrange.withOpacity(0.08),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (widget.isCompleted ? lightGreen : orange)
                                        .withOpacity(0.25),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: widget.isCompleted
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    size: 44,
                                    color: Colors.white,
                                  )
                                : Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 40),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Level badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [darkGreen, lightGreen],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          S.get(
                            'home_lesson_detail',
                            args: {
                              'level': widget.level,
                              'n': widget.lessonInLevel.toString(),
                            },
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Title
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: darkGreen,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),

                      // Status text
                      Text(
                        widget.isCompleted
                            ? S.get('home_lesson_done_msg')
                            : S.get('home_lesson_start_msg'),
                        style: TextStyle(
                          fontSize: 13,
                          color: darkGreen.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Exercise types preview
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                else if (_exercises.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              S.get(
                                'home_activities',
                                args: {'n': _exercises.length.toString()},
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: darkGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Exercise type chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _getExerciseTypeCounts().entries.map((
                            entry,
                          ) {
                            final icon =
                                _typeIcons[entry.key] ??
                                Icons.extension_rounded;
                            final name = _typeNames[entry.key] ?? entry.key;
                            final color = _typeColors[entry.key] ?? Colors.grey;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: color.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, size: 16, color: color),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$name (${entry.value})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: color.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Start button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: widget.onStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isCompleted
                            ? lightGreen
                            : orange,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: (widget.isCompleted ? lightGreen : orange)
                            .withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isCompleted
                                ? Icons.replay_rounded
                                : Icons.play_arrow_rounded,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.isCompleted
                                ? S.get('home_redo')
                                : S.get('home_start_lesson'),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
