import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/recipe_service.dart';
import '../models/recipe.dart';
import '../providers/favorites_provider.dart';
import 'recipe_detail_screen.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'submit_recipe_screen.dart';
import 'all_categories_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuestMode;

  const HomeScreen({super.key, this.isGuestMode = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RecipeService _recipeService = RecipeService();
  List<Category> _categories = [];
  List<Recipe> _recentRecipes = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Load favorites if user is authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.isAuthenticated) {
        Provider.of<FavoritesProvider>(context, listen: false).loadFavorites();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _recipeService.getCategories(),
        _recipeService.getRecipes(),
      ]);

      final categories = results[0] as List<Category>;
      final allRecipes = results[1] as List<Recipe>;
      final recentRecipes = allRecipes.take(2).toList();

      setState(() {
        _categories = categories;
        _recentRecipes = recentRecipes;
        _isLoading = false;
      });
    } catch (e) {
      log('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isGuest = widget.isGuestMode || !authService.isAuthenticated;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeContent(),
          const SearchScreen(),
          isGuest ? _buildGuestFavorites() : const FavoritesScreen(),
          ProfileScreen(isGuestMode: isGuest),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (isGuest && (index == 2 || index == 3)) {
            _showLoginRequiredDialog();
            return;
          }
          setState(() => _selectedIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (isGuest) {
            _showLoginRequiredDialog();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubmitRecipeScreen()),
            );
          }
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildGuestFavorites() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Favorites'),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Login to save favorites',
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Create an account to save your favorite recipes',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please login to access favorites and profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue as Guest'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading delicious recipes...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.orange.shade400, Colors.orange.shade700],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 10),
                  Text(
                    'Discover South Sudanese Cuisine',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Explore authentic recipes from South Sudan',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Categories
            if (_categories.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Categories',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AllCategoriesScreen()),
                        );
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _categories.length > 4 ? 4 : _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return _buildCategoryCard(category);
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Latest Recipes
            if (_recentRecipes.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Latest Recipes',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SearchScreen()),
                        );
                      },
                      child: const Text('See All'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: _recentRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = _recentRecipes[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(recipe: recipe),
                          ),
                        );
                      },
                      child: _buildRecipeCard(recipe),
                    );
                  },
                ),
              ),
            ],

            // No Recipes Message
            if (_recentRecipes.isEmpty && !_isLoading) ...[
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.no_food, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No Recipes Yet',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Add recipes in the admin panel',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchScreen(initialCategory: category.name),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                _getCategoryIcon(category.name),
                size: 25,
                color: Colors.orange.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Container(
              height: 120,
              width: double.infinity,
              color: Colors.orange.shade100,
              child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                  ? Image.network(
                      recipe.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.restaurant,
                        size: 50,
                        color: Colors.orange,
                      ),
                    )
                  : const Icon(
                      Icons.restaurant,
                      size: 50,
                      color: Colors.orange,
                    ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text(
                        recipe.averageRating.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.access_time,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.totalTime} min',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      recipe.categoryName,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('main') || name.contains('dish')) {
      return Icons.lunch_dining;
    }
    if (name.contains('stew') || name.contains('curry')) {
      return Icons.soup_kitchen;
    }
    if (name.contains('bread') || name.contains('grain')) {
      return Icons.bakery_dining;
    }
    if (name.contains('soup')) {
      return Icons.kitchen;
    }
    if (name.contains('side')) {
      return Icons.eco;
    }
    if (name.contains('beverage')) {
      return Icons.local_cafe;
    }
    if (name.contains('snack')) {
      return Icons.icecream;
    }
    if (name.contains('dessert')) {
      return Icons.cake;
    }
    return Icons.restaurant_menu;
  }
}
