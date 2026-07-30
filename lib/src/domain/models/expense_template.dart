class ExpenseTemplate {
  const ExpenseTemplate({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.paymentMethodId,
    required this.isActive,
  });

  final int id;
  final String name;
  final int amount;
  final int categoryId;
  final int paymentMethodId;
  final bool isActive;

  factory ExpenseTemplate.fromMap(Map<String, Object?> map) {
    return ExpenseTemplate(
      id: map['id']! as int,
      name: map['name']! as String,
      amount: map['amount']! as int,
      categoryId: map['category_id']! as int,
      paymentMethodId: map['payment_method_id']! as int,
      isActive: map['is_active'] == 1,
    );
  }
}
