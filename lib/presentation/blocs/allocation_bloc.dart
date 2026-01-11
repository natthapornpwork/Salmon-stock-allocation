import 'dart:async';
import 'dart:isolate';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/types.dart';
import '../../data/mock/mock_repository.dart';
import '../../data/models/allocation.dart';
import '../../data/models/customer.dart';
import '../../data/models/order.dart';
import '../../data/models/price.dart';
import '../../data/models/stock.dart';
import '../../domain/allocator/allocation_engine.dart';
import '../../domain/allocator/pricing.dart';
import '../../domain/manual/manual_allocation_service.dart';

part 'allocation_event.dart';
part 'allocation_state.dart';

const bool _isWeb = bool.fromEnvironment('dart.library.html');

class AllocationBloc extends Bloc<AllocationEvent, AllocationState> {
  AllocationBloc(this._repo) : super(const AllocationState()) {
    on<AllocationLoadRequested>(_onLoadRequested);
    on<AllocationSearchChanged>(
      _onSearchChanged,
      transformer: _debounce(const Duration(milliseconds: 200)),
    );
    on<AllocationJumpToOrderRequested>(_onJumpToOrderRequested);
    on<AllocationOrderSelected>(_onOrderSelected);
    on<AllocationManualAllocationSubmitted>(_onManualAllocationSubmitted);
    on<AllocationTypeFilterChanged>(_onTypeFilterChanged);
    on<AllocationReAutoRequested>(_onReAutoRequested);
    on<AllocationOrderLockToggled>(_onOrderLockToggled);
  }

  final MockRepository _repo;
  final Map<String, Order> _orderById = {};
  final Map<String, String> _searchBlobByOrderId = {};
  final Map<String, String> _firstSubIdByParent = {};
  late Map<StockKey, Qty> _baseStock;
  late Map<String, Money> _baseCredit;

