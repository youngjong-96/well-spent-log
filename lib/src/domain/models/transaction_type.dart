enum TransactionType { expense, income }

extension TransactionTypeLabel on TransactionType {
  String get label {
    return switch (this) {
      TransactionType.expense => '지출',
      TransactionType.income => '수입',
    };
  }
}
