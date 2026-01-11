import 'package:allocation_app/domain/allocator/pricing.dart';
import 'package:allocation_app/utils/order_type_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/types.dart';
import '../../data/models/allocation.dart';
import '../../data/models/order.dart';
import '../../data/models/stock.dart';
import '../blocs/allocation_bloc.dart';

class OrderDetailPanel extends StatefulWidget {
  const OrderDetailPanel({super.key});

  @override
  State<OrderDetailPanel> createState() => _OrderDetailPanelState();
}

class _OrderDetailPanelState extends State<OrderDetailPanel> {
  bool _editing = false;
  int _draftAllocatedQty = 0;
  String? _errorText;

  String? _editingOrderId; // to reset draft when user changes selection

  void _resetDraftFromState(AllocationState state) {
    final id = state.selectedOrderId;
    if (id == null) return;

    final order = state.ordersAll.firstWhere((o) => o.orderId == id);
    final alloc = state.allocationsByOrderId[id] ??
        OrderAllocation(orderId: id, lines: const []);

    _draftAllocatedQty = alloc.totalQty;
    _errorText = null;
    _editingOrderId = order.orderId;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AllocationBloc, AllocationState>(
          listenWhen: (p, c) => p.manualSaveNonce != c.manualSaveNonce,
          listener: (context, state) {
            // only react if current selected order was saved
            if (state.manualSaveOrderId != state.selectedOrderId) return;

            if (state.manualSaveSuccess == true) {
              setState(() {
                _editing = false;
                _errorText = null;
                _resetDraftFromState(state);
              });
            } else {
              setState(() => _errorText = state.manualSaveMessage ?? 'Failed');
            }
          },
        ),
      ],
      child: BlocBuilder<AllocationBloc, AllocationState>(
        buildWhen: (p, c) =>
            p.selectedOrderId != c.selectedOrderId ||
            p.ordersAll != c.ordersAll ||
            p.allocationsByOrderId != c.allocationsByOrderId ||
            p.remainingCredit != c.remainingCredit ||
            p.remainingStock != c.remainingStock ||
            p.priceTable != c.priceTable ||
            p.lockedOrderIds != c.lockedOrderIds,
        builder: (context, state) {
          final id = state.selectedOrderId;
          if (id == null) {
            return const Center(child: Text('Select an order'));
          }

          final order = state.ordersAll.firstWhere((o) => o.orderId == id);
          final alloc = state.allocationsByOrderId[id] ??
              OrderAllocation(orderId: id, lines: const []);
          final allocQty = alloc.totalQty;

          // reset draft when switching orders (only if not editing)
          if (!_editing && _editingOrderId != order.orderId) {
            _resetDraftFromState(state);
          }

          final fmt = DateFormat('y-MM-dd HH:mm');
          final locked = state.lockedOrderIds.contains(order.orderId);

          final priceTable = state.priceTable;
          final unitPrice = priceTable == null
              ? 0
              : unitPriceForOrder(order: order, priceTable: priceTable);
          final remainingCreditNow =
              state.remainingCredit[order.customerId] ?? 0;
          final oldCost = allocQty * unitPrice;
          final availableCreditForThisOrder = remainingCreditNow + oldCost;

          final newCostPreview = _draftAllocatedQty * unitPrice;
          final remainingAfterSavePreview =
              (availableCreditForThisOrder - newCostPreview).clamp(0, 1 << 62);

          final rebalance = _rebalanceLines(
            order: order,
            state: state,
            oldAlloc: alloc,
            draftTotalQty: _draftAllocatedQty,
          );

          return Padding(
            padding: const EdgeInsets.all(10),
            child: ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.parentOrderId,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          if (order.hasSubOrder)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Sub: ${order.orderId}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: locked
                          ? 'Unlock (auto allocation can overwrite this order)'
                          : 'Lock (keep this order fixed when re-running auto)',
                      icon: Icon(locked ? Icons.lock : Icons.lock_open),
                      onPressed: () {
                        context.read<AllocationBloc>().add(
                              AllocationOrderLockToggled(
                                orderId: order.orderId,
                                locked: !locked,
                              ),
                            );
                      },
                    ),
                    const SizedBox(width: 8),
                    _TypeChip(type: order.type, text: _typeLabel(order.type)),
                  ],
                ),
                const SizedBox(height: 12),
                _PastelCard(
                  title: 'Order details',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Field(
                          label: 'Customer',
                          value: order.customerId,
                          icon: Icons.person),
                      _Field(
                          label: 'Created',
                          value: fmt.format(order.createdAt),
                          icon: Icons.schedule),
                      _Field(
                          label: 'Item',
                          value: order.itemId,
                          icon: Icons.inventory_2_outlined),
                      _Field(
                          label: 'Requested qty',
                          value: qtyToString(order.requestQty),
                          icon: Icons.scale),
                      _Field(
                          label: 'Warehouse',
                          value: order.warehouseId,
                          icon: Icons.warehouse_outlined),
                      _Field(
                          label: 'Supplier',
                          value: order.supplierId,
                          icon: Icons.local_shipping_outlined),
                      if (order.remark.isNotEmpty)
                        _Field(
                            label: 'Remark',
                            value: order.remark,
                            icon: Icons.notes),
                    ],
                  ),
                ),
                _PastelCard(
                  title: 'Allocation summary',
                  trailing: !_editing
                      ? FilledButton.icon(
                          onPressed: priceTable == null
                              ? null
                              : () {
                                  setState(() {
                                    _editing = true;
                                    _errorText = null;
                                    _draftAllocatedQty = allocQty;
                                    _editingOrderId = order.orderId;
                                  });
                                },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _editing = false;
                                  _errorText = null;
                                  _draftAllocatedQty = allocQty;
                                });
                              },
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () {
                                setState(() => _errorText = null);

                                if (priceTable == null) {
                                  setState(() =>
                                      _errorText = 'Price table not loaded.');
                                  return;
                                }
                                if (_draftAllocatedQty < 0) {
                                  setState(() => _errorText =
                                      'Allocated qty cannot be negative.');
                                  return;
                                }
                                if (_draftAllocatedQty > order.requestQty) {
                                  setState(() => _errorText =
                                      'Allocated qty exceeds requested qty.');
                                  return;
                                }
                                if (rebalance.errorMessage != null) {
                                  setState(() =>
                                      _errorText = rebalance.errorMessage);
                                  return;
                                }
                                if (newCostPreview >
                                    availableCreditForThisOrder) {
                                  setState(() => _errorText =
                                      'Insufficient credit. Available ${moneyToString(availableCreditForThisOrder)}, needs ${moneyToString(newCostPreview)}.');
                                  return;
                                }

                                context.read<AllocationBloc>().add(
                                      AllocationManualAllocationSubmitted(
                                        orderId: order.orderId,
                                        lines: rebalance.lines,
                                      ),
                                    );
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _Field(
                              label: 'Requested',
                              value: qtyToString(order.requestQty)),
                          if (!_editing)
                            _Field(
                                label: 'Allocated',
                                value: qtyToString(allocQty))
                          else
                            _EditableQtyField(
                              label: 'Allocated (edit)',
                              initial: _draftAllocatedQty,
                              onChanged: (v) => setState(() {
                                _draftAllocatedQty = v;
                                _errorText = null;
                              }),
                            ),
                          _Field(
                              label: 'Unit price',
                              value: moneyToString(unitPrice)),
                          _Field(
                              label: 'Remaining credit',
                              value: moneyToString(remainingCreditNow)),
                          if (_editing)
                            _Field(
                              label: 'Remaining after save',
                              value: moneyToString(remainingAfterSavePreview),
                            ),
                        ],
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _errorText!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  _RebalanceResult _rebalanceLines({
    required Order order,
    required AllocationState state,
    required OrderAllocation oldAlloc,
    required int draftTotalQty,
  }) {
    final oldByKey = <StockKey, int>{};
    for (final l in oldAlloc.lines) {
      final k = StockKey(
        warehouseId: l.warehouseId,
        supplierId: l.supplierId,
        itemId: order.itemId,
      );
      oldByKey[k] = (oldByKey[k] ?? 0) + l.qty;
    }

    final oldTotal = oldAlloc.totalQty;
    if (oldByKey.isEmpty) {
      if (draftTotalQty == 0) return const _RebalanceResult(lines: []);
      final best = _pickBestKey(order: order, state: state);
      if (best == null) {
        return const _RebalanceResult(
            lines: [], errorMessage: 'No stock available for this item.');
      }
      final avail = state.remainingStock[best] ?? 0;
      if (draftTotalQty > avail) {
        return _RebalanceResult(
          lines: const [],
          errorMessage:
              'Not enough stock for ${best.warehouseId}/${best.supplierId}. Available ${qtyToString(avail)}.',
        );
      }
      return _RebalanceResult(lines: [
        AllocationLine(
            warehouseId: best.warehouseId,
            supplierId: best.supplierId,
            qty: draftTotalQty),
      ]);
    }

    if (draftTotalQty == oldTotal) {
      return _RebalanceResult(lines: oldAlloc.lines);
    }

    final maxAtKey = <StockKey, int>{};
    for (final k in oldByKey.keys) {
      maxAtKey[k] = (state.remainingStock[k] ?? 0) + (oldByKey[k] ?? 0);
    }

    final nextByKey = Map<StockKey, int>.from(oldByKey);

    if (draftTotalQty < oldTotal) {
      var reduce = oldTotal - draftTotalQty;
      final keys = nextByKey.keys.toList()
        ..sort((a, b) => '${a.warehouseId}/${a.supplierId}'
            .compareTo('${b.warehouseId}/${b.supplierId}'));

      for (final k in keys.reversed) {
        if (reduce <= 0) break;
        final have = nextByKey[k] ?? 0;
        final cut = have < reduce ? have : reduce;
        nextByKey[k] = have - cut;
        reduce -= cut;
      }
      nextByKey.removeWhere((_, v) => v <= 0);
    } else {
      var add = draftTotalQty - oldTotal;

      final keys = nextByKey.keys.toList()
        ..sort((a, b) {
          final headA = (maxAtKey[a] ?? 0) - (nextByKey[a] ?? 0);
          final headB = (maxAtKey[b] ?? 0) - (nextByKey[b] ?? 0);
          return headB.compareTo(headA);
        });

      for (final k in keys) {
        if (add <= 0) break;
        final headroom = (maxAtKey[k] ?? 0) - (nextByKey[k] ?? 0);
        if (headroom <= 0) continue;
        final take = headroom < add ? headroom : add;
        nextByKey[k] = (nextByKey[k] ?? 0) + take;
        add -= take;
      }

      if (add > 0) {
        return const _RebalanceResult(
          lines: [],
          errorMessage:
              'Not enough stock on existing allocation source to increase quantity.',
        );
      }
    }

    final lines = <AllocationLine>[];
    for (final e in nextByKey.entries) {
      lines.add(AllocationLine(
        warehouseId: e.key.warehouseId,
        supplierId: e.key.supplierId,
        qty: e.value,
      ));
    }

    lines.sort((a, b) => '${a.warehouseId}/${a.supplierId}'
        .compareTo('${b.warehouseId}/${b.supplierId}'));
    return _RebalanceResult(lines: lines);
  }

  StockKey? _pickBestKey({
    required Order order,
    required AllocationState state,
  }) {
    final anyWh = order.warehouseId == 'WH-000';
    final anySp = order.supplierId == 'SP-000';

    StockKey? best;
    int bestQty = -1;

    for (final e in state.remainingStock.entries) {
      final k = e.key;
      if (k.itemId != order.itemId) continue;
      if (!anyWh && k.warehouseId != order.warehouseId) continue;
      if (!anySp && k.supplierId != order.supplierId) continue;

      if (e.value > bestQty) {
        bestQty = e.value;
        best = k;
      }
    }
    return best;
  }

  String _typeLabel(OrderType t) => switch (t) {
        OrderType.emergency => 'EMERGENCY',
        OrderType.claim => 'CLAIM',
        OrderType.overdue => 'OVERDUE',
        OrderType.daily => 'DAILY',
      };
}

class _RebalanceResult {
  final List<AllocationLine> lines;
  final String? errorMessage;
  const _RebalanceResult({required this.lines, this.errorMessage});
}

class _EditableQtyField extends StatelessWidget {
  final String label;
  final int initial;
  final ValueChanged<int> onChanged;

  const _EditableQtyField({
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  int _parseQty(String input) {
    final s = input.trim().replaceAll(',', '');
    return int.tryParse(s) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: qtyToString(initial),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => onChanged(_parseQty(v)),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(text));
  }
}

class _PastelCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _PastelCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceVariant.withOpacity(0.35),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleMedium)),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const _Field({
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final OrderType type;
  final String text;

  const _TypeChip({required this.type, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = OrderTypeUi.accent(context, type);

    return Chip(
      label: Text(
        text,
        style: TextStyle(
          color: OrderTypeUi.fg(context, type),
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: OrderTypeUi.bg(context, type),
      side: BorderSide(color: OrderTypeUi.border(context, type)),
    );
  }
}
