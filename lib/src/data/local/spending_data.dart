/// Tables in foreign-key insertion order. Shared by migration and backup restore.
const spendingTables = [
  'categories',
  'payment_methods',
  'budget_periods',
  'monthly_budgets',
  'transactions',
  'expense_templates',
  'alert_history',
];

const legacyTables = [
  'categories',
  'accounts',
  'payment_methods',
  'budget_periods',
  'monthly_budgets',
  'transactions',
  'account_ledger',
  'expense_templates',
  'alert_history',
];

/// Convert v1 backups / pre-v3 databases without changing retained record IDs.
Map<String, List<Map<String, Object?>>> convertLegacyData(
  Map<String, Object?> source,
) {
  final result = <String, List<Map<String, Object?>>>{};
  for (final table in spendingTables) {
    final rows = source[table];
    if (rows is! List) throw FormatException('Missing table: $table');
    result[table] = rows.map((row) {
      if (row is! Map) throw FormatException('Invalid row: $table');
      return Map<String, Object?>.from(row);
    }).toList();
  }
  for (final row in result['payment_methods']!) {
    row.removeWhere(
      (key, _) =>
          ['type', 'account_id', 'card_company', 'billing_day'].contains(key),
    );
  }
  result['transactions']!.removeWhere((row) => row['type'] == 'income');
  final expenseIds = result['transactions']!
      .where((row) => row['type'] == 'expense')
      .map((row) => row['id'])
      .toSet();
  for (final row in result['transactions']!) {
    row.remove('account_id');
    if (!expenseIds.contains(row['refunded_expense_id'])) {
      row['refunded_expense_id'] = null;
    }
  }
  return result;
}
