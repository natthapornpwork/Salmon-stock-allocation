import 'package:flutter_test/flutter_test.dart';
import 'package:allocation_app/data/models/order.dart';
import 'package:allocation_app/data/models/price.dart';
import 'package:allocation_app/domain/allocator/pricing.dart';

void main() {
  test('SP-000 uses cheapest supplier base price for that item', () {
    final table = PriceTable(
      baseUnitPriceSatang: {
        const PriceKey(itemId: 'item-1', supplierId: 'SP-001'): 12000,
        const PriceKey(itemId: 'item-1', supplierId: 'SP-002'): 9000,
      },
      typeMultiplierBp: {
        OrderType.daily: 10000,
        OrderType.emergency: 10000,
        OrderType.claim: 10000,
        OrderType.overdue: 10000,
      },
    );

    final order = Order(
      orderId: 'ORDER-1',
      itemId: 'item-1',
      warehouseId: 'WH-000',
      supplierId: 'SP-000',
      requestQty: 100,
      type: OrderType.daily,
      createdAt: DateTime(2025, 1, 1),
      customerId: 'CT-1',
      remark: '',
      parentOrderId: 'ORDER-PARENT-1',
    );

    final unit = unitPriceForOrder(order: order, priceTable: table);
    expect(unit, 9000);
  });
}
