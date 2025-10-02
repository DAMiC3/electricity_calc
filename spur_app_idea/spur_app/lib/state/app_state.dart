import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../models/user.dart';
import '../models/geo.dart';
import '../models/booking.dart';
import '../services/location_service.dart';

class AppState extends ChangeNotifier {
  Restaurant? selectedRestaurant;
  final List<Restaurant> allRestaurants;
  final List<CartLine> cart = [];
  final List<Order> orders = [];
  String? preferredLanguage; // captured at selection time
  AuthUser? currentUser;
  final LocationService location = LocationService();
  final List<Booking> bookings = [];
  final Map<String, int> lateCountByRestaurant = {};

  AppState({required this.allRestaurants});

  factory AppState.bootstrap() => AppState(allRestaurants: MockData.restaurants());

  void selectRestaurant(Restaurant r) {
    selectedRestaurant = r;
    preferredLanguage = r.languageSuggestion;
    cart.clear();
    notifyListeners();
  }

  void signIn(UserRole role, UserProfile profile) {
    currentUser = AuthUser(id: 'u-${DateTime.now().millisecondsSinceEpoch}', role: role, profile: profile);
    notifyListeners();
  }

  void signOut() {
    currentUser = null;
    selectedRestaurant = null;
    cart.clear();
    notifyListeners();
  }

  void addToCart(MenuItem item) {
    final existing = cart.where((l) => l.item.id == item.id).toList();
    if (existing.isNotEmpty) {
      existing.first.qty += 1;
    } else {
      cart.add(CartLine(item: item));
    }
    notifyListeners();
  }

  void removeFromCart(String itemId) {
    cart.removeWhere((l) => l.item.id == itemId);
    notifyListeners();
  }

  void updateQty(String itemId, int qty) {
    for (final l in cart) {
      if (l.item.id == itemId) {
        l.qty = qty.clamp(1, 99);
      }
    }
    notifyListeners();
  }

  double get cartTotal => cart.fold(0.0, (s, l) => s + l.lineTotal);

  Order placeOrder({
    required bool delivery,
    required String customerName,
    String? address,
  }) {
    final restaurantId = selectedRestaurant?.id ?? 'unknown';
    final order = Order(
      id: 'o${orders.length + 1}',
      lines: cart.map((e) => CartLine(item: e.item, qty: e.qty)).toList(),
      delivery: delivery,
      restaurantId: restaurantId,
      customerName: customerName,
      address: address,
      customerLanguage: currentUser?.profile.language ?? preferredLanguage,
      customerAllergies: currentUser?.profile.allergies ?? const [],
    );
    orders.insert(0, order);
    cart.clear();
    notifyListeners();
    return order;
  }

  void setOrderStatus(String orderId, OrderStatus status) {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final o = orders[idx];
      o.status = status;
      if (status == OrderStatus.preparing) {
        o.startedPreparingAt = DateTime.now();
        final totalPrep = o.lines.fold<int>(0, (s, l) => s + (l.item.prepMinutes * l.qty));
        o.expectedReadyAt = o.startedPreparingAt!.add(Duration(minutes: totalPrep));
      } else if (status == OrderStatus.completed) {
        o.completedAt = DateTime.now();
        if (o.isLate) {
          lateCountByRestaurant.update(o.restaurantId, (v) => v + 1, ifAbsent: () => 1);
        }
      }
      notifyListeners();
    }
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in context');
    return scope!.notifier!;
  }
}
