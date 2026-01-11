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

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Search
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search Order ID / Customer ID / Remark',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) =>
                context.read<AllocationBloc>().add(AllocationSearchChanged(v)),
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

          // Filter chips
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

          // List
          Expanded(
            child: BlocBuilder<AllocationBloc, AllocationState>(
              buildWhen: (p, c) =>
                  p.ordersVisible != c.ordersVisible ||
                  p.selectedOrderId != c.selectedOrderId ||
                  p.allocationsByOrderId != c.allocationsByOrderId ||
                  p.lockedOrderIds != c.lockedOrderIds,
              builder: (context, state) {
                final orders = state.ordersVisible;

                return ListView.builder(
                  itemExtent: 74, // smoother for huge lists
                  itemCount: orders.length,
                  itemBuilder: (context, i) {
                    final o = orders[i];
                    final selected = o.orderId == state.selectedOrderId;

                    final alloc = state.allocationsByOrderId[o.orderId];
                    final allocQty = alloc?.totalQty ?? 0;

                    final parent =
                        o.parentOrderId.isEmpty ? o.orderId : o.parentOrderId;
                    final sub = o.hasSubOrder ? o.orderId : '${parent}-001';
                    final locked = state.lockedOrderIds.contains(o.orderId);

                    return Material(
                      color: selected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.08)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () => context
                            .read<AllocationBloc>()
                            .add(AllocationOrderSelected(o.orderId)),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      parent, // ✅ Parent order
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Sub: $sub • ${o.customerId} • ${o.type.name.toUpperCase()} • ${fmt.format(o.createdAt)}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (locked)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(Icons.lock, size: 16),
                                ),
                              const SizedBox(width: 8),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Requested ${qtyToString(o.requestQty)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  Text('Allocated ${qtyToString(allocQty)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
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
