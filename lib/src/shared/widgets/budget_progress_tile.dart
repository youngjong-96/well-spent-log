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
                            color: visibleForeground(
                              colorFromHex(usage.colorHex),
                              scheme.surface,
                              scheme.primary,
                            ),
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
                child: BudgetProgressBar(value: progress, color: progressColor),
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

class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    super.key,
    required this.value,
    required this.color,
  });

  final double value;
  final Color color;

  static bool usesFallback(ThemeData theme, Color color) =>
      _visibleColor(theme, color) != color;

  static Color _trackColor(ThemeData theme) =>
      theme.progressIndicatorTheme.linearTrackColor ??
      theme.colorScheme.surfaceContainerHigh;

  static Color _visibleColor(ThemeData theme, Color color) {
    final scheme = theme.colorScheme;
    return visibleForeground(
      visibleForeground(color, scheme.surface, scheme.primary),
      _trackColor(theme),
      scheme.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LinearProgressIndicator(
      value: value,
      color: _visibleColor(theme, color),
      backgroundColor: _trackColor(theme),
      minHeight: 8,
      borderRadius: BorderRadius.circular(4),
    );
  }
}
