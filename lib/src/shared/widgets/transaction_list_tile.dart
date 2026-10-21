import 'package:flutter/material.dart';

import '../../domain/models/transaction_record.dart';
import '../category_icon.dart';
import '../formatters.dart';

class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    required this.record,
    this.onDelete,
    this.onEdit,
    super.key,
  });

  final TransactionRecord record;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amountColor = scheme.onSurface;
    final categoryColor = record.categoryColorHex == null
        ? scheme.secondary
        : Theme.of(context).brightness == Brightness.dark
        ? scheme.primary
        : colorFromHex(record.categoryColorHex!);
    return ListTile(
      minTileHeight: 64,
      onTap: onEdit,
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
            RecordType.expense => categoryIconFor(record.categoryName),
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
          if (onDelete != null || onEdit != null)
            PopupMenuButton<String>(
              tooltip: '내역 메뉴',
              onSelected: (action) {
                if (action == 'edit') {
                  onEdit?.call();
                }
                if (action == 'delete') {
                  onDelete?.call();
                }
              },
              itemBuilder: (context) => [
                if (onEdit != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 8),
                        Text('수정'),
                      ],
                    ),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
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
