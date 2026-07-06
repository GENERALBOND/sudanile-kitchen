import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../models/review.dart';
import '../services/recipe_service.dart';
import '../services/auth_service.dart';
import '../providers/favorites_provider.dart';

class RecipeDetailScreen extends StatefulWidget {
  final dynamic recipe;
  
  const RecipeDetailScreen({Key? key, required this.recipe}) : super(key: key);

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final RecipeService _recipeService = RecipeService();
  late Recipe _recipe;
  List<Review> _reviews = [];
  bool _isLoading = true;
  bool _isReviewing = false;
  int _userRating = 0;
  final TextEditingController _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _loadData();
  }

  Future<void> _loadData() async {
    final recipeData = await _recipeService.getRecipe(_recipe.id);
    if (recipeData != null) setState(() => _recipe = recipeData);
    
    final reviews = await _recipeService.getReviews(_recipe.id);
    setState(() => _reviews = reviews);
    
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isAuthenticated) {
      final favProvider = Provider.of<FavoritesProvider>(context, listen: false);
      if (favProvider.favoriteIds.isEmpty) {
        await favProvider.loadFavorites();
      }
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _toggleFavorite() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to save favorites')),
      );
      return;
    }
    
    final favProvider = Provider.of<FavoritesProvider>(context, listen: false);
    await favProvider.toggleFavorite(_recipe);
    
    setState(() {});
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          favProvider.isFavorite(_recipe.id) 
              ? 'Added to favorites' 
              : 'Removed from favorites'
        ),
      ),
    );
  }

  Future<void> _submitReview() async {
    if (_userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }
    
    setState(() => _isReviewing = true);
    final success = await _recipeService.submitReview(
      _recipe.id,
      _userRating,
      _reviewController.text,
    );
    setState(() => _isReviewing = false);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted!')),
      );
      Navigator.pop(context);
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit review')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, favProvider, child) {
        final isFavorite = favProvider.isFavorite(_recipe.id);
        
        return Scaffold(
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    // Hero Header with Image Background
                    SliverAppBar(
                      expandedHeight: 300,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Background Image
                            _recipe.imageUrl != null && _recipe.imageUrl!.isNotEmpty
                                ? Image.network(
                                    _recipe.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.orange.shade300,
                                      child: const Icon(
                                        Icons.restaurant,
                                        size: 80,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.orange.shade300,
                                    child: const Icon(
                                      Icons.restaurant,
                                      size: 80,
                                      color: Colors.white,
                                    ),
                                  ),
                            // Dark Overlay for text readability
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.6),
                                  ],
                                ),
                              ),
                            ),
                            // Title at bottom
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _recipe.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 10,
                                          color: Colors.black54,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _recipe.categoryName,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 6,
                                          color: Colors.black45,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        title: null, // Remove title from app bar
                      ),
                      actions: [
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: Colors.white,
                          ),
                          onPressed: _toggleFavorite,
                        ),
                      ],
                    ),
                    // Content
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Rating and Info
                            Row(
                              children: [
                                RatingBarIndicator(
                                  rating: _recipe.averageRating,
                                  itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                                  itemCount: 5,
                                  itemSize: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_recipe.averageRating} (${_recipe.totalReviews} reviews)',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Time & Difficulty Chips
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildInfoChip(Icons.timer, _recipe.preparationTimeDisplay, 'Prep'),
                                _buildInfoChip(Icons.timer, _recipe.cookingTimeDisplay, 'Cook'),
                                _buildInfoChip(Icons.people, '${_recipe.servings}', 'Servings'),
                                _buildInfoChip(Icons.fitness_center, _recipe.difficulty, 'Difficulty'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // Description
                            const Text(
                              'Description',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(_recipe.description),
                            const SizedBox(height: 16),
                            
                            // Cultural Information
                            if (_recipe.culturalInfo.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.history_edu, color: Colors.orange.shade700),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Cultural Information',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(_recipe.culturalInfo),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            
                            // Ingredients
                            const Text(
                              'Ingredients',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...(_recipe.ingredients as List).map((ingredient) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, size: 18, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(ingredient.toString())),
                                  ],
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 16),
                            
                            // Instructions
                            const Text(
                              'Instructions',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...(_recipe.instructions as List).asMap().entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${entry.key + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(entry.value.toString())),
                                  ],
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 24),
                            
                            // Reviews Section
                            const Text(
                              'Reviews',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => _showReviewDialog(),
                              icon: const Icon(Icons.rate_review),
                              label: const Text('Write a Review'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_reviews.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text('No reviews yet. Be the first to review!'),
                                ),
                              )
                            else
                              ..._reviews.map((review) => _buildReviewCard(review)),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.orange.shade800),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: review.userProfilePicture != null
                      ? NetworkImage(review.userProfilePicture!)
                      : null,
                  child: review.userProfilePicture == null
                      ? Text(review.userName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      RatingBarIndicator(
                        rating: review.rating.toDouble(),
                        itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                        itemCount: 5,
                        itemSize: 14,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(review.comment),
          ],
        ),
      ),
    );
  }

  void _showReviewDialog() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to write a review')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Write a Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RatingBar.builder(
              initialRating: 0,
              minRating: 1,
              direction: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) => setState(() => _userRating = rating.toInt()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reviewController,
              decoration: const InputDecoration(
                hintText: 'Share your experience...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isReviewing ? null : _submitReview,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: _isReviewing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
