class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.isActive,
  });
  final int id;
  final String name;
  final bool isActive;
  factory PaymentMethod.fromMap(Map<String, Object?> map) => PaymentMethod(
    id: map['id']! as int,
    name: map['name']! as String,
    isActive: map['is_active'] == 1,
  );
}
