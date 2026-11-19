final _digitGroup = RegExp(r'\d(?=(\d{3})+$)');

String formatGroupedInteger(int amount) =>
    amount.toString().replaceAllMapped(_digitGroup, (match) => '${match[0]},');

class Money {
  const Money(this.amount);

  final int amount;

  String format() {
    return '${formatGroupedInteger(amount)}원';
  }

  static const zero = Money(0);
}