  Future<void> _onLoadRequested(
    AllocationLoadRequested event,
    Emitter<AllocationState> emit,
  ) async {
    emit(state.copyWith(status: AllocationStatus.loading, errorMessage: null));

    try {
      final data = await _repo.load();

      _orderById
        ..clear()
        ..addEntries(data.orders.map((o) => MapEntry(o.orderId, o)));

      _searchBlobByOrderId
        ..clear()
        ..addEntries(data.orders.map((o) {
          final blob =
              '${o.parentOrderId} ${o.orderId} ${o.customerId} ${o.remark}'
                  .toLowerCase();

          return MapEntry(o.orderId, blob);
        }));

      _firstSubIdByParent.clear();
      for (final o in data.orders) {
        _firstSubIdByParent.putIfAbsent(o.parentOrderId, () => o.orderId);
      }

      final creditByCustomer = <String, Money>{
        for (final c in data.customers) c.customerId: c.creditSatang,
      };

      _baseStock = Map<StockKey, Qty>.from(data.stockByKey);
      _baseCredit = Map<String, Money>.from(creditByCustomer);

      final bool useIsolate = !_isWeb && data.orders.length >= 5000;

      if (useIsolate) {
        emit(state.copyWith(status: AllocationStatus.runningAuto));
      }

      final AllocationResult result = useIsolate
          ? await _runAutoAllocationInIsolate(
              orders: data.orders,
              stock: data.stockByKey,
              creditByCustomer: creditByCustomer,
              priceTable: data.priceTable,
            )
          : AllocationEngine().autoAllocateAll(
              orders: data.orders,
              stock: data.stockByKey,
              creditByCustomer: creditByCustomer,
              priceTable: data.priceTable,
            );

      final visible =
          _applyQueryAndFilter(data.orders, state.query, state.filterType);

      emit(state.copyWith(
        status: AllocationStatus.ready,
        ordersAll: data.orders,
        ordersVisible: visible,
        customers: data.customers,
        allocationsByOrderId: result.allocationsByOrderId,
        remainingCredit: result.remainingCredit,
        remainingStock: result.remainingStock,
        priceTable: data.priceTable,
        selectedOrderId: data.orders.isEmpty ? null : data.orders.first.orderId,
        lockedOrderIds: const <String>{},
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AllocationStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onSearchChanged(
    AllocationSearchChanged event,
    Emitter<AllocationState> emit,
  ) {
    final q = event.query.trim();
    emit(state.copyWith(
      query: q,
      ordersVisible: _applyQueryAndFilter(state.ordersAll, q, state.filterType),
    ));
  }

  void _onJumpToOrderRequested(
    AllocationJumpToOrderRequested event,
    Emitter<AllocationState> emit,
  ) {
    final id = event.orderId.trim();
    if (id.isEmpty) return;

    final direct = _orderById[id];
    if (direct != null) {
      emit(state.copyWith(selectedOrderId: id));
      return;
    }

    final firstSub = _firstSubIdByParent[id];
    if (firstSub != null) {
      emit(state.copyWith(
        query: id,
        ordersVisible:
            _applyQueryAndFilter(state.ordersAll, id, state.filterType),
        selectedOrderId: firstSub,
      ));
      return;
    }

    emit(state.withManualSave(
      orderId: state.selectedOrderId ?? '',
      success: false,
      message: 'Order not found: $id',
    ));
  }

  void _onOrderSelected(
    AllocationOrderSelected event,
    Emitter<AllocationState> emit,
  ) {
    emit(state.copyWith(selectedOrderId: event.orderId));
  }

  void _onManualAllocationSubmitted(
    AllocationManualAllocationSubmitted event,
    Emitter<AllocationState> emit,
  ) {
    final priceTable = state.priceTable;

    if (priceTable == null) {
      emit(state.withManualSave(
        orderId: event.orderId,
        success: false,
        message: 'Price table not loaded.',
      ));
      return;
    }

    final order = _orderById[event.orderId];
    if (order == null) {
      emit(state.withManualSave(
        orderId: event.orderId,
        success: false,
        message: 'Order not found.',
      ));
      return;
    }
    final nextLocked = {...state.lockedOrderIds, event.orderId};

    final oldAlloc = state.allocationsByOrderId[event.orderId] ??
        OrderAllocation(orderId: event.orderId, lines: const []);

    const svc = ManualAllocationService();

    final outcome = svc.validateAndApply(
      ManualAllocationInput(
        order: order,
        oldAllocation: oldAlloc,
        newLines: event.lines,
        remainingStock: state.remainingStock,
        remainingCredit: state.remainingCredit,
        priceTable: priceTable,
      ),
    );

    switch (outcome) {
      case ManualAllocationFailure():
        emit(state.withManualSave(
          orderId: order.orderId,
          success: false,
          message: outcome.message,
        ));
        return;

      case ManualAllocationSuccess():
        final nextAllocs =
            Map<String, OrderAllocation>.from(state.allocationsByOrderId);
        nextAllocs[order.orderId] = outcome.allocation;


        emit(state
            .copyWith(
              allocationsByOrderId: nextAllocs,
              remainingStock: outcome.nextRemainingStock,
              remainingCredit: outcome.nextRemainingCredit,
              lockedOrderIds: nextLocked,
            )
            .withManualSave(
                orderId: order.orderId,
                success: true,
                message: 'Saved & locked.'));
        return;
    }
  }

  Future<void> _onReAutoRequested(
    AllocationReAutoRequested event,
    Emitter<AllocationState> emit,
  ) async {
    final priceTable = state.priceTable;
    if (priceTable == null) return;

    emit(state.copyWith(
        status: AllocationStatus.runningAuto, errorMessage: null));

    try {
      final locked = state.lockedOrderIds;

      final stockLeft = Map<StockKey, Qty>.from(_baseStock);
      final creditLeft = Map<String, Money>.from(_baseCredit);

      for (final orderId in locked) {
        final order = _orderById[orderId];
        final alloc = state.allocationsByOrderId[orderId];
        if (order == null || alloc == null) continue;

        for (final line in alloc.lines) {
          final k = StockKey(
            warehouseId: line.warehouseId,
            supplierId: line.supplierId,
            itemId: order.itemId,
          );
          stockLeft[k] = (stockLeft[k] ?? 0) - line.qty;
        }

        final unitPrice =
            unitPriceForOrder(order: order, priceTable: priceTable);
        final cost = alloc.totalQty * unitPrice; // Qty is int units now
        creditLeft[order.customerId] =
            ((creditLeft[order.customerId] ?? 0) - cost).clamp(0, 1 << 62);
      }

      final unlockedOrders = state.ordersAll
          .where((o) => !locked.contains(o.orderId))
          .toList(growable: false);

      final bool useIsolate = !_isWeb && unlockedOrders.length >= 5000;

      final AllocationResult result = useIsolate
          ? await _runAutoAllocationInIsolate(
              orders: unlockedOrders,
              stock: stockLeft,
              creditByCustomer: creditLeft,
              priceTable: priceTable,
            )
          : AllocationEngine().autoAllocateAll(
              orders: unlockedOrders,
              stock: stockLeft,
              creditByCustomer: creditLeft,
              priceTable: priceTable,
            );

      final merged = <String, OrderAllocation>{};

      for (final id in locked) {
        final a = state.allocationsByOrderId[id];
        if (a != null) merged[id] = a;
      }

      merged.addAll(result.allocationsByOrderId);

      final nextCredit = _recomputeRemainingCredit(
        allocationsByOrderId: merged,
        priceTable: priceTable,
      );

      emit(state.copyWith(
        status: AllocationStatus.ready,
        allocationsByOrderId: merged,
        remainingStock: result.remainingStock,
        remainingCredit: nextCredit, // ✅ stable
        ordersVisible: _applyQueryAndFilter(
            state.ordersAll, state.query, state.filterType),
      ));
    } catch (e) {
      emit(state.copyWith(
          status: AllocationStatus.failure, errorMessage: e.toString()));
    }
  }

  void _onOrderLockToggled(
    AllocationOrderLockToggled event,
    Emitter<AllocationState> emit,
  ) {
    final next = {...state.lockedOrderIds};
    if (event.locked) {
      next.add(event.orderId);
    } else {
      next.remove(event.orderId);
    }
    emit(state.copyWith(lockedOrderIds: next));
  }

  void _onTypeFilterChanged(
    AllocationTypeFilterChanged event,
    Emitter<AllocationState> emit,
  ) {
    emit(state.copyWith(
      filterType: event.filterType,
      ordersVisible: _applyQueryAndFilter(
        state.ordersAll,
        state.query,
        event.filterType,
      ),
    ));
  }

  List<Order> _applyQueryAndFilter(
      List<Order> input, String q, OrderType? filter) {
    final trimmed = q.trim();

    // 1) Exact SUB-order id jump (fast path)
    if (trimmed.isNotEmpty) {
      final exact = _orderById[trimmed]; // keyed by sub-order orderId
      if (exact != null) {
        if (filter != null && exact.type != filter) return const [];
        return [exact];
      }
    }

    Iterable<Order> it = input;

    // 2) Type filter
    if (filter != null) {
      it = it.where((o) => o.type == filter);
    }

    // 3) Query handling
    if (trimmed.isNotEmpty) {
      // 3a) Exact PARENT-order id match => show ALL sub-orders in that parent
      final parentMatches =
          it.where((o) => o.parentOrderId == trimmed).toList(growable: false);

      if (parentMatches.isNotEmpty) {
        parentMatches.sort((a, b) {
          final p = _typePriority(a.type).compareTo(_typePriority(b.type));
          if (p != 0) return p;
          final d = a.createdAt.compareTo(b.createdAt);
          if (d != 0) return d;
          return a.orderId.compareTo(b.orderId);
        });
        return parentMatches;
      }

      // 3b) Fuzzy search (contains)
      final needle = trimmed.toLowerCase();
      it = it.where((o) {
        final blob = _searchBlobByOrderId[o.orderId]; // keyed by sub-order id
        return blob != null && blob.contains(needle);
      });
    }

    // 4) Sort by priority + FIFO + orderId
    final list = it.toList(growable: false);
    list.sort((a, b) {
      final p = _typePriority(a.type).compareTo(_typePriority(b.type));
      if (p != 0) return p;
      final d = a.createdAt.compareTo(b.createdAt);
      if (d != 0) return d;
      return a.orderId.compareTo(b.orderId);
    });

    return list;
  }

  int _typePriority(OrderType t) => switch (t) {
        OrderType.emergency => 0,
        OrderType.claim => 1,
        OrderType.overdue => 2,
        OrderType.daily => 3,
      };

  // --------- Page 3: Isolate auto-allocation ----------
  Future<AllocationResult> _runAutoAllocationInIsolate({
    required List<Order> orders,
    required Map<StockKey, Qty> stock,
    required Map<String, Money> creditByCustomer,
    required PriceTable priceTable,
  }) async {
    if (_isWeb) {
      await Future<void>.delayed(Duration.zero);

      return AllocationEngine().autoAllocateAll(
        orders: orders,
        stock: stock,
        creditByCustomer: creditByCustomer,
        priceTable: priceTable,
      );
    }

    final payload = _encodePayload(
      orders: orders,
      stock: stock,
      creditByCustomer: creditByCustomer,
      priceTable: priceTable,
    );

    final out = await Isolate.run(() => _autoAllocCompute(payload));
    return _decodeResult(out);
  }

  static EventTransformer<T> _debounce<T>(Duration duration) {
    return (events, mapper) =>
        events.debounceTime(duration).asyncExpand(mapper);
  }

  Map<String, Money> _recomputeRemainingCredit({
    required Map<String, OrderAllocation> allocationsByOrderId,
    required PriceTable priceTable,
  }) {
    final remaining = Map<String, Money>.from(_baseCredit);

    for (final o in state.ordersAll) {
      final alloc = allocationsByOrderId[o.orderId];
      if (alloc == null) continue;

      final qty = alloc.totalQty;
      if (qty <= 0) continue;

      final unitPrice = unitPriceForOrder(order: o, priceTable: priceTable);
      final cost = qty * unitPrice; // qty = int units, unitPrice = satang/unit

      remaining[o.customerId] =
          ((remaining[o.customerId] ?? 0) - cost).clamp(0, 1 << 62);
    }

    return remaining;
  }
}

// Minimal debounce without rxdart
extension _DebounceExt<T> on Stream<T> {
  Stream<T> debounceTime(Duration duration) {
    Timer? timer;
    StreamController<T>? controller;
    T? last;

    controller = StreamController<T>(
      onListen: () {
        final sub = listen(
          (event) {
            last = event;
            timer?.cancel();
            timer = Timer(duration, () {
              if (!controller!.isClosed && last != null)
                controller!.add(last as T);
            });
          },
          onError: (Object e, StackTrace st) => controller!.addError(e, st),
          onDone: () async {
            timer?.cancel();
            if (!controller!.isClosed) await controller!.close();
          },
          cancelOnError: false,
        );
        controller!.onCancel = () async {
          timer?.cancel();
          await sub.cancel();
        };
      },
    );

    return controller.stream;
  }
}

// =======================
// Isolate encode/compute/decode (TOP LEVEL helpers)
// Everything below must be top-level or static-like for isolate safety.
// =======================

Map<String, dynamic> _encodePayload({
  required List<Order> orders,
  required Map<StockKey, Qty> stock,
  required Map<String, Money> creditByCustomer,
  required PriceTable priceTable,
}) {
  return {
    'orders': orders
        .map((o) => {
              'orderId': o.orderId,
              'itemId': o.itemId,
              'warehouseId': o.warehouseId,
              'supplierId': o.supplierId,
              'requestQty': o.requestQty,
              'type': o.type.name,
              'createdAt': o.createdAt.millisecondsSinceEpoch,
              'customerId': o.customerId,
              'remark': o.remark,
              'parentOrderId': o.parentOrderId,
            })
        .toList(growable: false),
    'stock': stock.entries
        .map((e) => {
              'wh': e.key.warehouseId,
              'sp': e.key.supplierId,
              'item': e.key.itemId,
              'qty': e.value,
            })
        .toList(growable: false),
    'credit': creditByCustomer,
    'prices': {
      'base': priceTable.baseUnitPriceSatang.entries
          .map((e) => {
                'item': e.key.itemId,
                'sp': e.key.supplierId,
                'price': e.value,
              })
          .toList(growable: false),
      'mult': {
        for (final e in priceTable.typeMultiplierBp.entries)
          e.key.name: e.value,
      },
    },
  };
}

Map<String, dynamic> _autoAllocCompute(Map<String, dynamic> payload) {
  // Decode
  final ordersJson = (payload['orders'] as List).cast<Map>();
  final stockJson = (payload['stock'] as List).cast<Map>();
  final credit = Map<String, int>.from(payload['credit'] as Map);

  final prices = payload['prices'] as Map;
  final baseJson = (prices['base'] as List).cast<Map>();
  final multJson = Map<String, int>.from(prices['mult'] as Map);

  final orders = ordersJson.map((m) {
    return Order(
      orderId: m['orderId'] as String,
      itemId: m['itemId'] as String,
      warehouseId: m['warehouseId'] as String,
      supplierId: m['supplierId'] as String,
      requestQty: m['requestQty'] as int,
      type: OrderType.values.firstWhere((t) => t.name == (m['type'] as String)),
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      customerId: m['customerId'] as String,
      remark: m['remark'] as String,
      parentOrderId: (m['parentOrderId'] as String),
    );
  }).toList(growable: false);

  final stock = <StockKey, Qty>{};
  for (final m in stockJson) {
    stock[StockKey(
      warehouseId: m['wh'] as String,
      supplierId: m['sp'] as String,
      itemId: m['item'] as String,
    )] = m['qty'] as int;
  }

  final base = <PriceKey, int>{};
  for (final m in baseJson) {
    base[PriceKey(itemId: m['item'] as String, supplierId: m['sp'] as String)] =
        m['price'] as int;
  }

  final mult = <OrderType, int>{
    for (final e in multJson.entries)
      OrderType.values.firstWhere((t) => t.name == e.key): e.value,
  };

  final priceTable =
      PriceTable(baseUnitPriceSatang: base, typeMultiplierBp: mult);

  // Compute
  final result = AllocationEngine().autoAllocateAll(
    orders: orders,
    stock: stock,
    creditByCustomer: credit,
    priceTable: priceTable,
  );

  // Encode output
  return {
    'allocations': result.allocationsByOrderId.values
        .map((oa) => {
              'orderId': oa.orderId,
              'lines': oa.lines
                  .map((l) => {
                        'wh': l.warehouseId,
                        'sp': l.supplierId,
                        'qty': l.qty,
                      })
                  .toList(growable: false),
            })
        .toList(growable: false),
    'remainingStock': result.remainingStock.entries
        .map((e) => {
              'wh': e.key.warehouseId,
              'sp': e.key.supplierId,
              'item': e.key.itemId,
              'qty': e.value,
            })
        .toList(growable: false),
    'remainingCredit': result.remainingCredit,
  };
}

AllocationResult _decodeResult(Map<String, dynamic> out) {
  final allocList = (out['allocations'] as List).cast<Map>();
  final stockList = (out['remainingStock'] as List).cast<Map>();
  final credit = Map<String, int>.from(out['remainingCredit'] as Map);

  final allocations = <String, OrderAllocation>{};
  for (final m in allocList) {
    final orderId = m['orderId'] as String;
    final linesJson = (m['lines'] as List).cast<Map>();
    final lines = linesJson
        .map((l) => AllocationLine(
              warehouseId: l['wh'] as String,
              supplierId: l['sp'] as String,
              qty: l['qty'] as int,
            ))
        .toList(growable: false);

    allocations[orderId] = OrderAllocation(orderId: orderId, lines: lines);
  }

  final remainingStock = <StockKey, Qty>{};
  for (final m in stockList) {
    remainingStock[StockKey(
      warehouseId: m['wh'] as String,
      supplierId: m['sp'] as String,
      itemId: m['item'] as String,
    )] = m['qty'] as int;
  }

  return AllocationResult(
    allocationsByOrderId: allocations,
    remainingStock: remainingStock,
    remainingCredit: credit,
  );
}
