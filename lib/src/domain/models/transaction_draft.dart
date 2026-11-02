import 'transaction_record.dart';

class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.occurredAt,
    required this.amount,
    this.categoryId,
    this.paymentMethodId,
    this.memo = '',
    this.refundedExpenseId,
  });

  final RecordType type;
  final DateTime occurredAt;
  final int amount;
  final int? categoryId;
  final int? paymentMethodId;
  final String memo;
  final int? refundedExpenseId;
}
