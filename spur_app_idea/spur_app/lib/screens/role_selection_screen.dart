import 'package:flutter/material.dart';
import '../models/user.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Role')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _roleButton(context, 'Customer', UserRole.customer),
            const SizedBox(height: 12),
            _roleButton(context, 'Manager', UserRole.manager),
            const SizedBox(height: 12),
            _roleButton(context, 'Chef/Waiter', UserRole.staff),
          ],
        ),
      ),
    );
  }

  Widget _roleButton(BuildContext context, String label, UserRole role) {
    return FilledButton(
      onPressed: () => Navigator.of(context).pushNamed('/signin', arguments: role),
      child: Text(label),
    );
  }
}

