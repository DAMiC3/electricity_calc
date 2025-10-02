import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../models/order.dart';

class OrderStatusScreen extends StatelessWidget {
  final String orderId;
  const OrderStatusScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final order = state.orders.firstWhere((o) => o.id == orderId);

    return Scaffold(
      appBar: AppBar(title: Text('Order ${order.id}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusRow(order.status),
            const SizedBox(height: 12),
            Text('Items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...order.lines.map((l) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('${l.qty} × ${l.item.name}')),
                    Text('\$${l.lineTotal.toStringAsFixed(2)}'),
                  ],
                )),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total'),
                Text('\$${order.total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const Spacer(),
            Center(
              child: Text(
                order.delivery ? 'Delivery selected' : 'Pickup selected',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(OrderStatus status) {
    final steps = [
      OrderStatus.received,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.completed,
    ];
    return Row(
      children: steps.map((s) {
        final reached = steps.indexOf(s) <= steps.indexOf(status);
        return Expanded(
          child: Row(
            children: [
              Icon(
                reached ? Icons.check_circle : Icons.radio_button_unchecked,
                color: reached ? Colors.green : Colors.grey,
              ),
              if (s != steps.last) const Expanded(child: Divider(thickness: 2)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

