import 'package:flutter/material.dart';
import '../../services/duck_theme.dart';

class WordOrderExercise extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final Function(bool) onAnswer;

  const WordOrderExercise({
    super.key,
    required this.exercise,
    required this.onAnswer,
  });

  @override
  State<WordOrderExercise> createState() => _WordOrderExerciseState();
}

class _WordOrderExerciseState extends State<WordOrderExercise>
    with SingleTickerProviderStateMixin {
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get orange => _c.orange;

  late List<String> availableWords;
  List<String> selectedWords = [];
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    availableWords = List<String>.from(widget.exercise['components']);
    availableWords.shuffle();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onWordTap(String word, {required bool fromSelected}) {
    setState(() {
      if (fromSelected) {
        selectedWords.remove(word);
        availableWords.add(word);
      } else {
        availableWords.remove(word);
        selectedWords.add(word);
      }
    });
  }

  void _checkAnswer() {
    final correctOrder = List<String>.from(widget.exercise['correctOrder']);
    bool isCorrect = selectedWords.length == correctOrder.length;
    if (isCorrect) {
      for (int i = 0; i < selectedWords.length; i++) {
        if (selectedWords[i] != correctOrder[i]) {
          isCorrect = false;
          break;
        }
      }
    }
    widget.onAnswer(isCorrect);
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.exercise['question'] as String;

    return FadeTransition(
      opacity: _animController,
      child: Column(
        children: [
          // Question
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: darkGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🧩', style: TextStyle(fontSize: 22)),
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

          // Construction area
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            constraints: const BoxConstraints(minHeight: 70),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selectedWords.isEmpty
                  ? _c.shimmer
                  : darkGreen.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selectedWords.isEmpty
                    ? _c.divider
                    : darkGreen.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: selectedWords.isEmpty
                ? Center(
                    child: Text(
                      'Kelimeleri buraya ekle',
                      style: TextStyle(
                        color: _c.textSecondary,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedWords.map((word) {
                      return _buildChip(
                        word: word,
                        color: darkGreen,
                        onTap: () => _onWordTap(word, fromSelected: true),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 20),

          // Divider with icon
          Row(
            children: [
              Expanded(child: Divider(color: _c.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: _c.textSecondary,
                  size: 20,
                ),
              ),
              Expanded(child: Divider(color: _c.divider)),
            ],
          ),
          const SizedBox(height: 20),

          // Word pool
          Wrap(
            spacing: 8,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: availableWords.map((word) {
              return _buildChip(
                word: word,
                color: orange,
                onTap: () => _onWordTap(word, fromSelected: false),
              );
            }).toList(),
          ),

          const Spacer(),

          // Check button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: availableWords.isEmpty ? _checkAnswer : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _c.shimmer,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
              child: const Text(
                'KONTROL ET',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String word,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          word,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
