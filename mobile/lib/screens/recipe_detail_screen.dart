import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/recipe.dart';
import '../models/review.dart';
import '../services/recipe_service.dart';
import '../services/auth_service.dart';
import '../utils/app_themes.dart';
import '../providers/favorites_provider.dart';
import '../widgets/offline_banner.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final RecipeService _recipeService = RecipeService();
  late Recipe _recipe;
  List<Review> _reviews = [];
  bool _isLoading = true;
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
    if (!mounted) return;
    if (recipeData != null) setState(() => _recipe = recipeData);

    final reviews = await _recipeService.getReviews(_recipe.id);
    if (!mounted) return;
    setState(() => _reviews = reviews);

    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isAuthenticated) {
      final favProvider =
          Provider.of<FavoritesProvider>(context, listen: false);
      if (favProvider.favoriteIds.isEmpty) {
        await favProvider.loadFavorites();
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _toggleFavorite() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to save favorites')),
      );
      return;
    }

    final favProvider = Provider.of<FavoritesProvider>(context, listen: false);
    await favProvider.toggleFavorite(_recipe);

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(favProvider.isFavorite(_recipe.id)
            ? 'Added to favorites'
            : 'Removed from favorites'),
      ),
    );
  }

  Future<void> _submitReviewWithRating(String reviewText) async {
    if (_userRating == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final success = await _recipeService.submitReview(
      _recipe.id,
      _userRating,
      reviewText,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted!'),
          backgroundColor: Colors.green,
        ),
      );
      _reviewController.clear();
      setState(() => _userRating = 0);
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit review'),
          backgroundColor: Colors.red,
        ),
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
              : Column(
                  children: [
                    const OfflineBanner(),
                    Expanded(
                      child: CustomScrollView(
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
                            _recipe.imageUrl != null &&
                                    _recipe.imageUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: _recipe.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
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
                                    Colors.black.withValues(alpha: 0.6),
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
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      fontSize: 14,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 6,
                                          color: Colors.black45,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_recipe.isAnyTime) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.restaurant_menu,
                                          size: 13,
                                          color: Colors.white70,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _recipe.mealTypesDisplay,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.8),
                                            fontSize: 13,
                                            shadows: const [
                                              Shadow(
                                                blurRadius: 6,
                                                color: Colors.black45,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                                  itemBuilder: (context, _) => const Icon(
                                      Icons.star,
                                      color: Colors.amber),
                                  itemCount: 5,
                                  itemSize: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_recipe.averageRating} (${_recipe.totalReviews} reviews)',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Time & Difficulty Chips
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildInfoChip(context, Icons.timer,
                                    _recipe.preparationTimeDisplay, 'Prep'),
                                _buildInfoChip(context, Icons.timer,
                                    _recipe.cookingTimeDisplay, 'Cook'),
                                _buildInfoChip(context, Icons.people,
                                    '${_recipe.servings}', 'Servings'),
                                _buildInfoChip(context, Icons.fitness_center,
                                    _recipe.difficulty, 'Difficulty'),
                              ],
                            ),
                            if (_recipe.videoUrl != null &&
                                _recipe.videoUrl!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _watchVideo(_recipe.videoUrl!),
                                  icon: const Icon(Icons.play_circle_outline),
                                  label: const Text('Watch Video Tutorial'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange.shade800,
                                    side: BorderSide(color: Colors.orange.shade300),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Description
                            const Text(
                              'Description',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(_recipe.description),
                            const SizedBox(height: 16),

                            // Cultural Information
                            if (_recipe.culturalInfo.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: context.appColors.chipBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: context.appColors.chipBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.history_edu,
                                            color: context.appColors.chipFg),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Cultural Information',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: context.appColors.chipFg,
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
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...(_recipe.ingredients).map((ingredient) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        size: 18, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(ingredient.toString())),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 16),

                            // Instructions
                            const Text(
                              'Instructions',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...(_recipe.instructions)
                                .asMap()
                                .entries
                                .map((entry) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
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
                                    Expanded(
                                        child: Text(entry.value.toString())),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 24),

                            // Reviews Section
                            const Text(
                              'Reviews',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => _showReviewBottomSheet(),
                              icon: const Icon(Icons.rate_review),
                              label: const Text('Write a Review'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.orange.shade800
                                        : Colors.orange,
                                foregroundColor:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_reviews.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text(
                                      'No reviews yet. Be the first to review!'),
                                ),
                              )
                            else
                              ..._reviews.map(
                                  (review) => _buildReviewCard(context, review)),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      );
      },
    );
  }

  Future<void> _watchVideo(String url) async {
    final uri = Uri.tryParse(url);
    final launched = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the video link.')),
      );
    }
  }

  Widget _buildInfoChip(
      BuildContext context, IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.appColors.iconCircleBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: context.appColors.iconCircleFg),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(BuildContext context, Review review) {
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
                      ? CachedNetworkImageProvider(review.userProfilePicture!)
                      : null,
                  child: review.userProfilePicture == null
                      ? Text(
                          review.userName.isNotEmpty
                              ? review.userName[0].toUpperCase()
                              : '?')
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
                        itemBuilder: (context, _) =>
                            const Icon(Icons.star, color: Colors.amber),
                        itemCount: 5,
                        itemSize: 14,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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

  void _showReviewBottomSheet() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to write a review')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Write a Review',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Center(
                child: RatingBar.builder(
                  initialRating: _userRating.toDouble(),
                  minRating: 1,
                  direction: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, _) =>
                      const Icon(Icons.star, color: Colors.amber),
                  onRatingUpdate: (rating) {
                    _userRating = rating.toInt();
                    setSheetState(() {});
                  },
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _reviewController,
                decoration: const InputDecoration(
                  hintText: 'Share your experience...',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final reviewText = _reviewController.text;
                    Navigator.pop(sheetContext);
                    _submitReviewWithRating(reviewText);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness ==
                            Brightness.dark
                        ? Colors.orange.shade800
                        : Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit Review',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
