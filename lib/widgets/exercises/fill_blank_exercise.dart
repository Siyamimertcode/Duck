import 'package:flutter/material.dart';
import '../../services/duck_theme.dart';

class FillBlankExercise extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final Function(bool) onAnswer;

  const FillBlankExercise({
    super.key,
    required this.exercise,
    required this.onAnswer,
  });

  @override
  State<FillBlankExercise> createState() => _FillBlankExerciseState();
}

class _FillBlankExerciseState extends State<FillBlankExercise>
    with TickerProviderStateMixin {
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get orange => _c.orange;

  late AnimationController _cursorController;
  late AnimationController _scaleController;
  String? _selectedOption;
  bool? _isCorrect;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _cursorController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onOptionTap(String option) {
    if (_selectedOption != null) return;
    final correct = option == widget.exercise['answer'];
    setState(() {
      _selectedOption = option;
      _isCorrect = correct;
    });
    _cursorController.stop();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) widget.onAnswer(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.exercise['question'] as String;
    final options = List<String>.from(widget.exercise['options']);
    final parts = question.split('______');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Question with animated blank
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _c.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: darkGreen.withValues(alpha: 0.15),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: darkGreen.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text('✏️', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _c.textPrimary,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(text: parts[0]),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: _selectedOption != null
                          ? Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _isCorrect!
                                    ? (context.isDarkMode
                                          ? _c.correctGreen.withValues(
                                              alpha: 0.15,
                                            )
                                          : const Color(0xFFE8F5E9))
                                    : (context.isDarkMode
                                          ? _c.wrongRed.withValues(alpha: 0.15)
                                          : const Color(0xFFFFEBEE)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isCorrect!
                                      ? _c.correctGreen
                                      : _c.wrongRed,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                _selectedOption!,
                                style: TextStyle(
                                  color: _isCorrect!
                                      ? (context.isDarkMode
                                            ? _c.correctGreen
                                            : const Color(0xFF2E7D32))
                                      : (context.isDarkMode
                                            ? _c.wrongRed
                                            : const Color(0xFFC62828)),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            )
                          : AnimatedBuilder(
                              animation: _cursorController,
                              builder: (context, _) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: orange.withValues(
                                      alpha:
                                          0.08 + _cursorController.value * 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: orange.withValues(
                                          alpha:
                                              0.5 +
                                              _cursorController.value * 0.5,
                                        ),
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '  ???  ',
                                    style: TextStyle(
                                      color: orange.withValues(alpha: 0.6),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (parts.length > 1) TextSpan(text: parts[1]),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Options with scale animation
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: List.generate(options.length, (i) {
            final delay = i / options.length;
            final isSelected = _selectedOption == options[i];
            final isCorrectOption = options[i] == widget.exercise['answer'];
            final showFeedback = _selectedOption != null;

            Color btnBg = _c.cardColor;
            Color btnBorder = darkGreen.withValues(alpha: 0.2);
            Color btnText = _c.textPrimary;

            if (showFeedback) {
              if (isSelected && _isCorrect!) {
                btnBg = context.isDarkMode
                    ? _c.correctGreen.withValues(alpha: 0.15)
                    : const Color(0xFFE8F5E9);
                btnBorder = _c.correctGreen;
                btnText = context.isDarkMode
                    ? _c.correctGreen
                    : const Color(0xFF2E7D32);
              } else if (isSelected && !_isCorrect!) {
                btnBg = context.isDarkMode
                    ? _c.wrongRed.withValues(alpha: 0.15)
                    : const Color(0xFFFFEBEE);
                btnBorder = _c.wrongRed;
                btnText = context.isDarkMode
                    ? _c.wrongRed
                    : const Color(0xFFC62828);
              } else if (isCorrectOption && !_isCorrect!) {
                btnBg = context.isDarkMode
                    ? _c.correctGreen.withValues(alpha: 0.10)
                    : const Color(0xFFE8F5E9).withValues(alpha: 0.6);
                btnBorder = _c.correctGreen.withValues(alpha: 0.6);
                btnText = context.isDarkMode
                    ? _c.correctGreen
                    : const Color(0xFF2E7D32);
              } else {
                btnBg = _c.shimmer;
                btnBorder = _c.divider;
                btnText = _c.textSecondary;
              }
            }

            return AnimatedBuilder(
              animation: _scaleController,
              builder: (context, child) {
                final progress =
                    ((_scaleController.value - delay * 0.5) / (1 - delay * 0.5))
                        .clamp(0.0, 1.0);
                final scale = 0.5 + 0.5 * Curves.elasticOut.transform(progress);
                return Transform.scale(
                  scale: scale,
                  child: Opacity(opacity: progress, child: child),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: ElevatedButton(
                  onPressed: _selectedOption == null
                      ? () => _onOptionTap(options[i])
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnBg,
                    foregroundColor: btnText,
                    disabledBackgroundColor: btnBg,
                    disabledForegroundColor: btnText,
                    elevation: showFeedback ? 0 : 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: btnBorder, width: 2),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
