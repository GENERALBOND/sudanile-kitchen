import 'dart:async';
import '../models/recipe.dart';
import '../models/review.dart';
import 'api_service.dart';

class RecipeService {
  final ApiService _apiService = ApiService();
  
  // Cache for recipes
  List<Recipe> _cachedRecipes = [];
  List<Category> _cachedCategories = [];
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  Future<List<Recipe>> getRecipes({
    String? category,
    String? search,
    String? ordering,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    try {
      Map<String, String> queryParams = {};
      if (category != null) queryParams['category'] = category;
      if (search != null) queryParams['search'] = search;
      if (ordering != null) queryParams['ordering'] = ordering;
      queryParams['page'] = page.toString();
      
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final response = await _apiService.get('/recipes/?$queryString');
      
      List<dynamic> results;
      if (response['results'] != null) {
        results = response['results'];
      } else if (response is List) {
        results = response;
      } else {
        results = [];
      }
      
      final recipes = results.map((json) => Recipe.fromJson(json)).toList();
      
      // Cache the first page
      if (page == 1 && !forceRefresh) {
        _cachedRecipes = recipes;
        _lastFetchTime = DateTime.now();
      }
      
      return recipes;
    } catch (e) {
      print('❌ Error fetching recipes: $e');
      return [];
    }
  }

  Future<Recipe?> getRecipe(int id) async {
    // Check cache first
    if (_cachedRecipes.isNotEmpty) {
      try {
        final cached = _cachedRecipes.firstWhere((r) => r.id == id);
        return cached;
      } catch (e) {
        // Not in cache, fetch from API
      }
    }
    
    try {
      final response = await _apiService.get('/recipes/$id/');
      return Recipe.fromJson(response);
    } catch (e) {
      print('❌ Error fetching recipe: $e');
      return null;
    }
  }

  Future<List<Review>> getReviews(int recipeId) async {
    try {
      final response = await _apiService.get('/reviews/recipe/$recipeId/');
      final List<dynamic> data = response is List ? response : (response['results'] ?? []);
      return data.map((json) => Review.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error fetching reviews: $e');
      return [];
    }
  }

  Future<List<Category>> getCategories({bool forceRefresh = false}) async {
    // Return cached data if valid
    if (!forceRefresh && 
        _cachedCategories.isNotEmpty && 
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      print('📦 Using cached categories');
      return _cachedCategories;
    }
    
    try {
      final response = await _apiService.get('/recipes/categories/');
      
      List<dynamic> categoriesList;
      if (response['results'] != null) {
        categoriesList = response['results'];
      } else if (response is List) {
        categoriesList = response;
      } else {
        categoriesList = [];
      }
      
      _cachedCategories = categoriesList.map((json) => Category.fromJson(json)).toList();
      print('✅ Categories loaded: ${_cachedCategories.length}');
      return _cachedCategories;
    } catch (e) {
      print('❌ Error fetching categories: $e');
      return _cachedCategories.isNotEmpty ? _cachedCategories : [];
    }
  }

  Future<bool> addToFavorites(int recipeId) async {
    try {
      await _apiService.post('/favorites/add/', {'recipe': recipeId});
      return true;
    } catch (e) {
      print('❌ Error adding to favorites: $e');
      return false;
    }
  }

  Future<bool> removeFromFavorites(int recipeId) async {
    try {
      await _apiService.delete('/favorites/remove/$recipeId/');
      return true;
    } catch (e) {
      print('❌ Error removing from favorites: $e');
      return false;
    }
  }

  Future<bool> isFavorite(int recipeId) async {
    try {
      final favorites = await getFavorites();
      return favorites.any((recipe) => recipe.id == recipeId);
    } catch (e) {
      print('❌ Error checking favorite: $e');
      return false;
    }
  }

  Future<List<Recipe>> getFavorites() async {
    try {
      final response = await _apiService.get('/favorites/');
      
      List<dynamic> data;
      if (response is Map && response['results'] != null) {
        data = response['results'];
      } else if (response is List) {
        data = response;
      } else {
        data = [];
      }
      
      final favorites = <Recipe>[];
      for (var item in data) {
        if (item['recipe_details'] != null) {
          favorites.add(Recipe.fromJson(item['recipe_details']));
        }
      }
      
      return favorites;
    } catch (e) {
      print('❌ Error fetching favorites: $e');
      return [];
    }
  }

  Future<bool> submitReview(int recipeId, int rating, String comment) async {
    try {
      await _apiService.post('/reviews/recipe/$recipeId/create/', {
        'rating': rating,
        'comment': comment,
      });
      return true;
    } catch (e) {
      print('❌ Error submitting review: $e');
      return false;
    }
  }

  Future<bool> submitRecipe(Map<String, dynamic> recipeData) async {
    try {
      await _apiService.post('/submissions/create/', recipeData);
      return true;
    } catch (e) {
      print('❌ Error submitting recipe: $e');
      return false;
    }
  }

  // Clear cache
  void clearCache() {
    _cachedRecipes.clear();
    _cachedCategories.clear();
    _lastFetchTime = null;
    print('🧹 Cache cleared');
  }
}
