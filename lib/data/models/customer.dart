import 'package:equatable/equatable.dart';
import '../../core/types.dart';

class Customer extends Equatable {
  final String customerId;
  final Money creditSatang;

  const Customer({
    required this.customerId,
    required this.creditSatang,
  });

  @override
  List<Object?> get props => [customerId, creditSatang];
}
