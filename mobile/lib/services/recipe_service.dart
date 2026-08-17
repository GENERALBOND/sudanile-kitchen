import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
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
    String? difficulty,
    String? search,
    String? mealTypes,
    String? ordering,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    try {
      Map<String, String> queryParams = {};
      if (category != null) queryParams['category'] = category;
      if (difficulty != null) queryParams['difficulty'] = difficulty;
      if (search != null) queryParams['search'] = search;
      if (mealTypes != null) queryParams['meal_types'] = mealTypes;
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
      log('❌ Error fetching recipes: $e');
      return [];
    }
  }

  Future<Recipe?> getRecipe(int id) async {
    // Always fetch the live detail so ratings, view counts and any edits are
    // reflected (a cached first-page copy would be stale).
    try {
      final response = await _apiService.get('/recipes/$id/');
      return Recipe.fromJson(response);
    } catch (e) {
      log('❌ Error fetching recipe: $e');
      return null;
    }
  }

  Future<List<Review>> getReviews(int recipeId) async {
    try {
      final response = await _apiService.get('/reviews/recipe/$recipeId/');
      final List<dynamic> data =
          response is List ? response : (response['results'] ?? []);
      return data.map((json) => Review.fromJson(json)).toList();
    } catch (e) {
      log('❌ Error fetching reviews: $e');
      return [];
    }
  }

  Future<List<Category>> getCategories({bool forceRefresh = false}) async {
    // Return cached data if valid
    if (!forceRefresh &&
        _cachedCategories.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      log('📦 Using cached categories');
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

      _cachedCategories =
          categoriesList.map((json) => Category.fromJson(json)).toList();
      log('✅ Categories loaded: ${_cachedCategories.length}');
      return _cachedCategories;
    } catch (e) {
      log('❌ Error fetching categories: $e');
      return _cachedCategories.isNotEmpty ? _cachedCategories : [];
    }
  }

  Future<bool> addToFavorites(int recipeId) async {
    try {
      await _apiService.post('/favorites/add/', {'recipe': recipeId});
      return true;
    } catch (e) {
      log('❌ Error adding to favorites: $e');
      return false;
    }
  }

  Future<bool> removeFromFavorites(int recipeId) async {
    try {
      await _apiService.delete('/favorites/remove/$recipeId/');
      return true;
    } catch (e) {
      log('❌ Error removing from favorites: $e');
      return false;
    }
  }

  Future<bool> isFavorite(int recipeId) async {
    try {
      final favorites = await getFavorites();
      return favorites.any((recipe) => recipe.id == recipeId);
    } catch (e) {
      log('❌ Error checking favorite: $e');
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
      log('❌ Error fetching favorites: $e');
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
      log('❌ Error submitting review: $e');
      return false;
    }
  }

  /// Returns `null` on success, or a user-facing error message on failure
  /// (e.g. the backend's "already submitted" rejection) so callers can show
  /// the real reason instead of a generic retry prompt that causes duplicates.
  Future<String?> submitRecipe(Map<String, dynamic> recipeData) async {
    try {
      await _apiService.post('/submissions/create/', recipeData);
      return null;
    } catch (e) {
      log('❌ Error submitting recipe: $e');
      return _errorMessage(e);
    }
  }

  /// Submits a recipe together with a user-picked image file (JPEG/PNG/GIF)
  /// as a multipart request. Returns `null` on success, or a user-facing
  /// error message on failure.
  Future<String?> submitRecipeWithImage(
      Map<String, dynamic> recipeData, XFile image) async {
    try {
      final fields = <String, String>{};
      recipeData.forEach((key, value) {
        if (value == null) {
          fields[key] = '';
        } else if (value is List || value is Map) {
          fields[key] = json.encode(value);
        } else {
          fields[key] = value.toString();
        }
      });

      final bytes = await image.readAsBytes();
      await _apiService.postMultipart(
        '/submissions/create/',
        fields,
        fileField: 'image',
        fileBytes: bytes,
        filename: image.name,
        fileContentType: _mediaTypeFor(image),
      );
      return null;
    } catch (e) {
      log('❌ Error submitting recipe with image: $e');
      return _errorMessage(e);
    }
  }

  String _errorMessage(Object e) {
    if (e is ApiException) return e.message;
    return e.toString().replaceFirst('Exception: ', '');
  }

  MediaType _mediaTypeFor(XFile image) {
    final mime = image.mimeType;
    if (mime != null) {
      final parts = mime.split('/');
      if (parts.length == 2) return MediaType(parts[0], parts[1]);
    }
    final name = image.name.toLowerCase();
    if (name.endsWith('.gif')) return MediaType('image', 'gif');
    if (name.endsWith('.png')) return MediaType('image', 'png');
    return MediaType('image', 'jpeg');
  }

  // Clear cache
  void clearCache() {
    _cachedRecipes.clear();
    _cachedCategories.clear();
    _lastFetchTime = null;
    log('🧹 Cache cleared');
  }
}
