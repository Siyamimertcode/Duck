import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/duck_theme.dart';
import '../../services/app_localizations.dart';
import '../../services/sound_service.dart';

class MatchingExercise extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final Function(bool) onAnswer;

  const MatchingExercise({
    super.key,
    required this.exercise,
    required this.onAnswer,
  });

  @override
  State<MatchingExercise> createState() => _MatchingExerciseState();
}

class _MatchingExerciseState extends State<MatchingExercise>
    with TickerProviderStateMixin {
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get orange => _c.orange;
  Color get successGreen => _c.correctGreen;
  Color get errorRed => _c.wrongRed;

  late List<_MatchItem> _leftItems;
  late List<_MatchItem> _rightItems;
  int? _selectedLeftIndex;
  int? _selectedRightIndex;
  final Set<int> _matchedLeftIndices = {};
  final Set<int> _matchedRightIndices = {};
  int _wrongAttempts = 0;
  int _totalPairs = 0;
  int _lastMatchedLeft = -1;
  int _lastMatchedRight = -1;
  bool _showWrongFlash = false;

  // Color palette for matched pairs
  static const List<Color> _pairColors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFFFF9800),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFF795548),
    Color(0xFF607D8B),
  ];

  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;
  late AnimationController _matchCelebrationController;
  late Animation<double> _matchCelebrationAnim;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _matchCelebrationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _matchCelebrationAnim = CurvedAnimation(
      parent: _matchCelebrationController,
      curve: Curves.elasticOut,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    final pairs = List<Map<String, dynamic>>.from(widget.exercise['pairs']);
    _totalPairs = pairs.length;

    _leftItems = pairs
        .asMap()
        .entries
        .map((e) => _MatchItem(index: e.key, text: e.value['left'] as String))
        .toList();

    _rightItems = pairs
        .asMap()
        .entries
        .map((e) => _MatchItem(index: e.key, text: e.value['right'] as String))
        .toList();

    _rightItems.shuffle();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _matchCelebrationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color _getColorForPair(int pairIndex) {
    return _pairColors[pairIndex % _pairColors.length];
  }

  void _onLeftTap(int index) {
    if (_matchedLeftIndices.contains(_leftItems[index].index)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedLeftIndex = index;
      _tryMatch();
    });
  }

  void _onRightTap(int index) {
    if (_matchedRightIndices.contains(_rightItems[index].index)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedRightIndex = index;
      _tryMatch();
    });
  }

  void _tryMatch() {
    if (_selectedLeftIndex == null || _selectedRightIndex == null) return;

    final leftPairIndex = _leftItems[_selectedLeftIndex!].index;
    final rightPairIndex = _rightItems[_selectedRightIndex!].index;

    if (leftPairIndex == rightPairIndex) {
      HapticFeedback.mediumImpact();
      SoundService().playMatch();
      _matchedLeftIndices.add(leftPairIndex);
      _matchedRightIndices.add(rightPairIndex);
      _lastMatchedLeft = _selectedLeftIndex!;
      _lastMatchedRight = _selectedRightIndex!;
      _selectedLeftIndex = null;
      _selectedRightIndex = null;

      _matchCelebrationController.forward(from: 0);

      if (_matchedLeftIndices.length == _totalPairs) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) {
            widget.onAnswer(_wrongAttempts == 0);
          }
        });
      }
    } else {
      _wrongAttempts++;
      HapticFeedback.heavyImpact();
      SoundService().playWrong();
      setState(() => _showWrongFlash = true);
      _shakeController.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _selectedLeftIndex = null;
            _selectedRightIndex = null;
            _showWrongFlash = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.exercise['question'] as String;
    final matchedCount = _matchedLeftIndices.length;
    final progressValue = _totalPairs > 0 ? matchedCount / _totalPairs : 0.0;

    return Column(
      children: [
        // Question header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                darkGreen.withValues(alpha: 0.08),
                darkGreen.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: darkGreen.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔗', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _c.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S.get(
                      'ex_match_progress',
                      args: {
                        'matched': matchedCount.toString(),
                        'total': _totalPairs.toString(),
                      },
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: darkGreen.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_wrongAttempts > 0)
                    Text(
                      '$_wrongAttempts hata',
                      style: TextStyle(
                        fontSize: 12,
                        color: errorRed.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progressValue),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      backgroundColor: _c.shimmer,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.lerp(orange, successGreen, value) ?? orange,
                      ),
                      minHeight: 6,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Matching grid
        Expanded(
          child: AnimatedBuilder(
            animation: _shakeAnim,
            builder: (context, child) {
              final shakeOffset =
                  _shakeAnim.value *
                  10 *
                  ((_shakeAnim.value * 12).toInt().isOdd ? 1 : -1);
              return Transform.translate(
                offset: Offset(_showWrongFlash ? shakeOffset : 0, 0),
                child: child,
              );
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: _totalPairs,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final leftItem = _leftItems[i];
                final rightItem = _rightItems[i];
                final isLeftMatched = _matchedLeftIndices.contains(
                  leftItem.index,
                );
                final isRightMatched = _matchedRightIndices.contains(
                  rightItem.index,
                );
                final isLeftSelected = _selectedLeftIndex == i;
                final isRightSelected = _selectedRightIndex == i;
                final wasLeftJustMatched =
                    _lastMatchedLeft == i && isLeftMatched;
                final wasRightJustMatched =
                    _lastMatchedRight == i && isRightMatched;
                final rowMatched = isLeftMatched || isRightMatched;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildCard(
                        text: leftItem.text,
                        pairIndex: leftItem.index,
                        isMatched: isLeftMatched,
                        isSelected: isLeftSelected,
                        wasJustMatched: wasLeftJustMatched,
                        onTap: () => _onLeftTap(i),
                        isLeft: true,
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: Icon(
                        rowMatched
                            ? Icons.link_rounded
                            : Icons.link_off_rounded,
                        size: 17,
                        color: rowMatched
                            ? successGreen.withValues(alpha: 0.65)
                            : _c.textSecondary.withValues(alpha: 0.3),
                      ),
                    ),
                    Expanded(
                      child: _buildCard(
                        text: rightItem.text,
                        pairIndex: rightItem.index,
                        isMatched: isRightMatched,
                        isSelected: isRightSelected,
                        wasJustMatched: wasRightJustMatched,
                        onTap: () => _onRightTap(i),
                        isLeft: false,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // Hint text at bottom
        if (_matchedLeftIndices.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.4 + _pulseController.value * 0.4,
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 16,
                    color: _c.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    S.get('ex_match_hint'),
                    style: TextStyle(
                      fontSize: 12,
                      color: _c.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCard({
    required String text,
    required int pairIndex,
    required bool isMatched,
    required bool isSelected,
    required bool wasJustMatched,
    required VoidCallback onTap,
    required bool isLeft,
  }) {
    final pairColor = _getColorForPair(pairIndex);
    final matchColor = isMatched ? pairColor : null;

    Widget card = GestureDetector(
      onTap: isMatched ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isMatched
              ? matchColor!.withValues(alpha: 0.08)
              : isSelected
              ? (isLeft
                    ? darkGreen.withValues(alpha: 0.06)
                    : orange.withValues(alpha: 0.06))
              : _c.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMatched
                ? matchColor!.withValues(alpha: 0.6)
                : isSelected
                ? (isLeft ? darkGreen : orange)
                : _c.divider,
            width: isMatched ? 2 : (isSelected ? 2.5 : 1.5),
          ),
          boxShadow: [
            if (isSelected && !isMatched)
              BoxShadow(
                color: (isLeft ? darkGreen : orange).withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            if (isMatched)
              BoxShadow(
                color: matchColor!.withValues(alpha: 0.15),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            if (!isMatched && !isSelected)
              BoxShadow(
                color: _c.shadowColor,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Status icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isMatched
                  ? Container(
                      key: const ValueKey('matched'),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: matchColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    )
                  : isSelected
                  ? Container(
                      key: const ValueKey('selected'),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isLeft ? darkGreen : orange,
                          width: 2.5,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isLeft ? darkGreen : orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      key: const ValueKey('idle'),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _c.divider, width: 1.5),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isMatched || isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: isMatched
                      ? matchColor!.withValues(alpha: 0.9)
                      : isSelected
                      ? (isLeft ? darkGreen : orange)
                      : _c.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );

    // Add scale animation for just-matched items
    if (wasJustMatched) {
      card = AnimatedBuilder(
        animation: _matchCelebrationAnim,
        builder: (context, child) {
          final scale = 0.95 + _matchCelebrationAnim.value * 0.05;
          return Transform.scale(scale: scale, child: child);
        },
        child: card,
      );
    }

    return card;
  }
}

class _MatchItem {
  final int index;
  final String text;
  _MatchItem({required this.index, required this.text});
}
