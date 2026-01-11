import 'package:equatable/equatable.dart';

class StockKey extends Equatable {
  final String warehouseId;
  final String supplierId;
  final String itemId;

  const StockKey({
    required this.warehouseId,
    required this.supplierId,
    required this.itemId,
  });

  @override
  List<Object?> get props => [warehouseId, supplierId, itemId];
}
