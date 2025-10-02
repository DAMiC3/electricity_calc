import 'branding.dart';
import 'menu.dart';

class Restaurant {
  final String id;
  final String displayName;
  final Branding branding;
  final List<MenuCategory> categories;
  final String? languageSuggestion; // e.g., "en", "es"
  final double lat;
  final double lng;

  const Restaurant({
    required this.id,
    required this.displayName,
    required this.branding,
    required this.categories,
    this.languageSuggestion,
    required this.lat,
    required this.lng,
  });
}
