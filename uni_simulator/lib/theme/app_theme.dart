import 'package:flutter/material.dart';

/// 低饱和配色：米白 + 深灰 + 少量蓝。
class AppColors {
  static const Color bone = Color(0xFFF6F3ED); // 米白背景
  static const Color surface = Color(0xFFFDFCF9); // 卡片
  static const Color ink = Color(0xFF2F2F31); // 深灰主文字
  static const Color inkSoft = Color(0xFF71717A); // 次级文字
  static const Color line = Color(0xFFE4DFD5); // 分隔线
  static const Color accent = Color(0xFF3E6FB0); // 少量蓝
  static const Color accentSoft = Color(0xFFE9EFF7);
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerSoft = Color(0xFFF7E9E7);
  static const Color warn = Color(0xFFA97B2C);
}

class AppTheme {
  /// 叙事正文用衬线体（思源宋体优先，回退系统衬线）。
  static const List<String> serifFallback = [
    'Noto Serif CJK SC',
    'Source Han Serif SC',
    'Songti SC',
    'SimSun',
    'serif',
  ];

  static const TextStyle narrativeStyle = TextStyle(
    fontSize: 17,
    height: 1.95,
    color: AppColors.ink,
    letterSpacing: 0.3,
    fontFamilyFallback: serifFallback,
  );

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      surface: AppColors.surface,
    ).copyWith(
      primary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      outlineVariant: AppColors.line,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bone,
      fontFamilyFallback: const [
        'Noto Sans CJK SC',
        'Source Han Sans SC',
        'sans-serif',
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bone,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.ink,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.line,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.12),
        trackHeight: 3,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.accentSoft,
        side: BorderSide.none,
        labelStyle: const TextStyle(color: AppColors.accent, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentSoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}