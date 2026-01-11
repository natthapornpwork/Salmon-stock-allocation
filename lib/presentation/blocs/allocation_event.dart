part of 'allocation_bloc.dart';

sealed class AllocationEvent extends Equatable {
  const AllocationEvent();

  @override
  List<Object?> get props => [];
}

class AllocationLoadRequested extends AllocationEvent {
  const AllocationLoadRequested();
}

class AllocationSearchChanged extends AllocationEvent {
  final String query;
  const AllocationSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class AllocationJumpToOrderRequested extends AllocationEvent {
  final String orderId;
  const AllocationJumpToOrderRequested(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class AllocationOrderSelected extends AllocationEvent {
  final String orderId;
  const AllocationOrderSelected(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class AllocationManualAllocationSubmitted extends AllocationEvent {
  final String orderId;
  final List<AllocationLine> lines;

  const AllocationManualAllocationSubmitted({
    required this.orderId,
    required this.lines,
  });

  @override
  List<Object?> get props => [orderId, lines];
}

class AllocationTypeFilterChanged extends AllocationEvent {
  final OrderType? filterType; // null = ALL
  const AllocationTypeFilterChanged(this.filterType);

  @override
  List<Object?> get props => [filterType];
}

class AllocationReAutoRequested extends AllocationEvent {
  const AllocationReAutoRequested();
}

class AllocationOrderLockToggled extends AllocationEvent {
  final String orderId;
  final bool locked;
  const AllocationOrderLockToggled(
      {required this.orderId, required this.locked});

  @override
  List<Object?> get props => [orderId, locked];
}
