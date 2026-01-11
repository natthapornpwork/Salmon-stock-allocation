import 'package:allocation_app/core/types.dart';
import 'package:equatable/equatable.dart';

enum OrderType { emergency, claim, overdue, daily }

class Order extends Equatable {
  final String orderId;
  final String parentOrderId;
  final String itemId;
  final String warehouseId;
  final String supplierId;
  final Qty requestQty;
  final OrderType type;
  final DateTime createdAt;
  final String customerId;
  final String remark;

  const Order({
    required this.orderId,
    required this.parentOrderId,
    required this.itemId,
    required this.warehouseId,
    required this.supplierId,
    required this.requestQty,
    required this.type,
    required this.createdAt,
    required this.customerId,
    required this.remark,
  });

  bool get hasSubOrder => orderId != parentOrderId;

  @override
  List<Object?> get props => [
        orderId,
        parentOrderId,
        itemId,
        warehouseId,
        supplierId,
        requestQty,
        type,
        createdAt,
        customerId,
        remark,
      ];
}
