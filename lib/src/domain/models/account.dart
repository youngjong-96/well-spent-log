enum AccountType {
  cash,
  bank;

  String get label => this == cash ? '현금' : '통장';
}

class Account {
  const Account({
    required this.id,
    required this.type,
    required this.name,
    required this.balance,
    required this.includeInTotal,
    required this.isActive,
    this.bankName,
    this.accountNumber,
  });

  final int id;
  final AccountType type;
  final String name;
  final String? bankName;
  final String? accountNumber;
  final int balance;
  final bool includeInTotal;
  final bool isActive;

  String get maskedAccountNumber {
    final value = accountNumber?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (value.length <= 4) {
      return value.isEmpty ? '' : '****';
    }
    final mask = List.filled(value.length - 4, '*').join();
    return '$mask${value.substring(value.length - 4)}';
  }

  factory Account.fromMap(Map<String, Object?> map) {
    return Account(
      id: map['id']! as int,
      type: AccountType.values.byName(map['type']! as String),
      name: map['name']! as String,
      bankName: map['bank_name'] as String?,
      accountNumber: map['account_number'] as String?,
      balance: map['balance']! as int,
      includeInTotal: map['include_in_total'] == 1,
      isActive: map['is_active'] == 1,
    );
  }
}
