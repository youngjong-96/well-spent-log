import 'package:flutter/material.dart';

IconData categoryIconFor(String? name) {
  final categoryName = name ?? '';
  if (categoryName.contains('식') || categoryName.contains('카페')) {
    return Icons.restaurant_outlined;
  }
  if (categoryName.contains('교통') || categoryName.contains('차')) {
    return Icons.directions_bus_outlined;
  }
  if (categoryName.contains('생활') || categoryName.contains('쇼핑')) {
    return Icons.shopping_bag_outlined;
  }
  if (categoryName.contains('주거') || categoryName.contains('집')) {
    return Icons.home_outlined;
  }
  if (categoryName.contains('건강') || categoryName.contains('의료')) {
    return Icons.medical_services_outlined;
  }
  if (categoryName.contains('문화') || categoryName.contains('여가')) {
    return Icons.movie_outlined;
  }
  return Icons.account_balance_wallet_outlined;
}
