import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/types.dart';
import '../blocs/allocation_bloc.dart';
import '../widgets/order_list.dart';
import '../widgets/order_detail.dart';

class AllocationPage extends StatelessWidget {
  const AllocationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Salmon Stock Allocation'),
          actions: [
            IconButton(
              tooltip: 'Reload',
              onPressed: () => context
                  .read<AllocationBloc>()
                  .add(const AllocationLoadRequested()),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Re-run Auto (keep manual locks)',
              onPressed: () => context
                  .read<AllocationBloc>()
                  .add(const AllocationReAutoRequested()),
              icon: const Icon(Icons.auto_fix_high),
            ),
          ],
        ),
        body: BlocListener<AllocationBloc, AllocationState>(
          listenWhen: (p, c) => p.manualSaveNonce != c.manualSaveNonce,
          listener: (context, state) {
            final msg = state.manualSaveMessage;
            if (msg == null) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          },
          child: BlocBuilder<AllocationBloc, AllocationState>(
            buildWhen: (p, c) =>
                p.status != c.status || p.errorMessage != c.errorMessage,
            builder: (context, state) {
              if (state.status == AllocationStatus.loading ||
                  state.status == AllocationStatus.runningAuto) {
                final msg = state.status == AllocationStatus.loading
                    ? 'Loading mock data...'
                    : 'Auto allocating (gigaton mode)...';
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(msg),
                    ],
                  ),
                );
              }

              if (state.status == AllocationStatus.failure) {
                return Center(
                  child: Text('Failed: ${state.errorMessage}'),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;

                  if (!wide) {
                    return _MobileLayout();
                  }

                  return Row(
                    children: [
                      SizedBox(
                        width: (constraints.maxWidth * 0.40),
                        child: const OrderListPanel(),
                      ),
                      const VerticalDivider(width: 1),
                      const Expanded(
                        child: OrderDetailPanel(),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ));
  }
}

class _MobileLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const OrderListPanel();
  }
}
