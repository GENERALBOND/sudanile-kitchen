import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../models/recipe.dart';
import '../models/recipe_submission.dart';
import '../models/review.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

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

    final cacheKey = _queryKey(queryParams);

    try {
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

      // Persist this page + each recipe's detail so the same view works
      // fully offline (list render AND tapping into a recipe detail).
      await CacheService.instance.writeList(
        'recipe',
        recipes.map((r) => r.toJson()).toList(),
        key: cacheKey,
      );
      for (final recipe in recipes) {
        await CacheService.instance
            .writeJson('recipe', recipe.id, recipe.toJson());
      }

      ConnectivityService.instance.reportNetworkOk();
      return recipes;
    } catch (e) {
      log('❌ Error fetching recipes: $e');
      ConnectivityService.instance.reportNetworkError();
      return _cachedList<Recipe>('recipe', key: cacheKey, fromJson: Recipe.fromJson);
    }
  }

  Future<Recipe?> getRecipe(int id) async {
    // Always try the live detail first so ratings, view counts and any edits
    // are reflected; only fall back to the persisted copy when the network
    // is unavailable.
    try {
      final response = await _apiService.get('/recipes/$id/');
      final recipe = Recipe.fromJson(response);
      await CacheService.instance.writeJson('recipe', id, recipe.toJson());
      ConnectivityService.instance.reportNetworkOk();
      return recipe;
    } catch (e) {
      log('❌ Error fetching recipe: $e');
      ConnectivityService.instance.reportNetworkError();
      final cached = CacheService.instance.readJson('recipe', id);
      if (cached != null) {
        log('📦 Using cached recipe detail for $id');
        return Recipe.fromJson(cached);
      }
      return null;
    }
  }

  Future<List<Review>> getReviews(int recipeId) async {
    try {
      final response = await _apiService.get('/reviews/recipe/$recipeId/');
      final List<dynamic> data =
          response is List ? response : (response['results'] ?? []);
      final reviews = data.map((json) => Review.fromJson(json)).toList();
      await CacheService.instance.writeList(
        'review',
        reviews.map((r) => r.toJson()).toList(),
        key: recipeId.toString(),
      );
      ConnectivityService.instance.reportNetworkOk();
      return reviews;
    } catch (e) {
      log('❌ Error fetching reviews: $e');
      ConnectivityService.instance.reportNetworkError();
      return _cachedList<Review>('review',
          key: recipeId.toString(), fromJson: Review.fromJson);
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
      await CacheService.instance.writeList(
        'category',
        _cachedCategories.map((c) => c.toJson()).toList(),
      );
      log('✅ Categories loaded: ${_cachedCategories.length}');
      ConnectivityService.instance.reportNetworkOk();
      return _cachedCategories;
    } catch (e) {
      log('❌ Error fetching categories: $e');
      ConnectivityService.instance.reportNetworkError();
      final cached = _cachedList<Category>('category', fromJson: Category.fromJson);
      if (cached.isNotEmpty) return cached;
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

      // Persist so the Favorites tab is fully browsable offline. The cache is
      // cleared on logout, so this never leaks between accounts.
      await CacheService.instance
          .writeList('favorite', favorites.map((r) => r.toJson()).toList());
      ConnectivityService.instance.reportNetworkOk();
      return favorites;
    } catch (e) {
      log('❌ Error fetching favorites: $e');
      ConnectivityService.instance.reportNetworkError();
      final cached = _cachedList<Recipe>('favorite', fromJson: Recipe.fromJson);
      if (cached.isNotEmpty) return cached;
      return [];
    }
  }

  Future<bool> submitReview(int recipeId, int rating, String comment) async {
    try {
      await _apiService.post('/reviews/recipe/$recipeId/create/', {
        'rating': rating,
        'comment': comment,
      });
      // Drop the stale cached review list so the next (re)load reflects the
      // new review instead of the old snapshot.
      await CacheService.instance
          .removeList('review', key: recipeId.toString());
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

  /// Fetches the signed-in user's recipe submissions with their review status.
  /// Returns an empty list when the request fails (e.g. offline).
  Future<List<RecipeSubmission>> getMySubmissions() async {
    try {
      final response = await _apiService.get('/submissions/');

      List<dynamic> data;
      if (response is List) {
        data = response;
      } else if (response is Map && response['results'] != null) {
        data = response['results'];
      } else {
        data = [];
      }

      final submissions = data
          .map((json) => RecipeSubmission.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();

      await CacheService.instance.writeList(
        'submission',
        submissions.map((s) => s.toJson()).toList(),
      );
      ConnectivityService.instance.reportNetworkOk();
      return submissions;
    } catch (e) {
      log('❌ Error fetching submissions: $e');
      ConnectivityService.instance.reportNetworkError();
      return _cachedList<RecipeSubmission>(
        'submission',
        fromJson: RecipeSubmission.fromJson,
      );
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
    CacheService.instance.clearAll();
  }

  /// Builds a stable cache key from query params (sorted so the same filter
  /// set always maps to the same key regardless of insertion order).
  String _queryKey(Map<String, String> params) {
    final sorted = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => '${e.key}=${e.value}').join('&');
  }

  /// Reads a persisted list as typed models, or `[]` when nothing is cached.
  List<T> _cachedList<T>(
    String collection, {
    String? key,
    required T Function(Map<String, dynamic>) fromJson,
  }) {
    final cached = CacheService.instance.readList(collection, key: key);
    if (cached == null) return [];
    return cached
        .map((json) => fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }
}
