import 'package:flutter/material.dart';
import '../../services/duck_theme.dart';

class QuizExercise extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final Function(bool) onAnswer;

  const QuizExercise({
    super.key,
    required this.exercise,
    required this.onAnswer,
  });

  @override
  State<QuizExercise> createState() => _QuizExerciseState();
}

class _QuizExerciseState extends State<QuizExercise>
    with TickerProviderStateMixin {
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get orange => _c.orange;

  late AnimationController _staggerController;
  late AnimationController _feedbackController;
  int? _selectedIndex;
  bool? _isCorrect;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  void _onOptionTap(int index, String option) {
    if (_selectedIndex != null) return; // Prevent double tap

    final correct = option == widget.exercise['answer'];
    setState(() {
      _selectedIndex = index;
      _isCorrect = correct;
    });

    _feedbackController.forward().then((_) {
      if (mounted) widget.onAnswer(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.exercise['question'] as String;
    final options = List<String>.from(widget.exercise['options']);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Question with emoji decoration
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: darkGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: darkGreen.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                const Text('🤔', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 10),
                Text(
                  question,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _c.textPrimary,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Options with staggered animation
          ...List.generate(options.length, (i) {
            final delay = i / options.length;
            return AnimatedBuilder(
              animation: _staggerController,
              builder: (context, child) {
                final progress =
                    ((_staggerController.value - delay) / (1 - delay)).clamp(
                      0.0,
                      1.0,
                    );
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - progress)),
                  child: Opacity(opacity: progress, child: child),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _buildOptionButton(i, options[i]),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOptionButton(int index, String option) {
    final isSelected = _selectedIndex == index;
    final showFeedback = _selectedIndex != null;
    final isCorrectOption = option == widget.exercise['answer'];

    final isDark = context.isDarkMode;
    Color bgColor = _c.cardColor;
    Color borderColor = _c.divider;
    Color textColor = _c.textPrimary;

    if (showFeedback) {
      if (isSelected && _isCorrect!) {
        // User picked the correct answer
        bgColor = isDark
            ? _c.correctGreen.withValues(alpha: 0.15)
            : const Color(0xFFE8F5E9);
        borderColor = _c.correctGreen;
        textColor = isDark ? _c.correctGreen : const Color(0xFF2E7D32);
      } else if (isSelected && !_isCorrect!) {
        // User picked wrong answer
        bgColor = isDark
            ? _c.wrongRed.withValues(alpha: 0.15)
            : const Color(0xFFFFEBEE);
        borderColor = _c.wrongRed;
        textColor = isDark ? _c.wrongRed : const Color(0xFFC62828);
      } else if (!isSelected && isCorrectOption && !_isCorrect!) {
        // Highlight the correct answer when user picked wrong
        bgColor = isDark
            ? _c.correctGreen.withValues(alpha: 0.10)
            : const Color(0xFFE8F5E9).withValues(alpha: 0.6);
        borderColor = _c.correctGreen.withValues(alpha: 0.6);
        textColor = isDark ? _c.correctGreen : const Color(0xFF2E7D32);
      }
    }

    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: ElevatedButton(
          onPressed: _selectedIndex == null
              ? () => _onOptionTap(index, option)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: textColor,
            disabledBackgroundColor: bgColor,
            disabledForegroundColor: textColor,
            elevation: isSelected ? 0 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor, width: 2),
            ),
            padding: const EdgeInsets.all(16),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color:
                      showFeedback &&
                          (isSelected || (isCorrectOption && !_isCorrect!))
                      ? borderColor.withValues(alpha: 0.2)
                      : darkGreen.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child:
                      showFeedback &&
                          (isSelected || (isCorrectOption && !_isCorrect!))
                      ? Icon(
                          (isSelected && _isCorrect!) ||
                                  (isCorrectOption && !_isCorrect!)
                              ? Icons.check
                              : Icons.close,
                          size: 18,
                          color: borderColor,
                        )
                      : Text(
                          String.fromCharCode(65 + index), // A, B, C, D
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: darkGreen,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
