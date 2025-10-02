import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../restaurant_picker_screen.dart';
import '../menu_screen.dart';
import '../cart_screen.dart';
import '../orders_screen.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final r = state.selectedRestaurant;
    final title = r == null ? 'Choose Restaurant' : r.branding.name;
    final screens = r == null
        ? [
            RestaurantPickerScreen(onSelected: (rest) => setState(() => state.selectRestaurant(rest))),
          ]
        : const [
            MenuScreen(),
            CartScreen(),
            OrdersScreen(),
          ];
    final labels = r == null ? ['Restaurants'] : ['Menu', 'Cart', 'Orders'];

    return Scaffold(
      appBar: AppBar(
        title: Text('$title • ${labels[_index]}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Back should navigate out (e.g., to Role Selection) if possible
            Navigator.of(context).maybePop();
          },
        ),
        actions: r == null
            ? null
            : [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => RestaurantPickerScreen(
                        onSelected: (rest) {
                          setState(() {
                            state.selectRestaurant(rest);
                            _index = 0; // jump to Menu after switching
                          });
                        },
                      ),
                    ));
                  },
                  icon: const Icon(Icons.storefront),
                  tooltip: 'Change restaurant',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pushNamed('/booking'),
                  icon: const Icon(Icons.event_seat),
                  tooltip: 'Book Table (Dine-in)',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pushNamed('/checkout'),
                  icon: const Icon(Icons.payment),
                  tooltip: 'Checkout',
                )
              ],
      ),
      body: screens[_index.clamp(0, screens.length - 1)],
      bottomNavigationBar: r == null
          ? null
          : NavigationBar(
              selectedIndex: _index.clamp(0, screens.length - 1),
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Menu'),
                NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Cart'),
                NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
              ],
            ),
    );
  }
}
