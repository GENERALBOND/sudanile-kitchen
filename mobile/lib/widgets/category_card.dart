import 'package:flutter/material.dart';
import '../models/recipe.dart';

class CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;
  
  const CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                _getCategoryIcon(category.name),
                size: 30,
                color: Colors.orange.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('main') || name.contains('dish')) {
      return Icons.lunch_dining;
    } else if (name.contains('stew') || name.contains('soup')) {
      return Icons.soup_kitchen;
    } else if (name.contains('bread') || name.contains('grain') || name.contains('pastry')) {
      return Icons.bakery_dining;
    } else if (name.contains('side')) {
      return Icons.eco;
    } else if (name.contains('beverage') || name.contains('drink')) {
      return Icons.local_cafe;
    } else if (name.contains('snack')) {
      return Icons.icecream;
    } else if (name.contains('dessert')) {
      return Icons.cake;
    }
    return Icons.restaurant_menu;
  }
}
