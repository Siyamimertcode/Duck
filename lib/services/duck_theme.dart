import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ╔══════════════════════════════════════════════════════════════════════╗
// ║  DuckTheme — centralised light & dark themes for the Duck app      ║
// ╚══════════════════════════════════════════════════════════════════════╝

/// A [ThemeExtension] that carries the Duck brand colours so every widget
/// can resolve its palette from [Theme.of(context).extension<DuckColors>()].
@immutable
class DuckColors extends ThemeExtension<DuckColors> {
  const DuckColors({
    required this.darkGreen,
    required this.lightGreen,
    required this.orange,
    required this.lightOrange,
    required this.cream,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnPrimary,
    required this.divider,
    required this.correctGreen,
    required this.wrongRed,
    required this.successGreen,
    required this.shimmer,
    required this.inputFill,
    required this.shadowColor,
  });

  final Color darkGreen;
  final Color lightGreen;
  final Color orange;
  final Color lightOrange;
  final Color cream;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnPrimary;
  final Color divider;
  final Color correctGreen;
  final Color wrongRed;
  final Color successGreen;
  final Color shimmer;
  final Color inputFill;
  final Color shadowColor;

  // ── Light palette ────────────────────────────────────────────────
  static const light = DuckColors(
    darkGreen: Color(0xFF1D6755),
    lightGreen: Color(0xFF2A8A6E),
    orange: Color(0xFFEA8018),
    lightOrange: Color(0xFFF5A623),
    cream: Color(0xFFFCFCFB),
    cardColor: Colors.white,
    textPrimary: Color(0xFF1D6755),
    textSecondary: Color(0xFF6C9C90),
    textOnPrimary: Colors.white,
    divider: Color(0x141D6755), // darkGreen 8%
    correctGreen: Color(0xFF4CAF50),
    wrongRed: Color(0xFFE53935),
    successGreen: Color(0xFF66BB6A),
    shimmer: Color(0xFFF0F0F0),
    inputFill: Colors.white,
    shadowColor: Color(0x0F1D6755), // darkGreen 6%
  );

  // ── Dark palette ─────────────────────────────────────────────────
  static const dark = DuckColors(
    darkGreen: Color(0xFF5BC4A0),
    lightGreen: Color(0xFF3DAF90),
    orange: Color(0xFFE07B10),
    lightOrange: Color(0xFFC86D08),
    cream: Color(0xFF0D1B16),
    cardColor: Color(0xFF162922),
    textPrimary: Color(0xFFE5F0EB),
    textSecondary: Color(0xFF89A99D),
    textOnPrimary: Color(0xFF0D1B16),
    divider: Color(0x1AE5F0EB), // white 10%
    correctGreen: Color(0xFF66BB6A),
    wrongRed: Color(0xFFEF5350),
    successGreen: Color(0xFF81C784),
    shimmer: Color(0xFF1E332C),
    inputFill: Color(0xFF1E332C),
    shadowColor: Color(0x33000000), // black 20%
  );

  @override
  DuckColors copyWith({
    Color? darkGreen,
    Color? lightGreen,
    Color? orange,
    Color? lightOrange,
    Color? cream,
    Color? cardColor,
    Color? textPrimary,
    Color? textSecondary,
    Color? textOnPrimary,
    Color? divider,
    Color? correctGreen,
    Color? wrongRed,
    Color? successGreen,
    Color? shimmer,
    Color? inputFill,
    Color? shadowColor,
  }) {
    return DuckColors(
      darkGreen: darkGreen ?? this.darkGreen,
      lightGreen: lightGreen ?? this.lightGreen,
      orange: orange ?? this.orange,
      lightOrange: lightOrange ?? this.lightOrange,
      cream: cream ?? this.cream,
      cardColor: cardColor ?? this.cardColor,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      divider: divider ?? this.divider,
      correctGreen: correctGreen ?? this.correctGreen,
      wrongRed: wrongRed ?? this.wrongRed,
      successGreen: successGreen ?? this.successGreen,
      shimmer: shimmer ?? this.shimmer,
      inputFill: inputFill ?? this.inputFill,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  DuckColors lerp(DuckColors? other, double t) {
    if (other is! DuckColors) return this;
    return DuckColors(
      darkGreen: Color.lerp(darkGreen, other.darkGreen, t)!,
      lightGreen: Color.lerp(lightGreen, other.lightGreen, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      lightOrange: Color.lerp(lightOrange, other.lightOrange, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      correctGreen: Color.lerp(correctGreen, other.correctGreen, t)!,
      wrongRed: Color.lerp(wrongRed, other.wrongRed, t)!,
      successGreen: Color.lerp(successGreen, other.successGreen, t)!,
      shimmer: Color.lerp(shimmer, other.shimmer, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}

// ╔══════════════════════════════════════════════════════════════════════╗
// ║  Convenience extension on BuildContext                              ║
// ╚══════════════════════════════════════════════════════════════════════╝

extension DuckThemeContext on BuildContext {
  DuckColors get duckColors => Theme.of(this).extension<DuckColors>()!;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

// ╔══════════════════════════════════════════════════════════════════════╗
// ║  ThemeData builders                                                 ║
// ╚══════════════════════════════════════════════════════════════════════╝

class DuckTheme {
  DuckTheme._();

  // ── Original brand constants (useful for gradients on colored surfaces) ──
  static const brandGreen = Color(0xFF1D6755);
  static const brandLightGreen = Color(0xFF2A8A6E);
  static const brandOrange = Color(0xFFEA8018);

  // ────────────────────────────────────────────────────────────────────
  //  LIGHT THEME
  // ────────────────────────────────────────────────────────────────────
  static ThemeData get light {
    const c = DuckColors.light;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      extensions: const [c],
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandGreen,
        brightness: Brightness.light,
        primary: brandGreen,
        secondary: c.orange,
        tertiary: c.lightOrange,
        surface: c.cream,
      ),
      scaffoldBackgroundColor: c.cream,
      cardColor: c.cardColor,
      dividerColor: c.divider,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: brandGreen,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFFFCFCFB),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: c.cardColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: brandGreen,
          foregroundColor: c.cream,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        backgroundColor: c.orange,
        foregroundColor: c.cream,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: c.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
        bodyLarge: const TextStyle(fontSize: 16, color: Color(0xFF37474F)),
        bodyMedium: TextStyle(fontSize: 14, color: c.textSecondary),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  //  DARK THEME
  // ────────────────────────────────────────────────────────────────────
  static ThemeData get dark {
    const c = DuckColors.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: const [c],
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandGreen,
        brightness: Brightness.dark,
        primary: c.darkGreen,
        secondary: c.orange,
        tertiary: c.lightOrange,
        surface: c.cream,
      ),
      scaffoldBackgroundColor: c.cream,
      cardColor: c.cardColor,
      dividerColor: c.divider,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: c.darkGreen,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: c.cream,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: c.cardColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: c.darkGreen,
          foregroundColor: c.cream,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        backgroundColor: c.orange,
        foregroundColor: c.cream,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: c.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: c.textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: c.textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: c.textSecondary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: c.textPrimary,
        ),
        contentTextStyle: TextStyle(fontSize: 14, color: c.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputFill,
        hintStyle: TextStyle(color: c.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.divider, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.orange, width: 2),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.orange;
          return c.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return c.orange.withOpacity(0.35);
          }
          return c.divider;
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: c.shimmer,
        circularTrackColor: c.shimmer,
      ),
    );
  }
}
