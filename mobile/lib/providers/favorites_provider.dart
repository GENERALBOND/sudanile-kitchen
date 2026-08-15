import 'dart:developer';
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
      log('Error loading favorites: $e');
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

  /// Optimistically removes a favorite immediately (required by Dismissible,
  /// which expects the item to leave the tree when dismissed) and reverts if
  /// the API call fails. Returns whether the removal succeeded.
  Future<bool> removeFavorite(Recipe recipe) async {
    final lengthBefore = _favorites.length;
    _favorites.removeWhere((r) => r.id == recipe.id);
    final removed = lengthBefore - _favorites.length;
    _favoriteIds.remove(recipe.id);
    notifyListeners();

    final success = await _recipeService.removeFromFavorites(recipe.id);
    if (!success && removed > 0) {
      _favorites.add(recipe);
      _favoriteIds.add(recipe.id);
      notifyListeners();
    }
    return success;
  }

  /// Clears all cached favorites (e.g. on sign-out so the previous account's
  /// data never leaks into the next session).
  void clear() {
    _favorites = [];
    _favoriteIds = {};
    notifyListeners();
  }

  Future<void> refreshFavorites() async {
    await loadFavorites();
  }
}
