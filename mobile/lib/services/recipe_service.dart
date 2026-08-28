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

  // Guards the one-at-a-time guarantee for the background catalog prefetch.
  bool _prefetching = false;
  static bool _prefetchScheduled = false;

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

      // Merge this page into the persistent pool so filters / search / sort
      // still work offline over recipes the user has already seen.
      await _mergePool(recipes);

      ConnectivityService.instance.reportNetworkOk();
      return recipes;
    } catch (e) {
      log('❌ Error fetching recipes: $e');
      ConnectivityService.instance.reportNetworkError();
      // Exact query-keyed snapshot first (fast path, byte-identical to what
      // was originally served online)...
      final exact =
          _cachedList<Recipe>('recipe', key: cacheKey, fromJson: Recipe.fromJson);
      if (exact.isNotEmpty) return exact;
      // ...otherwise apply the requested category/difficulty/meal/search/sort
      // locally to the persistent recipe pool so filters respond offline even
      // for combinations that were never fetched before.
      final pool = _readPool();
      if (pool.isNotEmpty) {
        final filtered = _filterLocally(pool,
            category: category,
            difficulty: difficulty,
            search: search,
            mealTypes: mealTypes);
        return _pageList(_sortLocally(filtered, ordering), page);
      }
      return const [];
    }
  }

  /// The full set of recipes currently persisted for offline use — the merged
  /// pool of everything fetched this session or earlier sessions.
  Future<List<Recipe>> getCachedRecipes() async => _readPool();

  /// Fetches every page of the published recipe catalog and merges it into
  /// the offline pool, rooting off the DRF `count` returned by page 1 (so the
  /// whole catalog is browsable/filterable offline, not just what was seen).
  /// Background fire-and-forget: partial results are fine on failure, and it
  /// never touches the offline banner — the app's regular requests already
  /// report real connectivity problems.
  Future<void> prefetchAllForOffline() async {
    if (_prefetching) return;
    _prefetching = true;
    var fetched = 0;
    try {
      final first = await _apiService.get('/recipes/?page=1');

      // Unpaginated fallback — shouldn't happen with DRF settings, but be safe.
      List<dynamic> results;
      if (first is List) {
        results = first;
      } else if (first is Map && first['results'] is List) {
        results = first['results'] as List;
      } else {
        results = const [];
      }
      if (results.isEmpty) return;

      await _absorbPage(results);
      fetched += results.length;

      final count = first is Map ? (first['count'] as num?)?.toInt() ?? 0 : 0;
      final pageSize = results.length;
      final totalPages = count > 0 ? (count / pageSize).ceil() : 1;

      for (var page = 2; page <= totalPages; page++) {
        final response = await _apiService.get('/recipes/?page=$page');
        final items = response is Map && response['results'] is List
            ? response['results'] as List
            : <dynamic>[];
        if (items.isEmpty) break;
        await _absorbPage(items);
        fetched += items.length;
        if (fetched >= count) break;
      }
      log('🗄️ Prefetched $fetched recipes for offline use');
    } catch (e) {
      // Transient failure mid-sync is fine — keep whatever pages made it.
      log('❌ Recipe prefetch incomplete at $fetched: $e');
    } finally {
      _prefetching = false;
    }
  }

  /// Merges a fetched page's recipes into the pool and caches each detail so
  /// tapping any recipe works offline too.
  Future<void> _absorbPage(List<dynamic> results) async {
    final recipes = results
        .map((json) => Recipe.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
    for (final recipe in recipes) {
      await CacheService.instance.writeJson('recipe', recipe.id, recipe.toJson());
    }
    await _mergePool(recipes);
  }

  /// Syncs the full catalog the first time the app is online in this session.
  /// Safe to call at startup: if the device is offline it simply waits until
  /// connectivity returns, then runs [prefetchAllForOffline] once.
  static void prefetchWhenOnline() {
    if (_prefetchScheduled) return;
    _prefetchScheduled = true;

    void maybeStart() {
      if (ConnectivityService.instance.isOffline.value) return;
      ConnectivityService.instance.isOffline.removeListener(maybeStart);
      unawaited(RecipeService().prefetchAllForOffline());
    }

    maybeStart();
    ConnectivityService.instance.isOffline.addListener(maybeStart);
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

  /// Reads the persistent recipe pool (recipes merged from every fetch).
  List<Recipe> _readPool() =>
      _cachedList<Recipe>('recipe', key: 'pool', fromJson: Recipe.fromJson);

  /// Merges a freshly fetched page into the pool, de-duplicated by id so
  /// repeating the same filter never grows it.
  Future<void> _mergePool(List<Recipe> recipes) async {
    if (recipes.isEmpty) return;
    final byId = <int, Recipe>{
      for (final r in _readPool()) r.id: r,
      for (final r in recipes) r.id: r,
    };
    await CacheService.instance.writeList(
      'recipe',
      byId.values.map((r) => r.toJson()).toList(),
      key: 'pool',
    );
  }

  /// Applies the same category/difficulty/meal/search semantics the backend
  /// uses server-side, but locally, so offline results match online ones.
  List<Recipe> _filterLocally(
    List<Recipe> all, {
    String? category,
    String? difficulty,
    String? search,
    String? mealTypes,
  }) {
    var list = all;
    if (category != null) {
      list = list
          .where((r) => r.categoryName.toLowerCase() == category.toLowerCase())
          .toList();
    }
    if (difficulty != null) {
      list = list
          .where((r) => r.difficulty.toLowerCase() == difficulty.toLowerCase())
          .toList();
    }
    if (mealTypes != null) {
      final wanted = mealTypes
          .split(',')
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList();
      if (wanted.isNotEmpty) {
        list = list.where((r) {
          final has = r.mealTypes.map((m) => m.toLowerCase()).toSet();
          return wanted.every((w) => has.contains(w.toLowerCase()));
        }).toList();
      }
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list.where((r) {
        return r.title.toLowerCase().contains(q) ||
            r.description.toLowerCase().contains(q) ||
            r.culturalInfo.toLowerCase().contains(q) ||
            _flattenIngredients(r).contains(q);
      }).toList();
    }
    return list;
  }

  /// Mirrors the backend's OrderingFilter for the orderings the app offers.
  List<Recipe> _sortLocally(List<Recipe> list, String? ordering) {
    final copy = [...list];
    switch (ordering) {
      case 'created_at':
        copy.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case '-created_at':
        copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case '-average_rating':
        copy.sort((a, b) {
          final c = b.averageRating.compareTo(a.averageRating);
          return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
        });
      case '-view_count':
        copy.sort((a, b) {
          final c = b.viewCount.compareTo(a.viewCount);
          return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
        });
      default:
        copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return copy;
  }

  /// Slices a locally-filtered result set into the same page size the app
  /// already uses to detect the last page (`recipes.length < 10`).
  List<Recipe> _pageList(List<Recipe> list, int page, {int pageSize = 10}) {
    final start = (page - 1) * pageSize;
    if (start >= list.length) return [];
    final end = (start + pageSize).clamp(0, list.length);
    return list.sublist(start, end);
  }

  /// Ingredients can be a mix of strings and maps (e.g. an
  /// `{ingredient, amount}` shape) — flatten all of it to text for search.
  String _flattenIngredients(Recipe recipe) => recipe.ingredients
      .map((i) => i is Map ? i.values.join(' ') : i.toString())
      .join(' ')
      .toLowerCase();
}
