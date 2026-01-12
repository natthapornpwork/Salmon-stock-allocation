import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/allocation_bloc.dart';
import '../widgets/order_list.dart';
import '../widgets/order_detail.dart';

class AllocationPage extends StatefulWidget {
  const AllocationPage({super.key});

  @override
  State<AllocationPage> createState() => _AllocationPageState();
}

class _AllocationPageState extends State<AllocationPage> {
  bool _detailPopupOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 245),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 235, 125, 82),
        foregroundColor: Colors.white,
        title: const Text('Salmon Stock Allocation'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: () => context
                .read<AllocationBloc>()
                .add(const AllocationLoadRequested()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<AllocationBloc, AllocationState>(
            listenWhen: (p, c) => p.manualSaveNonce != c.manualSaveNonce,
            listener: (context, state) {
              final msg = state.manualSaveMessage;
              if (msg == null) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(msg),
                backgroundColor: Colors.lightGreen,
              ));
            },
          ),
          BlocListener<AllocationBloc, AllocationState>(
            listenWhen: (p, c) => p.selectedOrderId != c.selectedOrderId,
            listener: (context, state) async {
              final id = state.selectedOrderId;
              if (id == null) return;
              if (_detailPopupOpen) return;

              _detailPopupOpen = true;
              final wide = MediaQuery.of(context).size.width >= 900;

              if (wide) {
                await _showDetailDialog(context);
              } else {
                await _showDetailBottomSheet(context);
              }

              _detailPopupOpen = false;

              if (!mounted) return;
              // ignore: use_build_context_synchronously
              context
                  .read<AllocationBloc>()
                  .add(const AllocationOrderDeselected());
            },
          ),
        ],
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

            return const OrderListPanel();
          },
        ),
      ),
    );
  }

  Future<void> _showDetailDialog(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxW = min(mq.size.width * 0.92, 980.0);
    final maxH = mq.size.height * 0.90;
    const radius = 12.0;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Order details',
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const Expanded(
                    child: ColoredBox(
                      color: Color(0xFFF2F3F5),
                      child: OrderDetailPanel(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDetailBottomSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF2F3F5),
      builder: (ctx) {
        final h = MediaQuery.of(ctx).size.height;
        return SizedBox(
          height: h * 0.92,
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Order details',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const Expanded(child: OrderDetailPanel()),
            ],
          ),
        );
      },
    );
  }
}
