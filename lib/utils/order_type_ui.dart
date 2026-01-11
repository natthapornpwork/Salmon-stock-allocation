import 'package:flutter/material.dart';
import '../data/models/order.dart';

class OrderTypeUi {
  static Color accent(BuildContext context, OrderType t) {
    return switch (t) {
      OrderType.emergency => Colors.red,
      OrderType.claim => Colors.orange,
      OrderType.overdue => Colors.purple,
      OrderType.daily => Colors.green,
    };
  }

  static Color bg(BuildContext context, OrderType t) =>
      accent(context, t).withOpacity(0.14);

  static Color border(BuildContext context, OrderType t) =>
      accent(context, t).withOpacity(0.45);

  static Color fg(BuildContext context, OrderType t) =>
      accent(context, t).withOpacity(0.95);
}
