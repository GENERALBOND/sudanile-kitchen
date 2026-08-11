import 'package:flutter/material.dart';

IconData categoryIcon(String? iconName, String categoryName) {
  if (iconName != null && iconName.isNotEmpty) {
    final icon = _iconMap[iconName.toLowerCase()];
    if (icon != null) return icon;
  }
  return _iconByCategoryName(categoryName);
}

const Map<String, IconData> _iconMap = {
  'restaurant': Icons.restaurant,
  'restaurant_menu': Icons.restaurant_menu,
  'lunch_dining': Icons.lunch_dining,
  'dinner_dining': Icons.dinner_dining,
  'bakery_dining': Icons.bakery_dining,
  'breakfast_dining': Icons.breakfast_dining,
  'brunch_dining': Icons.brunch_dining,
  'ramen_dining': Icons.ramen_dining,
  'rice_bowl': Icons.rice_bowl,
  'soup_kitchen': Icons.soup_kitchen,
  'set_meal': Icons.set_meal,
  'tapas': Icons.tapas,
  'flatware': Icons.flatware,
  'local_pizza': Icons.local_pizza,
  'kebab_dining': Icons.kebab_dining,
  'icecream': Icons.icecream,
  'cake': Icons.cake,
  'cookie': Icons.cookie,
  'fastfood': Icons.fastfood,
  'egg': Icons.egg,
  'emoji_food_beverage': Icons.emoji_food_beverage,
  'local_cafe': Icons.local_cafe,
  'coffee_maker': Icons.coffee_maker,
  'local_bar': Icons.local_bar,
  'water_drop': Icons.water_drop,
  'eco': Icons.eco,
  'kitchen': Icons.kitchen,
  'microwave': Icons.microwave,
  'countertops': Icons.countertops,
  'outdoor_grill': Icons.outdoor_grill,
};

IconData _iconByCategoryName(String categoryName) {
  final name = categoryName.toLowerCase();
  if (name.contains('main') || name.contains('dish')) {
    return Icons.lunch_dining;
  }
  if (name.contains('stew') || name.contains('curry')) {
    return Icons.soup_kitchen;
  }
  if (name.contains('bread') || name.contains('grain')) {
    return Icons.bakery_dining;
  }
  if (name.contains('soup')) {
    return Icons.kitchen;
  }
  if (name.contains('side')) {
    return Icons.eco;
  }
  if (name.contains('beverage')) {
    return Icons.local_cafe;
  }
  if (name.contains('snack')) {
    return Icons.icecream;
  }
  if (name.contains('dessert')) {
    return Icons.cake;
  }
  return Icons.restaurant_menu;
}
