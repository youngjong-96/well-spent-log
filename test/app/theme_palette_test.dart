import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:well_spent_log/src/app/theme/app_colors.dart';
import 'package:well_spent_log/src/app/theme/app_theme.dart';
import 'package:well_spent_log/src/domain/models/category_colors.dart';
import 'package:well_spent_log/src/shared/widgets/budget_progress_tile.dart';
import 'package:well_spent_log/src/shared/formatters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Material icon family maps to the bundled font', () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final family = manifest.cast<Map<String, dynamic>>().singleWhere(
      (entry) => entry['family'] == 'MaterialIcons',
    );
    final asset = family['fonts'][0]['asset'] as String;
    expect(asset, 'fonts/MaterialIcons-Regular.otf');
    final font = await rootBundle.load(asset);
    expect(font.lengthInBytes, greaterThan(1000000));
  });

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

  test('category hex renders RGB and preserves the three legacy aliases', () {
    expect(colorFromHex('#7a5cfa'), const Color(0xFF7A5CFA));
    expect(colorFromHex('123456'), const Color(0xFF123456));
    expect(colorFromHex('#D8E8F5'), AppColors.softBlue);
    expect(colorFromHex('#84B6E2'), AppColors.skyBlue);
    expect(colorFromHex('#294761'), AppColors.navyBlue);
  });

  test('all category presets contrast with both tracks and surfaces', () {
    expect(categoryColorPresets.toSet(), hasLength(14));
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      for (final hex in categoryColorPresets) {
        final color = colorFromHex(hex);
        for (final background in [
          theme.colorScheme.surface,
          theme.progressIndicatorTheme.linearTrackColor!,
        ]) {
          expect(
            _contrast(color, background),
            greaterThanOrEqualTo(3),
            reason: hex,
          );
        }
        expect(
          BudgetProgressBar.usesFallback(theme, color),
          isFalse,
          reason: hex,
        );
      }
    }
  });
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
