import 'package:flutter/material.dart';
import '../../services/duck_theme.dart';
import '../../services/app_localizations.dart';

class TranslationExercise extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final Function(bool) onAnswer;

  const TranslationExercise({
    super.key,
    required this.exercise,
    required this.onAnswer,
  });

  @override
  State<TranslationExercise> createState() => _TranslationExerciseState();
}

class _TranslationExerciseState extends State<TranslationExercise>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get orange => _c.orange;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _controller.addListener(_onAnswerChanged);
    _animController.forward();
  }

  void _onAnswerChanged() {
    if (mounted) {
      setState(() {}); // Rebuild to update submit button enable state.
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnswerChanged);
    _controller.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _checkAnswer() {
    final userAnswer = _controller.text.trim().toLowerCase();
    final correctAnswer = (widget.exercise['answer'] as String)
        .trim()
        .toLowerCase();
    widget.onAnswer(userAnswer == correctAnswer);
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.exercise['question'] as String;
    final sentence = widget.exercise['sentence'] as String;

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Question header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: darkGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔄', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              question,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _c.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sentence to translate
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _c.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: darkGreen.withValues(alpha: 0.2),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: darkGreen.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        sentence,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _c.textPrimary,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Answer input
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: orange.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          hintText: S.get('ex_translate_hint'),
                          hintStyle: TextStyle(color: _c.textSecondary),
                          filled: true,
                          fillColor: _c.inputFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: _c.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: _c.divider, width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: orange, width: 2),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: _c.textSecondary,
                            ),
                            onPressed: () => _controller.clear(),
                          ),
                        ),
                        onSubmitted: (_) => _checkAnswer(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _controller.text.trim().isNotEmpty
                            ? _checkAnswer
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: orange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _c.shimmer,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'KONTROL ET',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
