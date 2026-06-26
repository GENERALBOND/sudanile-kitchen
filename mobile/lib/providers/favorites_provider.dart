import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final RecipeService _recipeService = RecipeService();
  List<Recipe> _favorites = [];
  Set<int> _favoriteIds = {};
  bool _isLoading = false;

  List<Recipe> get favorites => _favorites;
  Set<int> get favoriteIds => _favoriteIds;
  bool get isLoading => _isLoading;
  int get count => _favorites.length;

  Future<void> loadFavorites() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _favorites = await _recipeService.getFavorites();
      _favoriteIds = _favorites.map((r) => r.id).toSet();
    } catch (e) {
      print('Error loading favorites: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleFavorite(Recipe recipe) async {
    final isFavorite = _favoriteIds.contains(recipe.id);
    
    if (isFavorite) {
      final success = await _recipeService.removeFromFavorites(recipe.id);
      if (success) {
        _favorites.removeWhere((r) => r.id == recipe.id);
        _favoriteIds.remove(recipe.id);
        notifyListeners();
      }
    } else {
      final success = await _recipeService.addToFavorites(recipe.id);
      if (success) {
        _favorites.add(recipe);
        _favoriteIds.add(recipe.id);
        notifyListeners();
      }
    }
  }

  bool isFavorite(int recipeId) {
    return _favoriteIds.contains(recipeId);
  }

  Future<void> refreshFavorites() async {
    await loadFavorites();
  }

  // Remove from favorites by recipe ID
  Future<void> removeFavorite(int recipeId) async {
    final recipe = _favorites.firstWhere((r) => r.id == recipeId, orElse: () => throw Exception());
    await toggleFavorite(recipe);
  }
}
