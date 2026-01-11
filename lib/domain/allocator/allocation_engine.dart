import '../../core/types.dart';
import '../../data/models/allocation.dart';
import '../../data/models/order.dart';
import '../../data/models/price.dart';
import '../../data/models/stock.dart';
import 'pricing.dart';

class AllocationResult {
  final Map<String, OrderAllocation> allocationsByOrderId;
  final Map<StockKey, Qty> remainingStock;
  final Map<String, Money> remainingCredit;

  const AllocationResult({
    required this.allocationsByOrderId,
    required this.remainingStock,
    required this.remainingCredit,
  });
}

class AllocationEngine {
  AllocationResult autoAllocateAll({
    required List<Order> orders,
    required Map<StockKey, Qty> stock,
    required Map<String, Money> creditByCustomer,
    required PriceTable priceTable,
  }) {
    final sorted = [...orders]..sort((a, b) {
        final p = _typePriority(a.type).compareTo(_typePriority(b.type));
        if (p != 0) return p;

        // ✅ New: double wildcard first, then single wildcard, then fixed
        final w = _wildcardPriority(a).compareTo(_wildcardPriority(b));
        if (w != 0) return w;

        final d = a.createdAt.compareTo(b.createdAt);
        if (d != 0) return d;

        return a.orderId.compareTo(b.orderId);
      });

    final stockLeft = Map<StockKey, Qty>.from(stock);
    final creditLeft = Map<String, Money>.from(creditByCustomer);

    final allocations = <String, OrderAllocation>{};

    for (final order in sorted) {
      final unitPrice = unitPriceForOrder(order: order, priceTable: priceTable);
      final remainingNeed = order.requestQty;

      final credit = creditLeft[order.customerId] ?? 0;
      if (unitPrice <= 0 || credit <= 0 || remainingNeed <= 0) {
        allocations[order.orderId] =
            OrderAllocation(orderId: order.orderId, lines: const []);
        continue;
      }

      final maxByCreditQty = credit ~/ unitPrice;

      var target =
          remainingNeed < maxByCreditQty ? remainingNeed : maxByCreditQty;
      if (target <= 0) {
        allocations[order.orderId] =
            OrderAllocation(orderId: order.orderId, lines: const []);
        continue;
      }

      final candidates = _candidateStocksForOrder(order, stockLeft);

      final lines = <AllocationLine>[];
      for (final k in candidates) {
        if (target <= 0) break;

        final avail = stockLeft[k] ?? 0;
        if (avail <= 0) continue;

        final take = avail < target ? avail : target;
        stockLeft[k] = avail - take;
        target -= take;

        lines.add(AllocationLine(
          warehouseId: k.warehouseId,
          supplierId: k.supplierId,
          qty: take,
        ));
      }

      final allocQty = lines.fold<int>(0, (s, l) => s + l.qty);
      final costBaht = allocQty * unitPrice;
      creditLeft[order.customerId] = (credit - costBaht).clamp(0, 1 << 62);
      allocations[order.orderId] =
          OrderAllocation(orderId: order.orderId, lines: lines);
    }

    return AllocationResult(
      allocationsByOrderId: allocations,
      remainingStock: stockLeft,
      remainingCredit: creditLeft,
    );
  }

  int _wildcardPriority(Order o) {
    final anyWh = o.warehouseId == 'WH-000';
    final anySp = o.supplierId == 'SP-000';
    if (anyWh && anySp) return 0; // first
    if (anyWh || anySp) return 1; // second
    return 2; // last
  }

  List<StockKey> _candidateStocksForOrder(
      Order order, Map<StockKey, Qty> stockLeft) {
    final anyWh = order.warehouseId == 'WH-000';
    final anySp = order.supplierId == 'SP-000';

    final list = stockLeft.keys.where((k) {
      if (k.itemId != order.itemId) return false;
      if (!anyWh && k.warehouseId != order.warehouseId) return false;
      if (!anySp && k.supplierId != order.supplierId) return false;
      return true;
    }).toList();

    // Prioritize the highest remaining stock
    list.sort((a, b) => (stockLeft[b] ?? 0).compareTo(stockLeft[a] ?? 0));
    return list;
  }

  int _typePriority(OrderType t) => switch (t) {
        OrderType.emergency => 0,
        OrderType.claim => 1,
        OrderType.overdue => 2,
        OrderType.daily => 3,
      };
}
