import 'package:intl/intl.dart';

class Money {
  const Money(this.amount);

  final int amount;

  String format() {
    return '${NumberFormat.decimalPattern('ko_KR').format(amount)}원';
  }

  static const zero = Money(0);
}
