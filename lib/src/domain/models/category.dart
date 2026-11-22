String normalizeCategoryName(String name) => name.trim().toLowerCase();

class HiddenCategory {
  const HiddenCategory(this.category, this.transactionCount);

  final SpendingCategory category;
  final int transactionCount;
}

class SpendingCategory {
  const SpendingCategory({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.sortOrder,
    required this.isActive,
    this.alertsEnabled = true,
  });

  final int id;
  final String name;
  final String colorHex;
  final int sortOrder;
  final bool isActive;
  final bool alertsEnabled;

  factory SpendingCategory.fromMap(Map<String, Object?> map) {
    return SpendingCategory(
      id: map['id']! as int,
      name: map['name']! as String,
      colorHex: map['color_hex']! as String,
      sortOrder: map['sort_order']! as int,
      isActive: map['is_active'] == 1,
      alertsEnabled: (map['alerts_enabled'] ?? 1) == 1,
    );
  }
}
