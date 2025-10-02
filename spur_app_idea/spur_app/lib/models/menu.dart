class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> dietary; // e.g., ['vegan','gluten-free']
  final List<String> allergens; // e.g., ['nuts']
  final int prepMinutes; // manager-set preparation time per dish

  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.dietary = const [],
    this.allergens = const [],
    this.prepMinutes = 10,
  });
}

class MenuCategory {
  final String id;
  final String name;
  final List<MenuItem> items;

  const MenuCategory({
    required this.id,
    required this.name,
    required this.items,
  });
}
