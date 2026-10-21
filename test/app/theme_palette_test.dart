import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:well_spent_log/src/app/theme/app_colors.dart';
import 'package:well_spent_log/src/app/theme/app_theme.dart';
import 'package:well_spent_log/src/shared/formatters.dart';

void main() {
  test('app themes use Moneygraphy with a Korean fallback', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Moneygraphy');
      expect(
        theme.textTheme.bodyMedium?.fontFamilyFallback,
        contains('NotoSansKR'),
      );
    }
  });

  test('app theme uses only the six documented base colors', () {
    final palette = {
      AppColors.surface,
      AppColors.paleBlue,
      AppColors.softBlue,
      AppColors.skyBlue,
      AppColors.navyBlue,
      AppColors.graphite,
    };
    final scheme = AppTheme.light.colorScheme;
    final usedColors = {
      scheme.primary,
      scheme.onPrimary,
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
      scheme.primaryFixed,
      scheme.primaryFixedDim,
      scheme.onPrimaryFixed,
      scheme.onPrimaryFixedVariant,
      scheme.secondary,
      scheme.onSecondary,
      scheme.secondaryContainer,
      scheme.onSecondaryContainer,
      scheme.secondaryFixed,
      scheme.secondaryFixedDim,
      scheme.onSecondaryFixed,
      scheme.onSecondaryFixedVariant,
      scheme.tertiary,
      scheme.onTertiary,
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
      scheme.tertiaryFixed,
      scheme.tertiaryFixedDim,
      scheme.onTertiaryFixed,
      scheme.onTertiaryFixedVariant,
      scheme.error,
      scheme.onError,
      scheme.errorContainer,
      scheme.onErrorContainer,
      scheme.surface,
      scheme.onSurface,
      scheme.surfaceDim,
      scheme.surfaceBright,
      scheme.surfaceContainerLowest,
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
      scheme.surfaceContainerHigh,
      scheme.surfaceContainerHighest,
      scheme.onSurfaceVariant,
      scheme.outline,
      scheme.outlineVariant,
      scheme.shadow,
      scheme.scrim,
      scheme.inverseSurface,
      scheme.onInverseSurface,
      scheme.inversePrimary,
      scheme.surfaceTint,
    };
    expect(palette, hasLength(6));
    expect(usedColors.difference(palette), isEmpty);
  });

  test('text colors keep WCAG AA contrast on their intended surfaces', () {
    for (final background in const [
      AppColors.surface,
      AppColors.paleBlue,
      AppColors.softBlue,
    ]) {
      final light = background.computeLuminance();
      final dark = AppColors.graphite.computeLuminance();
      final contrast = (light + 0.05) / (dark + 0.05);
      expect(contrast, greaterThanOrEqualTo(4.5));
    }
    final primaryContrast =
        (AppColors.surface.computeLuminance() + 0.05) /
        (AppColors.skyBlue.computeLuminance() + 0.05);
    expect(primaryContrast, greaterThanOrEqualTo(4.5));
  });

  test('dark theme uses only the six documented dark colors', () {
    final palette = {
      AppDarkColors.canvas,
      AppDarkColors.surface,
      AppDarkColors.raisedSurface,
      AppDarkColors.mutedBlue,
      AppDarkColors.softBlue,
      AppDarkColors.text,
    };
    final scheme = AppTheme.dark.colorScheme;
    final usedColors = {
      scheme.primary,
      scheme.onPrimary,
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
      scheme.secondary,
      scheme.onSecondary,
      scheme.secondaryContainer,
      scheme.onSecondaryContainer,
      scheme.tertiary,
      scheme.onTertiary,
      scheme.tertiaryContainer,
      scheme.onTertiaryContainer,
      scheme.error,
      scheme.onError,
      scheme.errorContainer,
      scheme.onErrorContainer,
      scheme.surface,
      scheme.onSurface,
      scheme.surfaceDim,
      scheme.surfaceBright,
      scheme.surfaceContainerLowest,
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
      scheme.surfaceContainerHigh,
      scheme.surfaceContainerHighest,
      scheme.onSurfaceVariant,
      scheme.outline,
      scheme.outlineVariant,
      scheme.shadow,
      scheme.scrim,
      scheme.inverseSurface,
      scheme.onInverseSurface,
      scheme.inversePrimary,
      scheme.surfaceTint,
    };

    expect(palette, hasLength(6));
    expect(usedColors.difference(palette), isEmpty);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });

  test('dark text and primary button meet WCAG AA contrast', () {
    for (final background in const [
      AppDarkColors.canvas,
      AppDarkColors.surface,
      AppDarkColors.raisedSurface,
      AppDarkColors.mutedBlue,
    ]) {
      expect(
        _contrast(AppDarkColors.text, background),
        greaterThanOrEqualTo(4.5),
      );
    }
    expect(
      _contrast(AppDarkColors.canvas, AppDarkColors.softBlue),
      greaterThanOrEqualTo(4.5),
    );
  });

  test(
    'legacy category colors are normalized to the blue category palette',
    () {
      for (final legacyColor in const [
        '#7A5CFA',
        '#8B6F47',
        '#007E9E',
        '#4C7C59',
        '#B04A82',
        '#D8584A',
      ]) {
        expect(AppColors.categoryPalette, contains(colorFromHex(legacyColor)));
      }
    },
  );
}

double _contrast(Color first, Color second) {
  final high = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final low = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (high + 0.05) / (low + 0.05);
}
