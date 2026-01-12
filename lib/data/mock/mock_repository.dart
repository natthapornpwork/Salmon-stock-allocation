import 'dart:math';

import '../../core/types.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/stock.dart';
import '../models/price.dart';

class MockDataSet {
  final List<Order> orders;
  final List<Customer> customers;
  final Map<StockKey, Qty> stockByKey;
  final PriceTable priceTable;

  const MockDataSet({
    required this.orders,
    required this.customers,
    required this.stockByKey,
    required this.priceTable,
  });
}

class MockRepository {
  MockDataSet? _cache;

  Future<MockDataSet> load() async {
    _cache ??= _build(seed: 8, orderCount: 5000);
    return _cache!;
  }

  MockDataSet _build({required int seed, required int orderCount}) {
    final rnd = Random(seed);

    final items = ['item-1', 'item-2', 'item-3'];
    final warehouses = ['WH-001', 'WH-002', 'WH-003', 'WH-004'];
    final suppliers = ['SP-001', 'SP-002', 'SP-003'];

    final customers = List.generate(4, (i) {
      final id = 'CT-${(1001 + i)}';
      final creditBaht = 200000000 + rnd.nextInt(38000000);
      final creditSatang = creditBaht * 100;
      return Customer(customerId: id, creditSatang: creditSatang);
    });

    final stock = <StockKey, Qty>{};
    for (final item in items) {
      for (final wh in warehouses) {
        for (final sp in suppliers) {
          final qty = 100 + rnd.nextInt(500);
          stock[StockKey(warehouseId: wh, supplierId: sp, itemId: item)] = qty;
        }
      }
    }

    final basePrices = <PriceKey, Money>{};
    const base100BySupplierSatang = <String, Money>{
      'SP-001': 9900, // ฿99.00
      'SP-002': 8750, // ฿87.50
      'SP-003': 10500, // ฿105.00
    };

    const itemOffsetSatang = <String, Money>{
      'item-1': 0,
      'item-2': 350, // +฿3.50
      'item-3': 800, // +฿8.00
    };

    for (final item in items) {
      for (final sp in suppliers) {
        final base100 = base100BySupplierSatang[sp]!;
        final offset = itemOffsetSatang[item] ?? 0;
        basePrices[PriceKey(itemId: item, supplierId: sp)] = base100 + offset;
      }
    }

    final multipliers = <OrderType, int>{
      OrderType.emergency: 12500, // 125%
      OrderType.claim: 10000,
      OrderType.overdue: 10000,
      OrderType.daily: 10000,
    };

    final priceTable = PriceTable(
      baseUnitPriceSatang: basePrices,
      typeMultiplierBp: multipliers,
    );

    final now = DateTime.now();

    OrderType randType() {
      final x = rnd.nextInt(100);
      if (x < 10) return OrderType.emergency;
      if (x < 25) return OrderType.claim;
      if (x < 40) return OrderType.overdue;
      return OrderType.daily;
    }

    final orders = <Order>[];
    int parentIndex = 0;

    while (orders.length < orderCount) {
      final parentOrderId = 'ORDER-${(100000 + parentIndex)}';
      final subCount = 1 + rnd.nextInt(3);

      final customer = customers[rnd.nextInt(customers.length)].customerId;

      final createdAt = now.subtract(Duration(
        days: rnd.nextInt(30),
        minutes: rnd.nextInt(24 * 60),
      ));

      final type = randType();

      for (int j = 0; j < subCount && orders.length < orderCount; j++) {
        final subOrderId =
            '$parentOrderId-${(j + 1).toString().padLeft(3, '0')}';

        final item = items[rnd.nextInt(items.length)];
        final roll = rnd.nextInt(100);

        late final String wh;
        late final String sp;

        if (roll < 8) {
          // 8%: both wildcard
          wh = 'WH-000';
          sp = 'SP-000';
        } else if (roll < 12) {
          // 4%: warehouse wildcard only
          wh = 'WH-000';
          sp = suppliers[rnd.nextInt(suppliers.length)];
        } else if (roll < 16) {
          // 4%: supplier wildcard only
          wh = warehouses[rnd.nextInt(warehouses.length)];
          sp = 'SP-000';
        } else {
          // 84%: fixed
          wh = warehouses[rnd.nextInt(warehouses.length)];
          sp = suppliers[rnd.nextInt(suppliers.length)];
        }

        final req = 1 + rnd.nextInt(60);

        orders.add(Order(
          orderId: subOrderId,
          parentOrderId: parentOrderId,
          itemId: item,
          warehouseId: wh,
          supplierId: sp,
          requestQty: req,
          type: type,
          createdAt: createdAt,
          customerId: customer,
          remark: (type == OrderType.emergency && rnd.nextBool())
              ? 'Special for VIP — handle with care.\n'
                  'This order needs to be delivered ASAP.\n'
                  'Contact customer before delivery.'
              : '',
        ));
      }

      parentIndex++;
    }

    for (final t in OrderType.values) {
      final hasDoubleWildcard = orders.any((o) =>
          o.type == t && o.warehouseId == 'WH-000' && o.supplierId == 'SP-000');

      if (!hasDoubleWildcard) {
        final idx = orders.indexWhere((o) => o.type == t);
        if (idx >= 0) {
          final o = orders[idx];
          orders[idx] = Order(
            orderId: o.orderId,
            parentOrderId: o.parentOrderId,
            itemId: o.itemId,
            warehouseId: 'WH-000',
            supplierId: 'SP-000',
            requestQty: o.requestQty,
            type: o.type,
            createdAt: o.createdAt,
            customerId: o.customerId,
            remark: o.remark,
          );
        }
      }
    }

    return MockDataSet(
      orders: orders,
      customers: customers,
      stockByKey: stock,
      priceTable: priceTable,
    );
  }
}
