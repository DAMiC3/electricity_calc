import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../models/models.dart';

class ManagerHome extends StatelessWidget {
  const ManagerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed('/manager/new'),
        label: const Text('Add Restaurant'),
        icon: const Icon(Icons.add_business),
      ),
      body: ListView.builder(
        itemCount: state.allRestaurants.length,
        itemBuilder: (context, i) {
          final r = state.allRestaurants[i];
          final late = state.lateCountByRestaurant[r.id] ?? 0;
          return Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: r.branding.primaryColor, child: Text(r.displayName[0])),
              title: Text(r.displayName),
              subtitle: Text('Location: (${r.lat.toStringAsFixed(4)}, ${r.lng.toStringAsFixed(4)})\n'
                  'Late orders: $late'),
              isThreeLine: true,
              onTap: () => Navigator.of(context).pushNamed('/manager/detail', arguments: r.id),
            ),
          );
        },
      ),
    );
  }
}

class NewRestaurantScreen extends StatefulWidget {
  const NewRestaurantScreen({super.key});

  @override
  State<NewRestaurantScreen> createState() => _NewRestaurantScreenState();
}

class _NewRestaurantScreenState extends State<NewRestaurantScreen> {
  final _form = GlobalKey<FormState>();
  String name = '';
  String primaryName = 'Red';
  String secondaryName = 'Blue';
  double? lat;
  double? lng;

  static const Map<String, Color> named = {
    'Red': Colors.red,
    'Blue': Colors.blue,
    'Green': Colors.green,
    'Orange': Colors.orange,
    'Purple': Colors.purple,
    'Teal': Colors.teal,
    'Amber': Colors.amber,
    'Indigo': Colors.indigo,
    'Pink': Colors.pink,
    'Brown': Colors.brown,
    'Grey': Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Restaurant')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                onSaved: (v) => name = v!.trim(),
              ),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: primaryName,
                    decoration: const InputDecoration(labelText: 'Primary color'),
                    items: named.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                    onChanged: (v) => setState(() => primaryName = v ?? primaryName),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: secondaryName,
                    decoration: const InputDecoration(labelText: 'Secondary color'),
                    items: named.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                    onChanged: (v) => setState(() => secondaryName = v ?? secondaryName),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Preview: '),
                  CircleAvatar(backgroundColor: named[primaryName]),
                  const SizedBox(width: 8),
                  CircleAvatar(backgroundColor: named[secondaryName]),
                ],
              ),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'Required' : null,
                    onSaved: (v) => lat = double.tryParse(v ?? ''),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'Required' : null,
                    onSaved: (v) => lng = double.tryParse(v ?? ''),
                  ),
                ),
              ]),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    _form.currentState!.save();
                    final b = Branding(name: name, primaryColor: named[primaryName]!, secondaryColor: named[secondaryName]!);
                    final r = Restaurant(
                      id: 'r${state.allRestaurants.length + 1}',
                      displayName: name,
                      branding: b,
                      languageSuggestion: 'en',
                      lat: lat!,
                      lng: lng!,
                      categories: [],
                    );
                    state.allRestaurants.add(r);
                    state.notifyListeners();
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Create'),
              )
            ],
          ),
        ),
      ),
    );
  }

  
}

class ManagerDetailScreen extends StatelessWidget {
  final String restaurantId;
  const ManagerDetailScreen({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final r = state.allRestaurants.firstWhere((e) => e.id == restaurantId);
    final bookings = state.bookings.where((b) => b.restaurantId == restaurantId).toList();
    final late = state.lateCountByRestaurant[restaurantId] ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(r.displayName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMenuItem(context, state, r),
        icon: const Icon(Icons.add),
        label: const Text('Add Menu Item'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Branding: ${r.branding.name}'),
            Text('Primary: ${r.branding.primaryColor}'),
            Text('Secondary: ${r.branding.secondaryColor}'),
            Text('Location: ${r.lat}, ${r.lng}'),
            const SizedBox(height: 16),
            Text('Performance', style: Theme.of(context).textTheme.titleMedium),
            Text('Late orders: $late'),
            const Divider(height: 32),
            Text('Recent Orders', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: ListView(
                children: state.orders
                    .where((o) => o.restaurantId == restaurantId)
                    .take(6)
                    .map((o) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.receipt_long),
                          title: Text('Order ${o.id} • ${o.status.name}'),
                          subtitle: Text(o.expectedReadyAt == null
                              ? 'Awaiting preparation start'
                              : (o.completedAt == null
                                  ? 'Expected by ${o.expectedReadyAt}'
                                  : (o.isLate ? 'Completed (late)' : 'Completed (on time)'))),
                        ))
                    .toList(),
              ),
            ),
            const Divider(height: 32),
            Text('Bookings (${bookings.length})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: bookings.isEmpty
                  ? const Text('No bookings yet')
                  : ListView.separated(
                      itemCount: bookings.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final b = bookings[i];
                        return ListTile(
                          leading: const Icon(Icons.event_seat),
                          title: Text('${b.customerName} • ${b.partySize} ppl'),
                          subtitle: Text(b.time.toLocal().toString() + (b.notes == null ? '' : '\n${b.notes}')),
                          isThreeLine: b.notes != null,
                        );
                      },
                    ),
            )
          ],
        ),
      ),
    );
  }

  void _showAddMenuItem(BuildContext context, AppState state, Restaurant r) {
    final form = GlobalKey<FormState>();
    String category = '';
    String name = '';
    String desc = '';
    String price = '';
    String allergens = '';
    String dietary = '';
    String prep = '10';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Menu Item'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(decoration: const InputDecoration(labelText: 'Category'), onSaved: (v) => category = v!.trim(), validator: _req),
                TextFormField(decoration: const InputDecoration(labelText: 'Item name'), onSaved: (v) => name = v!.trim(), validator: _req),
                TextFormField(decoration: const InputDecoration(labelText: 'Description'), onSaved: (v) => desc = v!.trim()),
                TextFormField(decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number, onSaved: (v) => price = v!.trim(), validator: _req),
                TextFormField(decoration: const InputDecoration(labelText: 'Allergens (comma-separated)'), onSaved: (v) => allergens = v?.trim() ?? ''),
                TextFormField(decoration: const InputDecoration(labelText: 'Dietary tags (comma-separated)'), onSaved: (v) => dietary = v?.trim() ?? ''),
                TextFormField(decoration: const InputDecoration(labelText: 'Preparation time (minutes)'), keyboardType: TextInputType.number, initialValue: prep, onSaved: (v) => prep = v?.trim() ?? '10'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                form.currentState!.save();
                final priceVal = double.tryParse(price) ?? 0.0;
                final item = MenuItem(
                  id: 'm${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  description: desc,
                  price: priceVal,
                  allergens: allergens.isEmpty ? const [] : allergens.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  dietary: dietary.isEmpty ? const [] : dietary.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  prepMinutes: int.tryParse(prep) ?? 10,
                );
                final existingIndex = r.categories.indexWhere((c) => c.name.toLowerCase() == category.toLowerCase());
                if (existingIndex >= 0) {
                  final cat = r.categories[existingIndex];
                  final newItems = [...cat.items, item];
                  r.categories[existingIndex] = MenuCategory(id: cat.id, name: cat.name, items: newItems);
                } else {
                  r.categories.add(MenuCategory(id: 'c${r.categories.length + 1}', name: category, items: [item]));
                }
                state.notifyListeners();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
}
