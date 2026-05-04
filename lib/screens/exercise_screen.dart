import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, rootBundle;
import 'package:confetti/confetti.dart';
import 'package:duck/services/progress_service.dart';
import 'package:duck/services/user_preferences.dart';
import 'package:duck/services/tts_service.dart';
import 'package:duck/services/sound_service.dart';
import 'package:duck/widgets/exercises/quiz_exercise.dart';
import 'package:duck/widgets/exercises/fill_blank_exercise.dart';
import 'package:duck/widgets/exercises/word_order_exercise.dart';
import 'package:duck/widgets/exercises/speaking_exercise.dart';
import 'package:duck/widgets/exercises/translation_exercise.dart';
import 'package:duck/widgets/exercises/matching_exercise.dart';
import '../services/duck_theme.dart';
import '../services/app_localizations.dart';

class ExerciseScreen extends StatefulWidget {
  /// The language level this lesson belongs to (e.g. 'A1', 'B2').
  final String level;

  /// 1‑based lesson index within the level (1–25).
  final int lessonInLevel;

  /// Human‑readable lesson title.
  final String title;

  const ExerciseScreen({
    super.key,
    required this.level,
    required this.lessonInLevel,
    required this.title,
  });

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with TickerProviderStateMixin {
  List<dynamic> _exercises = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _error;

  // Progress tracking
  int _correctCount = 0;
  int _wrongCount = 0;
  final List<Map<String, String>> _wrongAnswers = [];
  bool _showResults = false;
  int _currentStreak = 0;
  int _bestStreak = 0;

  // Duolingo-style feedback state
  bool _showFeedback = false;
  bool _lastAnswerCorrect = false;
  bool _showCorrectAnswer = false;
  String _correctAnswerText = '';

  late ConfettiController _confettiController;

  // Animation controllers
  late AnimationController _feedbackSlideController;
  late AnimationController _correctAnswerFadeController;
  late AnimationController _progressPulseController;
  late AnimationController _exerciseTransitionController;
  late AnimationController _streakController;
  late Animation<Offset> _feedbackSlideAnimation;
  late Animation<double> _correctAnswerFadeAnimation;

  // Brand colors (dynamic from theme)
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get orange => _c.orange;
  Color get successGreen => _c.successGreen;
  Color get errorRed => _c.wrongRed;

  final SoundService _soundService = SoundService();

  /// Whether the current lesson is the alphabet unit (lesson 1 = lessonId 0).
  bool get _isAlphabetLesson =>
      widget.lessonInLevel == 1 && widget.level == 'A1';

  // Exercise type helpers
  static String _exerciseTypeLabel(String type) {
    switch (type) {
      case 'quiz':
        return S.get('ex_multiple_choice');
      case 'fill_blank':
        return S.get('ex_fill_blank');
      case 'word_order':
        return S.get('ex_word_order');
      case 'speaking':
        return S.get('ex_speaking');
      case 'translation':
        return S.get('ex_translation');
      case 'matching':
        return S.get('ex_matching');
      default:
        return S.get('ex_exercise');
    }
  }

  static IconData _exerciseTypeIcon(String type) {
    switch (type) {
      case 'quiz':
        return Icons.quiz_rounded;
      case 'fill_blank':
        return Icons.edit_note_rounded;
      case 'word_order':
        return Icons.reorder_rounded;
      case 'speaking':
        return Icons.mic_rounded;
      case 'translation':
        return Icons.translate_rounded;
      case 'matching':
        return Icons.compare_arrows_rounded;
      default:
        return Icons.assignment_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _feedbackSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _feedbackSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _feedbackSlideController,
            curve: Curves.easeOutCubic,
          ),
        );

    _correctAnswerFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _correctAnswerFadeAnimation = CurvedAnimation(
      parent: _correctAnswerFadeController,
      curve: Curves.easeOut,
    );

    _progressPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _exerciseTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..value = 1.0;

    _streakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _loadExercises();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _feedbackSlideController.dispose();
    _correctAnswerFadeController.dispose();
    _progressPulseController.dispose();
    _exerciseTransitionController.dispose();
    _streakController.dispose();
    super.dispose();
  }

  // ── Load Exercises ───────────────────────────────────────────────────

  Future<void> _loadExercises() async {
    try {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
        _error = null;
      });

