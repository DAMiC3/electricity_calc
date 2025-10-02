import 'package:flutter/material.dart';
import '../state/app_state.dart';
import 'menu_screen.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final brand = state.selectedRestaurant!.branding;
    final screens = const [MenuScreen(), CartScreen(), OrdersScreen()];
    final titles = ['Menu', 'Cart', 'Orders'];

    return Scaffold(
      appBar: AppBar(
        title: Text('${brand.name} • ${titles[_index]}'),
      ),
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
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

