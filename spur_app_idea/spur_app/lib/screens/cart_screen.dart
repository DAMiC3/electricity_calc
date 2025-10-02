import 'package:flutter/material.dart';
import '../state/app_state.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final lines = state.cart;
    return Column(
      children: [
        Expanded(
          child: lines.isEmpty
              ? const Center(child: Text('Your cart is empty'))
              : ListView.separated(
                  itemCount: lines.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final l = lines[i];
                    return ListTile(
                      title: Text(l.item.name),
                      subtitle: Text('\$${l.item.price.toStringAsFixed(2)} each'),
                      leading: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => state.removeFromCart(l.item.id),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () => state.updateQty(l.item.id, l.qty - 1),
                          ),
                          Text(l.qty.toString()),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => state.updateQty(l.item.id, l.qty + 1),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text('Total: \$${state.cartTotal.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              FilledButton(
                onPressed: lines.isEmpty
                    ? null
                    : () => Navigator.of(context).pushNamed('/checkout'),
                child: const Text('Checkout'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

