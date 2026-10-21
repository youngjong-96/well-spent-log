import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // The complete app palette is limited to these six base colors.
  static const surface = Color(0xFFFFFFFF);
  static const paleBlue = Color(0xFFF4F8FD);
  static const softBlue = Color(0xFFDCEBFA);
  static const skyBlue = Color(0xFF2F6FEB);
  static const navyBlue = Color(0xFF153B66);
  static const graphite = Color(0xFF172033);

  static const background = surface;
  static const surfaceVariant = paleBlue;
  static const textPrimary = graphite;
  static const textSecondary = graphite;
  static const border = softBlue;
  static const primary = skyBlue;
  static const primaryContainer = softBlue;
  static const accent = skyBlue;
  static const income = graphite;
  static const warning50 = skyBlue;
  static const warning80 = navyBlue;
  static const overBudget = navyBlue;
  static const info = navyBlue;

  static const categoryPalette = [softBlue, skyBlue, navyBlue];
}
