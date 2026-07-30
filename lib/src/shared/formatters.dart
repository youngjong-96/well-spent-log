import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.decimalPattern('ko_KR');

String formatWon(int amount, {bool signed = false}) {
  final prefix = signed && amount > 0 ? '+' : '';
  return '$prefix${_currencyFormat.format(amount)}원';
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

Color colorFromHex(String hex) {
  final normalized = hex.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}
