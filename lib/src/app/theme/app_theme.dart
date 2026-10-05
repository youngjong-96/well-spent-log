import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'GowunDodum',
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.graphite,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.graphite,
        primaryFixed: AppColors.skyBlue,
        primaryFixedDim: AppColors.softBlue,
        onPrimaryFixed: AppColors.graphite,
        onPrimaryFixedVariant: AppColors.graphite,
        secondary: AppColors.navyBlue,
        onSecondary: AppColors.surface,
        secondaryContainer: AppColors.softBlue,
        onSecondaryContainer: AppColors.graphite,
        secondaryFixed: AppColors.softBlue,
        secondaryFixedDim: AppColors.skyBlue,
        onSecondaryFixed: AppColors.graphite,
        onSecondaryFixedVariant: AppColors.graphite,
        tertiary: AppColors.skyBlue,
        onTertiary: AppColors.graphite,
        tertiaryContainer: AppColors.softBlue,
        onTertiaryContainer: AppColors.graphite,
        tertiaryFixed: AppColors.skyBlue,
        tertiaryFixedDim: AppColors.softBlue,
        onTertiaryFixed: AppColors.graphite,
        onTertiaryFixedVariant: AppColors.graphite,
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
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: AppColors.textSecondary.withValues(alpha: 0.72),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.border),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryContainer,
        height: 72,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.graphite,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.graphite,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.softBlue,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),
    );
  }
}
