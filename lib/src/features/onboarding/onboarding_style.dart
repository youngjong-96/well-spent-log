import 'package:flutter/material.dart';

const onboardingBackground = Color(0xff0d1624);
const onboardingSurface = Color(0xff142033);
const onboardingRaised = Color(0xff1c2a40);
const onboardingLine = Color(0xff2a405f);
const onboardingAccent = Color(0xff83aee8);
const onboardingText = Color(0xffeef3fa);
const onboardingMuted = Color(0xffadbfd6);
const onboardingTourShade = Color(0xe003080e);
final onboardingTourBackground = Color.alphaBlend(
  onboardingTourShade,
  onboardingBackground,
);

TextStyle onboardingType(
  double size, {
  Color color = onboardingText,
  bool bold = false,
  double height = 1.25,
}) => TextStyle(
  fontFamily: 'Moneygraphy',
  fontFamilyFallback: const ['NotoSansKR'],
  fontSize: size,
  color: color,
  height: height,
  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
);

ThemeData onboardingTheme(BuildContext context) {
  final theme = Theme.of(context);
  return theme.copyWith(
    scaffoldBackgroundColor: onboardingBackground,
    filledButtonTheme: const FilledButtonThemeData(),
    textButtonTheme: const TextButtonThemeData(),
    dialogTheme: const DialogThemeData(backgroundColor: onboardingSurface),
    colorScheme: const ColorScheme.dark(
      primary: onboardingAccent,
      onPrimary: onboardingBackground,
      surface: onboardingSurface,
      onSurface: onboardingText,
      onSurfaceVariant: onboardingMuted,
      outline: onboardingAccent,
      outlineVariant: onboardingLine,
      surfaceContainerHighest: onboardingRaised,
    ),
    textTheme: theme.textTheme.apply(
      bodyColor: onboardingText,
      displayColor: onboardingText,
    ),
    inputDecorationTheme: const InputDecorationTheme(),
  );
}

BoxDecoration onboardingBox({
  Color color = onboardingSurface,
  Color? border,
  double radius = 13,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(radius),
  border: border == null ? null : Border.all(color: border),
);

Widget onboardingButton(
  String label,
  VoidCallback? action, {
  bool secondary = false,
  IconData? icon,
  bool compact = false,
  double? labelSize,
}) {
  final style = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, compact ? 43 : 55)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
    textStyle: WidgetStatePropertyAll(
      onboardingType(labelSize ?? (compact ? 16 : 19), bold: true),
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? onboardingLine
          : secondary
          ? onboardingSurface
          : onboardingAccent,
    ),
    foregroundColor: WidgetStatePropertyAll(
      secondary ? onboardingAccent : onboardingBackground,
    ),
    side: secondary
        ? const WidgetStatePropertyAll(BorderSide(color: onboardingAccent))
        : null,
  );
  final child = icon == null
      ? Text(label, textAlign: TextAlign.center)
      : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 6),
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        );
  return secondary
      ? OutlinedButton(onPressed: action, style: style, child: child)
      : FilledButton(onPressed: action, style: style, child: child);
}

Widget onboardingInfo(
  String copy, {
  IconData icon = Icons.info_outline,
  bool shaded = false,
  bool compact = false,
}) => Container(
  decoration: shaded ? onboardingBox(color: onboardingRaised) : null,
  padding: shaded
      ? EdgeInsets.symmetric(
          horizontal: compact ? 11 : 14,
          vertical: compact ? 8 : 13,
        )
      : EdgeInsets.zero,
  child: Row(
    crossAxisAlignment: compact
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Icon(icon, color: onboardingAccent, size: 21),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          copy,
          style: onboardingType(
            compact ? 16 : 17,
            color: onboardingMuted,
            height: 1.45,
          ),
        ),
      ),
    ],
  ),
);

Widget onboardingMeter(double value) => LinearProgressIndicator(
  value: value.clamp(0, 1),
  minHeight: 6,
  borderRadius: BorderRadius.circular(8),
  color: onboardingAccent,
  backgroundColor: onboardingLine,
);

Widget onboardingTile(IconData icon, {double size = 68}) => Container(
  width: size,
  height: size,
  alignment: Alignment.center,
  decoration: onboardingBox(color: onboardingLine, radius: 22),
  child: Icon(icon, color: onboardingAccent, size: 36),
);
