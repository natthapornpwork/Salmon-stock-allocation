import 'package:flutter/material.dart';

import '../widgets/order_detail.dart';

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order detail')),
      body: OrderDetailPanel(),
    );
  }
}
