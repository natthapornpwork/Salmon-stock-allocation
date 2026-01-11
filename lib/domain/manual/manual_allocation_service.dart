import '../../core/types.dart';
import '../../data/models/allocation.dart';
import '../../data/models/order.dart';
import '../../data/models/price.dart';
import '../../data/models/stock.dart';
import '../allocator/pricing.dart';

sealed class ManualAllocationOutcome {
  const ManualAllocationOutcome();
}

class ManualAllocationSuccess extends ManualAllocationOutcome {
  final OrderAllocation allocation;
  final Map<StockKey, Qty> nextRemainingStock;
  final Map<String, Money> nextRemainingCredit;
  final Money newCostBaht;
  final Money oldCostBaht;

  const ManualAllocationSuccess({
    required this.allocation,
    required this.nextRemainingStock,
    required this.nextRemainingCredit,
    required this.newCostBaht,
    required this.oldCostBaht,
  });
}

class ManualAllocationFailure extends ManualAllocationOutcome {
  final String message;
  const ManualAllocationFailure(this.message);
}

class ManualAllocationInput {
  final Order order;
  final OrderAllocation oldAllocation;
  final List<AllocationLine> newLines;
  final Map<StockKey, Qty> remainingStock;
  final Map<String, Money> remainingCredit;

  final PriceTable priceTable;

  const ManualAllocationInput({
    required this.order,
    required this.oldAllocation,
    required this.newLines,
    required this.remainingStock,
    required this.remainingCredit,
    required this.priceTable,
  });
}

class ManualAllocationService {
  const ManualAllocationService();

  ManualAllocationOutcome validateAndApply(ManualAllocationInput input) {
    final order = input.order;

    final cleaned =
        input.newLines.where((l) => l.qty > 0).toList(growable: false);
    final newAlloc = OrderAllocation(orderId: order.orderId, lines: cleaned);

    final newTotal = newAlloc.totalQty;
    final oldTotal = input.oldAllocation.totalQty;

    if (newTotal > order.requestQty) {
      return const ManualAllocationFailure(
          'Allocated qty exceeds requested qty.');
    }

    StockKey keyOf(AllocationLine l) => StockKey(
          warehouseId: l.warehouseId,
          supplierId: l.supplierId,
          itemId: order.itemId,
        );

    Map<StockKey, Qty> sumByKey(OrderAllocation alloc) {
      final map = <StockKey, Qty>{};
      for (final l in alloc.lines) {
        final k = keyOf(l);
        map[k] = (map[k] ?? 0) + l.qty;
      }
      return map;
    }

    final oldByKey = sumByKey(input.oldAllocation);
    final newByKey = sumByKey(newAlloc);

    for (final l in newAlloc.lines) {
      if (order.warehouseId != 'WH-000' && l.warehouseId != order.warehouseId) {
        return ManualAllocationFailure(
            'Warehouse must be ${order.warehouseId} for this order.');
      }
      if (order.supplierId != 'SP-000' && l.supplierId != order.supplierId) {
        return ManualAllocationFailure(
            'Supplier must be ${order.supplierId} for this order.');
      }
    }

    for (final entry in newByKey.entries) {
      final k = entry.key;
      final want = entry.value;
      final available = (input.remainingStock[k] ?? 0) + (oldByKey[k] ?? 0);
      if (want > available) {
        return ManualAllocationFailure(
          'Not enough stock for ${k.warehouseId}/${k.supplierId}. Available ${qtyToString(available)}.',
        );
      }
    }

    final unitPrice =
        unitPriceForOrder(order: order, priceTable: input.priceTable);

    Money costBaht(Qty qty) => qty * unitPrice;

    final oldCost = costBaht(oldTotal);
    final newCost = costBaht(newTotal);

    final currentRemainingCredit = input.remainingCredit[order.customerId];
    if (currentRemainingCredit == null) {
      return ManualAllocationFailure(
        'Credit not found for customer ${order.customerId}. Check seeding/map keys.',
      );
    }
    final availableCredit = currentRemainingCredit + oldCost;

    if (newCost > availableCredit) {
      return ManualAllocationFailure(
        'Insufficient credit. Available ${moneyToString(availableCredit)}, needs ${moneyToString(newCost)}.',
      );
    }

    final nextStock = Map<StockKey, Qty>.from(input.remainingStock);
    for (final e in oldByKey.entries) {
      nextStock[e.key] = (nextStock[e.key] ?? 0) + e.value;
    }
    for (final e in newByKey.entries) {
      nextStock[e.key] = (nextStock[e.key] ?? 0) - e.value;
    }

    final updated = availableCredit - newCost;
    final nextCredit = Map<String, Money>.from(input.remainingCredit);
    nextCredit[order.customerId] = updated;

    return ManualAllocationSuccess(
      allocation: newAlloc,
      nextRemainingStock: nextStock,
      nextRemainingCredit: nextCredit,
      newCostBaht: newCost,
      oldCostBaht: oldCost,
    );
  }
}
