import 'package:intl/intl.dart';

typedef Qty = int;
typedef Money = int;

int bankersDiv(int numerator, int denominator) {
  final q = numerator ~/ denominator;
  final r = numerator % denominator;
  final twiceR = r * 2;
  if (twiceR < denominator) return q;
  if (twiceR > denominator) return q + 1;
  return q.isEven ? q : q + 1;
}

final _qtyFmt = NumberFormat.decimalPattern('th_TH');
String qtyToString(Qty q) => _qtyFmt.format(q);

final _bahtFmt = NumberFormat.currency(
  locale: 'th_TH',
  symbol: '฿',
  decimalDigits: 2,
);

/// Convert satang -> "฿x,xxx.xx"
String moneyToString(Money satang) => _bahtFmt.format(satang / 100.0);

/// bahtToMoney(99.00) -> 9900 satang
Money bahtToMoney(num baht) => (baht * 100).round();
