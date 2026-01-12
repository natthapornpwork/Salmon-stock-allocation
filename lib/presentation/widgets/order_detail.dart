import 'package:allocation_app/service/allocator/pricing_service.dart';
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
  final TextEditingController _allocCtrl = TextEditingController();
  final TextEditingController _ctrlCustomer = TextEditingController();
  final TextEditingController _ctrlCreated = TextEditingController();
  final TextEditingController _ctrlItem = TextEditingController();
  final TextEditingController _ctrlRequested = TextEditingController();
  final TextEditingController _ctrlWarehouse = TextEditingController();
  final TextEditingController _ctrlSupplier = TextEditingController();
  final TextEditingController _ctrlUnitPrice = TextEditingController();
  final TextEditingController _ctrlRemainingCredit = TextEditingController();
  final TextEditingController _ctrlRemark = TextEditingController();
  final FocusNode _allocFocus = FocusNode();

  bool _dirty = false;
  bool _syncingCtrl = false;
  int _draftAllocatedQty = 0;
  int _baselineAllocatedQty = 0;
  String? _errorText;
  String? _currentOrderId;
  bool _editing = false;
  String? _editingOrderId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_allocFocus);
      _selectAllAllocatedText();
    });

    _allocCtrl.addListener(() {
      if (_syncingCtrl) return;

      final v = _parseQty(_allocCtrl.text);
      if (v == _draftAllocatedQty) return;

      setState(() {
        _draftAllocatedQty = v;
        _dirty = (_draftAllocatedQty != _baselineAllocatedQty);
        _errorText = null;
      });
    });
  }

  @override
  void dispose() {
    _allocFocus.dispose();
    _ctrlCustomer.dispose();
    _ctrlCreated.dispose();
    _ctrlItem.dispose();
    _ctrlRequested.dispose();
    _ctrlWarehouse.dispose();
    _ctrlSupplier.dispose();
    _ctrlUnitPrice.dispose();
    _ctrlRemainingCredit.dispose();
    _ctrlRemark.dispose();
    _allocCtrl.dispose();
    super.dispose();
  }

  void _selectAllAllocatedText() {
    final text = _allocCtrl.text;
    _allocCtrl.selection =
        TextSelection(baseOffset: 0, extentOffset: text.length);
  }

  int _parseQty(String input) {
    final s = input.trim().replaceAll(',', '');
    return int.tryParse(s) ?? 0;
  }

  void _resetDraftFromState(AllocationState state) {
    final id = state.selectedOrderId;
    if (id == null) return;

    final alloc = state.allocationsByOrderId[id] ??
        OrderAllocation(orderId: id, lines: const []);

    _baselineAllocatedQty = alloc.totalQty;
    _draftAllocatedQty = alloc.totalQty;
    _dirty = false;
    _errorText = null;
    _currentOrderId = id;

    _syncingCtrl = true;
    _allocCtrl.text = qtyToString(_baselineAllocatedQty);
    _syncingCtrl = false;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AllocationBloc, AllocationState>(
          listenWhen: (p, c) => p.selectedOrderId != c.selectedOrderId,
          listener: (context, state) {
            if (!mounted) return;
            setState(() {
              _editing = false;
              _errorText = null;
              _resetDraftFromState(state);
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              FocusScope.of(context).requestFocus(_allocFocus);
              _selectAllAllocatedText();
            });
          },
        ),
        BlocListener<AllocationBloc, AllocationState>(
          listenWhen: (p, c) => p.manualSaveNonce != c.manualSaveNonce,
          listener: (context, state) {
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
        buildWhen: (previous, current) =>
            previous.selectedOrderId != current.selectedOrderId ||
            previous.ordersAll != current.ordersAll ||
            previous.allocationsByOrderId != current.allocationsByOrderId ||
            previous.remainingCredit != current.remainingCredit ||
            previous.remainingStock != current.remainingStock ||
            previous.priceTable != current.priceTable,
        builder: (context, state) {
          final cs = Theme.of(context).colorScheme;

          final id = state.selectedOrderId;
          if (id == null) {
            return const Center(child: Text('Select an order'));
          }

          final order = state.ordersAll.firstWhere((o) => o.orderId == id);
          final alloc = state.allocationsByOrderId[id] ??
              OrderAllocation(orderId: id, lines: const []);
          final allocQty = alloc.totalQty;

          if (_currentOrderId != order.orderId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _resetDraftFromState(state));
            });
          }

          final fmt = DateFormat('y-MM-dd HH:mm');
          final priceTable = state.priceTable;
          final unitPrice = priceTable == null
              ? 0
              : unitPriceForOrder(order: order, priceTable: priceTable);
          final remainingCreditNow =
              state.remainingCredit[order.customerId] ?? 0;
          final oldCost = allocQty * unitPrice;
          final availableCreditForThisOrder = remainingCreditNow + oldCost;
          final newCostPreview = _draftAllocatedQty * unitPrice;
          final allocEditable = priceTable != null;

          final rebalance = _rebalanceLines(
            order: order,
            state: state,
            oldAlloc: alloc,
            draftTotalQty: _draftAllocatedQty,
          );

          final createdText = fmt.format(order.createdAt);
          _syncReadOnlyControllers(
            order: order,
            createdText: createdText,
            unitPrice: unitPrice,
            remainingCredit: remainingCreditNow,
          );

          if (_currentOrderId != order.orderId) {
            _currentOrderId = order.orderId;
            _resetAllocatedDraft(allocQty);
          } else if (!_dirty && _baselineAllocatedQty != allocQty) {
            _resetAllocatedDraft(allocQty);
          }
          final showActions = _dirty && allocEditable;

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
                    const SizedBox(width: 8),
                    _TypeChip(type: order.type, text: _typeLabel(order.type)),
                  ],
                ),
                const SizedBox(height: 12),
                _PastelCard(
                  title: 'Details',
                  backgroundColor: Colors.white,
                  child: Column(
                    children: [
                      _TwoColumnFields(
                        children: [
                          _BoxTextField(
                              label: 'Customer',
                              controller: _ctrlCustomer,
                              readOnly: true,
                              icon: Icons.person,
                              tone: Colors.deepOrange.shade100),
                          _BoxTextField(
                              label: 'Created',
                              controller: _ctrlCreated,
                              readOnly: true,
                              icon: Icons.schedule,
                              tone: Colors.deepOrange.shade100),
                          _BoxTextField(
                              label: 'Item',
                              controller: _ctrlItem,
                              readOnly: true,
                              icon: Icons.inventory_2_outlined,
                              tone: Colors.deepOrange.shade100),
                          _BoxTextField(
                              label: 'Requested quantity',
                              controller: _ctrlRequested,
                              readOnly: true,
                              icon: Icons.scale,
                              tone: Colors.deepOrange.shade100),
                          _BoxTextField(
                              label: 'Warehouse',
                              controller: _ctrlWarehouse,
                              readOnly: true,
                              icon: Icons.warehouse_outlined,
                              tone: Colors.deepOrange.shade100),
                          _BoxTextField(
                              label: 'Supplier',
                              controller: _ctrlSupplier,
                              readOnly: true,
                              icon: Icons.local_shipping_outlined,
                              tone: Colors.deepOrange.shade100),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _BoxTextField(
                          label: 'Remark',
                          controller: _ctrlRemark,
                          readOnly: true,
                          tone: Colors.deepOrange.shade100),
                    ],
                  ),
                ),
                _PastelCard(
                  title: 'Allocation summary',
                  backgroundColor: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TwoColumnFields(
                        children: [
                          _BoxTextField(
                              label: 'Unit price',
                              controller: _ctrlUnitPrice,
                              readOnly: true),
                          _BoxTextField(
                              label: 'Remaining credit',
                              controller: _ctrlRemainingCredit,
                              readOnly: true),
                          _BoxTextField(
                              label: 'Requested',
                              controller: _ctrlRequested,
                              readOnly: true),
                          _BoxTextField(
                            label: 'Allocated',
                            controller: _allocCtrl,
                            readOnly: !allocEditable,
                            autofocus: true,
                            focusNode: _allocFocus,
                            onChanged: (text) {
                              final v = _parseQty(text);
                              setState(() {
                                _draftAllocatedQty = v;
                                _dirty = v != _baselineAllocatedQty;
                                _errorText = null;
                              });
                            },
                          ),
                        ],
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(_errorText!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                    ],
                  ),
                ),
                _BottomActionBar(
                  showActions: showActions,
                  onCancel: () => setState(() {
                    _resetAllocatedDraft(_baselineAllocatedQty);
                    Navigator.of(context).pop();
                  }),
                  onSave: () {
                    setState(() => _errorText = null);

                    if (_draftAllocatedQty < 0) {
                      setState(() => _errorText =
                          'Allocated quantity cannot be negative.');
                      return;
                    }
                    if (_draftAllocatedQty > order.requestQty) {
                      setState(() => _errorText =
                          'Allocated quantity exceeds requested quantity.');
                      return;
                    }
                    if (rebalance.errorMessage != null) {
                      setState(() => _errorText = rebalance.errorMessage);
                      return;
                    }
                    if (newCostPreview > availableCreditForThisOrder) {
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

  void _syncReadOnlyControllers({
    required Order order,
    required String createdText,
    required Money unitPrice,
    required Money remainingCredit,
  }) {
    _ctrlCustomer.text = order.customerId;
    _ctrlCreated.text = createdText;
    _ctrlItem.text = order.itemId;
    _ctrlRequested.text = qtyToString(order.requestQty);
    _ctrlWarehouse.text = order.warehouseId;
    _ctrlSupplier.text = order.supplierId;
    _ctrlRemark.text = order.remark;

    _ctrlUnitPrice.text = moneyToString(unitPrice);
    _ctrlRemainingCredit.text = moneyToString(remainingCredit);
  }

  void _resetAllocatedDraft(int allocQty) {
    _baselineAllocatedQty = allocQty;
    _draftAllocatedQty = allocQty;
    _dirty = false;
    _errorText = null;
    _allocCtrl.text = qtyToString(allocQty);
  }
}

class _RebalanceResult {
  final List<AllocationLine> lines;
  final String? errorMessage;
  const _RebalanceResult({required this.lines, this.errorMessage});
}

class _BoxTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final IconData? icon;
  final Color? tone;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final int maxLines;
  final TextInputType keyboardType;

  const _BoxTextField({
    required this.label,
    required this.controller,
    required this.readOnly,
    this.icon,
    this.tone,
    this.onChanged,
    this.focusNode,
    this.maxLines = 1,
    this.autofocus = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final base = tone ?? cs.primaryContainer;
    final bg = base.withOpacity(0.9);
    OutlineInputBorder _b(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: 3),
        );

    return Container(
      constraints: BoxConstraints(minHeight: maxLines == 1 ? 64 : 110),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onChanged: readOnly ? null : onChanged,
        focusNode: focusNode,
        autofocus: autofocus,
        keyboardType: maxLines > 1
            ? TextInputType.multiline
            : (readOnly ? TextInputType.text : TextInputType.number),
        decoration: InputDecoration(
          fillColor: cs.primaryContainer.withOpacity(0.10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          labelText: label,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: cs.primary,
          ),
          prefixIcon: icon == null ? null : Icon(icon, size: 18),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          enabledBorder: _b(base.withOpacity(0.65)),
          focusedBorder: _b(cs.primary),
          disabledBorder: _b(cs.outlineVariant.withOpacity(0.35)),
        ),
      ),
    );
  }
}

class _PastelCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final Color? backgroundColor;

  const _PastelCard({
    required this.title,
    required this.child,
    this.trailing,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: backgroundColor ?? cs.surfaceVariant.withOpacity(0.35),
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

class _TypeChip extends StatelessWidget {
  final OrderType type;
  final String text;

  const _TypeChip({required this.type, required this.text});

  @override
  Widget build(BuildContext context) {
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

class _TwoColumnFields extends StatelessWidget {
  final List<Widget> children;
  final double hGap;
  final double vGap;

  const _TwoColumnFields({
    required this.children,
    this.hGap = 10,
    this.vGap = 10,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (int i = 0; i < children.length; i += 2) {
      final left = children[i];
      final right =
          (i + 1 < children.length) ? children[i + 1] : const SizedBox.shrink();

      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            SizedBox(width: hGap),
            Expanded(child: right),
          ],
        ),
      );

      if (i + 2 < children.length) {
        rows.add(SizedBox(height: vGap));
      }
    }

    return Column(children: rows);
  }
}

class _BottomActionBar extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool showActions;

  const _BottomActionBar({
    required this.onCancel,
    required this.onSave,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
            const SizedBox(width: 8),
            if (showActions)
              FilledButton(onPressed: onSave, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
