import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/recipe_service.dart';

class SubmitRecipeScreen extends StatefulWidget {
  const SubmitRecipeScreen({Key? key}) : super(key: key);

  @override
  State<SubmitRecipeScreen> createState() => _SubmitRecipeScreenState();
}

class _SubmitRecipeScreenState extends State<SubmitRecipeScreen> {
  final RecipeService _recipeService = RecipeService();
  final _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _culturalInfoController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _categoryNameController = TextEditingController();  // Fixed: added controller
  
  String _difficulty = 'medium';
  List<Map<String, String>> _ingredients = [];
  List<String> _instructions = [];
  
  bool _isSubmitting = false;

  void _addIngredient() {
    setState(() {
      _ingredients.add({'amount': '', 'name': ''});
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  void _addInstruction() {
    setState(() {
      _instructions.add('');
    });
  }

  void _removeInstruction(int index) {
    setState(() {
      _instructions.removeAt(index);
    });
  }

  Future<void> _submitRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one ingredient')),
      );
      return;
    }
    
    if (_instructions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one instruction')),
      );
      return;
    }
    
    if (_categoryNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category')),
      );
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    final ingredientsList = _ingredients.map((i) => "${i['amount']} ${i['name']}").toList();
    
    final recipeData = {
      'title': _titleController.text,
      'description': _descriptionController.text,
      'ingredients': ingredientsList,
      'instructions': _instructions,
      'cultural_info': _culturalInfoController.text,
      'preparation_time': int.parse(_prepTimeController.text),
      'cooking_time': int.parse(_cookTimeController.text),
      'servings': int.parse(_servingsController.text),
      'difficulty': _difficulty,
      'image_url': _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null,
      'video_url': _videoUrlController.text.isNotEmpty ? _videoUrlController.text : null,
      'category_name': _categoryNameController.text,
    };
    
    final success = await _recipeService.submitRecipe(recipeData);
    
    setState(() => _isSubmitting = false);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe submitted for review!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit recipe. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Recipe'),
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Basic Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Recipe Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Please enter title' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) => value?.isEmpty ?? true ? 'Please enter description' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _culturalInfoController,
                      decoration: const InputDecoration(
                        labelText: 'Cultural Information (Optional)',
                        hintText: 'Historical background, cultural significance...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _categoryNameController,  // Fixed: using controller now
                      decoration: const InputDecoration(
                        labelText: 'Category (e.g., Main Dish, Stew, Bread)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Please enter category' : null,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    const Text('Time & Servings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _prepTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Prep Time (minutes)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cookTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Cook Time (minutes)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _servingsController,
                            decoration: const InputDecoration(
                              labelText: 'Servings',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    DropdownButtonFormField<String>(
                      value: _difficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                      ],
                      onChanged: (value) => setState(() => _difficulty = value!),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Ingredients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.orange),
                          onPressed: _addIngredient,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._ingredients.asMap().entries.map((entry) {
                      int index = entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: entry.value['amount'],
                                decoration: const InputDecoration(
                                  hintText: 'Amount (e.g., 2 cups)',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  _ingredients[index]['amount'] = value;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: entry.value['name'],
                                decoration: const InputDecoration(
                                  hintText: 'Ingredient',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  _ingredients[index]['name'] = value;
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeIngredient(index),
                            ),
                          ],
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.orange),
                          onPressed: _addInstruction,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._instructions.asMap().entries.map((entry) {
                      int index = entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: entry.value,
                                decoration: const InputDecoration(
                                  hintText: 'Step description',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  _instructions[index] = value;
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeInstruction(index),
                            ),
                          ],
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 24),
                    
                    const Text('Media (Optional)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Image URL',
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _videoUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Video URL',
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    ElevatedButton(
                      onPressed: _submitRecipe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Submit Recipe for Review', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 16),
                    
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
