import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../services/app_localizations.dart';
import '../services/duck_theme.dart';
import '../services/navigation_helper.dart';
import '../services/tts_service.dart';
import '../services/user_preferences.dart';

class ListeningPracticeScreen extends StatefulWidget {
  const ListeningPracticeScreen({super.key});

  @override
  State<ListeningPracticeScreen> createState() =>
      _ListeningPracticeScreenState();
}

class _ListeningPracticeScreenState extends State<ListeningPracticeScreen>
    with SingleTickerProviderStateMixin {
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get lightGreen => _c.lightGreen;
  Color get orange => _c.orange;

  final TtsService _ttsService = TtsService();
  List<String> _sentences = [];
  int _currentIndex = 0;
  int _previousIndex = -1;
  bool _isLoading = true;
  bool _showIntro = true;
  String? _error;

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
    _loadSentences();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadSentences() async {
    try {
      final jsonString = await rootBundle.loadString(
        'json/listening_sentences.json',
      );
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final sentences = List<String>.from(data['sentences'] as List);

      if (!mounted) return;
      setState(() {
        _sentences = sentences..shuffle();
        _isLoading = false;
      });
      _animController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = S.get('listen_load_error', args: {'e': e.toString()});
      });
    }
  }

  Future<void> _speakCurrentSentence() async {
    if (_sentences.isEmpty) return;
    await _ttsService.speakEnglish(_sentences[_currentIndex]);
    await UserPreferences.recordListeningActivity();
  }

  void _nextSentence() {
    if (_sentences.isEmpty) return;
    _animController.reset();

    late int nextIndex;
    if (_sentences.length == 1) {
      nextIndex = 0;
    } else {
      do {
        nextIndex = DateTime.now().microsecond % _sentences.length;
      } while (nextIndex == _previousIndex);
    }

    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = nextIndex;
    });
    _animController.forward();
    _speakCurrentSentence();
  }

  void _startPractice() {
    setState(() {
      _showIntro = false;
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _speakCurrentSentence();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _withSafePop(
        Scaffold(
          backgroundColor: _c.cream,
          body: Center(child: CircularProgressIndicator(color: orange)),
        ),
      );
    }

    if (_error != null) {
      return _withSafePop(
        Scaffold(
          backgroundColor: _c.cream,
          appBar: _buildAppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                style: TextStyle(color: darkGreen, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return _showIntro ? _buildIntroScreen() : _buildPracticeScreen();
  }

  Widget _withSafePop(Widget child) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        NavigationHelper.safePopOrHome(context);
      },
      child: child,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close, color: darkGreen),
        onPressed: () => NavigationHelper.safePopOrHome(context),
      ),
    );
  }

  Widget _buildIntroScreen() {
    return _withSafePop(
      Scaffold(
        backgroundColor: _c.cream,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🎧', style: TextStyle(fontSize: 60)),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  S.get('listen_title'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _c.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: darkGreen.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.hearing_rounded,
                        S.get('listen_intro_hear'),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.touch_app_rounded,
                        S.get('listen_intro_next'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _startPractice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: orange.withValues(alpha: 0.4),
                    ),
                    child: Text(
                      S.get('listen_start'),
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
            color: orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: orange, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: darkGreen.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeScreen() {
    final sentence = _sentences[_currentIndex];

    return _withSafePop(
      Scaffold(
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
                    color: darkGreen.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.close, color: darkGreen, size: 20),
            ),
            onPressed: () => NavigationHelper.safePopOrHome(context),
          ),
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentIndex + 1}/${_sentences.length}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: orange,
              ),
            ),
          ),
          centerTitle: true,
        ),
        body: GestureDetector(
          onTap: _nextSentence,
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: null,
                      backgroundColor: darkGreen.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(orange),
                      minHeight: 8,
                    ),
                  ),
                  const Spacer(),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 44,
                        ),
                        decoration: BoxDecoration(
                          color: _c.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: darkGreen.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                S.get('listen_badge'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: orange,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              sentence,
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: darkGreen,
                                height: 1.35,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            GestureDetector(
                              onTap: _speakCurrentSentence,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: orange.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.volume_up_rounded,
                                      size: 20,
                                      color: orange,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      S.get('listen_again'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: darkGreen.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: darkGreen.withValues(alpha: 0.5),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          S.get('listen_next_hint'),
                          style: TextStyle(
                            fontSize: 14,
                            color: darkGreen.withValues(alpha: 0.5),
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
      ),
    );
  }
}
