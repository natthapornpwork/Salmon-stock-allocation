import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/types.dart';
import '../../data/models/allocation.dart';
import '../../data/models/order.dart';
import '../../data/models/stock.dart';
import '../../service/allocator/pricing_service.dart';
import '../blocs/allocation_bloc.dart';

class AllocationEditorDialog extends StatefulWidget {
  final String orderId;

  const AllocationEditorDialog({super.key, required this.orderId});

  @override
  State<AllocationEditorDialog> createState() => _AllocationEditorDialogState();
}

class _AllocationEditorDialogState extends State<AllocationEditorDialog> {
  late List<_DraftLine> _lines;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final state = context.read<AllocationBloc>().state;

    final order =
        state.ordersAll.firstWhere((o) => o.orderId == widget.orderId);
    final oldAlloc = state.allocationsByOrderId[order.orderId] ??
        OrderAllocation(orderId: order.orderId, lines: const []);

    _lines = oldAlloc.lines.isEmpty
        ? [_DraftLine.fromOrder(order, state)]
        : oldAlloc.lines.map((l) => _DraftLine.fromLine(l)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AllocationBloc, AllocationState>(
      listenWhen: (p, c) => p.manualSaveNonce != c.manualSaveNonce,
      listener: (context, state) {
        if (state.manualSaveOrderId != widget.orderId) return;
        if (!mounted) return;

        if (state.manualSaveSuccess == true) {
          Navigator.of(context).pop();
        } else {
          setState(() => _errorText = state.manualSaveMessage ?? 'Failed');
        }
      },
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BlocBuilder<AllocationBloc, AllocationState>(
              buildWhen: (p, c) =>
                  p.ordersAll != c.ordersAll ||
                  p.remainingStock != c.remainingStock ||
                  p.remainingCredit != c.remainingCredit ||
                  p.allocationsByOrderId != c.allocationsByOrderId ||
                  p.priceTable != c.priceTable,
              builder: (context, state) {
                final order = state.ordersAll
                    .firstWhere((o) => o.orderId == widget.orderId);

                final priceTable = state.priceTable!;
                final unitPrice =
                    unitPriceForOrder(order: order, priceTable: priceTable);

                final oldAlloc = state.allocationsByOrderId[order.orderId] ??
                    OrderAllocation(orderId: order.orderId, lines: const []);

                final oldTotal = oldAlloc.totalQty;
                final availableCredit =
                    (state.remainingCredit[order.customerId] ?? 0) +
                        (oldTotal * unitPrice);

                final newTotal = _lines.fold<int>(0, (s, l) => s + l.qty);

                return SizedBox(
                  height: MediaQuery.of(context).size.height * 0.78,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Manual allocation • ${order.orderId}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _ChipKV(
                                  label: 'Customer', value: order.customerId),
                              _ChipKV(
                                  label: 'Type',
                                  value: order.type.name.toUpperCase()),
                              _ChipKV(label: 'Item', value: order.itemId),
                              _ChipKV(
                                  label: 'Warehouse', value: order.warehouseId),
                              _ChipKV(
                                  label: 'Supplier', value: order.supplierId),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _ChipKV(
                              label: 'Requested',
                              value: qtyToString(order.requestQty)),
                          _ChipKV(
                              label: 'Unit price',
                              value: moneyToString(unitPrice)),
                          _ChipKV(
                              label: 'Available credit',
                              value: moneyToString(availableCredit)),
                          _ChipKV(
                              label: 'Draft allocation',
                              value: qtyToString(newTotal)),
                        ],
                      ),

                      const SizedBox(height: 10),

                      if (_errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _errorText!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Allocation lines (read-only)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final draft = await _openLineDialog(
                                          context: context,
                                          state: state,
                                          order: order,
                                          initial: null,
                                          oldAlloc: oldAlloc,
                                        );
                                        if (draft == null) return;
                                        setState(() {
                                          _errorText = null;
                                          _lines.add(draft);
                                        });
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add line'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: _lines.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, i) {
                                      final line = _lines[i];
                                      final key = StockKey(
                                        warehouseId: line.warehouseId,
                                        supplierId: line.supplierId,
                                        itemId: order.itemId,
                                      );

                                      final oldByKey =
                                          _sumOldByKey(order, oldAlloc);
                                      final effectiveAvail =
                                          (state.remainingStock[key] ?? 0) +
                                              (oldByKey[key] ?? 0);

                                      return ListTile(
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                            '${line.warehouseId} • ${line.supplierId}'),
                                        subtitle: Text(
                                            'Available: ${qtyToString(effectiveAvail)}'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(qtyToString(line.qty)),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              tooltip: 'Edit line',
                                              onPressed: () async {
                                                final updated =
                                                    await _openLineDialog(
                                                  context: context,
                                                  state: state,
                                                  order: order,
                                                  initial: line,
                                                  oldAlloc: oldAlloc,
                                                );
                                                if (updated == null) return;
                                                setState(() {
                                                  _errorText = null;
                                                  _lines[i] = updated;
                                                });
                                              },
                                              icon: const Icon(
                                                  Icons.edit_outlined),
                                            ),
                                            IconButton(
                                              tooltip: 'Remove line',
                                              onPressed: _lines.length == 1
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        _errorText = null;
                                                        _lines.removeAt(i);
                                                      });
                                                    },
                                              icon: const Icon(
                                                  Icons.delete_outline),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              setState(() => _errorText = null);

                              final lines = _lines
                                  .map((d) => AllocationLine(
                                        warehouseId: d.warehouseId,
                                        supplierId: d.supplierId,
                                        qty: d.qty,
                                      ))
                                  .toList(growable: false);

                              context.read<AllocationBloc>().add(
                                    AllocationManualAllocationSubmitted(
                                      orderId: widget.orderId,
                                      lines: lines,
                                    ),
                                  );
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<_DraftLine?> _openLineDialog({
    required BuildContext context,
    required AllocationState state,
    required Order order,
    required _DraftLine? initial,
    required OrderAllocation oldAlloc,
  }) async {
    final result = await showDialog<_DraftLine>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<AllocationBloc>(),
        child: _AllocationLineEditDialog(
          order: order,
          state: state,
          initial: initial,
          oldAllocation: oldAlloc,
        ),
      ),
    );
    return result;
  }

