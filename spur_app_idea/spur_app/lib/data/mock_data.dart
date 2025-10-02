import '../models/models.dart';
import 'package:flutter/material.dart';

class MockData {
  static List<Restaurant> restaurants() {
    final cafeBrand = Branding(
      name: 'Cafe Aurora',
      primaryColor: Colors.teal,
      secondaryColor: Colors.orange,
    );
    final grillBrand = Branding(
      name: 'Urban Grill',
      primaryColor: Colors.redAccent,
      secondaryColor: Colors.grey,
    );

    final cafe = Restaurant(
      id: 'r1',
      displayName: 'Cafe Aurora',
      branding: cafeBrand,
      languageSuggestion: 'en',
      lat: -33.9249, // Cape Town approx
      lng: 18.4241,
      categories: [
        MenuCategory(
          id: 'c1',
          name: 'Coffee & Tea',
          items: [
            MenuItem(
              id: 'm1',
              name: 'Cappuccino',
              description: 'Double shot with steamed milk foam',
              price: 3.90,
              prepMinutes: 4,
              dietary: ['vegetarian'],
            ),
            MenuItem(
              id: 'm2',
              name: 'Matcha Latte',
              description: 'Ceremonial grade matcha with milk',
              price: 4.50,
              prepMinutes: 5,
              dietary: ['vegetarian'],
            ),
          ],
        ),
        MenuCategory(
          id: 'c2',
          name: 'Pastries',
          items: [
            MenuItem(
              id: 'm3',
              name: 'Almond Croissant',
              description: 'Buttery croissant with almond filling',
              price: 3.20,
              prepMinutes: 8,
              allergens: ['nuts', 'gluten'],
            ),
            MenuItem(
              id: 'm4',
              name: 'Blueberry Muffin',
              description: 'Fresh blueberries and crumb topping',
              price: 2.80,
              prepMinutes: 6,
              allergens: ['gluten'],
            ),
          ],
        ),
      ],
    );

    final grill = Restaurant(
      id: 'r2',
      displayName: 'Urban Grill',
      branding: grillBrand,
      languageSuggestion: 'es',
      lat: -26.2041, // Johannesburg approx
      lng: 28.0473,
      categories: [
        MenuCategory(
          id: 'c3',
          name: 'Burgers',
          items: [
            MenuItem(
              id: 'm5',
              name: 'Classic Burger',
              description: 'Beef patty, cheddar, lettuce, tomato',
              price: 8.90,
              prepMinutes: 15,
              allergens: ['gluten', 'dairy'],
            ),
            MenuItem(
              id: 'm6',
              name: 'Veggie Burger',
              description: 'Grilled veggie patty with avocado',
              price: 8.50,
              prepMinutes: 14,
              dietary: ['vegetarian'],
            ),
          ],
        ),
        MenuCategory(
          id: 'c4',
          name: 'Sides',
          items: [
            MenuItem(
              id: 'm7',
              name: 'Fries',
              description: 'Crispy golden fries',
              price: 2.90,
              prepMinutes: 7,
              dietary: ['vegan', 'gluten-free'],
            ),
            MenuItem(
              id: 'm8',
              name: 'Onion Rings',
              description: 'Beer-battered rings',
              price: 3.20,
              prepMinutes: 9,
              allergens: ['gluten'],
            ),
          ],
        ),
      ],
    );

    return [cafe, grill];
  }
}