      debugPrint(
        '📚 Loading exercises for Level: ${widget.level}, Lesson: ${widget.lessonInLevel}',
      );

      // Load and decode JSON specifically as UTF-8 to handle Turkish characters
      final jsonString = await rootBundle.loadString(
        'json/${widget.level}_exercises.json',
      );
      final List<dynamic> allLessons = json.decode(jsonString);

      // Robust matching: ID can be int or string, target is 0-based
      final targetId = widget.lessonInLevel - 1;

      final lessonData = allLessons.firstWhere(
        (l) => (l['lessonId'] ?? l['id']).toString() == targetId.toString(),
        orElse: () => null,
      );

      if (lessonData == null) {
        debugPrint('📚 Error: Lesson ID $targetId not found in JSON');
        if (mounted) {
          setState(() {
            _error = S.get('ex_not_found', args: {'id': '$targetId'});
            _isLoading = false;
          });
        }
        return;
      }

      final exercises = lessonData['exercises'] as List<dynamic>?;
      if (exercises == null || exercises.isEmpty) {
        debugPrint('📚 Error: Exercises list is empty or null');
        if (mounted) {
          setState(() {
            _error = S.get('ex_preparing');
            _isLoading = false;
          });
        }
        return;
      }

      debugPrint(
        '📚 Successfully loaded ${exercises.length} exercises for Lesson $targetId',
      );

