import 'dart:math';
import 'package:flutter/material.dart';
import '../services/user_preferences.dart';
import '../services/duck_theme.dart';
import '../services/app_localizations.dart';

class SelectLevelScreen extends StatefulWidget {
  const SelectLevelScreen({super.key});

  @override
  State<SelectLevelScreen> createState() => _SelectLevelScreenState();
}

class _SelectLevelScreenState extends State<SelectLevelScreen>
    with TickerProviderStateMixin {
  // Brand Colors (dynamic from theme)
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get lightGreen => _c.lightGreen;
  Color get orange => _c.orange;
  Color get lightOrange => _c.lightOrange;
  Color get cream => _c.cream;

  // User name from onboarding
  String _userName = 'Kullanıcı';

  // Animation Controllers
  late final AnimationController _bubbleController;

  // Floating bubbles data
  final List<_FloatingBubble> _bubbles = [];
  bool _bubblesInitialized = false;

  // Selected level
  String? _selectedLevel;
  bool _showContent = false;
  bool _showButton = false;

  // Level data
  List<Map<String, dynamic>> get _levels => [
    {
      'level': 'A1',
      'title': S.get('level_beginner'),
      'description': S.get('level_beginner_desc'),
      'emoji': '🌱',
      'color': const Color(0xFF4CAF50),
    },
    {
      'level': 'A2',
      'title': S.get('level_elementary'),
      'description': S.get('level_elementary_desc'),
      'emoji': '🌿',
      'color': const Color(0xFF8BC34A),
    },
    {
      'level': 'B1',
      'title': S.get('level_pre_intermediate'),
      'description': S.get('level_pre_intermediate_desc'),
      'emoji': '🌳',
      'color': const Color(0xFFFF9800),
    },
    {
      'level': 'B2',
      'title': S.get('level_upper_intermediate'),
      'description': S.get('level_upper_intermediate_desc'),
      'emoji': '🌲',
      'color': const Color(0xFFFF5722),
    },
    {
      'level': 'C1',
      'title': S.get('level_advanced'),
      'description': S.get('level_advanced_desc'),
      'emoji': '🏆',
      'color': const Color(0xFF9C27B0),
    },
  ];

  @override
  void initState() {
    super.initState();

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _startAnimation();
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

    for (int i = 0; i < 15; i++) {
      final gridX = (i % 5) / 5.0;
      final gridY = (i ~/ 5) / 3.0;
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

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _showContent = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _showButton = true);
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    super.dispose();
  }

  void _selectLevel(String level) {
    setState(() => _selectedLevel = level);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bubblesInitialized) {
      _initBubbles();
      _bubblesInitialized = true;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      _userName = args;
    }
  }

  void _onContinue() async {
    if (_selectedLevel == null) return;

    // Save English level to storage
    await UserPreferences.saveEnglishLevel(_selectedLevel!);

    // Navigate to home with userName and selected level
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(
        '/home',
        arguments: {'userName': _userName, 'level': _selectedLevel},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Stack(
          children: [
            // Floating bubbles background
            _buildFloatingBubbles(),

            // Background decorations
            _buildBackgroundDecorations(),

            // Main content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Title
                  _buildTitle(),

                  const SizedBox(height: 32),

                  // Level cards
                  Expanded(child: _buildLevelCards()),

                  // Continue button
                  _buildContinueButton(),

                  const SizedBox(height: 24),
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
        Positioned(
          bottom: -100,
          right: -80,
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

  Widget _buildTitle() {
    return AnimatedOpacity(
      opacity: _showContent ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 600),
      child: AnimatedSlide(
        offset: _showContent ? Offset.zero : const Offset(0, -0.3),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('📚', style: TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [darkGreen, lightGreen],
              ).createShader(bounds),
              child: Text(
                S.get('select_where'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.get('select_subtitle'),
              style: TextStyle(
                fontSize: 15,
                color: darkGreen.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCards() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _levels.length,
      itemBuilder: (context, index) {
        final level = _levels[index];
        final isSelected = _selectedLevel == level['level'];
        final delay = 100 + (index * 100);

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: _showContent ? 1.0 : 0.0),
          duration: Duration(milliseconds: 800 + delay),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildLevelCard(level, isSelected),
          ),
        );
      },
    );
  }

  Widget _buildLevelCard(Map<String, dynamic> level, bool isSelected) {
    final Color levelColor = level['color'] as Color;

    return GestureDetector(
      onTap: () => _selectLevel(level['level']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? levelColor.withOpacity(0.1) : _c.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? levelColor : lightGreen.withOpacity(0.15),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? levelColor.withOpacity(0.2)
                  : darkGreen.withOpacity(0.06),
              blurRadius: isSelected ? 20 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Level badge
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSelected
                      ? [levelColor, levelColor.withOpacity(0.8)]
                      : [
                          levelColor.withOpacity(0.15),
                          levelColor.withOpacity(0.1),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: levelColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  level['level'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : levelColor,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        level['emoji'],
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          level['title'],
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? levelColor : darkGreen,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level['description'],
                    style: TextStyle(
                      fontSize: 13,
                      color: darkGreen.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Check icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? levelColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? levelColor : lightGreen.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    final bool canContinue = _selectedLevel != null;

    return AnimatedOpacity(
      opacity: _showButton ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: AnimatedSlide(
        offset: _showButton ? Offset.zero : const Offset(0, 0.5),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: canContinue
                  ? [darkGreen, const Color(0xFF2A7A65)]
                  : [darkGreen.withOpacity(0.4), darkGreen.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: canContinue
                ? [
                    BoxShadow(
                      color: darkGreen.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canContinue ? _onContinue : null,
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    canContinue ? S.get('select_start') : S.get('select_pick'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: canContinue ? cream : cream.withOpacity(0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (canContinue) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: cream,
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
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

      final time = animationValue * 2 * pi;
      final yMovement = sin(time * bubble.speed + bubble.wobbleOffset) * 0.08;
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
