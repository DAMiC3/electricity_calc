import 'package:flutter/material.dart';
import '../../state/app_state.dart';

class RestaurantDetailScreen extends StatelessWidget {
  const RestaurantDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final r = state.selectedRestaurant!;
    return Scaffold(
      appBar: AppBar(
        title: Text(r.displayName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(backgroundColor: r.branding.primaryColor),
              const SizedBox(width: 8),
              CircleAvatar(backgroundColor: r.branding.secondaryColor),
            ]),
            const SizedBox(height: 12),
            Text('Language: ${r.languageSuggestion ?? '-'}'),
            Text('Location: (${r.lat.toStringAsFixed(4)}, ${r.lng.toStringAsFixed(4)})'),
            const Divider(height: 24),
            Text('Menu preview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: r.categories.expand((c) => c.items.take(2).map((i) => ListTile(
                      title: Text(i.name),
                      subtitle: Text('\$${i.price.toStringAsFixed(2)} • ~${i.prepMinutes}m'),
                    ))).toList(),
              ),
            ),
            FilledButton(
              // Return to the previous CustomerHome instead of stacking another
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Start Ordering'),
            )
          ],
        ),
      ),
    );
  }
}
