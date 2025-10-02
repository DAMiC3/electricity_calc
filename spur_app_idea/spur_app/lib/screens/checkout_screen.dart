import 'dart:async';
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../models/order.dart';
import '../models/geo.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  bool delivery = false;
  String name = '';
  String address = '';
  double? distanceKm;
  int? etaMin;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    _recalcEta(state);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Delivery'),
                subtitle: const Text('Off = Dine-in (table)'),
                value: delivery,
                onChanged: (v) => setState(() => delivery = v),
              ),
              if (delivery && state.selectedRestaurant != null && etaMin != null && distanceKm != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.route, size: 18),
                      const SizedBox(width: 6),
                      Text('Distance: ${distanceKm!.toStringAsFixed(1)} km • ETA: ${etaMin}m'),
                    ],
                  ),
                ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Your name'),
                onSaved: (v) => name = v?.trim() ?? '',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              if (delivery)
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Address'),
                  onSaved: (v) => address = v?.trim() ?? '',
                  validator: (v) => delivery && (v == null || v.trim().isEmpty)
                      ? 'Address required for delivery'
                      : null,
                ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text('Total: \$${state.cartTotal.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        final order = state.placeOrder(
                          delivery: delivery,
                          customerName: name,
                          address: delivery ? address : null,
                        );
                        Navigator.of(context).pushReplacementNamed('/order', arguments: order.id);
                      }
                    },
                    child: const Text('Place Order'),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _simulateOrderProgress(BuildContext context, Order order) {}

  void _recalcEta(AppState state) {
    if (!delivery) {
      distanceKm = null;
      etaMin = null;
      return;
    }
    final r = state.selectedRestaurant;
    if (r == null) return;
    final prof = state.currentUser?.profile;
    final hasCoords = prof?.homeLat != null && prof?.homeLng != null;
    if (!hasCoords) return;
    final pos = LatLng(prof!.homeLat!, prof.homeLng!);
    final rest = LatLng(r.lat, r.lng);
    final d = haversineKm(pos, rest);
    distanceKm = d;
    etaMin = state.location.estimateEtaMinutes(d);
  }
}
