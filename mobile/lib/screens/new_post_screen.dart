import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../providers/community_provider.dart';
import '../services/auth_service.dart';
import '../services/community_service.dart';
import '../services/recipe_service.dart';
import 'login_screen.dart';

class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final CommunityService _communityService = CommunityService();
  final RecipeService _recipeService = RecipeService();
  final TextEditingController _captionController = TextEditingController();

  static const Set<String> _allowedImageMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
  };

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  String? _imageError;

  List<Recipe> _recipes = [];
  Recipe? _selectedRecipe;
  bool _isLoadingRecipes = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  bool _isAllowedImage(XFile file) {
    final mime = file.mimeType?.toLowerCase();
    if (mime != null) return _allowedImageMimeTypes.contains(mime);
    final name = file.name.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.gif');
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;

    if (!_isAllowedImage(file)) {
      setState(() {
        _pickedImage = null;
        _pickedImageBytes = null;
        _imageError = 'Only JPEG, PNG, and GIF images are allowed.';
      });
      return;
    }

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = file;
      _pickedImageBytes = bytes;
      _imageError = null;
    });
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoadingRecipes = true);
    try {
      final recipes = await _recipeService.getRecipes();
      setState(() {
        _recipes = recipes;
        _isLoadingRecipes = false;
      });
    } catch (e) {
      log('Error loading recipes: $e');
      setState(() => _isLoadingRecipes = false);
    }
  }

  Future<void> _submitPost() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to share a post')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo of your dish')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final (post, error) = await _communityService.createPost(
        image: _pickedImage!,
        caption: _captionController.text.trim(),
        recipeId: _selectedRecipe?.id,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (post != null) {
        Provider.of<CommunityProvider>(context, listen: false)
            .prependPost(post);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post shared successfully!')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Failed to share post. Please try again.')),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      log('❌ Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share a Post'),
        backgroundColor: Colors.orange,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image picker
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 260,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: _pickedImageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _pickedImageBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 50,
                                  color: Colors.orange.shade400,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Add a photo of your dish',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'JPEG, PNG, or GIF',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (_pickedImage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: const Text('Change photo'),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _pickedImage = null;
                              _pickedImageBytes = null;
                              _imageError = null;
                            }),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Remove'),
                          ),
                        ],
                      ),
                    ),
                  if (_imageError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _imageError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Caption
                  TextField(
                    controller: _captionController,
                    decoration: const InputDecoration(
                      labelText: 'Caption',
                      hintText: 'Tell us about your dish...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    maxLength: 2000,
                  ),
                  const SizedBox(height: 16),

                  // Optional recipe link
                  const Text(
                    'Did you cook one of our recipes?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _isLoadingRecipes
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.orange),
                          ),
                        )
                      : SearchAnchor(
                          builder: (context, controller) {
                            return InkWell(
                              onTap: () => controller.openView(),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Link a recipe (optional)',
                                  hintText: 'Tap to search',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.search),
                                ),
                                child: _selectedRecipe == null
                                    ? const Text('No recipe linked')
                                    : Text(
                                        _selectedRecipe!.title,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                            );
                          },
                          suggestionsBuilder: (context, controller) {
                            final query = controller.text.trim().toLowerCase();
                            final results = query.isEmpty
                                ? _recipes
                                : _recipes
                                    .where((r) => r.title
                                        .toLowerCase()
                                        .contains(query))
                                    .toList();
                            if (results.isEmpty) {
                              return [
                                const ListTile(
                                  leading: Icon(Icons.search_off),
                                  title: Text('No recipes found'),
                                ),
                              ];
                            }
                            return results.map((recipe) {
                              return ListTile(
                                leading: recipe.imageUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          recipe.imageUrl!,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.restaurant),
                                        ),
                                      )
                                    : const Icon(Icons.restaurant),
                                title: Text(recipe.title),
                                subtitle: recipe.categoryName.isNotEmpty
                                    ? Text(recipe.categoryName,
                                        style:
                                            const TextStyle(fontSize: 12))
                                    : null,
                                onTap: () {
                                  setState(() => _selectedRecipe = recipe);
                                  controller.closeView(recipe.title);
                                },
                              );
                            }).toList();
                          },
                        ),
                  const SizedBox(height: 24),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Share Post',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your post will be visible to the whole community.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