  Map<StockKey, Qty> _sumOldByKey(Order order, OrderAllocation alloc) {
    final map = <StockKey, Qty>{};
    for (final l in alloc.lines) {
      final k = StockKey(
          warehouseId: l.warehouseId,
          supplierId: l.supplierId,
          itemId: order.itemId);
      map[k] = (map[k] ?? 0) + l.qty;
    }
    return map;
  }
}

class _AllocationLineEditDialog extends StatefulWidget {
  final Order order;
  final AllocationState state;
  final _DraftLine? initial;
  final OrderAllocation oldAllocation;

  const _AllocationLineEditDialog({
    required this.order,
    required this.state,
    required this.initial,
    required this.oldAllocation,
  });

  @override
  State<_AllocationLineEditDialog> createState() =>
      _AllocationLineEditDialogState();
}

class _AllocationLineEditDialogState extends State<_AllocationLineEditDialog> {
  late String warehouseId;
  late String supplierId;
  late int qty;

  String? error;

  @override
  void initState() {
    super.initState();
    final init =
        widget.initial ?? _DraftLine.fromOrder(widget.order, widget.state);

    warehouseId = init.warehouseId;
    supplierId = init.supplierId;
    qty = init.qty;
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final state = widget.state;

    final allowedWarehouses = _warehousesFor(order, state);
    if (!allowedWarehouses.contains(warehouseId)) {
      warehouseId = allowedWarehouses.first;
    }

    final allowedSuppliers =
        _suppliersFor(order, state, selectedWarehouse: warehouseId);
    if (!allowedSuppliers.contains(supplierId)) {
      supplierId = allowedSuppliers.first;
    }

    final key = StockKey(
      warehouseId: warehouseId,
      supplierId: supplierId,
      itemId: order.itemId,
    );

    final oldByKey = _sumByKey(order, widget.oldAllocation);
    final effectiveAvail =
        (state.remainingStock[key] ?? 0) + (oldByKey[key] ?? 0);

    final overStock = qty > effectiveAvail;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.initial == null ? 'Add line' : 'Edit line',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: warehouseId,
                      decoration: const InputDecoration(
                        labelText: 'Warehouse',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final w in allowedWarehouses)
                          DropdownMenuItem(value: w, child: Text(w)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          warehouseId = v;
                          final sup =
                              _suppliersFor(order, state, selectedWarehouse: v);
                          if (!sup.contains(supplierId)) supplierId = sup.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: supplierId,
                      decoration: const InputDecoration(
                        labelText: 'Supplier',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final s in allowedSuppliers)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => supplierId = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: qtyToString(qty),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Qty (2 decimals)',
                  helperText:
                      'Available at key: ${qtyToString(effectiveAvail)}',
                  errorText: overStock ? 'Qty exceeds available stock.' : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => qty = _parseqty(v)),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: overStock
                        ? null
                        : () {
                            Navigator.of(context).pop(
                              _DraftLine(
                                warehouseId: warehouseId,
                                supplierId: supplierId,
                                qty: qty,
                              ),
                            );
                          },
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<StockKey, Qty> _sumByKey(Order order, OrderAllocation alloc) {
    final map = <StockKey, Qty>{};
    for (final l in alloc.lines) {
      final k = StockKey(
          warehouseId: l.warehouseId,
          supplierId: l.supplierId,
          itemId: order.itemId);
      map[k] = (map[k] ?? 0) + l.qty;
    }
    return map;
  }

  List<String> _warehousesFor(Order order, AllocationState state) {
    if (order.warehouseId != 'WH-000') return [order.warehouseId];
    final set = <String>{};
    for (final k in state.remainingStock.keys) {
      if (k.itemId == order.itemId) set.add(k.warehouseId);
    }
    final list = set.toList()..sort();
    return list.isEmpty ? ['WH-001'] : list;
  }

  List<String> _suppliersFor(
    Order order,
    AllocationState state, {
    required String selectedWarehouse,
  }) {
    if (order.supplierId != 'SP-000') return [order.supplierId];

    final set = <String>{};
    for (final k in state.remainingStock.keys) {
      if (k.itemId == order.itemId && k.warehouseId == selectedWarehouse) {
        set.add(k.supplierId);
      }
    }
    final list = set.toList()..sort();
    return list.isEmpty ? ['SP-001'] : list;
  }

  int _parseqty(String input) {
    final s = input.trim().replaceAll(',', '');
    if (s.isEmpty) return 0;
    final parts = s.split('.');
    final whole = int.tryParse(parts[0]) ?? 0;
    int frac = 0;
    if (parts.length > 1) {
      final f = parts[1];
      if (f.isNotEmpty) {
        final two = ('${f}00').substring(0, 2);
        frac = int.tryParse(two) ?? 0;
      }
    }
    return whole * 100 + frac;
  }
}

class _DraftLine {
  String warehouseId;
  String supplierId;
  int qty;

