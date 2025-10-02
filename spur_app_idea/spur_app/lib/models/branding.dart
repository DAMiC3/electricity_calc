import 'package:flutter/material.dart';

class Branding {
  final String name;
  final Color primaryColor;
  final Color secondaryColor;

  const Branding({
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
  });

  factory Branding.defaultBranding() => const Branding(
        name: 'Spur',
        primaryColor: Colors.deepPurple,
        secondaryColor: Colors.amber,
      );
}
