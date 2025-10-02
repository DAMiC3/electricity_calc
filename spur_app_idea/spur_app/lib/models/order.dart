import 'menu.dart';

class CartLine {
  final MenuItem item;
  int qty;
  CartLine({required this.item, this.qty = 1});

  double get lineTotal => item.price * qty;
}

enum OrderStatus { received, preparing, ready, completed, cancelled }

class Order {
  final String id;
  final List<CartLine> lines;
  final bool delivery;
  final String restaurantId;
  final String customerName;
  final String? address;
  final String? customerLanguage;
  final List<String> customerAllergies;
  OrderStatus status;
  final DateTime createdAt;
  DateTime? expectedReadyAt;
  DateTime? startedPreparingAt;
  DateTime? completedAt;

  Order({
    required this.id,
    required this.lines,
    required this.delivery,
    required this.restaurantId,
    required this.customerName,
    this.address,
    this.customerLanguage,
    this.customerAllergies = const [],
    this.status = OrderStatus.received,
    DateTime? createdAt,
    DateTime? expectedReadyAt,
    this.completedAt,
    this.startedPreparingAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        expectedReadyAt = expectedReadyAt;

  double get total => lines.fold(0.0, (s, l) => s + l.lineTotal);

  bool get isLate => expectedReadyAt != null && (completedAt ?? DateTime.now()).isAfter(expectedReadyAt!);
}
