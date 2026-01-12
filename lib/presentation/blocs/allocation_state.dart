part of 'allocation_bloc.dart';

enum AllocationStatus { initial, loading, runningAuto, ready, failure }

const Object _unset = Object();

class AllocationState extends Equatable {
  final AllocationStatus status;
  final String? errorMessage;
  final String query;
  final List<Order> ordersAll;
  final List<Order> ordersVisible;
  final List<Customer> customers;
  final PriceTable? priceTable;
  final Map<String, OrderAllocation> allocationsByOrderId;
  final Map<StockKey, Qty> remainingStock;
  final Map<String, Money> remainingCredit;
  final String? selectedOrderId;
  final int manualSaveNonce;
  final String? manualSaveOrderId;
  final bool? manualSaveSuccess;
  final String? manualSaveMessage;
  final OrderType? filterType;
  final Set<String> pinnedOrderIds;

  const AllocationState({
    this.status = AllocationStatus.initial,
    this.errorMessage,
    this.query = '',
    this.ordersAll = const [],
    this.ordersVisible = const [],
    this.customers = const [],
    this.priceTable,
    this.allocationsByOrderId = const {},
    this.remainingStock = const {},
    this.remainingCredit = const {},
    this.selectedOrderId,
    this.manualSaveNonce = 0,
    this.manualSaveOrderId,
    this.manualSaveSuccess,
    this.manualSaveMessage,
    this.filterType,
    this.pinnedOrderIds = const <String>{},
  });

  AllocationState copyWith({
    AllocationStatus? status,
    Object? errorMessage = _unset,
    String? query,
    List<Order>? ordersAll,
    List<Order>? ordersVisible,
    List<Customer>? customers,
    PriceTable? priceTable,
    Map<String, OrderAllocation>? allocationsByOrderId,
    Map<StockKey, Qty>? remainingStock,
    Map<String, Money>? remainingCredit,
    Object? selectedOrderId = _unset,
    Object? filterType = _unset,
    Set<String>? pinnedOrderIds,
  }) {
    return AllocationState(
      status: status ?? this.status,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      query: query ?? this.query,
      ordersAll: ordersAll ?? this.ordersAll,
      ordersVisible: ordersVisible ?? this.ordersVisible,
      customers: customers ?? this.customers,
      priceTable: priceTable ?? this.priceTable,
      allocationsByOrderId: allocationsByOrderId ?? this.allocationsByOrderId,
      remainingStock: remainingStock ?? this.remainingStock,
      remainingCredit: remainingCredit ?? this.remainingCredit,
      selectedOrderId: identical(selectedOrderId, _unset)
          ? this.selectedOrderId
          : selectedOrderId as String?,
      manualSaveNonce: manualSaveNonce,
      manualSaveOrderId: manualSaveOrderId,
      manualSaveSuccess: manualSaveSuccess,
      manualSaveMessage: manualSaveMessage,
      filterType: identical(filterType, _unset)
          ? this.filterType
          : filterType as OrderType?,
      pinnedOrderIds: pinnedOrderIds ?? this.pinnedOrderIds,
    );
  }

  AllocationState withManualSave({
    required String orderId,
    required bool success,
    required String message,
  }) {
    return AllocationState(
      status: status,
      errorMessage: errorMessage,
      query: query,
      ordersAll: ordersAll,
      ordersVisible: ordersVisible,
      customers: customers,
      priceTable: priceTable,
      allocationsByOrderId: allocationsByOrderId,
      remainingStock: remainingStock,
      remainingCredit: remainingCredit,
      selectedOrderId: selectedOrderId,
      manualSaveNonce: manualSaveNonce + 1,
      manualSaveOrderId: orderId,
      manualSaveSuccess: success,
      manualSaveMessage: message,
      pinnedOrderIds: pinnedOrderIds,
      filterType: filterType,
    );
  }

  @override
  List<Object?> get props => [
        status,
        errorMessage,
        query,
        ordersAll,
        ordersVisible,
        customers,
        priceTable,
        allocationsByOrderId,
        remainingStock,
        remainingCredit,
        selectedOrderId,
        manualSaveNonce,
        manualSaveOrderId,
        manualSaveSuccess,
        manualSaveMessage,
        filterType,
        pinnedOrderIds,
      ];
}
