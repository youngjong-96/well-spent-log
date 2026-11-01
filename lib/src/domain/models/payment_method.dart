enum PaymentMethodType {
  cash,
  card;

  String get label => this == cash ? '현금' : '카드';
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.type,
    required this.name,
    required this.accountId,
    required this.isActive,
    this.cardCompany,
    this.billingDay,
  });

  final int id;
  final PaymentMethodType type;
  final String name;
  final String? cardCompany;
  final int? billingDay;
  final int accountId;
  final bool isActive;

  factory PaymentMethod.fromMap(Map<String, Object?> map) {
    return PaymentMethod(
      id: map['id']! as int,
      type: PaymentMethodType.values.byName(map['type']! as String),
      name: map['name']! as String,
      cardCompany: map['card_company'] as String?,
      billingDay: map['billing_day'] as int?,
      accountId: map['account_id']! as int,
      isActive: map['is_active'] == 1,
    );
  }
}
