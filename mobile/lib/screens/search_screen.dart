import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../services/recipe_service.dart';
import '../services/search_history_service.dart';
import '../models/recipe.dart';
import '../widgets/recipe_card.dart';
import '../utils/meal_types.dart';
import 'recipe_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialMeal;

  const SearchScreen({super.key, this.initialCategory, this.initialMeal});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final RecipeService _recipeService = RecipeService();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedDifficulty;
  String? _selectedMeal;
  List<Category> _categories = [];
  List<Recipe> _suggestions = [];
  List<Recipe> _allRecipes = [];
  bool _showSuggestions = false;
  final PagingController<int, Recipe> _pagingController =
      PagingController(firstPageKey: 1);
  String? _currentSearch;
  String? _currentOrdering = '-created_at';
  bool _isLoadingCategories = true;
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadAllRecipes();
    _loadRecentSearches();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchRecipes(pageKey);
    });

    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory;
    }

    if (widget.initialMeal != null) {
      _selectedMeal = widget.initialMeal;
    }

    _searchController.addListener(() {
      _updateSuggestions();
    });
  }

  @override
  void dispose() {
    _pagingController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await _recipeService.getCategories();
    setState(() {
      _categories = categories;
      _isLoadingCategories = false;
    });
  }

  Future<void> _loadAllRecipes() async {
    // Prefer the persisted pool so suggestions also work offline over every
    // recipe the user has seen; fall back to a live fetch when nothing is
    // cached yet (e.g. a brand-new online session).
    final pool = await _recipeService.getCachedRecipes();
    _allRecipes = pool.isNotEmpty
        ? pool
        : await _recipeService.getRecipes();
  }

  Future<void> _loadRecentSearches() async {
    final history = await SearchHistoryService.getHistory();
    if (!mounted) return;
    setState(() => _recentSearches = history);
  }

  void _updateSuggestions() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    // First, match recipes that start with the typed letters
    final startsWith = _allRecipes.where((recipe) {
      return recipe.title.toLowerCase().startsWith(query) ||
          recipe.categoryName.toLowerCase().startsWith(query);
    }).toList();

    // Then, match recipes that contain the typed letters anywhere
    final contains = _allRecipes.where((recipe) {
      return (recipe.title.toLowerCase().contains(query) ||
              recipe.categoryName.toLowerCase().contains(query)) &&
          !startsWith.contains(recipe);
    }).toList();

    // Combine: starts with first, then contains
    final combined = [...startsWith, ...contains];

    // Limit to 10 suggestions
    setState(() {
      _suggestions = combined.take(10).toList();
      _showSuggestions = _suggestions.isNotEmpty;
    });
  }

  Future<void> _fetchRecipes(int pageKey) async {
    try {
      final recipes = await _recipeService.getRecipes(
        category: _selectedCategory,
        difficulty: _selectedDifficulty,
        search: _currentSearch,
        mealTypes: _selectedMeal,
        ordering: _currentOrdering,
        page: pageKey,
      );

      final isLastPage = recipes.length < 10;
      if (isLastPage) {
        _pagingController.appendLastPage(recipes);
      } else {
        _pagingController.appendPage(recipes, pageKey + 1);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  void _performSearch(String query) {
    setState(() {
      _currentSearch = query.isNotEmpty ? query : null;
      _showSuggestions = false;
      _pagingController.refresh();
    });

    if (query.trim().isNotEmpty) {
      SearchHistoryService.addSearch(query).then((_) => _loadRecentSearches());
    }

    // Close keyboard
    FocusScope.of(context).unfocus();
  }

  void _searchFromHistory(String query) {
    _searchController.text = query;
    _performSearch(query);
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _suggestions = [];
      _showSuggestions = false;
      _currentSearch = null;
      _pagingController.refresh();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedDifficulty = null;
      _selectedMeal = null;
      _currentOrdering = '-created_at';
      _currentSearch = null;
      _searchController.clear();
      _suggestions = [];
      _showSuggestions = false;
      _pagingController.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Recipes'),
        backgroundColor: Colors.orange,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, ingredient, or keyword...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) => _performSearch(value),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Categories and Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null &&
                      _selectedDifficulty == null &&
                      _selectedMeal == null,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = null;
                      _selectedDifficulty = null;
                      _selectedMeal = null;
                      _pagingController.refresh();
                    });
                  },
                ),
                const SizedBox(width: 8),
                if (_selectedCategory != null ||
                    _selectedDifficulty != null ||
                    _selectedMeal != null ||
                    _currentOrdering != '-created_at')
                  FilterChip(
                    label: const Text('Clear Filters'),
                    onSelected: (_) => _clearFilters(),
                    backgroundColor: Colors.red.shade100,
                    labelStyle: TextStyle(color: Colors.red.shade700),
                  ),
                const SizedBox(width: 8),
                if (!_isLoadingCategories && _categories.isNotEmpty)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      setState(() {
                        _selectedCategory = value == 'All' ? null : value;
                        _pagingController.refresh();
                      });
                    },
                    child: Chip(
                      label: Text(_selectedCategory ?? 'Category'),
                      avatar: const Icon(Icons.category, size: 18),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'All', child: Text('All Categories')),
                      ..._categories.map((cat) => PopupMenuItem(
                            value: cat.name,
                            child: Text(cat.name),
                          )),
                    ],
                  ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _selectedDifficulty = value == 'All' ? null : value;
                      _pagingController.refresh();
                    });
                  },
                  child: Chip(
                    label: Text(_selectedDifficulty ?? 'Difficulty'),
                    avatar: const Icon(Icons.fitness_center, size: 18),
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                        value: 'All', child: Text('All Difficulties')),
                    PopupMenuItem(value: 'easy', child: Text('Easy')),
                    PopupMenuItem(value: 'medium', child: Text('Medium')),
                    PopupMenuItem(value: 'hard', child: Text('Hard')),
                  ],
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _selectedMeal = value == 'All' ? null : value;
                      _pagingController.refresh();
                    });
                  },
                  child: Chip(
                    label: Text(
                      _selectedMeal == null
                          ? 'Meal'
                          : mealLabel(_selectedMeal!) ?? 'Meal',
                    ),
                    avatar: const Icon(Icons.restaurant_menu, size: 18),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'All', child: Text('All Meals')),
                    ...mealTypeOptions.map((option) => PopupMenuItem(
                          value: option.key,
                          child: Text(option.label),
                        )),
                  ],
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      _currentOrdering = value;
                      _pagingController.refresh();
                    });
                  },
                  child: Chip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_getSortLabel()),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                    avatar: const Icon(Icons.sort, size: 18),
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                        value: '-created_at', child: Text('Newest First')),
                    PopupMenuItem(
                        value: 'created_at', child: Text('Oldest First')),
                    PopupMenuItem(
                        value: '-average_rating', child: Text('Highest Rated')),
                    PopupMenuItem(
                        value: '-view_count', child: Text('Most Viewed')),
                  ],
                ),
              ],
            ),
          ),

          // Recent Searches (shown before the user starts typing)
          if (!_showSuggestions &&
              _searchController.text.isEmpty &&
              _recentSearches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Recent Searches',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _recentSearches
                        .map((term) => ActionChip(
                              avatar: const Icon(Icons.history, size: 16),
                              label: Text(term),
                              onPressed: () => _searchFromHistory(term),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

          // Suggestions List (appears when typing)
          if (_showSuggestions && _suggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(
                maxHeight: 300,
              ),
              color: Theme.of(context).cardColor,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final recipe = _suggestions[index];
                  return ListTile(
                    leading: const Icon(Icons.restaurant, color: Colors.orange),
                    title: Text(
                      recipe.title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      recipe.categoryName,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star,
                            size: 16, color: Colors.amber.shade700),
                        const SizedBox(width: 4),
                        Text(
                          recipe.averageRating.toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    onTap: () {
                      // Navigate to recipe detail
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecipeDetailScreen(recipe: recipe),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

          // Results with Lazy Loading
          if (!_showSuggestions)
            Expanded(
              child: PagedListView<int, Recipe>(
                pagingController: _pagingController,
                builderDelegate: PagedChildBuilderDelegate<Recipe>(
                  itemBuilder: (context, recipe, index) => RecipeCard(
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
                  firstPageProgressIndicatorBuilder: (_) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  newPageProgressIndicatorBuilder: (_) => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  noItemsFoundIndicatorBuilder: (_) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                        const SizedBox(height: 16),
                        const Text('No recipes found',
                            style: TextStyle(fontSize: 18)),
                        Text('Try adjusting your search',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getSortLabel() {
    switch (_currentOrdering) {
      case '-created_at':
        return 'Newest';
      case 'created_at':
        return 'Oldest';
      case '-average_rating':
        return 'Top Rated';
      case '-view_count':
        return 'Popular';
      default:
        return 'Sort';
    }
  }
}
