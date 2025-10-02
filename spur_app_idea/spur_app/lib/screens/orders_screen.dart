import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../models/order.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final orders = state.orders;
    if (orders.isEmpty) {
      return const Center(child: Text('No orders yet'));
    }
    return ListView.separated(
      itemCount: orders.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final o = orders[i];
        return ListTile(
          title: Text('Order ${o.id} • ${_statusLabel(o.status)}'),
          subtitle: Text('${o.lines.length} items • \$${o.total.toStringAsFixed(2)}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).pushNamed('/order', arguments: o.id),
        );
      },
    );
  }

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.received:
        return 'Received';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

