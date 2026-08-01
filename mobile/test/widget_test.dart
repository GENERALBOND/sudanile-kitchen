// Unit tests for the app's model parsing logic — the actual business logic
// in this app, unlike the widget tree which needs a live Firebase session
// to render past the splash screen. See STATUS_REPORT.md for context.
import 'package:flutter_test/flutter_test.dart';
import 'package:sudanile_kitchen/models/recipe.dart';
import 'package:sudanile_kitchen/models/user.dart';

void main() {
  group('Recipe.fromJson', () {
    test('parses a full recipe payload', () {
      final recipe = Recipe.fromJson({
        'id': 1,
        'title': 'Kisra',
        'description': 'Fermented sorghum flatbread',
        'ingredients': ['sorghum flour', 'water'],
        'instructions': ['Mix', 'Ferment', 'Cook'],
        'cultural_info': 'A staple of South Sudanese cuisine',
        'prep_hours': 0,
        'prep_minutes': 20,
        'prep_seconds': 0,
        'cook_hours': 0,
        'cook_minutes': 10,
        'cook_seconds': 0,
        'servings': 4,
        'difficulty': 'medium',
        'image_url': 'https://example.com/kisra.jpg',
        'video_url': 'https://example.com/kisra.mp4',
        'category_name': 'Bread',
        'author_name': 'Chef Amina',
        'average_rating': 4.5,
        'total_reviews': 3,
        'view_count': 42,
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(recipe.id, 1);
      expect(recipe.title, 'Kisra');
      expect(recipe.ingredients, ['sorghum flour', 'water']);
      expect(recipe.averageRating, 4.5);
      expect(recipe.totalTime, 30); // 20 prep + 10 cook minutes
      expect(recipe.totalTimeDisplay, '30m');
    });

    test('falls back to safe defaults for missing optional fields', () {
      final recipe = Recipe.fromJson({'id': 2});

      expect(recipe.title, '');
      expect(recipe.ingredients, isEmpty);
      expect(recipe.servings, 4);
      expect(recipe.difficulty, 'medium');
      expect(recipe.imageUrl, isNull);
      expect(recipe.averageRating, 0.0);
      expect(recipe.totalTime, 0);
    });

    test('totalTimeDisplay switches to hours once past 60 minutes', () {
      final recipe = Recipe.fromJson({
        'id': 3,
        'prep_hours': 1,
        'prep_minutes': 15,
        'cook_hours': 0,
        'cook_minutes': 0,
      });

      expect(recipe.totalTimeDisplay, '1h 15m');
    });
  });

  group('Category.fromJson', () {
    test('parses name and optional fields', () {
      final category = Category.fromJson({
        'id': 5,
        'name': 'Main Dishes',
        'description': 'Hearty mains',
        'icon': null,
      });

      expect(category.id, 5);
      expect(category.name, 'Main Dishes');
      expect(category.description, 'Hearty mains');
    });
  });

  group('User.fromJson', () {
    test('parses profile stats, defaulting missing counts to zero', () {
      final user = User.fromJson({
        'id': 7,
        'username': 'amina',
        'email': 'amina@example.com',
        'role': 'user',
        'bio': '',
        'created_at': '2026-01-01T00:00:00Z',
        'favorites_count': 3,
      });

      expect(user.username, 'amina');
      expect(user.favoritesCount, 3);
      expect(user.reviewsCount, 0);
      expect(user.submissionsCount, 0);
    });
  });
}
