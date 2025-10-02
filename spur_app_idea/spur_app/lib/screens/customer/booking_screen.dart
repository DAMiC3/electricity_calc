import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../models/booking.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  int partySize = 2;
  DateTime time = DateTime.now().add(const Duration(hours: 1));
  String? notes;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final user = state.currentUser;
    final r = state.selectedRestaurant;
    return Scaffold(
      appBar: AppBar(title: const Text('Book a Table')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (r == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(child: Text('Select a restaurant first (Restaurants tab).')),
                    ],
                  ),
                ),
              Row(children: [
                const Text('Party size:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: partySize,
                  onChanged: (v) => setState(() => partySize = v ?? partySize),
                  items: List.generate(10, (i) => i + 1)
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                ),
              ]),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Time: ${time.toLocal()}'),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    initialDate: DateTime.now(),
                  );
                  if (picked != null && context.mounted) {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(time),
                    );
                    if (t != null) {
                      setState(() {
                        time = DateTime(picked.year, picked.month, picked.day, t.hour, t.minute);
                      });
                    }
                  }
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Notes (allergies, requests)'),
                onSaved: (v) => notes = v?.trim(),
              ),
              const Spacer(),
              FilledButton(
                onPressed: r == null ? null : () {
                  _formKey.currentState!.save();
                  final booking = Booking(
                    id: 'b${state.bookings.length + 1}',
                    restaurantId: r.id,
                    customerName: user?.profile.name ?? 'Guest',
                    time: time,
                    partySize: partySize,
                    notes: notes,
                  );
                  state.bookings.add(booking);
                  state.notifyListeners();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Booked at ${r?.displayName ?? 'restaurant'} for $partySize')),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Confirm Booking'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
