import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
    brightness: Brightness.light,
    scheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.surface,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.graphite,
      secondary: AppColors.navyBlue,
      onSecondary: AppColors.surface,
      secondaryContainer: AppColors.softBlue,
      onSecondaryContainer: AppColors.graphite,
      tertiary: AppColors.skyBlue,
      onTertiary: AppColors.surface,
      tertiaryContainer: AppColors.softBlue,
      onTertiaryContainer: AppColors.graphite,
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
    scaffoldColor: AppColors.background,
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    scheme: const ColorScheme.dark(
      primary: AppDarkColors.softBlue,
      onPrimary: AppDarkColors.canvas,
      primaryContainer: AppDarkColors.mutedBlue,
      onPrimaryContainer: AppDarkColors.text,
      secondary: AppDarkColors.softBlue,
      onSecondary: AppDarkColors.canvas,
      secondaryContainer: AppDarkColors.mutedBlue,
      onSecondaryContainer: AppDarkColors.text,
      tertiary: AppDarkColors.softBlue,
      onTertiary: AppDarkColors.canvas,
      tertiaryContainer: AppDarkColors.mutedBlue,
      onTertiaryContainer: AppDarkColors.text,
      error: AppDarkColors.softBlue,
      onError: AppDarkColors.canvas,
      errorContainer: AppDarkColors.mutedBlue,
      onErrorContainer: AppDarkColors.text,
      surface: AppDarkColors.surface,
      onSurface: AppDarkColors.text,
      surfaceDim: AppDarkColors.canvas,
      surfaceBright: AppDarkColors.raisedSurface,
      surfaceContainerLowest: AppDarkColors.canvas,
      surfaceContainerLow: AppDarkColors.surface,
      surfaceContainer: AppDarkColors.surface,
      surfaceContainerHigh: AppDarkColors.raisedSurface,
      surfaceContainerHighest: AppDarkColors.mutedBlue,
      onSurfaceVariant: AppDarkColors.text,
      outline: AppDarkColors.softBlue,
      outlineVariant: AppDarkColors.mutedBlue,
      shadow: AppDarkColors.canvas,
      scrim: AppDarkColors.canvas,
      inverseSurface: AppDarkColors.text,
      onInverseSurface: AppDarkColors.canvas,
      inversePrimary: AppDarkColors.mutedBlue,
      surfaceTint: AppDarkColors.softBlue,
    ),
    scaffoldColor: AppDarkColors.canvas,
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffoldColor,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Moneygraphy',
      fontFamilyFallback: const ['NotoSansKR'],
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldColor,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontSize: 26,
          height: 1.25,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 17,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          fontSize: 13,
          height: 1.4,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        height: 72,
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: scheme.surface,
        elevation: 12,
        shadowColor: scheme.shadow,
        surfaceTintColor: scheme.surface,
        height: 78,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldColor,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.surface,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 8,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 10,
        shape: const CircleBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: scheme.surface),
      popupMenuTheme: PopupMenuThemeData(color: scheme.surface),
    );
  }
}
