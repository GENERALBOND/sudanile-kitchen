import 'package:flutter/material.dart';
import '../services/recipe_service.dart';
import '../models/recipe.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialCategory;
  
  const SearchScreen({Key? key, this.initialCategory}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final RecipeService _recipeService = RecipeService();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  List<Category> _categories = [];
  List<Recipe> _allRecipes = [];
  List<Recipe> _filteredRecipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final categories = await _recipeService.getCategories();
    final recipes = await _recipeService.getRecipes();
    
    setState(() {
      _categories = categories;
      _allRecipes = recipes;
      _filteredRecipes = recipes;
      if (_selectedCategory != null) {
        _filterRecipes();
      }
      _isLoading = false;
    });
  }

  void _filterRecipes() {
    setState(() {
      _filteredRecipes = _allRecipes.where((recipe) {
        final matchesSearch = _searchController.text.isEmpty ||
            recipe.title.toLowerCase().contains(_searchController.text.toLowerCase());
        final matchesCategory = _selectedCategory == null ||
            recipe.categoryName == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _searchController.clear();
      _filteredRecipes = _allRecipes;
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
                hintText: 'Search recipes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterRecipes();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => _filterRecipes(),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filters
                if (_categories.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _selectedCategory == null,
                          onSelected: (_) {
                            setState(() => _selectedCategory = null);
                            _filterRecipes();
                          },
                        ),
                        const SizedBox(width: 8),
                        ..._categories.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(cat.name),
                            selected: _selectedCategory == cat.name,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = selected ? cat.name : null;
                                _filterRecipes();
                              });
                            },
                            selectedColor: Colors.orange.shade100,
                          ),
                        )),
                        if (_selectedCategory != null)
                          FilterChip(
                            label: const Text('Clear'),
                            onSelected: (_) => _clearFilters(),
                            backgroundColor: Colors.red.shade100,
                            labelStyle: TextStyle(color: Colors.red.shade700),
                          ),
                      ],
                    ),
                  ),
                
                // Results
                Expanded(
                  child: _filteredRecipes.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('No recipes found'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredRecipes.length,
                          itemBuilder: (context, index) {
                            final recipe = _filteredRecipes[index];
                            return RecipeCard(
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
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
