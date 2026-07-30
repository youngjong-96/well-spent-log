import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../domain/models/transaction_record.dart';
import '../formatters.dart';

class TransactionListTile extends StatelessWidget {
  const TransactionListTile({required this.record, this.onDelete, super.key});

  final TransactionRecord record;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isExpense = record.type == RecordType.expense;
    final amountColor = isExpense ? AppColors.textPrimary : AppColors.income;
    final categoryColor = record.categoryColorHex == null
        ? AppColors.info
        : colorFromHex(record.categoryColorHex!);
    return ListTile(
      minTileHeight: 64,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: categoryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          switch (record.type) {
            RecordType.expense => Icons.shopping_bag_outlined,
            RecordType.income => Icons.add_card_outlined,
            RecordType.refund => Icons.replay_outlined,
          },
          color: categoryColor,
          semanticLabel: record.type.label,
        ),
      ),
      title: Text(
        record.memo.isEmpty
            ? (record.categoryName ?? record.type.label)
            : record.memo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          formatShortDate(record.occurredAt),
          record.paymentMethodName ?? record.accountName,
        ].where((value) => value.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatWon(record.signedAmount, signed: true),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onDelete != null)
            PopupMenuButton<void>(
              tooltip: '내역 메뉴',
              onSelected: (_) => onDelete?.call(),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 8),
                      Text('삭제'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
