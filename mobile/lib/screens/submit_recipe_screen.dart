import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/recipe_service.dart';
import '../services/auth_service.dart';
import '../models/recipe.dart';
import 'login_screen.dart';

class SubmitRecipeScreen extends StatefulWidget {
  const SubmitRecipeScreen({super.key});

  @override
  State<SubmitRecipeScreen> createState() => _SubmitRecipeScreenState();
}

class _SubmitRecipeScreenState extends State<SubmitRecipeScreen> {
  final RecipeService _recipeService = RecipeService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _culturalInfoController = TextEditingController();
  final _prepHoursController = TextEditingController();
  final _prepMinutesController = TextEditingController();
  final _prepSecondsController = TextEditingController();
  final _cookHoursController = TextEditingController();
  final _cookMinutesController = TextEditingController();
  final _cookSecondsController = TextEditingController();
  final _servingsController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _instructionsController = TextEditingController();

  static const Set<String> _allowedImageMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
  };

  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  String? _imageError;

  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  bool _submitted = false;
  String _selectedDifficulty = 'medium';

  @override
  void initState() {
    super.initState();
    _loadCategories();
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

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await _recipeService.getCategories();
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      log('Error loading categories: $e');
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _submitRecipe() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to submit a recipe')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final ingredients = _ingredientsController.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final instructions = _instructionsController.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (ingredients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one ingredient')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      if (instructions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one instruction')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // Parse time values safely
      int prepHours = int.tryParse(_prepHoursController.text) ?? 0;
      int prepMinutes = int.tryParse(_prepMinutesController.text) ?? 0;
      int prepSeconds = int.tryParse(_prepSecondsController.text) ?? 0;
      int cookHours = int.tryParse(_cookHoursController.text) ?? 0;
      int cookMinutes = int.tryParse(_cookMinutesController.text) ?? 0;
      int cookSeconds = int.tryParse(_cookSecondsController.text) ?? 0;
      int servings = int.tryParse(_servingsController.text) ?? 4;

      final recipeData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'cultural_info': _culturalInfoController.text.trim(),
        'ingredients': ingredients,
        'instructions': instructions,
        'prep_hours': prepHours,
        'prep_minutes': prepMinutes,
        'prep_seconds': prepSeconds,
        'cook_hours': cookHours,
        'cook_minutes': cookMinutes,
        'cook_seconds': cookSeconds,
        'servings': servings,
        'difficulty': _selectedDifficulty,
        'category_name': _selectedCategory!.name,
        'video_url': _videoUrlController.text.trim().isNotEmpty
            ? _videoUrlController.text.trim()
            : null,
      };

      final currentContext = context;
      final messenger = ScaffoldMessenger.of(currentContext);
      log('📤 Submitting recipe: $recipeData');

      final success = _pickedImage != null
          ? await _recipeService.submitRecipeWithImage(
              recipeData, _pickedImage!)
          : await _recipeService.submitRecipe(recipeData);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        setState(() => _submitted = true);
        messenger.showSnackBar(
          const SnackBar(content: Text('Recipe submitted successfully!')),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Failed to submit recipe. Please try again.')),
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
    if (_submitted) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Submit Recipe'),
          backgroundColor: Colors.orange,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 16),
              const Text('Recipe Submitted!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Your recipe is pending review.',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _submitted = false;
                    _titleController.clear();
                    _descriptionController.clear();
                    _culturalInfoController.clear();
                    _ingredientsController.clear();
                    _instructionsController.clear();
                    _prepHoursController.clear();
                    _prepMinutesController.clear();
                    _prepSecondsController.clear();
                    _cookHoursController.clear();
                    _cookMinutesController.clear();
                    _cookSecondsController.clear();
                    _servingsController.clear();
                    _videoUrlController.clear();
                    _pickedImage = null;
                    _pickedImageBytes = null;
                    _imageError = null;
                    _selectedCategory = null;
                    _selectedDifficulty = 'medium';
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Submit Another Recipe'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Recipe'),
        backgroundColor: Colors.orange,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Recipe Title *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Cultural Information
                    TextFormField(
                      controller: _culturalInfoController,
                      decoration: const InputDecoration(
                        labelText: 'Cultural Information',
                        hintText:
                            'Historical background, cultural significance...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),

                    // Category Dropdown
                    _isLoadingCategories
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : DropdownButtonFormField<Category>(
                            initialValue: _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category *',
                              border: OutlineInputBorder(),
                            ),
                            items: _categories.map((category) {
                              return DropdownMenuItem<Category>(
                                value: category,
                                child: Text(category.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value;
                              });
                            },
                            validator: (value) => value == null
                                ? 'Please select a category'
                                : null,
                          ),
                    const SizedBox(height: 16),

                    // Time & Servings Section
                    const Text(
                      'Time & Servings',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Preparation Time
                    const Text('Preparation Time',
                        style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _prepHoursController,
                            decoration: const InputDecoration(
                              labelText: 'Hours',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _prepMinutesController,
                            decoration: const InputDecoration(
                              labelText: 'Minutes',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _prepSecondsController,
                            decoration: const InputDecoration(
                              labelText: 'Seconds',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Cooking Time
                    const Text('Cooking Time', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cookHoursController,
                            decoration: const InputDecoration(
                              labelText: 'Hours',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _cookMinutesController,
                            decoration: const InputDecoration(
                              labelText: 'Minutes',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _cookSecondsController,
                            decoration: const InputDecoration(
                              labelText: 'Seconds',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Servings and Difficulty
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _servingsController,
                            decoration: const InputDecoration(
                              labelText: 'Servings *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedDifficulty,
                            decoration: const InputDecoration(
                              labelText: 'Difficulty',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'easy', child: Text('Easy')),
                              DropdownMenuItem(
                                  value: 'medium', child: Text('Medium')),
                              DropdownMenuItem(
                                  value: 'hard', child: Text('Hard')),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedDifficulty = value!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Ingredients
                    const Text(
                      'Ingredients * (one per line)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _ingredientsController,
                      decoration: const InputDecoration(
                        hintText: '2 cups flour\n1 tsp salt\n1 tbsp oil',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Instructions
                    const Text(
                      'Instructions * (one per line)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _instructionsController,
                      decoration: const InputDecoration(
                        hintText:
                            'Step 1: Mix flour and water\nStep 2: Knead the dough\nStep 3: Bake',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Media Section
                    const Text(
                      'Media (Optional)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Image upload picker
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 160,
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
                                    size: 40,
                                    color: Colors.orange.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Add a photo',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'JPEG, PNG, or GIF',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
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
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _videoUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Video URL',
                        hintText: 'https://www.youtube.com/watch?v=...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitRecipe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Submit Recipe',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Info Text
                    const Text(
                      'Your recipe will be reviewed by our team before being published.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
