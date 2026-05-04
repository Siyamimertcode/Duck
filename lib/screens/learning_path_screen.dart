import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../services/user_preferences.dart';
import '../services/lesson_service.dart';
import '../services/duck_theme.dart';
import '../services/app_localizations.dart';
import 'exercise_screen.dart';

class LearningPathScreen extends StatefulWidget {
  const LearningPathScreen({super.key});

  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen>
    with TickerProviderStateMixin {
  static const List<String> _levelOrder = ['A1', 'A2', 'B1', 'B2', 'C1'];
  static const int _lessonsPerLevel = 25;

  // Dynamic theme colors
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get lightGreen => _c.lightGreen;
  Color get orange => _c.orange;
  Color get lightOrange => _c.lightOrange;
  Color get cream => _c.cream;

  // User state
  String currentLevel = 'A1';
  List<String> completedLevels = [];
  int completedLessons = 0; // Track completed lesson count
  String? expandedLevel; // Track which level is expanded to show lessons
  // Per-level progress and unlocked levels
  final Map<String, int> _levelProgress = {
    for (final level in _levelOrder) level: 0,
  };
  List<String> _unlockedLevels = ['A1'];

  // Animation Controllers
  late final AnimationController _bubbleController;
  late final AnimationController _pathAnimController;
  late ConfettiController _confettiControllerLeft;
  late ConfettiController _confettiControllerRight;

  // Floating bubbles data
  final List<_FloatingBubble> _bubbles = [];

  // Generated lessons
  List<Map<String, dynamic>> _allLessons = [];

  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _loadLessonsFromJson();
    _loadUserProgress();

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pathAnimController = AnimationController(
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _initBubbles();
    }
  }

  Future<void> _loadLessonsFromJson() async {
    final lessons = await LessonService.getAllLessons();
    if (mounted) {
      setState(() {
        _allLessons = lessons;
      });
    }
  }

  Future<void> _loadUserProgress() async {
    final level = await UserPreferences.getCurrentLevel();
    final completed = await UserPreferences.getCompletedLevels();
    final progressMap = await UserPreferences.getAllLevelLessonProgress();
    final unlockedRaw = await UserPreferences.getUnlockedLevels();
    final currentLessonNum = await UserPreferences.getCurrentLessonNumber();

    if (!unlockedRaw.contains(level)) {
      unlockedRaw.add(level);
    }

    if (!mounted) return;

    setState(() {
      currentLevel = level;
      completedLevels = completed;
      _levelProgress
        ..clear()
        ..addEntries(
          _levelOrder.map((lv) => MapEntry(lv, progressMap[lv] ?? 0)),
        );

      completedLessons = _levelProgress.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
      _unlockedLevels = _mergeUnlockedLevels(unlockedRaw);
    });

    // Print current lesson for debugging
    debugPrint('📚 Kaydedilmiş ders numarası: $currentLessonNum');
  }

