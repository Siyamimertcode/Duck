import 'package:flutter/material.dart';
import '../../services/duck_theme.dart';
import '../../services/app_localizations.dart';
import '../../services/stt_service.dart';
import '../../services/tts_service.dart';

class SpeakingExercise extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final Function(bool) onAnswer;

  const SpeakingExercise({
    super.key,
    required this.exercise,
    required this.onAnswer,
  });

  @override
  State<SpeakingExercise> createState() => _SpeakingExerciseState();
}

class _SpeakingExerciseState extends State<SpeakingExercise>
    with TickerProviderStateMixin {
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get orange => _c.orange;

  late AnimationController _pulseController;
  late AnimationController _rippleController;

  final SttService _sttService = SttService();
  bool _isListening = false;
  bool _hasResult = false;
  String _recognizedText = '';
  String _statusText = '';
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _initStt();
  }

  Future<void> _initStt() async {
    final available = await _sttService.initialize();
    if (!available && mounted) {
      setState(() {
        _statusText = 'Ses tanıma kullanılamıyor';
      });
    }
  }

  @override
  void dispose() {
    _sttService.clearCallbacks();
    if (_isListening) {
      _sttService.cancelListening();
    }
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (_answered) return;

    // Stop any TTS first
    await TtsService().stop();

    setState(() {
      _isListening = true;
      _hasResult = false;
      _recognizedText = '';
      _statusText = 'Dinleniyor...';
    });

    _sttService.onResult = (text, isFinal) {
      if (!mounted) return;
      setState(() {
        _recognizedText = text;
        if (isFinal) {
          _isListening = false;
          _hasResult = true;
          _statusText = '';
          _evaluateAnswer(text);
        }
      });
    };

    _sttService.onListeningStarted = () {
      if (mounted) {
        setState(() {
          _isListening = true;
          _statusText = 'Dinleniyor... Konuşun';
        });
      }
    };

    _sttService.onListeningStopped = () {
      if (mounted) {
        setState(() {
          _isListening = false;
          if (!_hasResult && _recognizedText.isEmpty) {
            _statusText = 'Ses algılanamadı, tekrar deneyin';
          }
        });
      }
    };

    _sttService.onError = (error) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _statusText = error;
        });
      }
    };

    await _sttService.startListening(localeId: 'en_US');
  }

  Future<void> _stopListening() async {
    await _sttService.stopListening();
    setState(() => _isListening = false);
  }

  void _evaluateAnswer(String spokenText) {
    if (_answered) return;
    _answered = true;

    final expectedWord = (widget.exercise['word'] as String? ?? '')
        .toLowerCase()
        .trim();
    final spoken = spokenText.toLowerCase().trim();

    // Fuzzy comparison: check if the spoken text contains the expected word
    // or vice versa, or if they're similar enough
    final isCorrect = _isMatch(spoken, expectedWord);

    // Small delay so user can see the result
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        widget.onAnswer(isCorrect);
      }
    });
  }

  bool _isMatch(String spoken, String expected) {
    if (spoken.isEmpty || expected.isEmpty) return false;

    // Direct match
    if (spoken == expected) return true;

    // Contains match
    if (spoken.contains(expected) || expected.contains(spoken)) return true;

    // Split into words and check
    final spokenWords = spoken.split(RegExp(r'\s+'));
    for (final w in spokenWords) {
      if (w == expected) {
        return true;
      }
      // Levenshtein-like similarity: allow 1-2 char difference for shorter words
      if (_isSimilar(w, expected)) {
        return true;
      }
    }

    return false;
  }

  bool _isSimilar(String a, String b) {
    if (a == b) return true;
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return false;

    int distance = _levenshtein(a, b);
    // Allow ~30% error rate, minimum 1
    final threshold = (maxLen * 0.3).ceil().clamp(1, 3);
    return distance <= threshold;
  }

  int _levenshtein(String s, String t) {
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final m = s.length;
    final n = t.length;
    final d = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      d[0][j] = j;
    }

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    return d[m][n];
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.exercise['question'] as String;
    final word = widget.exercise['word'] as String;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
              const Text('🎤', style: TextStyle(fontSize: 22)),
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
        const SizedBox(height: 28),

        // Word to speak
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: BoxDecoration(
            color: _c.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: darkGreen.withValues(alpha: 0.15),
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
          child: Column(
            children: [
              Text(
                word,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: _c.textPrimary,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              // Listen button - pronounce the word
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => TtsService().speakEnglish(word),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: darkGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.volume_up_rounded,
                        size: 18,
                        color: darkGreen.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Dinle',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: darkGreen.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Recognized text display
        if (_recognizedText.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _hasResult
                  ? (_answered
                        ? darkGreen.withValues(alpha: 0.08)
                        : orange.withValues(alpha: 0.08))
                  : _c.cardColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isListening
                    ? orange.withValues(alpha: 0.3)
                    : darkGreen.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hasResult
                      ? Icons.check_circle_rounded
                      : Icons.hearing_rounded,
                  size: 20,
                  color: _hasResult ? darkGreen.withValues(alpha: 0.7) : orange,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _recognizedText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _c.textPrimary,
                      fontStyle: _isListening
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Mic button with pulse + ripple
        GestureDetector(
          onTap: _isListening ? _stopListening : _startListening,
          child: SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ripple circles - only when listening
                if (_isListening)
                  ...List.generate(3, (i) {
                    return AnimatedBuilder(
                      animation: _rippleController,
                      builder: (context, _) {
                        final progress =
                            ((_rippleController.value + i * 0.33) % 1.0);
                        final size = 80.0 + progress * 60;
                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.red.withValues(
                                alpha: (1 - progress) * 0.4,
                              ),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                if (!_isListening)
                  ...List.generate(3, (i) {
                    return AnimatedBuilder(
                      animation: _rippleController,
                      builder: (context, _) {
                        final progress =
                            ((_rippleController.value + i * 0.33) % 1.0);
                        final size = 80.0 + progress * 60;
                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: orange.withValues(
                                alpha: (1 - progress) * 0.3,
                              ),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                // Main button with pulse
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + _pulseController.value * 0.08;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _isListening
                            ? [Colors.red, Colors.redAccent]
                            : [orange, const Color(0xFFFF6D00)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? Colors.red : orange)
                              .withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _statusText.isNotEmpty
              ? _statusText
              : (_isListening ? 'Konuşun...' : S.get('ex_speak_hint')),
          style: TextStyle(
            color: _isListening ? orange : _c.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
