import 'package:flutter_test/flutter_test.dart';
import 'package:allocation_app/data/models/allocation.dart';
import 'package:allocation_app/data/models/order.dart';
import 'package:allocation_app/data/models/price.dart';
import 'package:allocation_app/data/models/stock.dart';
import 'package:allocation_app/service/manual/manual_allocation_service.dart';

void main() {
  PriceTable priceTable() {
    return PriceTable(
      baseUnitPriceSatang: {
        const PriceKey(itemId: 'item-1', supplierId: 'SP-001'):
            10000, // $100 / 1.00
      },
      typeMultiplierBp: {
        OrderType.daily: 10000,
        OrderType.emergency: 10000,
        OrderType.claim: 10000,
        OrderType.overdue: 10000,
      },
    );
  }

  Order order({
    String wh = 'WH-001',
    String sp = 'SP-001',
    int reqqty = 200, // 2.00
  }) {
    return Order(
      orderId: 'ORDER-1',
      itemId: 'item-1',
      warehouseId: wh,
      supplierId: sp,
      requestQty: reqqty,
      type: OrderType.daily,
      createdAt: DateTime(2025, 1, 1),
      customerId: 'CT-1',
      remark: '',
      parentOrderId: 'ORDER-PARENT-1',
    );
  }

  test('fails if allocated qty exceeds requested', () {
    const svc = ManualAllocationService();

    final o = order(reqqty: 200);

    final out = svc.validateAndApply(
      ManualAllocationInput(
        order: o,
        oldAllocation: const OrderAllocation(orderId: 'ORDER-1', lines: []),
        newLines: const [
          AllocationLine(warehouseId: 'WH-001', supplierId: 'SP-001', qty: 201),
        ],
        remainingStock: {
          const StockKey(
              warehouseId: 'WH-001',
              supplierId: 'SP-001',
              itemId: 'item-1'): 999999,
        },
        remainingCredit: {'CT-1': 999999999},
        priceTable: priceTable(),
      ),
    );

    expect(out, isA<ManualAllocationFailure>());
  });

  test('fails if stock is insufficient (but allows reusing old allocation)',
      () {
    const svc = ManualAllocationService();
    final o = order();

    // old allocation = 1.00
    const oldAlloc = OrderAllocation(orderId: 'ORDER-1', lines: [
      AllocationLine(warehouseId: 'WH-001', supplierId: 'SP-001', qty: 100),
    ]);

    // remaining stock says 0, but effective available is 0 + old(100) = 100
    final out = svc.validateAndApply(
      ManualAllocationInput(
        order: o,
        oldAllocation: oldAlloc,
        newLines: const [
          AllocationLine(warehouseId: 'WH-001', supplierId: 'SP-001', qty: 150),
        ],
        remainingStock: {
          const StockKey(
              warehouseId: 'WH-001', supplierId: 'SP-001', itemId: 'item-1'): 0,
        },
        remainingCredit: {'CT-1': 999999999},
        priceTable: priceTable(),
      ),
    );

    expect(out, isA<ManualAllocationFailure>());
  });

  test(
      'passes stock check when reallocating the same amount from old allocation',
      () {
    const svc = ManualAllocationService();
    final o = order();

    const oldAlloc = OrderAllocation(orderId: 'ORDER-1', lines: [
      AllocationLine(warehouseId: 'WH-001', supplierId: 'SP-001', qty: 100),
    ]);

    final out = svc.validateAndApply(
      ManualAllocationInput(
        order: o,
        oldAllocation: oldAlloc,
        newLines: const [
          AllocationLine(warehouseId: 'WH-001', supplierId: 'SP-001', qty: 100),
        ],
        remainingStock: {
          const StockKey(
              warehouseId: 'WH-001', supplierId: 'SP-001', itemId: 'item-1'): 0,
        },
        remainingCredit: {'CT-1': 999999999},
        priceTable: priceTable(),
      ),
    );

    expect(out, isA<ManualAllocationSuccess>());
  });

  test('fails if warehouse is not allowed when order is non-wildcard', () {
    const svc = ManualAllocationService();
    final o = order(wh: 'WH-001');

    final out = svc.validateAndApply(
      ManualAllocationInput(
        order: o,
        oldAllocation: const OrderAllocation(orderId: 'ORDER-1', lines: []),
        newLines: const [
          AllocationLine(warehouseId: 'WH-002', supplierId: 'SP-001', qty: 100),
        ],
        remainingStock: {
          const StockKey(
              warehouseId: 'WH-002',
              supplierId: 'SP-001',
              itemId: 'item-1'): 999999,
        },
        remainingCredit: {'CT-1': 999999999},
        priceTable: priceTable(),
      ),
    );

    expect(out, isA<ManualAllocationFailure>());
  });

  test('fails if credit is insufficient (but allows reusing old spend)', () {
    const svc = ManualAllocationService();
    final o = order(reqqty: 300); // 3.00

    // old = 1.00 => costs $100
    const oldAlloc = OrderAllocation(orderId: 'ORDER-1', lines: [
      AllocationLine(warehouseId: 'WH-001', supplierId: 'SP-001', qty: 100),
    ]);

    final out = svc.validateAndApply(
      ManualAllocationInput(
        order: o,
        oldAllocation: oldAlloc,
        newLines: const [
          AllocationLine(warehouseId: 'WH-001', supplierId: 'SP-001', qty: 200),
        ],
        remainingStock: {
          const StockKey(
              warehouseId: 'WH-001',
              supplierId: 'SP-001',
              itemId: 'item-1'): 999999,
        },
        remainingCredit: {'CT-1': 0},
        priceTable: priceTable(),
      ),
    );

    expect(out, isA<ManualAllocationFailure>());
  });
}
