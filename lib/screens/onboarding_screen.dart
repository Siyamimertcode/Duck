import 'dart:math';
import 'package:flutter/material.dart';
import '../services/user_preferences.dart';
import '../services/tts_service.dart';
import '../services/duck_theme.dart';
import '../services/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // Brand Colors (themed)
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get lightGreen => _c.lightGreen;
  Color get orange => _c.orange;
  Color get lightOrange => _c.lightOrange;
  Color get cream => _c.cream;

  // Animation Controllers
  late final AnimationController _pulseController;
  late final AnimationController _wobbleController;
  late final AnimationController _bubbleController;

  // Animations
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _wobbleAnimation;

  // Floating bubbles data
  final List<_FloatingBubble> _bubbles = [];

  // Single short prompt; avoid long intros like "Merhaba ben Duck".
  List<String> get _messages => [S.get('onboard_ask_name')];

  int _phase = 0;
  String _typed = '';
  bool _showInput = false;
  bool _showAvatar = false;
  bool _showBubble = false;

  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  // Birthday step
  bool _showBirthdayInput = false;
  DateTime? _selectedBirthday;

  // Welcome
  bool _showWelcome = false;
  String _welcomeText = '';
  bool _showButtons = false;

  // Transition state
  final bool _showTransition = false;
  String _userName = '';
  bool _bubblesInitialized = false;

  @override
  void initState() {
    super.initState();

    // Pulse animation for avatar (gentle breathing effect)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Wobble animation (gentle side-to-side)
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);
    _wobbleAnimation = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _wobbleController, curve: Curves.easeInOut),
    );

    // Bubble animation controller
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Start sequence
    _startSequence();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bubblesInitialized) {
      _bubblesInitialized = true;
      _initBubbles();
    }
  }

  void _initBubbles() {
    final random = Random();
    final colors = [
      darkGreen.withOpacity(0.08),
      lightGreen.withOpacity(0.1),
      orange.withOpacity(0.08),
      lightOrange.withOpacity(0.1),
      darkGreen.withOpacity(0.06),
      orange.withOpacity(0.06),
    ];

    // 20 bubbles (30% more than 15)
    // Distribute bubbles evenly across the screen to avoid spawning in clusters
    for (int i = 0; i < 20; i++) {
      // Create a grid-like distribution with some randomness
      final gridX = (i % 5) / 5.0; // 5 columns
      final gridY = (i ~/ 5) / 4.0; // 4 rows

      // Add randomness within each grid cell
      final randomOffsetX = (random.nextDouble() - 0.5) * 0.18;
      final randomOffsetY = (random.nextDouble() - 0.5) * 0.22;

      _bubbles.add(
        _FloatingBubble(
          x: (gridX + randomOffsetX).clamp(0.05, 0.95),
          y: (gridY + randomOffsetY).clamp(0.05, 0.95),
          size: (random.nextDouble() * 40 + 15) * 0.6,
          speed: random.nextDouble() * 0.3 + 0.1,
          color: colors[random.nextInt(colors.length)],
          wobbleOffset: random.nextDouble() * 2 * pi,
          wobbleSpeed: random.nextDouble() * 0.5 + 0.3,
        ),
      );
    }
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _showAvatar = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _showBubble = true);
    await Future.delayed(const Duration(milliseconds: 400));
    _startTyping();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _wobbleController.dispose();
    _bubbleController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _startTyping() async {
    for (; _phase < _messages.length; _phase++) {
      final msg = _messages[_phase];

      // Use runes to handle emojis properly (multi-byte characters)
      final runes = msg.runes.toList();
      for (int i = 1; i <= runes.length; i++) {
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 45));
        setState(() => _typed = String.fromCharCodes(runes.sublist(0, i)));
      }
      await Future.delayed(const Duration(milliseconds: 800));
      if (_phase < _messages.length - 1) {
        // Clear text for next message
        setState(() => _typed = '');
        await Future.delayed(const Duration(milliseconds: 200));
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() => _showInput = true);
      }
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Future<void> _onContinue() async {
    final raw = _nameController.text.trim();
    if (raw.isEmpty) return;
    final name = _capitalize(raw);
    _userName = name;

    // Save user name to local storage
    await UserPreferences.saveUserName(name);

    setState(() {
      _showInput = false;
      _showBubble = false;
    });
    await Future.delayed(const Duration(milliseconds: 400));

    // Show birthday input step (text only, no voice prompt)
    setState(() {
      _showBubble = true;
      _typed = '🎂 Doğum tarihini girebilir misin?';
    });
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _showBirthdayInput = true);
  }

  Future<void> _onBirthdaySelected() async {
    if (_selectedBirthday != null) {
      await UserPreferences.saveBirthday(
        _selectedBirthday!.month,
        _selectedBirthday!.day,
      );
    }

    setState(() {
      _showBirthdayInput = false;
      _showBubble = false;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {
      _showWelcome = true;
      _welcomeText = 'Hoşgeldin, $_userName';
    });

    // Speak only the welcome with name
    TtsService().speakTurkish('Hoşgeldin $_userName');

    await Future.delayed(const Duration(milliseconds: 700));
    setState(() => _showButtons = true);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: now,
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: darkGreen,
              onPrimary: cream,
              surface: _c.cardColor,
              onSurface: _c.textPrimary,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child,
        );
      },
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _selectedBirthday = picked);
    }
  }

  void _onLevelTest() =>
      Navigator.of(context).pushReplacementNamed('/level-test');

  Future<void> _onKnowMyLevel() async {
    // Hide buttons and welcome
    setState(() {
      _showButtons = false;
      _showWelcome = false;
      _showAvatar = false;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    // Navigate directly to select-level with userName
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacementNamed('/select-level', arguments: _userName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Stack(
          children: [
            // Animated floating bubbles background
            _buildFloatingBubbles(),

            // Background decorations
            _buildBackgroundDecorations(),

            // Main content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                children: [
                  const SizedBox(height: 50),

                  // Animated Avatar (centered, no horizontal movement)
                  Center(child: _buildAnimatedAvatar()),

                  const SizedBox(height: 36),

                  // Chat bubble with typing
                  if (!_showWelcome) _buildChatBubble(),

                  // Name input
                  if (_showInput) ...[
                    const SizedBox(height: 24),
                    _buildNameInput(),
                    const SizedBox(height: 20),
                    _buildContinueButton(),
                  ],

                  // Birthday input
                  if (_showBirthdayInput) ...[
                    const SizedBox(height: 24),
                    _buildBirthdayInput(),
                    const SizedBox(height: 20),
                    _buildBirthdayContinueButton(),
                  ],

                  // Welcome section
                  if (_showWelcome) ...[
                    const SizedBox(height: 20),
                    _buildWelcomeSection(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],

                  // Transition section
                  if (_showTransition) ...[
                    const SizedBox(height: 20),
                    _buildTransitionSection(),
                  ],

                  const Spacer(),
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

  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        // Top right gradient circle (orange dust)
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [orange.withOpacity(0.12), orange.withOpacity(0.0)],
              ),
            ),
          ),
        ),
        // Top left gradient circle (green dust) - matching top right style
        Positioned(
          top: -80,
          left: -60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  lightGreen.withOpacity(0.12),
                  lightGreen.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        // Bottom left gradient circle
        Positioned(
          bottom: -100,
          left: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  darkGreen.withOpacity(0.08),
                  darkGreen.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedAvatar() {
    return AnimatedOpacity(
      opacity: _showAvatar ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      child: AnimatedScale(
        scale: _showAvatar ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _wobbleAnimation]),
          builder: (context, child) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateZ(_wobbleAnimation.value)
                ..scale(_pulseAnimation.value),
              child: child,
            );
          },
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_c.cardColor, cream],
              ),
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
                BoxShadow(
                  color: orange.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: lightGreen.withOpacity(0.2), width: 3),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Image.asset('assets/duckavatar.png', fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble() {
    return AnimatedOpacity(
      opacity: _showBubble ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: AnimatedSlide(
        offset: _showBubble ? Offset.zero : const Offset(0, 0.3),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          constraints: const BoxConstraints(minHeight: 60),
          decoration: BoxDecoration(
            color: _c.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: darkGreen.withOpacity(0.08),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(color: lightGreen.withOpacity(0.15), width: 2),
          ),
          child: Text(
            _typed.isEmpty ? ' ' : _typed,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: darkGreen,
              letterSpacing: 0.3,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameInput() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _showInput ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 80 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _c.cardColor,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.1),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: lightGreen.withOpacity(0.25),
                width: 2.5,
              ),
            ),
            child: TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: darkGreen,
                letterSpacing: 0.3,
              ),
              decoration: InputDecoration(
                hintText: S.get('onboard_name_hint'),
                hintStyle: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  color: lightGreen.withOpacity(0.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 22,
                ),
                border: InputBorder.none,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Icon(
                    Icons.edit_rounded,
                    color: lightOrange.withOpacity(0.8),
                    size: 24,
                  ),
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(
                    Icons.person_rounded,
                    color: lightGreen.withOpacity(0.7),
                    size: 26,
                  ),
                ),
              ),
              onSubmitted: (_) => _onContinue(),
            ),
          ),
          const SizedBox(height: 14),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 1000),
            opacity: _showInput ? 1.0 : 0.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tips_and_updates_rounded,
                        size: 14,
                        color: orange.withOpacity(0.8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        S.get('onboard_name_note'),
                        style: TextStyle(
                          fontSize: 12,
                          color: darkGreen.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
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

  Widget _buildContinueButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _showInput ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        // Add slight delay effect by using a modified curve
        final delayedValue = (value - 0.15).clamp(0.0, 1.0) / 0.85;
        return Transform.translate(
          offset: Offset(0, 100 * (1 - delayedValue)),
          child: Opacity(opacity: delayedValue, child: child),
        );
      },
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [darkGreen, Color(0xFF2A7A65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: darkGreen.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _onContinue,
            borderRadius: BorderRadius.circular(22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  S.get('onboard_continue'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: cream,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: cream,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBirthdayInput() {
    final monthNames = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _showBirthdayInput ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 80 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: _pickBirthday,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: _c.cardColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: darkGreen.withOpacity(0.1),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: lightGreen.withOpacity(0.25), width: 2.5),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('🎂', style: TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _selectedBirthday != null
                      ? '${_selectedBirthday!.day} ${monthNames[_selectedBirthday!.month - 1]} ${_selectedBirthday!.year}'
                      : 'Doğum tarihini seç...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _selectedBirthday != null
                        ? darkGreen
                        : lightGreen.withOpacity(0.5),
                  ),
                ),
              ),
              Icon(
                Icons.calendar_today_rounded,
                color: orange.withOpacity(0.7),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBirthdayContinueButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _showBirthdayInput ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        final delayedValue = (value - 0.15).clamp(0.0, 1.0) / 0.85;
        return Transform.translate(
          offset: Offset(0, 100 * (1 - delayedValue)),
          child: Opacity(opacity: delayedValue, child: child),
        );
      },
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [darkGreen, const Color(0xFF2A7A65)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _selectedBirthday != null ? _onBirthdaySelected : null,
                borderRadius: BorderRadius.circular(22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      S.get('onboard_continue'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _selectedBirthday != null
                            ? cream
                            : cream.withOpacity(0.5),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: _selectedBirthday != null
                            ? cream
                            : cream.withOpacity(0.5),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Skip option
          TextButton(
            onPressed: _onBirthdaySelected,
            child: Text(
              'Atla',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: darkGreen.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitionSection() {
    return AnimatedOpacity(
      opacity: _showTransition ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      child: AnimatedScale(
        scale: _showTransition ? 1.0 : 0.8,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutBack,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: _c.cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: darkGreen.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
              BoxShadow(
                color: orange.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: lightGreen.withOpacity(0.15), width: 2),
          ),
          child: Column(
            children: [
              // Rocket emoji with animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: const Text('🚀', style: TextStyle(fontSize: 48)),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Transition text with gradient
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [darkGreen, lightGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  S.get('onboard_lets_start'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Name with orange gradient
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [orange, lightOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Text(
                  _userName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Animated dots loading
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 600 + (index * 200)),
                    curve: Curves.easeInOut,
                    builder: (context, value, _) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.lerp(
                            lightGreen.withOpacity(0.3),
                            orange,
                            value,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return AnimatedOpacity(
      opacity: _showWelcome ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      child: AnimatedScale(
        scale: _showWelcome ? 1.0 : 0.8,
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        child: Column(
          children: [
            // Welcome text with gradient
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [darkGreen, lightGreen],
              ).createShader(bounds),
              child: Text(
                _welcomeText,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🚀', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    S.get('onboard_great_journey'),
                    style: TextStyle(
                      fontSize: 16,
                      color: darkGreen.withOpacity(0.8),
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

  Widget _buildActionButtons() {
    return AnimatedOpacity(
      opacity: _showButtons ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Column(
        children: [
          // Level Test Button
          AnimatedSlide(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            offset: _showButtons ? Offset.zero : const Offset(0, 0.4),
            child: Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [orange, lightOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: orange.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _onLevelTest,
                  borderRadius: BorderRadius.circular(22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.quiz_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        S.get('onboard_placement_test'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Know My Level Button
          AnimatedSlide(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            offset: _showButtons ? Offset.zero : const Offset(0, 0.5),
            child: Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                color: _c.cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: darkGreen.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: darkGreen.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _onKnowMyLevel,
                  borderRadius: BorderRadius.circular(22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_rounded, color: darkGreen, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        S.get('onboard_know_my_level'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: darkGreen,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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

// Custom painter for floating bubbles
class _BubblePainter extends CustomPainter {
  final List<_FloatingBubble> bubbles;
  final double animationValue;

  _BubblePainter({required this.bubbles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (final bubble in bubbles) {
      final paint = Paint()
        ..color = bubble.color
        ..style = PaintingStyle.fill;

      // Use sin/cos for smooth continuous movement without jumps
      // Each bubble has its own phase offset for variety
      final time = animationValue * 2 * pi;

      // Smooth vertical oscillation
      final yMovement = sin(time * bubble.speed + bubble.wobbleOffset) * 0.08;

      // Smooth horizontal wobble
      final xWobble = sin(time * bubble.wobbleSpeed + bubble.wobbleOffset) * 15;

      final x = bubble.x * size.width + xWobble;
      final y = (bubble.y + yMovement) * size.height;

      canvas.drawCircle(Offset(x, y), bubble.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
