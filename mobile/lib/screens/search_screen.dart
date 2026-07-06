import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import '../services/recipe_service.dart';
import '../models/recipe.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialCategory;

  const SearchScreen({super.key, this.initialCategory});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final RecipeService _recipeService = RecipeService();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedDifficulty;
  List<Category> _categories = [];
  List<Recipe> _suggestions = [];
  List<Recipe> _allRecipes = [];
  bool _showSuggestions = false;
  final PagingController<int, Recipe> _pagingController =
      PagingController(firstPageKey: 1);
  String? _currentSearch;
  String? _currentOrdering = '-created_at';
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadAllRecipes();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchRecipes(pageKey);
    });

    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory;
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
    _allRecipes = await _recipeService.getRecipes();
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
        search: _currentSearch,
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

    // Close keyboard
    FocusScope.of(context).unfocus();
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
                fillColor: Colors.white,
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
                  selected:
                      _selectedCategory == null && _selectedDifficulty == null,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = null;
                      _selectedDifficulty = null;
                      _pagingController.refresh();
                    });
                  },
                ),
                const SizedBox(width: 8),
                if (_selectedCategory != null ||
                    _selectedDifficulty != null ||
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

          // Suggestions List (appears when typing)
          if (_showSuggestions && _suggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(
                maxHeight: 300,
              ),
              color: Colors.white,
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
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                  noItemsFoundIndicatorBuilder: (_) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No recipes found',
                            style: TextStyle(fontSize: 18)),
                        Text('Try adjusting your search',
                            style: TextStyle(color: Colors.grey)),
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