  _DraftLine({
    required this.warehouseId,
    required this.supplierId,
    required this.qty,
  });

  factory _DraftLine.fromLine(AllocationLine l) => _DraftLine(
      warehouseId: l.warehouseId, supplierId: l.supplierId, qty: l.qty);

  factory _DraftLine.fromOrder(Order order, AllocationState state) {
    if (order.warehouseId != 'WH-000' && order.supplierId != 'SP-000') {
      return _DraftLine(
          warehouseId: order.warehouseId, supplierId: order.supplierId, qty: 0);
    }

    StockKey? best;
    int bestQty = -1;
    for (final e in state.remainingStock.entries) {
      final k = e.key;
      if (k.itemId != order.itemId) continue;
      if (order.warehouseId != 'WH-000' && k.warehouseId != order.warehouseId) {
        continue;
      }
      if (order.supplierId != 'SP-000' && k.supplierId != order.supplierId) {
        continue;
      }
      if (e.value > bestQty) {
        bestQty = e.value;
        best = k;
      }
    }

    return _DraftLine(
      warehouseId: best?.warehouseId ??
          (order.warehouseId == 'WH-000' ? 'WH-001' : order.warehouseId),
      supplierId: best?.supplierId ??
          (order.supplierId == 'SP-000' ? 'SP-001' : order.supplierId),
      qty: 0,
    );
  }
}

class _ChipKV extends StatelessWidget {
  final String label;
  final String value;

  const _ChipKV({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}
