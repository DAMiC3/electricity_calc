import 'package:flutter/material.dart';

import 'models/models.dart';
import 'state/app_state.dart';
import 'screens/restaurant_picker_screen.dart';
import 'screens/home_shell.dart';
import 'screens/checkout_screen.dart';
import 'screens/order_status_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/signin_screen.dart';
import 'models/user.dart';
import 'screens/customer/customer_home.dart';
import 'screens/manager/manager_home.dart';
import 'screens/chef/chef_home.dart';
import 'screens/customer/booking_screen.dart';
import 'screens/customer/restaurant_detail_screen.dart';

void main() {
  runApp(const SpurApp());
}

class SpurApp extends StatefulWidget {
  const SpurApp({super.key});

  @override
  State<SpurApp> createState() => _SpurAppState();
}

class _SpurAppState extends State<SpurApp> {
  final AppState _state = AppState.bootstrap();

  @override
  Widget build(BuildContext context) {
    final brand = _state.selectedRestaurant?.branding ?? Branding.defaultBranding();
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: brand.primaryColor),
      useMaterial3: true,
    );

    return AppStateScope(
      state: _state,
      child: MaterialApp(
        title: 'Spur',
        theme: theme,
        home: const RoleSelectionScreen(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/signin':
              final role = settings.arguments as UserRole? ?? UserRole.customer;
              return MaterialPageRoute(builder: (_) => SignInScreen(role: role));
            case '/customer':
              return MaterialPageRoute(builder: (_) => const CustomerHome());
            case '/manager':
              return MaterialPageRoute(builder: (_) => const ManagerHome());
            case '/manager/new':
              return MaterialPageRoute(builder: (_) => const NewRestaurantScreen());
            case '/manager/detail':
              final id = settings.arguments as String?;
              if (id == null) return null;
              return MaterialPageRoute(builder: (_) => ManagerDetailScreen(restaurantId: id));
            case '/chef':
              return MaterialPageRoute(builder: (_) => const ChefHome());
            case '/booking':
              return MaterialPageRoute(builder: (_) => const BookingScreen());
            case '/restaurant_detail':
              return MaterialPageRoute(builder: (_) => const RestaurantDetailScreen());
            case '/checkout':
              return MaterialPageRoute(builder: (_) => const CheckoutScreen());
            case '/order':
              final id = settings.arguments as String?;
              if (id == null) {
                return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Order not found'))));
              }
              return MaterialPageRoute(builder: (_) => OrderStatusScreen(orderId: id));
          }
          return null;
        },
      ),
    );
  }
}
