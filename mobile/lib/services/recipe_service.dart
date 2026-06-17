import 'dart:async';
import '../models/recipe.dart';
import '../models/review.dart';
import 'api_service.dart';

class RecipeService {
  final ApiService _apiService = ApiService();
  
  // Simple rate limiting - 15 seconds between requests
  DateTime? _lastRequestTime;
  static const Duration MIN_INTERVAL = Duration(seconds: 15);

  Future<void> _waitIfNeeded() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < MIN_INTERVAL) {
        final waitTime = MIN_INTERVAL - elapsed;
        await Future.delayed(waitTime);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  Future<List<Recipe>> getRecipes() async {
    try {
      await _waitIfNeeded();
      final response = await _apiService.get('/recipes/');
      List<dynamic> results = response['results'] ?? [];
      return results.map((json) => Recipe.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching recipes: $e');
      return [];
    }
  }

  Future<Recipe?> getRecipe(int id) async {
    try {
      await _waitIfNeeded();
      final response = await _apiService.get('/recipes/$id/');
      return Recipe.fromJson(response);
    } catch (e) {
      print('Error fetching recipe: $e');
      return null;
    }
  }

  Future<List<Review>> getReviews(int recipeId) async {
    try {
      await _waitIfNeeded();
      final response = await _apiService.get('/reviews/recipe/$recipeId/');
      final List<dynamic> data = response is List ? response : (response['results'] ?? []);
      return data.map((json) => Review.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching reviews: $e');
      return [];
    }
  }

  Future<List<Category>> getCategories() async {
    try {
      await _waitIfNeeded();
      final response = await _apiService.get('/recipes/categories/');
      List<dynamic> categoriesList = response['results'] ?? [];
      return categoriesList.map((json) => Category.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  Future<bool> addToFavorites(int recipeId) async {
    try {
      await _waitIfNeeded();
      await _apiService.post('/favorites/add/', {'recipe': recipeId});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeFromFavorites(int recipeId) async {
    try {
      await _waitIfNeeded();
      await _apiService.delete('/favorites/remove/$recipeId/');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Recipe>> getFavorites() async {
    try {
      await _waitIfNeeded();
      final response = await _apiService.get('/favorites/');
      List<dynamic> data = response['results'] ?? [];
      final favorites = <Recipe>[];
      for (var item in data) {
        if (item['recipe_details'] != null) {
          favorites.add(Recipe.fromJson(item['recipe_details']));
        }
      }
      return favorites;
    } catch (e) {
      print('Error fetching favorites: $e');
      return [];
    }
  }

  Future<bool> submitReview(int recipeId, int rating, String comment) async {
    try {
      await _waitIfNeeded();
      await _apiService.post('/reviews/recipe/$recipeId/create/', {
        'rating': rating,
        'comment': comment,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> submitRecipe(Map<String, dynamic> recipeData) async {
    try {
      await _waitIfNeeded();
      await _apiService.post('/submissions/create/', recipeData);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isFavorite(int recipeId) async {
    try {
      final favorites = await getFavorites();
      return favorites.any((recipe) => recipe.id == recipeId);
    } catch (e) {
      return false;
    }
  }
}
