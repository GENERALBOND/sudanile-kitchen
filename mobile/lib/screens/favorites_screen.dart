import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../services/auth_service.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';
import 'login_screen.dart';

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
              const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No favorites yet', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              const Text('Sign in to save your favorite recipes', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
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
        backgroundColor: Colors.orange,
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
                  const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No favorites yet', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Start saving recipes you love!', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
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
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    favProvider.toggleFavorite(recipe);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${recipe.title} removed from favorites')),
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
