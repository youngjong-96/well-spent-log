import 'package:flutter/material.dart';

import '../../domain/models/budget_usage.dart';
import '../formatters.dart';

class BudgetProgressTile extends StatelessWidget {
  const BudgetProgressTile({
    required this.usage,
    required this.showAmount,
    required this.onToggleDisplay,
    this.onViewDetails,
    super.key,
  });

  final BudgetUsage usage;
  final bool showAmount;
  final VoidCallback onToggleDisplay;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final progress = usage.usedRatio.clamp(0.0, 1.0);
    final progressColor = switch (usage.usedPercent) {
      >= 100 => scheme.secondary,
      >= 80 => scheme.secondary,
      >= 50 => scheme.primary,
      _ =>
        Theme.of(context).brightness == Brightness.dark
            ? scheme.primary
            : colorFromHex(usage.colorHex),
    };
    final valueText = showAmount
        ? '${usage.spentAmount.format()} / ${usage.budgetAmount.format()}'
        : '${usage.usedPercent}%';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onToggleDisplay,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colorFromHex(usage.colorHex),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            usage.categoryName,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    valueText,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Semantics(
                label: '${usage.categoryName} 예산 ${usage.usedPercent}% 사용',
                child: LinearProgressIndicator(
                  value: progress,
                  color: progressColor,
                  backgroundColor: progressColor.withValues(alpha: 0.12),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (usage.budgetAmount.amount == 0) ...[
                const SizedBox(height: 6),
                Text('예산을 설정해 주세요', style: textTheme.bodySmall),
              ],
              if (onViewDetails != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('내역 보기'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
