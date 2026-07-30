import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../domain/models/budget_usage.dart';
import '../formatters.dart';

class BudgetProgressTile extends StatelessWidget {
  const BudgetProgressTile({
    required this.usage,
    required this.showAmount,
    required this.onToggleDisplay,
    super.key,
  });

  final BudgetUsage usage;
  final bool showAmount;
  final VoidCallback onToggleDisplay;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final progress = usage.usedRatio.clamp(0.0, 1.0);
    final progressColor = switch (usage.usedPercent) {
      >= 100 => AppColors.overBudget,
      >= 80 => AppColors.warning80,
      >= 50 => AppColors.warning50,
      _ => colorFromHex(usage.colorHex),
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
                      color: progressColor,
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
            ],
          ),
        ),
      ),
    );
  }
}
