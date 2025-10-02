import 'package:flutter/material.dart';
import '../models/user.dart';
import '../state/app_state.dart';
import '../models/geo.dart';

class SignInScreen extends StatefulWidget {
  final UserRole role;
  const SignInScreen({super.key, required this.role});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String? language;
  String? address;
  double? lat;
  double? lng;
  final List<String> _allergens = const [
    'gluten', 'dairy', 'eggs', 'fish', 'shellfish', 'peanuts', 'tree nuts', 'soy', 'sesame'
  ];
  final Set<String> _selectedAllergies = {};

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign in • ${_roleLabel(widget.role)}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                onSaved: (v) => name = v!.trim(),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Preferred language (e.g., en, es)'),
                onSaved: (v) => language = v?.trim(),
              ),
              if (widget.role == UserRole.customer) ...[
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Home address (optional)'),
                  onSaved: (v) => address = v?.trim(),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Allergies (optional)', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: _allergens
                      .map((a) => FilterChip(
                            label: Text(a),
                            selected: _selectedAllergies.contains(a),
                            onSelected: (sel) => setState(() {
                              if (sel) _selectedAllergies.add(a); else _selectedAllergies.remove(a);
                            }),
                          ))
                      .toList(),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'Lat (optional)'),
                        keyboardType: TextInputType.number,
                        onSaved: (v) => lat = double.tryParse(v ?? ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'Lng (optional)'),
                        keyboardType: TextInputType.number,
                        onSaved: (v) => lng = double.tryParse(v ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final pos = await state.location.getCurrentPosition();
                    setState(() {
                      lat = pos.lat;
                      lng = pos.lng;
                    });
                  },
                  child: Text('Use GPS${lat != null ? ' (set)' : ''}'),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    final profile = UserProfile(
                      name: name,
                      language: language,
                      homeAddress: address,
                      homeLat: lat,
                      homeLng: lng,
                      allergies: _selectedAllergies.toList(),
                    );
                    state.signIn(widget.role, profile);
                    // Navigate into the selected role's home; allow back to role selection
                    switch (widget.role) {
                      case UserRole.customer:
                        Navigator.of(context).pushReplacementNamed('/customer');
                        break;
                      case UserRole.manager:
                        Navigator.of(context).pushReplacementNamed('/manager');
                        break;
                      case UserRole.staff:
                        Navigator.of(context).pushReplacementNamed('/chef');
                        break;
                    }
                  }
                },
                child: const Text('Continue'),
              )
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(UserRole r) {
    switch (r) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.manager:
        return 'Manager';
      case UserRole.staff:
        return 'Chef/Waiter';
    }
  }
}