      if (mounted) {
        setState(() {
          _exercises = exercises;
          _isLoading = false;
          _speakCurrentQuestion();
        });
      }
    } catch (e, stack) {
      debugPrint('📚 EXCEPTION loading exercises: $e');
      debugPrint('📚 Stack: $stack');
      if (mounted) {
        setState(() {
          _error = S.get('ex_load_error', args: {'e': '$e'});
          _isLoading = false;
        });
      }
    }
  }

  // ── Answer Handling ──────────────────────────────────────────────────

  void _handleAnswer(bool isCorrect) {
    if (_showFeedback) return; // Prevent double submission

    final currentExercise = _exercises[_currentIndex] as Map<String, dynamic>;

    // Build correct answer text
    _correctAnswerText =
        currentExercise['answer'] as String? ??
        (currentExercise['correctOrder'] as List?)?.join(' ') ??
        '';

    if (isCorrect) {
      _correctCount++;
      _currentStreak++;
      if (_currentStreak > _bestStreak) _bestStreak = _currentStreak;
      if (_currentStreak >= 3) {
        _streakController.forward(from: 0);
        _soundService.playStreak();
      } else {
        _soundService.playCorrect();
      }
      HapticFeedback.lightImpact();
    } else {
      _wrongCount++;
      _currentStreak = 0;
      _soundService.playWrong();
      HapticFeedback.heavyImpact();
      // Record wrong answer details
      _wrongAnswers.add({
        'question': currentExercise['question'] as String? ?? '',
        'answer': _correctAnswerText,
        'type': (currentExercise['type'] as String?) ?? '',
      });
    }

    setState(() {
      _showFeedback = true;
      _lastAnswerCorrect = isCorrect;
      _showCorrectAnswer = false;
    });

    _feedbackSlideController.forward(from: 0);
  }

  /// User taps "Devam Et" (correct) or after seeing answer
  void _onContinue() {
    _feedbackSlideController.reverse().then((_) {
      if (!mounted) return;

      if (_currentIndex < _exercises.length - 1) {
        // Animate transition to next exercise
        _exerciseTransitionController.reverse().then((_) {
          if (!mounted) return;
          setState(() {
            _currentIndex++;
            _showFeedback = false;
            _showCorrectAnswer = false;
          });
          _exerciseTransitionController.forward();
          _speakCurrentQuestion();

          // Pulse progress bar
          _progressPulseController.forward(from: 0);
        });
      } else {
        setState(() {
          _showFeedback = false;
          _showCorrectAnswer = false;
        });
        _finishLesson();
      }
    });
  }

  /// User taps "Tekrar Dene" on wrong answer
  void _onRetry() {
    HapticFeedback.selectionClick();
    _feedbackSlideController.reverse().then((_) {
      if (!mounted) return;
      // Re-create the exercise by bumping a retry counter in the key
      setState(() {
        _showFeedback = false;
        _showCorrectAnswer = false;
        // Force widget rebuild with new key by toggling a hidden counter
        _retryCount++;
      });
    });
  }

  int _retryCount = 0;

  /// User taps "Doğru Cevabı Göster"
  void _onShowCorrectAnswer() {
    HapticFeedback.selectionClick();
    setState(() {
      _showCorrectAnswer = true;
    });
    _correctAnswerFadeController.forward(from: 0);
  }

  // ── Finish Lesson ────────────────────────────────────────────────────

  Future<void> _finishLesson() async {
    debugPrint(
      '🎓 Finishing Lesson: ${widget.level} - ${widget.lessonInLevel}',
    );

    // Persist progress through the centralized service.
    final progressService = ProgressService();
    final isLevelComplete = await progressService.completeLesson(
      widget.level,
      widget.lessonInLevel,
    );

    debugPrint('🎓 Lesson completed. Level Complete: $isLevelComplete');

    // Award XP based on performance
    final successRate = _correctCount / (_correctCount + _wrongCount);
    final xp = successRate >= 0.8 ? 20 : (successRate >= 0.5 ? 15 : 10);
    await UserPreferences.addXP(xp);

    if (!mounted) return;

    // Show results screen
    setState(() {
      _showResults = true;
    });

    // Play confetti and celebration sound if good performance
    if (successRate >= 0.7) {
      _confettiController.play();
      _soundService.playComplete();
    } else {
      _soundService.playLevelUp();
    }
  }

  // ── Results Screen ──────────────────────────────────────────────────

  Widget _buildResultsScreen() {
    final total = _correctCount + _wrongCount;
    final successRate = total > 0 ? _correctCount / total : 0.0;
    final percentage = (successRate * 100).round();

    Color rateColor;
    String rateEmoji;
    String rateMessage;
    String rateTitle;

    if (percentage >= 90) {
      rateColor = const Color(0xFF66BB6A);
      rateEmoji = '🏆';
      rateTitle = S.get('ex_magnificent');
      rateMessage = S.get('ex_near_perfect');
    } else if (percentage >= 80) {
      rateColor = const Color(0xFF66BB6A);
      rateEmoji = '🌟';
      rateTitle = S.get('ex_great');
      rateMessage = S.get('ex_great_desc');
    } else if (percentage >= 60) {
      rateColor = orange;
      rateEmoji = '👏';
      rateTitle = S.get('ex_doing_well');
      rateMessage = S.get('ex_more_practice');
    } else if (percentage >= 40) {
      rateColor = const Color(0xFFFF9800);
      rateEmoji = '📖';
      rateTitle = S.get('ex_keep_going');
      rateMessage = S.get('ex_review_topic');
    } else {
      rateColor = Colors.red.shade400;
      rateEmoji = '💪';
      rateTitle = S.get('ex_dont_give_up');
      rateMessage = S.get('ex_try_again_improve');
    }

    return Stack(
      children: [
        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
            ],
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Trophy / emoji
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Text(rateEmoji, style: const TextStyle(fontSize: 64)),
              ),
              const SizedBox(height: 12),

              Text(
                rateTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: rateColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                S.get('ex_lesson_complete'),
                style: TextStyle(
                  fontSize: 16,
                  color: darkGreen.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: darkGreen.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.level} · "${widget.title}"',
                  style: TextStyle(
                    fontSize: 13,
                    color: darkGreen.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28),

              // Circular progress indicator
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: successRate),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: value,
                          strokeWidth: 14,
                          backgroundColor: _c.shimmer,
                          valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                          strokeCap: StrokeCap.round,
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '%${(value * 100).round()}',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  color: rateColor,
                                ),
                              ),
                              Text(
                                S.get('ex_success'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _c.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              Text(
                rateMessage,
                style: TextStyle(
                  fontSize: 15,
                  color: darkGreen.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Stats row
              Row(
                children: [
                  _buildStatCard(
                    icon: Icons.check_circle_rounded,
                    iconColor: successGreen,
                    label: S.get('ex_correct'),
                    value: '$_correctCount',
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    icon: Icons.cancel_rounded,
                    iconColor: errorRed,
                    label: S.get('ex_wrong'),
                    value: '$_wrongCount',
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: const Color(0xFFFF6D00),
                    label: S.get('ex_best_streak'),
                    value: '$_bestStreak',
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    icon: Icons.star_rounded,
                    iconColor: orange,
                    label: 'XP',
                    value:
                        '+${successRate >= 0.8 ? 20 : (successRate >= 0.5 ? 15 : 10)}',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Wrong answers list - enhanced
              if (_wrongAnswers.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: context.isDarkMode
                          ? [
                              errorRed.withValues(alpha: 0.12),
                              orange.withValues(alpha: 0.08),
                            ]
                          : [
                              Colors.red.shade50,
                              Colors.orange.shade50.withValues(alpha: 0.5),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: context.isDarkMode
                          ? errorRed.withValues(alpha: 0.25)
                          : Colors.red.shade100,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: errorRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              color: errorRed,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                S.get('ex_review_needed'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: context.isDarkMode
                                      ? errorRed
                                      : Colors.red.shade700,
                                ),
                              ),
                              Text(
                                S.get(
                                  'ex_n_questions',
                                  args: {'n': '${_wrongAnswers.length}'},
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.isDarkMode
                                      ? errorRed.withValues(alpha: 0.7)
                                      : Colors.red.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...List.generate(_wrongAnswers.length, (i) {
                        final q = _wrongAnswers[i]['question']!;
                        // Deduplicate
                        if (i > 0 &&
                            _wrongAnswers
                                .sublist(0, i)
                                .any((w) => w['question'] == q)) {
                          return const SizedBox.shrink();
                        }
                        final type = _wrongAnswers[i]['type'] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _c.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: errorRed.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Exercise type badge
                                if (type.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: darkGreen.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _exerciseTypeIcon(type),
                                          size: 12,
                                          color: darkGreen.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _exerciseTypeLabel(type),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: darkGreen.withValues(
                                              alpha: 0.5,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Question
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: errorRed.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        Icons.help_outline_rounded,
                                        color: errorRed.withValues(alpha: 0.6),
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _wrongAnswers[i]['question']!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF37474F),
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Correct answer
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: successGreen.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: successGreen.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: successGreen,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              S.get('ex_correct_answer'),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: successGreen.withValues(
                                                  alpha: 0.7,
                                                ),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              _wrongAnswers[i]['answer']!,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF2E7D32),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Action buttons
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 4,
                    shadowColor: orange.withValues(alpha: 0.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_forward_rounded, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        S.get('ex_continue'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: _c.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: iconColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: iconColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: _c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _c.cream,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated loading indicator
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(opacity: value, child: child);
                },
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: darkGreen.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.5,
                            valueColor: AlwaysStoppedAnimation<Color>(orange),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${widget.level} · ${widget.title}',
                      style: TextStyle(
                        fontSize: 15,
                        color: darkGreen,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      S.get('ex_loading'),
                      style: TextStyle(
                        fontSize: 13,
                        color: darkGreen.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
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

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: darkGreen,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📭', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: darkGreen.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(S.get('ex_back')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Results screen
    if (_showResults) {
      return Scaffold(
        backgroundColor: _c.cream,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.level,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                S.get('ex_results'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: darkGreen,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _buildResultsScreen(),
      );
    }

    final currentExercise = _exercises[_currentIndex];
    final progress = (_currentIndex + 1) / _exercises.length;
    final currentType =
        (currentExercise['type'] as String?)?.toLowerCase() ?? '';

    return Scaffold(
      backgroundColor: _c.cream,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar with progress ──
            _buildTopBar(progress, currentType),

            // ── Exercise content ──
            Expanded(
              child: Stack(
                children: [
                  // Exercise widget with transition animation
                  Positioned.fill(
                    child: FadeTransition(
                      opacity: _exerciseTransitionController,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.05, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _exerciseTransitionController,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 20,
                            right: 20,
                            top: 8,
                            bottom: _showFeedback ? 200 : 20,
                          ),
                          child: _buildExerciseWidget(currentExercise),
                        ),
                      ),
                    ),
                  ),

                  // ── Duolingo-style feedback bottom bar ──
                  if (_showFeedback)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SlideTransition(
                        position: _feedbackSlideAnimation,
                        child: _buildFeedbackBar(),
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

  // ── Top Bar ──────────────────────────────────────────────────────────

  Widget _buildTopBar(double progress, String currentType) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              // Close button
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: darkGreen.withValues(alpha: 0.6),
                ),
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Row(
                      children: [
                        const Text('😢', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 10),
                        Flexible(child: Text(S.get('ex_quit_title'))),
                      ],
                    ),
                    content: Text(S.get('ex_quit_message')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          S.get('no'),
                          style: TextStyle(
                            color: darkGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: Text(
                          S.get('yes'),
                          style: TextStyle(color: orange),
                        ),
                      ),
                    ],
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),

              const SizedBox(width: 6),

              // Progress bar
              Expanded(
                child: AnimatedBuilder(
                  animation: _progressPulseController,
                  builder: (context, child) {
                    final pulse =
                        sin(_progressPulseController.value * pi) * 0.03;
                    return Transform.scale(scaleY: 1.0 + pulse, child: child);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: _c.shimmer,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.lerp(orange, successGreen, value) ?? orange,
                          ),
                          minHeight: 12,
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Counter badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: darkGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_exercises.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: darkGreen.withValues(alpha: 0.7),
                  ),
                ),
              ),

              // Streak indicator
              if (_currentStreak >= 2)
                AnimatedBuilder(
                  animation: _streakController,
                  builder: (context, child) {
                    final scale = _currentStreak >= 3
                        ? 1.0 +
                              (1 - _streakController.value).clamp(0, 0.3) * 0.3
                        : 1.0;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6D00), Color(0xFFFF9100)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6D00).withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$_currentStreak',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Mute Toggle
              FutureBuilder<bool>(
                future: UserPreferences.getMuted(),
                builder: (context, snapshot) {
                  final isMuted = snapshot.data ?? false;
                  return IconButton(
                    onPressed: () async {
                      await UserPreferences.saveMuted(!isMuted);
                      setState(() {});
                    },
                    icon: Icon(
                      isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: darkGreen.withValues(alpha: 0.5),
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  );
                },
              ),
            ],
          ),
          // Exercise type badge row
          if (currentType.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: darkGreen.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _exerciseTypeIcon(currentType),
                          size: 14,
                          color: darkGreen.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _exerciseTypeLabel(currentType),
                          style: TextStyle(
                            fontSize: 12,
                            color: darkGreen.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Duolingo-style Feedback Bar ──────────────────────────────────────

  Widget _buildFeedbackBar() {
    if (_lastAnswerCorrect) {
      return _buildCorrectFeedbackBar();
    } else {
      return _buildWrongFeedbackBar();
    }
  }

  Widget _buildCorrectFeedbackBar() {
    final streakMessages = [
      '',
      '',
      S.get('ex_streak_2'),
      S.get('ex_streak_3'),
      S.get('ex_streak_4'),
      S.get('ex_unstoppable'),
    ];
    final streakMsg = _currentStreak >= 2
        ? streakMessages[_currentStreak.clamp(0, streakMessages.length - 1)]
        : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.isDarkMode
              ? [const Color(0xFF1A3328), const Color(0xFF1E382D)]
              : [const Color(0xFFDFF5E3), const Color(0xFFE8F8EC)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: successGreen.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Animated checkmark
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: successGreen.withValues(alpha: 0.4),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentStreak >= 3
                          ? S.get('ex_perfect')
                          : S.get('ex_awesome'),
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: context.isDarkMode
                            ? _c.correctGreen
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                    if (streakMsg.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        streakMsg,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              (context.isDarkMode
                                      ? _c.correctGreen
                                      : const Color(0xFF2E7D32))
                                  .withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 2),
                      Text(
                        S.get('ex_correct_answer_msg'),
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              (context.isDarkMode
                                      ? _c.correctGreen
                                      : const Color(0xFF2E7D32))
                                  .withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: successGreen,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: successGreen.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                S.get('ex_continue'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWrongFeedbackBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.isDarkMode
              ? [const Color(0xFF2D1A1A), const Color(0xFF2D2118)]
              : [const Color(0xFFFFEBEE), const Color(0xFFFFF3E0)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: errorRed.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Animated X mark
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFEF5350), Color(0xFFD32F2F)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: errorRed.withValues(alpha: 0.4),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.get('ex_wrong_answer_msg'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.isDarkMode
                            ? errorRed
                            : const Color(0xFFC62828),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.get('ex_wrong_feedback'),
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            (context.isDarkMode
                                    ? errorRed
                                    : const Color(0xFFC62828))
                                .withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Correct answer reveal
          if (_showCorrectAnswer) ...[
            const SizedBox(height: 14),
            FadeTransition(
              opacity: _correctAnswerFadeAnimation,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _c.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF66BB6A).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_rounded,
                      color: Color(0xFFFFA726),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.get('ex_correct_answer'),
                            style: TextStyle(
                              fontSize: 12,
                              color: _c.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _correctAnswerText,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: context.isDarkMode
                                  ? _c.correctGreen
                                  : const Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Two buttons row
          if (!_showCorrectAnswer)
            Row(
              children: [
                // Tekrar Dene button
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: Text(
                        S.get('ex_retry'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.isDarkMode
                            ? errorRed
                            : const Color(0xFFC62828),
                        side: BorderSide(color: errorRed, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Doğru Cevabı Göster button
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _onShowCorrectAnswer,
                      icon: const Icon(Icons.visibility_rounded, size: 20),
                      label: Text(
                        S.get('ex_show_answer'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: errorRed,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: errorRed.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            // After showing correct answer, show "Devam Et"
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: errorRed,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: errorRed.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  S.get('ex_continue'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseWidget(Map<String, dynamic> exercise) {
    try {
      final type = (exercise['type'] as String?)?.toLowerCase() ?? 'unknown';
      final keyStr = '${type}_${_currentIndex}_r$_retryCount';

      switch (type) {
        case 'quiz':
          return QuizExercise(
            key: ValueKey(keyStr),
            exercise: exercise,
            onAnswer: _handleAnswer,
          );
        case 'fill_blank':
          return FillBlankExercise(
            key: ValueKey(keyStr),
            exercise: exercise,
            onAnswer: _handleAnswer,
          );
        case 'word_order':
          return WordOrderExercise(
            key: ValueKey(keyStr),
            exercise: exercise,
            onAnswer: _handleAnswer,
          );
        case 'speaking':
          return SpeakingExercise(
            key: ValueKey(keyStr),
            exercise: exercise,
            onAnswer: _handleAnswer,
          );
        case 'translation':
          return TranslationExercise(
            key: ValueKey(keyStr),
            exercise: exercise,
            onAnswer: _handleAnswer,
          );
        case 'matching':
          return MatchingExercise(
            key: ValueKey(keyStr),
            exercise: exercise,
            onAnswer: _handleAnswer,
          );
        default:
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.orange, size: 48),
                const SizedBox(height: 16),
                Text("Bilinmeyen egzersiz tipi: $type"),
              ],
            ),
          );
      }
    } catch (e, stack) {
      debugPrint('❌ Error rendering exercise widget: $e');
      debugPrint('Stack: $stack');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bug_report, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Egzersiz görüntülenirken hata oluştu",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _speakCurrentQuestion() async {
    if (!mounted || _exercises.isEmpty || _currentIndex >= _exercises.length) {
      return;
    }
    final exercise = _exercises[_currentIndex] as Map<String, dynamic>;
    final question = exercise['question'] as String?;

    // For specific types, we might want to speak specific fields
    // But mostly the question/sentence is in 'question' or 'sentence'
    final textToSpeak = question ?? exercise['sentence'] ?? exercise['word'];

    if (textToSpeak != null && textToSpeak.isNotEmpty) {
      // Small delay to ensure UI is ready and previous speech stopped
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      // If question contains blanks ("______"), don't read them as
      // "alt çizgi alt çizgi". Instead, speak the surrounding
      // text and insert a short pause (~2s) at the blank.
      if (textToSpeak.contains('______')) {
        final parts = textToSpeak.split('______');

        for (int i = 0; i < parts.length; i++) {
          final part = parts[i].trim();
          if (part.isNotEmpty) {
            await TtsService().speakSmart(
              part,
              forceAlphabetMode: _isAlphabetLesson,
            );
          }

          // Between blanks, brief pause in silence
          if (i < parts.length - 1) {
            await Future.delayed(const Duration(milliseconds: 800));
          }
        }
      } else {
        // Normal reading: Turkish parts in TR accent,
        // English parts in EN accent.
        await TtsService().speakSmart(
          textToSpeak,
          forceAlphabetMode: _isAlphabetLesson,
        );
      }
    }
  }
}
