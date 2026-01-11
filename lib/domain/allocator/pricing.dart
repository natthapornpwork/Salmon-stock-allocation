import '../../core/types.dart';
import '../../data/models/order.dart';
import '../../data/models/price.dart';

Money unitPriceForOrder({
  required Order order,
  required PriceTable priceTable,
}) {
  final multiplierBp = priceTable.typeMultiplierBp[order.type] ?? 10000;

  Money base;
  if (order.supplierId != 'SP-000') {
    base = priceTable.baseUnitPriceSatang[
            PriceKey(itemId: order.itemId, supplierId: order.supplierId)] ??
        0;
  } else {
    final candidates = priceTable.baseUnitPriceSatang.entries
        .where((e) => e.key.itemId == order.itemId)
        .map((e) => e.value)
        .toList()
      ..sort();
    base = candidates.isEmpty ? 0 : candidates.first;
  }

  // adjusted = round_bankers(base * multiplierBp / 10000)
  return bankersDiv(base * multiplierBp, 10000);
}
