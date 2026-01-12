import 'package:equatable/equatable.dart';
import '../../core/types.dart';
import 'order.dart';

class PriceKey extends Equatable {
  final String itemId;
  final String supplierId;

  const PriceKey({required this.itemId, required this.supplierId});

  @override
  List<Object?> get props => [itemId, supplierId];
}

class PriceTable extends Equatable {
  final Map<PriceKey, Money> baseUnitPriceSatang;
  final Map<OrderType, int> typeMultiplierBp;

  const PriceTable({
    required this.baseUnitPriceSatang,
    required this.typeMultiplierBp,
  });

  @override
  List<Object?> get props => [baseUnitPriceSatang, typeMultiplierBp];
}
