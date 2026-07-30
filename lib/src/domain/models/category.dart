class SpendingCategory {
  const SpendingCategory({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.sortOrder,
    required this.isActive,
  });

  final int id;
  final String name;
  final String colorHex;
  final int sortOrder;
  final bool isActive;

  factory SpendingCategory.fromMap(Map<String, Object?> map) {
    return SpendingCategory(
      id: map['id']! as int,
      name: map['name']! as String,
      colorHex: map['color_hex']! as String,
      sortOrder: map['sort_order']! as int,
      isActive: map['is_active'] == 1,
    );
  }
}
