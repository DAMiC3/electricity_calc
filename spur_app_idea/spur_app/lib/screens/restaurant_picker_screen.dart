import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../models/models.dart';
import '../models/geo.dart';
import '../services/location_service.dart';

class RestaurantPickerScreen extends StatelessWidget {
  final void Function(Restaurant) onSelected;
  const RestaurantPickerScreen({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final user = state.currentUser;
    final customerPos = (user?.profile.homeLat != null && user?.profile.homeLng != null)
        ? LatLng(user!.profile.homeLat!, user.profile.homeLng!)
        : null;
    final nearest = (customerPos == null) ? null : _nearest(state, customerPos);

    return Scaffold(
      appBar: AppBar(title: const Text('Select a Restaurant'), actions: [
        IconButton(
          tooltip: 'Use nearest',
          onPressed: () async {
            final pos = await state.location.getCurrentPosition(fallback: customerPos);
            final nearest = _nearest(state, pos);
            if (nearest != null) {
              onSelected(nearest);
              state.selectRestaurant(nearest);
              // Close picker and return to caller (e.g., CustomerHome)
              // ignore: use_build_context_synchronously
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.my_location),
        )
      ]),
      body: Column(
        children: [
          if (nearest != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(Icons.place, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Nearest: ${nearest.displayName}')),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
        itemCount: state.allRestaurants.length,
        itemBuilder: (context, index) {
          final r = state.allRestaurants[index];
          final distance = customerPos == null
              ? null
              : haversineKm(customerPos, LatLng(r.lat, r.lng));
          final eta = distance == null ? null : state.location.estimateEtaMinutes(distance);
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: r.branding.primaryColor,
                child: Text(r.displayName.substring(0, 1)),
              ),
              title: Text(r.displayName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.languageSuggestion != null)
                    Text('Suggested language: ${r.languageSuggestion}')
                        .copyWithStyle(context, Colors.grey),
                  if (distance != null)
                    Text('Distance: ${distance.toStringAsFixed(1)} km • ETA: ${eta}m')
                        .copyWithStyle(context, Colors.grey),
                ],
              ),
              onTap: () {
                onSelected(r);
                state.selectRestaurant(r);
                Navigator.of(context).pop();
              },
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

Restaurant? _nearest(AppState state, LatLng pos) {
  double best = double.infinity;
  Restaurant? pick;
  for (final r in state.allRestaurants) {
    final d = haversineKm(pos, LatLng(r.lat, r.lng));
    if (d < best) {
      best = d;
      pick = r;
    }
  }
  return pick;
}

extension _TextHelpers on Text {
  Widget copyWithStyle(BuildContext context, Color color) => DefaultTextStyle(
        style: DefaultTextStyle.of(context).style.copyWith(color: color),
        child: this,
      );
}
