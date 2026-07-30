enum RecordType {
  expense,
  income,
  refund;

  String get label => switch (this) {
    expense => '지출',
    income => '수입',
    refund => '환불',
  };

  int signedAmount(int amount) => switch (this) {
    expense => -amount,
    income || refund => amount,
  };
}

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.amount,
    required this.memo,
    required this.accountId,
    required this.accountName,
    this.categoryId,
    this.categoryName,
    this.categoryColorHex,
    this.paymentMethodId,
    this.paymentMethodName,
    this.refundedExpenseId,
    this.deletedAt,
  });

  final int id;
  final RecordType type;
  final DateTime occurredAt;
  final int amount;
  final String memo;
  final int accountId;
  final String accountName;
  final int? categoryId;
  final String? categoryName;
  final String? categoryColorHex;
  final int? paymentMethodId;
  final String? paymentMethodName;
  final int? refundedExpenseId;
  final DateTime? deletedAt;

  int get signedAmount => type.signedAmount(amount);
  bool get isDeleted => deletedAt != null;

  factory TransactionRecord.fromMap(Map<String, Object?> map) {
    return TransactionRecord(
      id: map['id']! as int,
      type: RecordType.values.byName(map['type']! as String),
      occurredAt: DateTime.parse(map['occurred_at']! as String),
      amount: map['amount']! as int,
      memo: (map['memo'] as String?) ?? '',
      accountId: map['account_id']! as int,
      accountName: (map['account_name'] as String?) ?? '',
      categoryId: map['category_id'] as int?,
      categoryName: map['category_name'] as String?,
      categoryColorHex: map['category_color_hex'] as String?,
      paymentMethodId: map['payment_method_id'] as int?,
      paymentMethodName: map['payment_method_name'] as String?,
      refundedExpenseId: map['refunded_expense_id'] as int?,
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.parse(map['deleted_at']! as String),
    );
  }
}
