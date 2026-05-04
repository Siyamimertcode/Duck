import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/user_preferences.dart';
import '../services/duck_theme.dart';
import '../services/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  DuckColors get _c => context.duckColors;
  Color get darkGreen => _c.darkGreen;
  Color get orange => _c.orange;
  Color get cream => _c.cream;
  Color get lightGreen => _c.lightGreen;
  Color get lightOrange => _c.lightOrange;
  Color get lightCream =>
      context.isDarkMode ? const Color(0xFF162922) : const Color(0xFFFDFDFC);

  late final AnimationController _mainCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _sparkleCtrl;
  late final AnimationController _exitCtrl;

  // Exit animations
  late final Animation<double> _exitFade;
  late final Animation<double> _exitScale;

  // Main animations
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoBounce;
  late final Animation<double> _textSlide;
  late final Animation<double> _textFade;
  late final Animation<double> _bubblesFade;
  late final Animation<double> _taglineFade;

  Timer? _navigationFallbackTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // Main animation controller - longer duration
    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4750),
    );

    // Floating animation for decorative elements
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Sparkle animation
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Exit animation controller
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _exitFade = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut));

    _exitScale = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut));

    _logoScale = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
    );

    _logoFade = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    );

    _logoBounce = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.35, 0.55, curve: Curves.easeInOut),
    );

    _textSlide = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.3, 0.6, curve: Curves.easeOutCubic),
    );

    _textFade = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.35, 0.65, curve: Curves.easeIn),
    );

    _bubblesFade = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.2, 0.5, curve: Curves.easeIn),
    );

    _taglineFade = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.5, 0.8, curve: Curves.easeIn),
    );

    _mainCtrl.forward();
    _mainCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            _exitCtrl.forward();
          }
        });
      }
    });

    _exitCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          _checkUserAndNavigate();
        }
      }
    });

    // Fallback: never stay stuck on splash due to plugin/animation async issues.
    _navigationFallbackTimer = Timer(const Duration(seconds: 8), () {
      _checkUserAndNavigate();
    });

    // First-launch: skip voice/chime; greeting is handled later with the user's name.
    Future.microtask(() async {
      try {
        final isFirst = await UserPreferences.isFirstLaunch();
        if (!mounted || !isFirst) return;
        await UserPreferences.setFirstLaunchDone();
      } catch (_) {
        // Ignore first-launch flag errors; splash must remain stable.
      }
    });
  }

  Future<void> _checkUserAndNavigate() async {
    if (!mounted || _hasNavigated) return;

    try {
      final userName = await UserPreferences.getUserName();
      if (!mounted || _hasNavigated) return;

      _hasNavigated = true;
      _navigationFallbackTimer?.cancel();

      if (userName != null && userName.isNotEmpty) {
        // User exists, go directly to home
        Navigator.of(
          context,
        ).pushReplacementNamed('/home', arguments: userName);
      } else {
        // No user, go to onboarding
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    } catch (_) {
      if (!mounted || _hasNavigated) return;
      _hasNavigated = true;
      _navigationFallbackTimer?.cancel();
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  @override
  void dispose() {
    _navigationFallbackTimer?.cancel();
    _mainCtrl.dispose();
    _floatCtrl.dispose();
    _sparkleCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _mainCtrl,
          _floatCtrl,
          _sparkleCtrl,
          _exitCtrl,
        ]),
        builder: (context, _) {
          return Opacity(
            opacity: _exitFade.value,
            child: Transform.scale(
              scale: _exitScale.value,
              child: Container(
                width: size.width,
                height: size.height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cream,
                      lightCream,
                      context.isDarkMode
                          ? const Color(0xFF0F1F1A)
                          : const Color(0xFFF5F5F0),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative floating bubbles
                    ..._buildFloatingBubbles(size),

                    // Decorative wavy pattern at bottom
                    _buildWavyBottom(size),

                    // Sparkles
                    ..._buildSparkles(size),

                    // Decorative circles
                    _buildDecorativeCircles(size),

                    // Main content
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animated Duck Logo
                          _buildAnimatedLogo(),

                          const SizedBox(height: 28),

                          // App name with fun styling
                          _buildAppName(),

                          const SizedBox(height: 16),

                          // Tagline with pill background
                          _buildTagline(),

                          const SizedBox(height: 50),

                          // Cute loading indicator
                          _buildLoadingIndicator(),
                        ],
                      ),
                    ),

                    // Developer logo at bottom
                    _buildDeveloperLogo(),

                    // Mute Button (Top Right)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 16,
                      right: 16,
                      child: Opacity(
                        opacity: _exitFade.value,
                        child: _buildMuteButton(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildFloatingBubbles(Size size) {
    return [
      // Large orange bubble top right
      Positioned(
        top: size.height * 0.08,
        right: size.width * 0.1,
        child: Opacity(
          opacity: _bubblesFade.value * 0.6,
          child: Transform.translate(
            offset: Offset(0, math.sin(_floatCtrl.value * math.pi) * 8),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    lightOrange.withOpacity(0.8),
                    orange.withOpacity(0.4),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: orange.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // Small green bubble top left
      Positioned(
        top: size.height * 0.15,
        left: size.width * 0.15,
        child: Opacity(
          opacity: _bubblesFade.value * 0.5,
          child: Transform.translate(
            offset: Offset(0, math.cos(_floatCtrl.value * math.pi) * 6),
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    lightGreen.withOpacity(0.7),
                    darkGreen.withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      // Medium green bubble bottom left
      Positioned(
        bottom: size.height * 0.25,
        left: size.width * 0.08,
        child: Opacity(
          opacity: _bubblesFade.value * 0.4,
          child: Transform.translate(
            offset: Offset(0, math.sin(_floatCtrl.value * math.pi + 1) * 10),
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    lightGreen.withOpacity(0.6),
                    darkGreen.withOpacity(0.2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      // Small orange bubble bottom right
      Positioned(
        bottom: size.height * 0.3,
        right: size.width * 0.12,
        child: Opacity(
          opacity: _bubblesFade.value * 0.5,
          child: Transform.translate(
            offset: Offset(0, math.cos(_floatCtrl.value * math.pi + 0.5) * 7),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lightOrange.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildWavyBottom(Size size) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: _bubblesFade.value,
        child: CustomPaint(
          size: Size(size.width, 120),
          painter: WavePainter(
            color1: lightGreen.withOpacity(0.3),
            color2: darkGreen.withOpacity(0.15),
            animValue: _floatCtrl.value,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSparkles(Size size) {
    final sparklePositions = [
      Offset(size.width * 0.2, size.height * 0.35),
      Offset(size.width * 0.8, size.height * 0.4),
      Offset(size.width * 0.15, size.height * 0.55),
      Offset(size.width * 0.85, size.height * 0.5),
      Offset(size.width * 0.3, size.height * 0.25),
      Offset(size.width * 0.7, size.height * 0.28),
    ];

    return sparklePositions.asMap().entries.map((entry) {
      final index = entry.key;
      final pos = entry.value;
      final delay = index * 0.15;
      final sparkleValue = ((_sparkleCtrl.value + delay) % 1.0);
      final opacity = math.sin(sparkleValue * math.pi) * 0.7;

      return Positioned(
        left: pos.dx,
        top: pos.dy,
        child: Opacity(
          opacity: opacity * _bubblesFade.value,
          child: Transform.scale(
            scale: 0.5 + sparkleValue * 0.5,
            child: Icon(
              Icons.star_rounded,
              size: 16 + (index % 3) * 4,
              color: index.isEven ? orange : lightGreen,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildDecorativeCircles(Size size) {
    return Stack(
      children: [
        // Large decorative ring top
        Positioned(
          top: -size.height * 0.08,
          right: -size.width * 0.15,
          child: Opacity(
            opacity: _bubblesFade.value * 0.15,
            child: Container(
              width: size.width * 0.5,
              height: size.width * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: darkGreen, width: 2),
              ),
            ),
          ),
        ),
        // Large decorative ring bottom
        Positioned(
          bottom: -size.height * 0.05,
          left: -size.width * 0.2,
          child: Opacity(
            opacity: _bubblesFade.value * 0.1,
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: orange, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedLogo() {
    final bounceOffset = math.sin(_logoBounce.value * math.pi * 2) * 5;

    return Transform.translate(
      offset: Offset(0, -bounceOffset),
      child: Transform.scale(
        scale: 0.2 + _logoScale.value * 0.8,
        child: Opacity(
          opacity: _logoFade.value,
          child: Container(
            decoration: BoxDecoration(
              color: cream,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: darkGreen.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 15),
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: orange.withOpacity(0.1),
                  blurRadius: 60,
                  offset: const Offset(0, 25),
                  spreadRadius: 10,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/ducklogo.png',
              width: 190,
              height: 190,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppName() {
    final titleShadowColor = context.isDarkMode
        ? Colors.black.withValues(alpha: 0.35)
        : darkGreen.withValues(alpha: 0.1);
    final titleGradientColors = context.isDarkMode
        ? [const Color(0xFFE8FFF4), const Color(0xFFFFC86B)]
        : [darkGreen, const Color(0xFF2A7A65)];

    return Transform.translate(
      offset: Offset(0, (1 - _textSlide.value) * 40),
      child: Opacity(
        opacity: _textFade.value,
        child: Column(
          children: [
            // Fun styled title
            Stack(
              children: [
                // Shadow text
                Text(
                  'Duck',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: titleShadowColor,
                    letterSpacing: 2,
                  ),
                ),
                // Main text with gradient
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: titleGradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    'Duck',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Cute emoji line
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDotDecor(lightOrange),
                const SizedBox(width: 8),
                Text(
                  '🦆',
                  style: TextStyle(
                    fontSize: 20,
                    shadows: [
                      Shadow(color: orange.withOpacity(0.3), blurRadius: 10),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildDotDecor(lightGreen),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDotDecor(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildTagline() {
    return Opacity(
      opacity: _taglineFade.value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [darkGreen.withOpacity(0.9), darkGreen],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: darkGreen.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: lightOrange, size: 18),
            const SizedBox(width: 10),
            Text(
              S.get('splash_easy'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cream,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.auto_awesome, color: lightOrange, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Opacity(
      opacity: _taglineFade.value * 0.8,
      child: Column(
        children: [
          // Custom bouncing dots loader
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final delay = index * 0.2;
              final animValue = ((_sparkleCtrl.value + delay) % 1.0);
              final bounce = math.sin(animValue * math.pi) * 8;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Transform.translate(
                  offset: Offset(0, -bounce),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: index == 1 ? orange : darkGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (index == 1 ? orange : darkGreen).withOpacity(
                            0.3,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Text(
            S.get('splash_preparing'),
            style: TextStyle(
              fontSize: 13,
              color: darkGreen.withOpacity(0.6),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperLogo() {
    return Positioned(
      bottom: 35,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: _taglineFade.value * 0.95,
        child: Center(
          child: Image.asset(
            'assets/Atakstulogo.png',
            width: 540,
            height: 180,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildMuteButton() {
    return FutureBuilder<bool>(
      future: UserPreferences.getMuted(),
      builder: (context, snapshot) {
        final isMuted = snapshot.data ?? false;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await UserPreferences.saveMuted(!isMuted);
              setState(() {}); // Rebuild to update icon
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _c.cardColor.withOpacity(0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: darkGreen,
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }
}

// Custom wave painter for bottom decoration
class WavePainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final double animValue;

  WavePainter({
    required this.color1,
    required this.color2,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = color1
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = color2
      ..style = PaintingStyle.fill;

    final path1 = Path();
    final path2 = Path();

    // First wave
    path1.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final y =
          size.height * 0.5 +
          math.sin((x / size.width * 2 * math.pi) + (animValue * 2 * math.pi)) *
              15 +
          20;
      path1.lineTo(x, y);
    }
    path1.lineTo(size.width, size.height);
    path1.close();

    // Second wave (offset)
    path2.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final y =
          size.height * 0.6 +
          math.sin(
                (x / size.width * 2 * math.pi) + (animValue * 2 * math.pi) + 1,
              ) *
              12 +
          15;
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
    canvas.drawPath(path1, paint1);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) =>
      animValue != oldDelegate.animValue;
}
