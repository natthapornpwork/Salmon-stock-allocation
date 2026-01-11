import 'package:equatable/equatable.dart';
import '../../core/types.dart';

class Customer extends Equatable {
  final String customerId;

  /// Stored as satang (฿0.01). Example: 6600 => ฿66.00
  final Money creditSatang;

  const Customer({
    required this.customerId,
    required this.creditSatang,
  });

  @override
  List<Object?> get props => [customerId, creditSatang];
}
