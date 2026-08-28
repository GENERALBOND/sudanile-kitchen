import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../services/auth_service.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';
import 'login_screen.dart';
import 'search_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    if (!authService.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Favorites')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border,
                  size: 80,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              const Text('No favorites yet', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text('Sign in to save your favorite recipes',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness ==
                          Brightness.dark
                      ? Colors.orange.shade800
                      : Colors.orange,
                ),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<FavoritesProvider>(context, listen: false).refreshFavorites();
            },
          ),
        ],
      ),
      body: Consumer<FavoritesProvider>(
        builder: (context, favProvider, child) {
          if (favProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (favProvider.favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border,
                      size: 80,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  const Text('No favorites yet', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Start saving recipes you love!',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness ==
                          Brightness.dark
                      ? Colors.orange.shade800
                      : Colors.orange,
                ),
                child: const Text('Browse Recipes'),
                  ),
                ],
              ),
            );
          }
          
          return RefreshIndicator(
            onRefresh: () => favProvider.refreshFavorites(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: favProvider.favorites.length,
              itemBuilder: (context, index) {
                final recipe = favProvider.favorites[index];
                return Dismissible(
                  key: Key(recipe.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.red.shade800
                        : Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    final success = await favProvider.removeFavorite(recipe);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? '${recipe.title} removed from favorites'
                            : 'Could not remove ${recipe.title}. Please try again.'),
                      ),
                    );
                  },
                  child: RecipeCard(
                    recipe: recipe,
                    horizontal: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecipeDetailScreen(recipe: recipe),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
