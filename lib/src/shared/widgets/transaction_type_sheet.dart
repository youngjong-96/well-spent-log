import 'package:flutter/material.dart';

import '../../domain/models/transaction_type.dart';

class TransactionTypeSheet extends StatelessWidget {
  const TransactionTypeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '빠른 기록',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: const Text('지출이나 수입을 선택해 바로 입력합니다.'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(TransactionType.expense);
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('지출'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(TransactionType.income);
                    },
                    icon: const Icon(Icons.savings_outlined),
                    label: const Text('수입'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
