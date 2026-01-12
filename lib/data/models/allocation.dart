import 'package:equatable/equatable.dart';

class AllocationLine extends Equatable {
  final String warehouseId;
  final String supplierId;
  final int qty;

  const AllocationLine({
    required this.warehouseId,
    required this.supplierId,
    required this.qty,
  });

  @override
  List<Object?> get props => [warehouseId, supplierId, qty];
}

class OrderAllocation extends Equatable {
  final String orderId;
  final List<AllocationLine> lines;

  const OrderAllocation({
    required this.orderId,
    required this.lines,
  });

  int get totalQty => lines.fold(0, (s, l) => s + l.qty);

  @override
  List<Object?> get props => [orderId, lines];
}
