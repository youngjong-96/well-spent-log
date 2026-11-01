import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:well_spent_log/src/shared/formatters.dart';

void main() {
  test('amounts format and parse positive, negative and empty input', () {
    expect(formatAmount(1234567), '1,234,567');
    expect(formatWon(-1234567), '-1,234,567원');
    expect(parseAmount('1,234,567'), 1234567);
    expect(parseAmount('-1,234'), -1234);
    expect(parseAmount(''), isNull);
  });

  test('typing, paste and middle edits retain a useful cursor position', () {
    const formatter = AmountInputFormatter();
    TextEditingValue edit(String text, int cursor) =>
        formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: cursor),
          ),
        );
    expect(edit('1234', 4).text, '1,234');
    expect(edit('1234', 4).selection.baseOffset, 5);
    expect(edit('1,234,567', 9).text, '1,234,567');
    final middle = edit('19,234', 2);
    expect(middle.text, '19,234');
    expect(middle.selection.baseOffset, 3);
    expect(edit('', 0).text, '');
    expect(edit('abc', 3), TextEditingValue.empty);
    expect(edit('-1234', 5), TextEditingValue.empty);
    const signed = AmountInputFormatter(allowNegative: true);
    expect(
      signed
          .formatEditUpdate(
            TextEditingValue.empty,
            const TextEditingValue(
              text: '-1234',
              selection: TextSelection.collapsed(offset: 5),
            ),
          )
          .text,
      '-1,234',
    );
  });
}
