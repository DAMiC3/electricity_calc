import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../models/models.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final r = state.selectedRestaurant!;
    final customerAllergies = state.currentUser?.profile.allergies ?? const <String>[];

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: r.categories.length,
      itemBuilder: (context, i) {
        final c = r.categories[i];
        return _CategorySection(category: c, customerAllergies: customerAllergies);
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  final MenuCategory category;
  final List<String> customerAllergies;
  const _CategorySection({required this.category, required this.customerAllergies});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(category.name, style: Theme.of(context).textTheme.titleLarge),
        ),
        ...category.items.map((m) => _MenuCard(item: m, customerAllergies: customerAllergies)).toList(),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuItem item;
  final List<String> customerAllergies;
  const _MenuCard({required this.item, required this.customerAllergies});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final hasAllergy = item.allergens.any((a) => customerAllergies.contains(a));
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: hasAllergy ? Colors.red.withOpacity(0.07) : null,
      child: ListTile(
        title: Text(item.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.description),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: -8, children: [
              ...item.dietary.map((d) => _chip(context, d, Colors.green)),
              ...item.allergens.map((a) => _chip(context, a, Colors.redAccent)),
              if (hasAllergy) _chip(context, 'Contains your allergens', Colors.red),
            ]),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('\$${item.price.toStringAsFixed(2)}'),
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: () => state.addToCart(item),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color.withOpacity(0.85),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}
