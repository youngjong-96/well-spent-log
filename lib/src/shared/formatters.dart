import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';

import '../domain/models/money.dart';

String formatAmount(int amount) => formatGroupedInteger(amount);

int? parseAmount(String text) => int.tryParse(text.replaceAll(',', '').trim());

class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter({this.allowNegative = false});

  final bool allowNegative;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final raw = newValue.text.replaceAll(',', '');
    final pattern = allowNegative ? r'^-?\d*$' : r'^\d*$';
    if (!RegExp(pattern).hasMatch(raw)) return oldValue;
    final amount = parseAmount(raw);
    if (raw.isNotEmpty && raw != '-' && amount == null) return oldValue;
    final formatted = amount == null ? raw : formatAmount(amount);
    int offsetFor(int offset) {
      if (offset < 0) return formatted.length;
      final remaining = newValue.text
          .substring(offset)
          .replaceAll(',', '')
          .length;
      var position = formatted.length;
      var count = 0;
      while (position > 0 && count < remaining) {
        position--;
        if (formatted[position] != ',') count++;
      }
      return position;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: offsetFor(newValue.selection.baseOffset),
        extentOffset: offsetFor(newValue.selection.extentOffset),
      ),
    );
  }
}

String formatWon(int amount, {bool signed = false}) {
  final prefix = signed && amount > 0 ? '+' : '';
  return '$prefix${formatGroupedInteger(amount)}원';
}

String formatDate(DateTime date) {
  return DateFormat('M월 d일 EEEE', 'ko_KR').format(date);
}

String formatShortDate(DateTime date) {
  return DateFormat('M.d (E)', 'ko_KR').format(date);
}

String formatMonth(DateTime date) {
  return DateFormat('yyyy년 M월', 'ko_KR').format(date);
}

Color visibleForeground(Color color, Color background, Color fallback) {
  final foregroundLuminance = color.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance < backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  // Preserve category colors when they meet 3:1 contrast for graphics.
  return (lighter + 0.05) / (darker + 0.05) >= 3 ? color : fallback;
}

Color colorFromHex(String hex) {
  final normalized = normalizeCategoryHex(hex);
  if (normalized == null) return AppColors.primary;
  final value = int.parse(normalized.substring(1), radix: 16);
  const currentPalette = {
    0xD8E8F5: AppColors.softBlue,
    0x84B6E2: AppColors.skyBlue,
    0x294761: AppColors.navyBlue,
  };
  return currentPalette[value] ?? Color(0xFF000000 | value);
}

String? normalizeCategoryHex(String input) {
  final hex = input.trim();
  if (!RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return '#${hex.replaceFirst('#', '').toUpperCase()}';
}