  Future<void> _loadLessonsAndProgress() async {
    await _loadLessonsFromJson();
    await _loadUserProgress();
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

  @override
  void dispose() {
    _bubbleController.dispose();
    _pathAnimController.dispose();
    _confettiControllerLeft.dispose();
    _confettiControllerRight.dispose();
    super.dispose();
  }

  bool _isLessonCompletedInLevel(Map<String, dynamic> lesson) {
    final level = lesson['level'] as String;
    final lessonInLevel = lesson['lessonInLevel'] as int;
    final progress = _levelProgress[level] ?? 0;
    return lessonInLevel <= progress;
  }

  bool _isLessonCurrentInLevel(Map<String, dynamic> lesson) {
    final level = lesson['level'] as String;
    final lessonInLevel = lesson['lessonInLevel'] as int;
    final progress = _levelProgress[level] ?? 0;
    return _unlockedLevels.contains(level) && lessonInLevel == progress + 1;
  }

  bool _isLessonLocked(Map<String, dynamic> lesson) {
    final level = lesson['level'] as String;
    return !_unlockedLevels.contains(level);
  }

  List<String> _mergeUnlockedLevels(List<String> storedLevels) {
    final ordered = <String>[];
    final seen = <String>{};
    for (final level in _levelOrder) {
      if (storedLevels.contains(level) && seen.add(level)) {
        ordered.add(level);
      }
    }
    if (!ordered.contains('A1')) {
      ordered.insert(0, 'A1');
    }
    return ordered;
  }

  String? _nextLevel(String level) {
    final index = _levelOrder.indexOf(level);
    if (index == -1 || index >= _levelOrder.length - 1) return null;
    return _levelOrder[index + 1];
  }

  int _levelProgressValue(String level) => _levelProgress[level] ?? 0;

  bool _isLevelCompleted(String level) =>
      _levelProgressValue(level) >= _lessonsPerLevel;

  String _levelStatusText(String level) {
    if (!_unlockedLevels.contains(level)) {
      return S.get('lp_locked_emoji');
    }

    final progress = _levelProgressValue(level);
    if (progress >= _lessonsPerLevel) {
      return S.get('lp_completed_check');
    }

    return S.get(
      'lp_lesson_progress',
      args: {'p': '$progress', 'total': '$_lessonsPerLevel'},
    );
  }

  /// Returns a short status like "A2 · Ders 17" for display
  String _currentLevelSummary() {
    final progress = _levelProgressValue(currentLevel);
    if (progress >= _lessonsPerLevel) {
      return S.get('lp_level_progress', args: {'level': currentLevel});
    }
    return S.get(
      'lp_level_in_progress',
      args: {
        'level': currentLevel,
        'p': '$progress',
        'total': '$_lessonsPerLevel',
      },
    );
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

            // Main content
            Column(
              children: [
                // Top bar
                _buildTopBar(),

                // Learning path
                Expanded(child: _buildLearningPath()),
              ],
            ),

            // Confetti widgets
            Align(
              alignment: Alignment.topLeft,
              child: ConfettiWidget(
                confettiController: _confettiControllerLeft,
                blastDirection: pi / 4,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.3,
                colors: [
                  darkGreen,
                  lightGreen,
                  orange,
                  lightOrange,
                  Colors.yellow,
                  Colors.pink,
                ],
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: ConfettiWidget(
                confettiController: _confettiControllerRight,
                blastDirection: 3 * pi / 4,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.3,
                colors: [
                  darkGreen,
                  lightGreen,
                  orange,
                  lightOrange,
                  Colors.yellow,
                  Colors.pink,
                ],
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 28),
            color: darkGreen,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.get('lp_title'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
                Text(
                  S.get('lp_subtitle'),
                  style: TextStyle(
                    fontSize: 14,
                    color: darkGreen.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: orange.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  '5',
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

  Widget _buildLearningPath() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress summary card
          _buildProgressCard(),
          const SizedBox(height: 30),

          // Candy Crush style lesson path
          _buildLessonPath(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final totalLessons = _levelOrder.length * _lessonsPerLevel;
    final progress = totalLessons > 0 ? completedLessons / totalLessons : 0.0;
    final emoji = LessonService.getEmojiForLevel(currentLevel);
    final currentStatus = _levelStatusText(currentLevel);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [darkGreen, lightGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.get('lp_active_level'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$emoji  $currentLevel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentStatus,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Column(
                  children: [
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedLessons / $totalLessons',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            S.get('lp_level_status'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildLevelProgressChips(),
        ],
      ),
    );
  }

  Widget _buildLevelProgressChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _levelOrder.map(_buildLevelChip).toList(),
    );
  }

  Widget _buildLevelChip(String level) {
    final statusText = _levelStatusText(level);
    final isCompleted = _isLevelCompleted(level);
    final isUnlocked = _unlockedLevels.contains(level);
    final emoji = LessonService.getEmojiForLevel(level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isCompleted ? 0.35 : 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(isCompleted ? 0.7 : 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    level,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isCompleted)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isUnlocked ? statusText : S.get('lp_locked'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLessonPath() {
    // Build Candy Crush style path
    final pathItems = <Widget>[];

    for (int i = 0; i < _allLessons.length; i++) {
      final lesson = _allLessons[i];
      final isCompleted = _isLessonCompletedInLevel(lesson);
      final isCurrent = _isLessonCurrentInLevel(lesson);
      final isLocked = _isLessonLocked(lesson);

      // Add level header at the start of each level block
      if (i % _lessonsPerLevel == 0) {
        pathItems.add(_buildLevelHeader(lesson['level'] as String));
      }

      // Calculate position (zigzag pattern)
      final rowInLevel = (i % _lessonsPerLevel) ~/ 3; // 3 lessons per row
      final colInRow = i % 3;
      final isEvenRow = rowInLevel % 2 == 0;

      // Add row container
      if (colInRow == 0) {
        final lessonsInRow = <Widget>[];

        for (int j = 0; j < 3 && (i + j) < _allLessons.length; j++) {
          final currentLesson = _allLessons[i + j];
          final lessonCompleted = _isLessonCompletedInLevel(currentLesson);
          final lessonCurrent = _isLessonCurrentInLevel(currentLesson);
          final lessonLocked = _isLessonLocked(currentLesson);

          if (j > 0) {
            lessonsInRow.add(_buildConnector(lessonCompleted));
          }

          lessonsInRow.add(
            _buildLessonNode(
              lesson: currentLesson,
              isCompleted: lessonCompleted,
              isCurrent: lessonCurrent,
              isLocked: lessonLocked,
            ),
          );
        }

        pathItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: isEvenRow
                  ? lessonsInRow
                  : lessonsInRow.reversed.toList(),
            ),
          ),
        );
      }
    }

    return Column(children: pathItems);
  }

  Widget _buildLevelHeader(String level) {
    final emoji = LessonService.getEmojiForLevel(level);
    final statusText = _levelStatusText(level);
    return Container(
      margin: const EdgeInsets.only(bottom: 20, top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [orange.withOpacity(0.8), lightOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: orange.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.get('lp_level_n', args: {'level': level}),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  S.get(
                    'lp_lessons_status',
                    args: {'total': '$_lessonsPerLevel', 'status': statusText},
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLessonNode({
    required Map<String, dynamic> lesson,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLocked,
  }) {
    const size = 55.0;
    final level = lesson['level'] as String;
    final levelColor = LessonService.getColorForLevel(level);
    final emoji = LessonService.getEmojiForLevel(level);
    final bool isAccessible = !isLocked && (isCompleted || isCurrent);

    return GestureDetector(
      onTap: isAccessible
          ? () => _onLessonTap(lesson['lessonNumber'], level)
          : null,
      child: AnimatedBuilder(
        animation: _pathAnimController,
        builder: (context, child) {
          final scale = isCurrent
              ? 1.0 + (_pathAnimController.value * 0.08)
              : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isLocked
                ? Colors.grey.shade300
                : isCompleted
                ? lightGreen
                : isCurrent
                ? orange
                : _c.cardColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: isLocked
                  ? Colors.grey.shade400
                  : isCompleted
                  ? darkGreen
                  : isCurrent
                  ? orange
                  : levelColor.withOpacity(0.5),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (isCompleted
                            ? lightGreen
                            : isCurrent
                            ? orange
                            : levelColor)
                        .withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: isLocked
                    ? Icon(
                        Icons.lock_rounded,
                        size: 24,
                        color: Colors.grey.shade600,
                      )
                    : isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        size: 28,
                        color: Colors.white,
                      )
                    : Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
              if (!isLocked)
                Positioned(
                  bottom: 4,
                  right: 0,
                  left: 0,
                  child: Center(
                    child: Text(
                      '${lesson['lessonInLevel']}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isCompleted || isCurrent
                            ? Colors.white
                            : levelColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnector(bool isCompleted) {
    return Container(
      width: 30,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isCompleted ? lightGreen : darkGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  void _onLessonTap(int lessonNumber, String level) {
    final lesson = _allLessons.firstWhere(
      (l) => l['lessonNumber'] == lessonNumber,
      orElse: () => {},
    );

    if (lesson.isEmpty) return;

    final title =
        lesson['title'] ?? S.get('lp_lesson_n', args: {'n': '$lessonNumber'});
    final levelDescription = lesson['levelDescription'] ?? '';
    final lessonInLevel = lesson['lessonInLevel'] as int? ?? 1;
    final isAlreadyCompleted = _isLessonCompletedInLevel(lesson);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(
              LessonService.getEmojiForLevel(level),
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                '$level - $levelDescription',
                style: TextStyle(
                  fontSize: 13,
                  color: orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              S.get(
                'lp_lesson_progress',
                args: {'p': '$lessonInLevel', 'total': '$_lessonsPerLevel'},
              ),
              style: TextStyle(
                fontSize: 14,
                color: darkGreen.withValues(alpha: 0.7),
              ),
            ),
            if (isAlreadyCompleted) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: lightGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: lightGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      S.get('lp_completed'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: darkGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.get('lp_close'), style: TextStyle(color: darkGreen)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToExercise(
                level: level,
                lessonInLevel: lessonInLevel,
                title: title,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isAlreadyCompleted ? S.get('lp_redo') : S.get('lp_start'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToExercise({
    required String level,
    required int lessonInLevel,
    required String title,
  }) async {
    debugPrint('👉 Navigating to exercise: $level - Lesson $lessonInLevel');

    // Capture progress before exercise to detect level completion.
    final progressBefore = _levelProgressValue(level);

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseScreen(
          level: level,
          lessonInLevel: lessonInLevel,
          title: title,
        ),
      ),
    );

    if (!mounted) return;

    // Reload progress when returning from exercise screen.
    if (result == true) {
      debugPrint('🔙 Returning from completed exercise. Reloading progress...');
      await _loadLessonsAndProgress();

      // Check if a level was just completed (went from <25 to 25).
      final progressAfter = _levelProgressValue(level);
      debugPrint(
        '📊 Progress check: Before=$progressBefore, After=$progressAfter (Target=$_lessonsPerLevel)',
      );

      if (progressBefore < _lessonsPerLevel &&
          progressAfter >= _lessonsPerLevel) {
        debugPrint('🎉 Level completion detected! Showing celebration.');
        final nextLevel = _nextLevel(level);
        await _showLevelCompletionCelebration(level, nextLevel: nextLevel);
      }
    } else {
      debugPrint('🔙 Returned without completing lesson (result: $result)');
    }
  }

  Future<void> _showLevelCompletionCelebration(
    String completedLevel, {
    String? nextLevel,
  }) async {
    // Trigger confetti
    _confettiControllerLeft.play();
    _confettiControllerRight.play();
    final hasNextLevel = nextLevel != null;

    // Show celebration dialog
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [lightGreen.withOpacity(0.1), orange.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Trophy or celebration icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: orange.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  S.get('lp_congrats'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  S.get('lp_level_done', args: {'level': completedLevel}),
                  style: TextStyle(
                    fontSize: 16,
                    color: darkGreen.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (hasNextLevel) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: lightGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: lightGreen, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          S.get('lp_next_level'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: darkGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              LessonService.getEmojiForLevel(nextLevel!),
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              nextLevel,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: darkGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          S.get(
                            'lp_next_lesson',
                            args: {'total': '$_lessonsPerLevel'},
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: darkGreen.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!hasNextLevel) ...[
                  const SizedBox(height: 20),
                  Text(
                    S.get('lp_all_done'),
                    style: TextStyle(
                      fontSize: 14,
                      color: darkGreen.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    // Update current level to next level
                    if (hasNextLevel) {
                      await UserPreferences.saveCurrentLevel(nextLevel!);
                      setState(() {
                        currentLevel = nextLevel;
                        _unlockedLevels = _mergeUnlockedLevels([
                          ..._unlockedLevels,
                          nextLevel,
                        ]);
                        _levelProgress.putIfAbsent(nextLevel, () => 0);
                      });
                    }

                    // Reload the learning path
                    await _loadLessonsAndProgress();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    hasNextLevel ? S.get('lp_go_next') : S.get('lp_awesome'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
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

// Bubble painter
class _BubblePainter extends CustomPainter {
  final List<_FloatingBubble> bubbles;
  final double animationValue;

  _BubblePainter({required this.bubbles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (var bubble in bubbles) {
      final paint = Paint()
        ..color = bubble.color
        ..style = PaintingStyle.fill;

      final offsetY = (animationValue * bubble.speed) % 1.0;
      final wobble =
          sin(
            (animationValue * bubble.wobbleSpeed + bubble.wobbleOffset) *
                2 *
                pi,
          ) *
          15;

      final x = bubble.x * size.width + wobble;
      final y = ((bubble.y + offsetY) % 1.0) * size.height;

      canvas.drawCircle(Offset(x, y), bubble.size, paint);
    }
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => true;
}
