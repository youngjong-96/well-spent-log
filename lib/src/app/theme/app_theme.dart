import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansKR',
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.surface,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.graphite,
        primaryFixed: AppColors.skyBlue,
        primaryFixedDim: AppColors.softBlue,
        onPrimaryFixed: AppColors.surface,
        onPrimaryFixedVariant: AppColors.surface,
        secondary: AppColors.navyBlue,
        onSecondary: AppColors.surface,
        secondaryContainer: AppColors.softBlue,
        onSecondaryContainer: AppColors.graphite,
        secondaryFixed: AppColors.softBlue,
        secondaryFixedDim: AppColors.skyBlue,
        onSecondaryFixed: AppColors.graphite,
        onSecondaryFixedVariant: AppColors.graphite,
        tertiary: AppColors.skyBlue,
        onTertiary: AppColors.surface,
        tertiaryContainer: AppColors.softBlue,
        onTertiaryContainer: AppColors.graphite,
        tertiaryFixed: AppColors.skyBlue,
        tertiaryFixedDim: AppColors.softBlue,
        onTertiaryFixed: AppColors.surface,
        onTertiaryFixedVariant: AppColors.surface,
        error: AppColors.navyBlue,
        onError: AppColors.surface,
        errorContainer: AppColors.softBlue,
        onErrorContainer: AppColors.graphite,
        surface: AppColors.surface,
        onSurface: AppColors.graphite,
        surfaceDim: AppColors.paleBlue,
        surfaceBright: AppColors.surface,
        surfaceContainerLowest: AppColors.surface,
        surfaceContainerLow: AppColors.paleBlue,
        surfaceContainer: AppColors.paleBlue,
        surfaceContainerHigh: AppColors.softBlue,
        surfaceContainerHighest: AppColors.softBlue,
        onSurfaceVariant: AppColors.graphite,
        outline: AppColors.skyBlue,
        outlineVariant: AppColors.softBlue,
        shadow: AppColors.navyBlue,
        scrim: AppColors.navyBlue,
        inverseSurface: AppColors.navyBlue,
        onInverseSurface: AppColors.surface,
        inversePrimary: AppColors.softBlue,
        surfaceTint: AppColors.skyBlue,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontSize: 26,
          height: 1.25,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 17,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          fontSize: 13,
          height: 1.4,
          color: AppColors.textSecondary.withValues(alpha: 0.7),
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.paleBlue,
        height: 72,
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: AppColors.surface,
        elevation: 12,
        shadowColor: AppColors.softBlue,
        surfaceTintColor: AppColors.surface,
        height: 78,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
        elevation: 8,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 10,
        shape: CircleBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.navyBlue),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.softBlue,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
