import 'package:flutter_test/flutter_test.dart';
import 'package:allocation_app/core/types.dart';

void main() {
  test('bankersDiv rounds halves to even', () {
    // 1.5 -> 2 (2 is even)
    expect(bankersDiv(3, 2), 2);

    // 2.5 -> 2 (2 is even)
    expect(bankersDiv(5, 2), 2);

    // 3.5 -> 4 (4 is even)
    expect(bankersDiv(7, 2), 4);

    // non-half: normal rounding
    expect(bankersDiv(1, 2), 0); // 0.5 -> 0? actually 0.5 half to even => 0
    expect(bankersDiv(9, 10), 1); // 0.9 -> 1
  });
}
