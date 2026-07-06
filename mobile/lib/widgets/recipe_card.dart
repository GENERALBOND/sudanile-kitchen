import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../models/recipe.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final bool horizontal;
  
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    // Preload image when widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty) {
        precacheImage(NetworkImage(recipe.imageUrl!), context);
      }
    });

    if (horizontal) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.orange.shade200,
                  child: const Icon(
                    Icons.restaurant,
                    size: 40,
                    color: Colors.orange,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          RatingBarIndicator(
                            rating: recipe.averageRating,
                            itemBuilder: (context, _) => const Icon(Icons.star, size: 14, color: Colors.amber),
                            itemCount: 5,
                            itemSize: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${recipe.totalReviews})',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            recipe.totalTimeDisplay,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.people, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.servings}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Vertical card
    return Card(
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Container(
                  height: 130,
                  width: double.infinity,
                  color: Colors.orange.shade200,
                  child: const Icon(
                    Icons.restaurant,
                    size: 50,
                    color: Colors.orange,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RatingBarIndicator(
                          rating: recipe.averageRating,
                          itemBuilder: (context, _) => const Icon(Icons.star, size: 12, color: Colors.amber),
                          itemCount: 5,
                          itemSize: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${recipe.totalReviews})',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          recipe.totalTimeDisplay,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
