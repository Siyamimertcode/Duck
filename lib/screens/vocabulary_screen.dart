import 'package:flutter/material.dart';
import '../services/word_service.dart';
import '../services/user_preferences.dart';
import '../services/duck_theme.dart';
import '../services/app_localizations.dart';
import '../services/tts_service.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen>
    with SingleTickerProviderStateMixin {
  // Colors
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get lightGreen => _c.lightGreen;
  Color get orange => _c.orange;

  List<WordItem> _words = [];
  int _currentIndex = 0;
  int _previousIndex = -1;
  bool _isLoading = true;
  bool _showIntro = true;
  String _currentLevel = 'A1';

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _loadWords();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    final level = await UserPreferences.getCurrentLevel();
    final words = await WordService.getWordsForLevel(level);

    if (mounted) {
      setState(() {
        _currentLevel = level;
        _words = List.from(words)..shuffle();
        _isLoading = false;
      });
      _animController.forward();
    }
  }

  void _nextWord() {
    _animController.reset();

    late int nextIndex;
    if (_words.length == 1) {
      // Eğer sadece 1 kelime varsa, hep onu göster
      nextIndex = 0;
    } else {
      // Rastgele yeni kelime seç, ama önceki kelimeyle aynı olmasın
      do {
        nextIndex = DateTime.now().microsecond % _words.length;
      } while (nextIndex == _previousIndex);
    }

    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = nextIndex;
    });
    _animController.forward();

    // Auto-speak the new word
    TtsService().speakEnglish(_words[_currentIndex].english);
  }

  void _startPractice() {
    setState(() {
      _showIntro = false;
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || _words.isEmpty) return;
      TtsService().speakEnglish(_words[_currentIndex].english);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _c.cream,
        body: Center(child: CircularProgressIndicator(color: lightGreen)),
      );
    }

    if (_showIntro) {
      return _buildIntroScreen();
    }

    return _buildPracticeScreen();
  }

  Widget _buildIntroScreen() {
    return Scaffold(
      backgroundColor: _c.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: lightGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('📖', style: TextStyle(fontSize: 60)),
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                S.get('vocab_title'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 16),

              // Level badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: orange.withOpacity(0.3)),
                ),
                child: Text(
                  S.get('vocab_level', args: {'level': _currentLevel}),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: orange,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Description
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _c.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: darkGreen.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      Icons.touch_app_rounded,
                      S.get('vocab_tap_hint'),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.translate_rounded,
                      S.get('vocab_learn_desc'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Start button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startPractice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: lightGreen.withOpacity(0.4),
                  ),
                  child: Text(
                    S.get('vocab_start'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: lightGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: lightGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: darkGreen.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeScreen() {
    final currentWord = _words[_currentIndex];

    return Scaffold(
      backgroundColor: _c.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _c.cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.close, color: darkGreen, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '∞',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: orange,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _currentLevel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: lightGreen,
                ),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _nextWord,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: null, // null means indeterminate/infinite animation
                    backgroundColor: darkGreen.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(lightGreen),
                    minHeight: 8,
                  ),
                ),
                const Spacer(),

                // Word card
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 48,
                      ),
                      decoration: BoxDecoration(
                        color: _c.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: darkGreen.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // English word
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: lightGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '🇬🇧 English',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: lightGreen,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            currentWord.english,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: darkGreen,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          // Speaker button
                          GestureDetector(
                            onTap: () =>
                                TtsService().speakEnglish(currentWord.english),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: lightGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: lightGreen.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.volume_up_rounded,
                                    size: 20,
                                    color: lightGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Dinle',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: lightGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Divider
                          Container(
                            width: 60,
                            height: 3,
                            decoration: BoxDecoration(
                              color: orange.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Turkish word
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              S.get('vocab_turkish'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: orange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            currentWord.turkish,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: orange,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Hint
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: darkGreen.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        color: darkGreen.withOpacity(0.5),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        S.get('vocab_next_hint'),
                        style: TextStyle(
                          fontSize: 14,
                          color: darkGreen.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
