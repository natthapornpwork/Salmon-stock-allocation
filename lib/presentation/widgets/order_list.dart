import 'package:allocation_app/data/models/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/types.dart';
import '../blocs/allocation_bloc.dart';

class OrderListPanel extends StatelessWidget {
  const OrderListPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('y-MM-dd HH:mm');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search Order ID / Customer ID / Remark',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => context
                    .read<AllocationBloc>()
                    .add(AllocationSearchChanged(v)),
                onSubmitted: (v) {
                  final t = v.trim();
                  if (t.isNotEmpty) {
                    context
                        .read<AllocationBloc>()
                        .add(AllocationJumpToOrderRequested(t));
                  }
                },
              ),
              const SizedBox(height: 8),
              BlocBuilder<AllocationBloc, AllocationState>(
                buildWhen: (p, c) => p.filterType != c.filterType,
                builder: (context, state) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('ALL'),
                          selected: state.filterType == null,
                          onSelected: (_) => context.read<AllocationBloc>().add(
                                const AllocationTypeFilterChanged(null),
                              ),
                        ),
                        _TypeChip(
                            type: OrderType.emergency,
                            selected: state.filterType == OrderType.emergency),
                        _TypeChip(
                            type: OrderType.claim,
                            selected: state.filterType == OrderType.claim),
                        _TypeChip(
                            type: OrderType.overdue,
                            selected: state.filterType == OrderType.overdue),
                        _TypeChip(
                            type: OrderType.daily,
                            selected: state.filterType == OrderType.daily),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: BlocBuilder<AllocationBloc, AllocationState>(
                  buildWhen: (p, c) =>
                      p.ordersVisible != c.ordersVisible ||
                      p.selectedOrderId != c.selectedOrderId ||
                      p.allocationsByOrderId != c.allocationsByOrderId ||
                      p.pinnedOrderIds != c.pinnedOrderIds,
                  builder: (context, state) {
                    final orders = state.ordersVisible;

                    return ListView.builder(
                      itemExtent: 80,
                      itemCount: orders.length,
                      itemBuilder: (context, i) {
                        final o = orders[i];
                        final selected = o.orderId == state.selectedOrderId;

                        final alloc = state.allocationsByOrderId[o.orderId];
                        final allocQty = alloc?.totalQty ?? 0;

                        final parent = o.parentOrderId.isEmpty
                            ? o.orderId
                            : o.parentOrderId;
                        final sub = o.hasSubOrder ? o.orderId : '$parent-001';

                        return Material(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.08)
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (state.selectedOrderId == o.orderId) {
                                context
                                    .read<AllocationBloc>()
                                    .add(const AllocationOrderDeselected());
                                Future.microtask(() => context
                                    .read<AllocationBloc>()
                                    .add(AllocationOrderSelected(o.orderId)));
                              } else {
                                context
                                    .read<AllocationBloc>()
                                    .add(AllocationOrderSelected(o.orderId));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                      width: 6, color: _typeColor(o.type)),
                                  bottom: BorderSide(
                                      width: 0.5,
                                      color: Theme.of(context).dividerColor),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          parent,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Sub: $sub • ${o.customerId} • ${o.type.name.toUpperCase()} • ${fmt.format(o.createdAt)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _QtyPill.req(value: o.requestQty),
                                      const SizedBox(width: 12),
                                      _QtyPill.alloc(
                                          value: allocQty,
                                          requested: o.requestQty),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final OrderType type;
  final bool selected;
  const _TypeChip({required this.type, required this.selected});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(type.name.toUpperCase()),
      selected: selected,
      avatar: CircleAvatar(
        radius: 6,
        backgroundColor: _typeColor(type),
      ),
      onSelected: (_) =>
          context.read<AllocationBloc>().add(AllocationTypeFilterChanged(type)),
    );
  }
}

Color _typeColor(OrderType t) => switch (t) {
      OrderType.emergency => Colors.red,
      OrderType.claim => Colors.orange,
      OrderType.overdue => Colors.purple,
      OrderType.daily => Colors.green,
    };

class _QtyPill extends StatelessWidget {
  final String label;
  final int value;
  final int? requested;

  const _QtyPill._({
    required this.label,
    required this.value,
    this.requested,
  });

  factory _QtyPill.req({required int value}) =>
      _QtyPill._(label: 'Requested', value: value);

  factory _QtyPill.alloc({required int value, required int requested}) =>
      _QtyPill._(label: 'Allocated', value: value, requested: requested);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color accent;
    if (label == 'Allocated') {
      if (value <= 0) {
        accent = cs.outline;
      } else if (requested != null && value >= requested!) {
        accent = Colors.green;
      } else {
        accent = Colors.orange;
      }
    } else {
      accent = Colors.blueAccent;
    }

    final bg = accent.withOpacity(0.60);
    final border = accent.withOpacity(0.60);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: 8),
          Text(
            qtyToString(value),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
