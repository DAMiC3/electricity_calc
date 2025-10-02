class Booking {
  final String id;
  final String restaurantId;
  final String customerName;
  final DateTime time;
  final int partySize;
  final String? notes;

  const Booking({
    required this.id,
    required this.restaurantId,
    required this.customerName,
    required this.time,
    required this.partySize,
    this.notes,
  });
}
